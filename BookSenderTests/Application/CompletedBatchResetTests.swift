import Foundation
import Testing
@testable import BookSender

@MainActor
struct CompletedBatchResetTests {
    @Test
    func completedBatchResetsToANewEmptyIdentity() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(stores: stores)
        let model = AppModel(dependencies: graph.dependencies)
        model.notificationCenter.attach(.main)
        let shortcutPreference = ShortcutPreference(
            isEnabled: false,
            keyCombinationDescription: "Control-Option-B",
            registrationState: .disabled
        )
        model.updateShortcutPreference(shortcutPreference)
        model.sendBookTab = .history
        model.setupDraft = validDraft()
        model.saveSetup()
        try await eventually { model.setup != nil }
        dismissSetupNotification(in: model)
        let url = stores.rootURL.appending(component: "Reset.pdf")
        try Data("%PDF-1.7\n%%EOF\n".utf8).write(to: url)
        model.addBooks([url])
        try await eventually { model.initialEligibleCount == 1 }
        model.requestSendConfirmation()
        try await eventually { model.isShowingConfirmation }
        model.confirmSend()
        try await eventually { model.canStartAnotherSend }
        let completedID = model.batch.id

        model.requestStartAnotherSend()
        try await eventually { model.items.isEmpty }

        #expect(model.batch.id != completedID)
        #expect(model.batch.phase == .editing)
        #expect(model.setup != nil)
        #expect(model.shortcutPreference == shortcutPreference)
        #expect(model.sendBookTab == .history)
        #expect(noMainNotifications(in: model))
    }

    @Test
    func deliveryUnknownRequiresAcknowledgementBeforeReset() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(
            stores: stores,
            outcomes: [.deliveryUnknown(.deliveryUnknown())]
        )
        let model = AppModel(dependencies: graph.dependencies)
        model.notificationCenter.attach(.main)
        model.setupDraft = validDraft()
        model.saveSetup()
        try await eventually { model.setup != nil }
        dismissSetupNotification(in: model)
        let url = stores.rootURL.appending(component: "Unknown.pdf")
        try Data("%PDF-1.7\n%%EOF\n".utf8).write(to: url)
        model.addBooks([url])
        try await eventually { model.initialEligibleCount == 1 }
        model.requestSendConfirmation()
        try await eventually { model.isShowingConfirmation }
        model.confirmSend()
        try await eventually { model.canStartAnotherSend }
        let completedID = model.batch.id

        model.requestStartAnotherSend()
        #expect(model.isShowingResetConfirmation)
        model.cancelStartAnotherSend()
        #expect(model.batch.id == completedID)
        #expect(!model.items.isEmpty)

        model.requestStartAnotherSend()
        model.confirmStartAnotherSend()
        try await eventually { model.items.isEmpty }
        #expect(model.batch.id != completedID)
        #expect(noMainNotifications(in: model))
    }

    @Test
    func cancelledBatchResetsSilentlyWithoutUncertaintyConfirmation() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(
            stores: stores,
            outcomes: [.cancelled]
        )
        let model = AppModel(dependencies: graph.dependencies)
        model.notificationCenter.attach(.main)
        model.setupDraft = validDraft()
        model.saveSetup()
        try await eventually { model.setup != nil }
        dismissSetupNotification(in: model)
        let url = stores.rootURL.appending(component: "Cancelled.pdf")
        try Data("%PDF-1.7\n%%EOF\n".utf8).write(to: url)
        model.addBooks([url])
        try await eventually { model.initialEligibleCount == 1 }
        model.requestSendConfirmation()
        try await eventually { model.isShowingConfirmation }
        model.confirmSend()
        try await eventually { model.canStartAnotherSend }

        #expect(model.items.first?.delivery == .cancelled)
        #expect(noMainNotifications(in: model))
        model.requestStartAnotherSend()
        try await eventually { model.items.isEmpty }

        #expect(!model.isShowingResetConfirmation)
        #expect(noMainNotifications(in: model))
    }

    @Test
    func resetPreservesHistoryAndRejectsAnOldBatchEvent() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(stores: stores)
        try await graph.dependencies.historyService.record(
            HistoryTestFixtures.receipt()
        )
        let model = AppModel(dependencies: graph.dependencies)
        model.notificationCenter.attach(.main)
        model.setupDraft = validDraft()
        model.saveSetup()
        try await eventually { model.setup != nil }
        dismissSetupNotification(in: model)
        let url = stores.rootURL.appending(component: "Preserved.pdf")
        try Data("%PDF-1.7\n%%EOF\n".utf8).write(to: url)
        model.addBooks([url])
        try await eventually { model.initialEligibleCount == 1 }
        model.requestSendConfirmation()
        try await eventually { model.isShowingConfirmation }
        model.confirmSend()
        try await eventually { model.canStartAnotherSend }
        let oldBatchID = model.batch.id

        model.requestStartAnotherSend()
        try await eventually {
            model.items.isEmpty && model.batch.id != oldBatchID
        }
        let newBatch = model.batch
        let currentSnapshot = await graph.dependencies.pipeline.snapshot()
        model.project(
            PipelineEvent(
                batchID: oldBatchID,
                kind: .batchProgress(completed: 99, total: 99)
            ),
            snapshot: currentSnapshot
        )

        #expect(model.batch.id == newBatch.id)
        #expect(model.batch.items.count == newBatch.items.count)
        #expect(model.batch.phase == newBatch.phase)
        #expect(model.aggregateMessage == nil)
        #expect(
            try await graph.dependencies.historyService.snapshot().records
                .count == 2
        )

        let secondURL = stores.rootURL.appending(component: "Second.pdf")
        try Data("%PDF-1.7\nsecond\n%%EOF\n".utf8).write(to: secondURL)
        model.addBooks([secondURL])
        try await eventually { model.initialEligibleCount == 1 }
        #expect(model.items.first?.displayName == "Second.pdf")
        #expect(noMainNotifications(in: model))
    }

    @Test
    func failedWorkspaceClearKeepsTheCompletedBatchVisible() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let rejectingWorkspace = RejectingBatchClearWorkspaceStore(
            rootURL: stores.rootURL.appending(component: "rejecting-work")
        )
        let graph = TestDependencyGraph.make(
            stores: stores,
            workspaceStore: rejectingWorkspace
        )
        let model = AppModel(dependencies: graph.dependencies)
        model.notificationCenter.attach(.main)
        model.setupDraft = validDraft()
        model.saveSetup()
        try await eventually { model.setup != nil }
        dismissSetupNotification(in: model)
        let url = stores.rootURL.appending(component: "Clear-Failure.pdf")
        try Data("%PDF-1.7\n%%EOF\n".utf8).write(to: url)
        model.addBooks([url])
        try await eventually { model.initialEligibleCount == 1 }
        model.requestSendConfirmation()
        try await eventually { model.isShowingConfirmation }
        model.confirmSend()
        try await eventually { model.canStartAnotherSend }
        let completedID = model.batch.id

        model.requestStartAnotherSend()
        try await eventually {
            model.feedback(for: .batch)?.state == .failed
        }

        #expect(model.batch.id == completedID)
        #expect(model.items.count == 1)
        #expect(model.canStartAnotherSend)
        #expect(
            model.feedback(for: .batch)?.title
                == "The completed batch was not cleared."
        )
        #expect(noMainNotifications(in: model))
    }

    private func eventually(
        _ condition: @escaping @MainActor () -> Bool
    ) async throws {
        for _ in 0..<4_000 {
            if condition() { return }
            await Task.yield()
        }
        throw CompletedBatchResetTestError.timeout
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

    private func dismissSetupNotification(in model: AppModel) {
        model.notificationCenter.remove(
            scope: .deliverySetup,
            destination: .main
        )
    }

    private func noMainNotifications(in model: AppModel) -> Bool {
        NotificationTestFixtures.hasNoPresentation(
            in: model.notificationCenter,
            destination: .main
        )
    }
}

private enum CompletedBatchResetTestError: Error {
    case timeout
}
