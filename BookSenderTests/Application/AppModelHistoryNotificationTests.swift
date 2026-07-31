import Foundation
import Testing
@testable import BookSender

@MainActor
struct AppModelHistoryNotificationTests {
    @Test
    func historyLoadAndClearRemainContextual() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let historyStore = InMemorySendHistoryStore(
            records: [HistoryTestFixtures.record()]
        )
        let graph = TestDependencyGraph.make(
            stores: stores,
            historyStore: historyStore
        )
        let model = AppModel(dependencies: graph.dependencies)
        model.notificationCenter.attach(.main)

        try await eventually {
            model.historyLoadState == .loaded
                && model.historySnapshot.records.count == 1
        }
        #expect(
            model.notificationFeedback(for: .history, destination: .main) == nil
        )

        model.requestClearHistory()
        model.confirmClearHistory()
        try await eventually {
            model.historySnapshot.records.isEmpty && !model.isClearingHistory
        }

        #expect(model.feedback(for: .history)?.state == .succeeded)
        #expect(
            model.notificationFeedback(for: .history, destination: .main) == nil
        )
    }

    @Test
    func historyWriteFailurePublishesOnceWithoutChangingAcceptedDelivery() async throws {
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
        let model = AppModel(dependencies: graph.dependencies)
        model.notificationCenter.attach(.main)
        model.setupDraft = validDraft()
        model.saveSetup()
        try await eventually {
            model.setup != nil
                && !model.isSavingSetup
                && model.historyLoadState == .loaded
        }
        model.notificationCenter.remove(
            scope: .deliverySetup,
            destination: .main
        )
        let pdf = try FixtureFactory.makePDF(
            valid: true,
            in: stores.rootURL
        )

        model.addBooks([pdf])
        try await eventually {
            model.items.first?.preparation == .ready
        }
        model.requestSendConfirmation()
        try await eventually { model.isShowingConfirmation }
        model.confirmSend()
        try await eventually {
            model.items.first?.delivery == .submitted
                && model.feedback(for: .history)?.state == .partial
        }

        let notification = try #require(
            model.notificationFeedback(for: .history, destination: .main)
        )
        #expect(notification.state == .partial)
        #expect(notification.title == "Book sent, but history was not updated.")
        #expect(model.items.first?.delivery == .submitted)
        #expect(await graph.transport.sentItemIDs.count == 1)
        #expect(await historyStore.replaceAttemptCount == 1)
        #expect(try await graph.dependencies.historyService.snapshot().records.isEmpty)
        #expect(
            model.notificationCenter.snapshot(for: .main).visible.filter {
                $0.feedback.scope == .history
            }.count == 1
        )
    }

    private func eventually(
        _ condition: @escaping @MainActor () -> Bool
    ) async throws {
        for _ in 0..<4_000 {
            if condition() { return }
            await Task.yield()
        }
        throw AppModelHistoryNotificationTestError.timeout
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

private enum AppModelHistoryNotificationTestError: Error {
    case timeout
}
