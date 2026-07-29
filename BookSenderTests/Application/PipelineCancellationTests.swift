import Foundation
import Testing
@testable import BookSender

struct PipelineCancellationTests {
    @Test
    func cancelStopsPendingDeliveryAndPreservesCompletedOutcome() async throws {
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
        let transport = GateSMTPTransport(
            firstOutcome: .submitted,
            blockedDataStarted: false
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
                transport: transport
            ),
            workspaceStore: workspace
        )
        let first = stores.rootURL.appending(component: "First.pdf")
        let second = stores.rootURL.appending(component: "Second.pdf")
        let third = stores.rootURL.appending(component: "Third.pdf")
        for url in [first, second, third] {
            try Data("%PDF-1.7\n\(url.lastPathComponent)\n%%EOF\n".utf8)
                .write(to: url)
        }

        await pipeline.add([first, second, third])
        try await eventually {
            let batch = await pipeline.snapshot()
            return batch.items.count == 3
                && batch.items.allSatisfy { $0.preparation == .ready }
        }
        let summary = try #require(
            await pipeline.confirmation(setup: setup, kind: .initial)
        )
        await pipeline.send(snapshotID: summary.id)
        try await eventually { await transport.blockedAttemptStarted }
        await pipeline.cancel()
        try await eventually { await pipeline.snapshot().phase == .completed }

        let batch = await pipeline.snapshot()
        #expect(batch.items[0].delivery == .submitted)
        #expect(batch.items[1].delivery == .cancelled)
        #expect(batch.items[2].delivery == .cancelled)
        #expect(batch.items.allSatisfy { $0.delivery.isTerminal })
    }

    @Test
    func phaseGuardsPreventMutationWhileConfirmationIsFrozen() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(stores: stores)
        let pipeline = graph.dependencies.pipeline
        let setup = try await graph.dependencies.setupService.save(
            validDraft(),
            replacing: nil
        )
        let pdf = try FixtureFactory.makePDF(valid: true, in: stores.rootURL)
        await pipeline.add([pdf])
        try await eventually {
            await pipeline.snapshot().items.first?
                .preparation == .ready
        }
        let summary = try #require(
            await pipeline.confirmation(
                setup: setup,
                kind: .initial
            )
        )
        let before = await pipeline.snapshot()

        await pipeline.remove(before.items[0].id)
        await pipeline.clear()

        let after = await pipeline.snapshot()
        #expect(after.id == before.id)
        #expect(after.items.count == 1)
        await pipeline.releaseConfirmation(summary.id)
        await pipeline.remove(before.items[0].id)
        #expect((await pipeline.snapshot()).items.isEmpty)
    }

    private func eventually(
        _ condition: @escaping @Sendable () async -> Bool
    ) async throws {
        for _ in 0..<2_000 {
            if await condition() { return }
            await Task.yield()
        }
        throw PipelineCancellationTestError.timeout
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

private actor GateSMTPTransport: SMTPDelivering {
    let firstOutcome: TerminalOutcome
    let blockedDataStarted: Bool
    private var invocation = 0
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var blockedAttemptStarted = false

    init(
        firstOutcome: TerminalOutcome,
        blockedDataStarted: Bool
    ) {
        self.firstOutcome = firstOutcome
        self.blockedDataStarted = blockedDataStarted
    }

    func send(
        book: PreparedBook,
        setup: DeliverySetup,
        credential: String,
        progress: @escaping @Sendable (DeliveryProgress) async -> Void
    ) async -> TerminalOutcome {
        invocation += 1
        if invocation == 1 {
            return firstOutcome
        }
        blockedAttemptStarted = true
        await progress(
            DeliveryProgress(
                stage: blockedDataStarted ? .transmitting : .connecting,
                dataTransmissionStarted: blockedDataStarted
            )
        )
        await withCheckedContinuation { continuation = $0 }
        return blockedDataStarted ? .deliveryUnknown : .cancelled
    }

    func cancelActiveAttempt() {
        continuation?.resume()
        continuation = nil
    }
}

private enum PipelineCancellationTestError: Error {
    case timeout
}
