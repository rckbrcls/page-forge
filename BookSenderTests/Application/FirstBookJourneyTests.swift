import Foundation
import Testing
@testable import BookSender

struct FirstBookJourneyTests {
    @Test
    func freezesValueSnapshotAndProducesOneIndependentOutcomePerItem() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(
            stores: stores,
            outcomes: [
                .submitted,
                .failed(sanitizedFailure(.smtpRecipientRejected)),
            ]
        )
        let pipeline = graph.dependencies.pipeline
        let setup = try await graph.dependencies.setupService.save(
            validDraft(),
            replacing: nil
        )
        let first = stores.rootURL.appending(component: "First.pdf")
        let second = stores.rootURL.appending(component: "Second.pdf")
        try Data("%PDF-1.7\nfirst\n%%EOF\n".utf8).write(to: first)
        try Data("%PDF-1.7\nsecond\n%%EOF\n".utf8).write(to: second)
        let recorder = PipelineEventRecorder()
        let eventTask = Task {
            for await event in pipeline.events {
                await recorder.append(event)
            }
        }
        defer { eventTask.cancel() }

        await pipeline.add([first, second])
        try await eventually {
            let batch = await pipeline.snapshot()
            return batch.items.count == 2
                && batch.items.allSatisfy { $0.preparation == .ready }
        }
        let summary = try #require(
            await pipeline.confirmation(
                setup: setup,
                kind: .initial
            )
        )
        let frozen = await pipeline.snapshot()

        #expect(summary.eligibleCount == 2)
        #expect(frozen.activeSnapshot?.eligibleItems.count == 2)
        #expect(frozen.activeSnapshot?.setup.revision == setup.revision)
        await pipeline.remove(frozen.items[0].id)
        #expect((await pipeline.snapshot()).items.count == 2)

        await pipeline.send(snapshotID: summary.id)
        try await eventually {
            let snapshot = await pipeline.snapshot()
            let batchCompletedCount = await recorder.batchCompletedCount
            return snapshot.phase == .completed
                && batchCompletedCount == 1
        }

        let completed = await pipeline.snapshot()
        #expect(completed.items.count == 2)
        #expect(completed.items.filter { $0.delivery.isTerminal }.count == 2)
        #expect(
            completed.items.contains {
                if case .submitted = $0.delivery { return true }
                return false
            }
        )
        #expect(
            completed.items.contains {
                if case .failed = $0.delivery { return true }
                return false
            }
        )
        #expect((await pipeline.deliveryAttempts()).count == 2)
        #expect(await recorder.batchCompletedCount == 1)
        #expect(await recorder.terminalItemEventCount == 2)
    }

    @Test
    @MainActor
    func appModelProjectsActorEventsWithoutPrivatePaths() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(stores: stores)
        let model = AppModel(dependencies: graph.dependencies)
        model.notificationCenter.attach(.main)
        model.setupDraft = validDraft()
        model.saveSetup()
        try await eventuallyMainActor { model.route == .sendBook }
        model.notificationCenter.remove(
            scope: .deliverySetup,
            destination: .main
        )
        let pdf = try FixtureFactory.makePDF(valid: true, in: stores.rootURL)

        model.addBooks([pdf])
        try await eventuallyMainActor {
            model.items.count == 1
                && model.items.first?.preparation == .ready
        }
        #expect(model.feedback(for: .batch)?.state == .succeeded)
        #expect(noMainNotifications(in: model))

        #expect(model.items.first?.displayName == "valid.pdf")
        #expect(String(describing: model.batch).contains(pdf.path) == false)
        #expect(model.eligibleCount == 1)
        model.requestSendConfirmation()
        try await eventuallyMainActor { model.isShowingConfirmation }
        #expect(model.feedback(for: .batch)?.title == "Confirmation ready.")
        #expect(noMainNotifications(in: model))
        #expect(model.confirmation?.eligibleCount == 1)
        model.confirmSend()
        try await eventuallyMainActor {
            model.items.first?.delivery == .submitted
                && model.aggregateMessage == "1 submitted"
        }
        #expect(model.aggregateMessage == "1 submitted")
        #expect(model.feedback(for: .batch)?.state == .succeeded)
        #expect(model.feedback(for: .batch)?.title == "1 book submitted.")
        #expect(noMainNotifications(in: model))
    }

    @Test
    @MainActor
    func removeClearAndDismissExposeTerminalFeedback() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(stores: stores)
        let model = AppModel(dependencies: graph.dependencies)
        model.notificationCenter.attach(.main)
        model.setupDraft = validDraft()
        model.saveSetup()
        try await eventuallyMainActor { model.setup != nil }
        model.notificationCenter.remove(
            scope: .deliverySetup,
            destination: .main
        )
        let pdf = try FixtureFactory.makePDF(valid: true, in: stores.rootURL)
        model.addBooks([pdf])
        try await eventuallyMainActor { model.items.first?.preparation == .ready }
        let id = try #require(model.items.first?.id)

        model.remove(id)
        try await eventuallyMainActor {
            model.items.isEmpty
                && model.feedback(for: .batch)?.title == "Book removed."
        }
        #expect(model.feedback(for: .batch)?.title == "Book removed.")
        #expect(noMainNotifications(in: model))

        model.addBooks([pdf])
        try await eventuallyMainActor { model.items.first?.preparation == .ready }
        model.requestSendConfirmation()
        try await eventuallyMainActor { model.isShowingConfirmation }
        model.dismissConfirmation()
        try await eventuallyMainActor {
            model.feedback(for: .batch)?.title == "Confirmation dismissed."
        }
        #expect(noMainNotifications(in: model))

        model.clear()
        try await eventuallyMainActor {
            model.items.isEmpty
                && model.feedback(for: .batch)?.title == "Batch cleared."
        }
        #expect(model.feedback(for: .batch)?.title == "Batch cleared.")
        #expect(noMainNotifications(in: model))
    }

    @Test
    @MainActor
    func emptyDropAttemptExplainsThatNoSupportedBookWasAdded() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(stores: stores)
        let model = AppModel(dependencies: graph.dependencies)
        model.notificationCenter.attach(.main)

        model.addBooks([])

        #expect(model.feedback(for: .batch)?.state == .failed)
        #expect(
            model.feedback(for: .batch)?.title
                == "No supported books were added."
        )
        #expect(
            model.feedback(for: .batch)?.failure?.code
                == .intakeUnsupported
        )
        #expect(noMainNotifications(in: model))
    }

    @Test
    @MainActor
    func failedOnlyRetryStartsANewFeedbackLifecycle() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(
            stores: stores,
            outcomes: [
                .failed(sanitizedFailure(.smtpRecipientRejected)),
                .submitted,
            ]
        )
        let model = AppModel(dependencies: graph.dependencies)
        model.notificationCenter.attach(.main)
        model.setupDraft = validDraft()
        model.saveSetup()
        try await eventuallyMainActor { model.setup != nil }
        model.notificationCenter.remove(
            scope: .deliverySetup,
            destination: .main
        )
        let pdf = try FixtureFactory.makePDF(valid: true, in: stores.rootURL)
        model.addBooks([pdf])
        try await eventuallyMainActor { model.items.first?.preparation == .ready }
        model.requestSendConfirmation()
        try await eventuallyMainActor { model.isShowingConfirmation }
        model.confirmSend()
        try await eventuallyMainActor {
            model.failedCount == 1
                && model.feedback(for: .batch)?.state == .failed
        }
        let firstFeedback = try #require(model.feedback(for: .batch))
        #expect(firstFeedback.state == .failed)
        #expect(noMainNotifications(in: model))

        model.requestRetryConfirmation()
        try await eventuallyMainActor { model.isShowingConfirmation }
        model.confirmSend()
        try await eventuallyMainActor {
            model.items.first?.delivery == .submitted
                && model.feedback(for: .batch)?.state == .succeeded
        }
        let retryFeedback = try #require(model.feedback(for: .batch))
        #expect(retryFeedback.id != firstFeedback.id)
        #expect(retryFeedback.state == .succeeded)
        #expect(noMainNotifications(in: model))
    }

    private func eventually(
        _ condition: @escaping @Sendable () async -> Bool
    ) async throws {
        for _ in 0..<2_000 {
            if await condition() { return }
            await Task.yield()
        }
        throw JourneyTestError.timeout
    }

    @MainActor
    private func eventuallyMainActor(
        _ condition: @escaping @MainActor () -> Bool
    ) async throws {
        for _ in 0..<2_000 {
            if condition() { return }
            await Task.yield()
        }
        throw JourneyTestError.timeout
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

    @MainActor
    private func noMainNotifications(in model: AppModel) -> Bool {
        NotificationTestFixtures.hasNoPresentation(
            in: model.notificationCenter,
            destination: .main
        )
    }
}

private actor PipelineEventRecorder {
    private var events: [PipelineEvent] = []

    var batchCompletedCount: Int {
        events.filter {
            if case .batchCompleted = $0.kind { return true }
            return false
        }.count
    }

    var terminalItemEventCount: Int {
        events.filter {
            switch $0.kind {
            case .submitted, .failed, .deliveryUnknown:
                return true
            case .batchChanged, .intakeOutcome, .checking, .preparing,
                 .ready, .needsAttention, .sending, .cancelled,
                 .batchProgress, .batchCompleted,
                 .historyPersistenceFailed:
                return false
            }
        }.count
    }

    func append(_ event: PipelineEvent) {
        events.append(event)
    }
}

private enum JourneyTestError: Error {
    case timeout
}
