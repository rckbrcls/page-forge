import Foundation
import Testing
@testable import BookSender

struct PipelineHistoryTests {
    @Test
    func recordsOnlyDefinitiveAcceptancesBeforeBatchCompletion() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(
            stores: stores,
            outcomes: [
                .submitted,
                .failed(sanitizedFailure(.smtpRecipientRejected)),
                .deliveryUnknown(.deliveryUnknown()),
            ]
        )
        let setup = try await graph.dependencies.setupService.save(
            validDraft(),
            replacing: nil
        )
        let urls = try makePDFs(count: 3, in: stores.rootURL)

        await graph.dependencies.pipeline.add(urls)
        try await waitUntilReady(
            graph.dependencies.pipeline,
            count: urls.count
        )
        let confirmation = try #require(
            await graph.dependencies.pipeline.confirmation(
                setup: setup,
                kind: .initial
            )
        )
        await graph.dependencies.pipeline.send(snapshotID: confirmation.id)
        try await waitUntilCompleted(graph.dependencies.pipeline)

        let attempts = await graph.dependencies.pipeline.deliveryAttempts()
        let snapshot = try await graph.dependencies.historyService.snapshot()
        let submittedAttempt = try #require(
            attempts.first { $0.outcome == .submitted }
        )

        #expect(snapshot.records.count == 1)
        #expect(snapshot.records[0].id == submittedAttempt.id)
        #expect(snapshot.records[0].displayName == "History-1.pdf")
        #expect(snapshot.records[0].acceptedAt == submittedAttempt.completedAt)
        #expect(attempts.count == 3)
    }

    @Test
    func repeatedAcceptedSendsWithTheSameNameRemainSeparate() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(
            stores: stores,
            outcomes: [.submitted, .submitted]
        )
        let setup = try await graph.dependencies.setupService.save(
            validDraft(),
            replacing: nil
        )
        let pdf = try #require(makePDFs(count: 1, in: stores.rootURL).first)

        try await send(
            pdf,
            setup: setup,
            through: graph.dependencies.pipeline
        )
        await graph.dependencies.pipeline.clear()
        try await send(
            pdf,
            setup: setup,
            through: graph.dependencies.pipeline
        )

        let records = try await graph.dependencies.historyService.snapshot()
            .records
        #expect(records.count == 2)
        #expect(Set(records.map(\.id)).count == 2)
        #expect(records.allSatisfy { $0.displayName == "History-1.pdf" })
        #expect(
            records[0].acceptedAt >= records[1].acceptedAt
        )
    }

    @Test
    func historyWriteFailureKeepsSubmittedAndNeverRetriesSMTP() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let historyStore = InMemorySendHistoryStore()
        await historyStore.setReplaceFailure(
            HistoryFailure(operation: .record, code: .write)
        )
        let graph = TestDependencyGraph.make(
            stores: stores,
            outcomes: [.submitted],
            historyStore: historyStore
        )
        let setup = try await graph.dependencies.setupService.save(
            validDraft(),
            replacing: nil
        )
        let pipeline = graph.dependencies.pipeline
        let probe = PipelineHistoryEventProbe()
        let observation = Task {
            for await event in pipeline.events {
                await probe.append(event)
            }
        }
        defer { observation.cancel() }
        let pdf = try #require(makePDFs(count: 1, in: stores.rootURL).first)

        try await send(
            pdf,
            setup: setup,
            through: graph.dependencies.pipeline
        )
        try await eventually {
            await probe.historyFailureCount == 1
        }

        let batch = await graph.dependencies.pipeline.snapshot()
        #expect(batch.items.first?.delivery == .submitted)
        #expect(await graph.transport.sentItemIDs.count == 1)
        #expect(try await graph.dependencies.historyService.snapshot().records.isEmpty)
        #expect(await probe.lastHistoryFailure?.code == .write)
    }

    @Test
    func acceptedRecordSurvivesAFreshServiceInstance() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let workspace = WorkspaceStore(
            rootURL: stores.rootURL.appending(component: "work")
        )
        let credentials = InMemoryCredentialStore()
        let preferences = InMemoryPreferencesStore()
        let setupService = DeliverySetupService(
            credentials: credentials,
            preferences: preferences,
            serviceName: stores.keychainServiceName
        )
        let setup = try await setupService.save(validDraft(), replacing: nil)
        let historyService = SendHistoryService(
            store: FileSendHistoryStore(rootURL: stores.historyRootURL)
        )
        let pipeline = PipelineActor(
            intakeService: BookIntakeService(workspaceStore: workspace),
            epubPreparer: EPUBRepairEngine(
                writer: EPUBArchiveWriter(),
                workspaceStore: workspace
            ),
            pdfPreparer: PDFEligibilityService(workspaceStore: workspace),
            deliveryService: BookDeliveryService(
                credentials: credentials,
                transport: StubSMTPTransport(outcomes: [.submitted])
            ),
            workspaceStore: workspace,
            historyService: historyService
        )
        let pdf = try #require(makePDFs(count: 1, in: stores.rootURL).first)

        try await send(pdf, setup: setup, through: pipeline)

        let relaunchedService = SendHistoryService(
            store: FileSendHistoryStore(rootURL: stores.historyRootURL)
        )
        let records = try await relaunchedService.snapshot().records
        #expect(records.count == 1)
        #expect(records[0].displayName == "History-1.pdf")
    }

    private func send(
        _ url: URL,
        setup: ValidatedDeliverySetup,
        through pipeline: PipelineActor
    ) async throws {
        await pipeline.add([url])
        try await waitUntilReady(pipeline, count: 1)
        let confirmation = try #require(
            await pipeline.confirmation(setup: setup, kind: .initial)
        )
        await pipeline.send(snapshotID: confirmation.id)
        try await waitUntilCompleted(pipeline)
    }

    private func waitUntilReady(
        _ pipeline: PipelineActor,
        count: Int
    ) async throws {
        try await eventually {
            let batch = await pipeline.snapshot()
            return batch.items.count == count
                && batch.items.allSatisfy { $0.preparation == .ready }
        }
    }

    private func waitUntilCompleted(_ pipeline: PipelineActor) async throws {
        try await eventually {
            await pipeline.snapshot().phase == .completed
        }
    }

    private func eventually(
        _ condition: @escaping @Sendable () async -> Bool
    ) async throws {
        for _ in 0..<4_000 {
            if await condition() { return }
            await Task.yield()
        }
        throw PipelineHistoryTestError.timeout
    }

    private func makePDFs(count: Int, in directory: URL) throws -> [URL] {
        try (1...count).map { index in
            let url = directory.appending(
                component: "History-\(index).pdf"
            )
            try Data("%PDF-1.7\n\(index)\n%%EOF\n".utf8).write(to: url)
            return url
        }
    }

    private func validDraft() -> DeliverySetupDraft {
        DeliverySetupDraft(
            senderAddress: "sender@example.com",
            smtpHost: "smtp.example.com",
            smtpPort: "465",
            securityMode: .implicitTLS,
            username: "sender",
            appPassword: "secret",
            kindleAddress: "reader@kindle.com"
        )
    }
}

private actor PipelineHistoryEventProbe {
    private var events: [PipelineEvent] = []

    var historyFailureCount: Int {
        events.filter {
            if case .historyPersistenceFailed = $0.kind { return true }
            return false
        }.count
    }

    var lastHistoryFailure: HistoryFailure? {
        events.reversed().compactMap { event -> HistoryFailure? in
            guard case .historyPersistenceFailed(_, let failure) = event.kind
            else {
                return nil
            }
            return failure
        }.first
    }

    func append(_ event: PipelineEvent) {
        events.append(event)
    }
}

private enum PipelineHistoryTestError: Error {
    case timeout
}
