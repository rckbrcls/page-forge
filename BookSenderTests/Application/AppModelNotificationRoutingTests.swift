import Foundation
import Testing
@testable import BookSender

@MainActor
struct AppModelNotificationRoutingTests {
    @Test
    func fixedScopesUseTheirOwningDestination() {
        for scope in [
            FeedbackScope.application,
            .batch,
            .batchItem(UUID()),
            .delivery(UUID()),
            .update,
            .history,
        ] {
            #expect(
                AppModel.notificationDestination(
                    for: scope,
                    preferred: .settings
                ) == .main
            )
        }
        #expect(
            AppModel.notificationDestination(
                for: .shortcut,
                preferred: .main
            ) == .settings
        )
        #expect(
            AppModel.notificationDestination(
                for: .deliverySetup,
                preferred: .settings
            ) == .settings
        )
        #expect(
            AppModel.notificationDestination(
                for: .diagnosticCopy,
                preferred: .settings
            ) == .settings
        )
    }

    @Test
    func setupFeedbackUsesTheExplicitSettingsDestination() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(stores: stores)
        let model = AppModel(dependencies: graph.dependencies)
        model.notificationCenter.attach(.main)
        model.notificationCenter.attach(.settings)
        model.setupDraft = validDraft()

        model.saveSetup(destination: .settings)
        try await eventually {
            model.notificationFeedback(
                for: .deliverySetup,
                destination: .settings
            )?.state == .succeeded
        }

        #expect(
            model.notificationFeedback(
                for: .deliverySetup,
                destination: .main
            ) == nil
        )
    }

    @Test
    func shortcutAndUpdateFeedbackRemainSemanticAndSilent() throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(stores: stores)
        let model = AppModel(dependencies: graph.dependencies)
        model.notificationCenter.attach(.main)
        model.notificationCenter.attach(.settings)

        model.publishShortcutFeedback(
            action: .clearShortcut,
            state: .succeeded,
            title: "Shortcut disabled."
        )
        model.acknowledgeUpdateCheck()

        #expect(model.feedback(for: .shortcut)?.state == .succeeded)
        #expect(model.feedback(for: .update)?.state == .succeeded)
        #expect(
            model.notificationFeedback(
                for: .shortcut,
                destination: .settings
            ) == nil
        )
        #expect(
            model.notificationFeedback(
                for: .update,
                destination: .main
            ) == nil
        )
        #expect(
            NotificationTestFixtures.hasNoPresentation(
                in: model.notificationCenter,
                destination: .main
            )
        )
        #expect(
            NotificationTestFixtures.hasNoPresentation(
                in: model.notificationCenter,
                destination: .settings
            )
        )
    }

    @Test
    func contextualFailureRemainsSemanticWithoutUsingNotificationCapacity() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(stores: stores)
        let model = AppModel(dependencies: graph.dependencies)
        model.notificationCenter.attach(.main)
        try await eventually { model.hasResolvedInitialSetup }

        model.addBooks([])

        #expect(model.feedback(for: .batch)?.state == .failed)
        #expect(
            NotificationTestFixtures.hasNoPresentation(
                in: model.notificationCenter,
                destination: .main
            )
        )
    }

    @Test
    func newerContextualActionRemovesOnlyMatchingStalePresentation() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(stores: stores)
        let model = AppModel(dependencies: graph.dependencies)
        model.notificationCenter.attach(.main)
        model.notificationCenter.attach(.settings)
        try await eventually { model.hasResolvedInitialSetup }

        let setupFeedback = NotificationTestFixtures.feedback(
            scope: .deliverySetup,
            action: .saveDeliverySetup,
            title: "Setup saved."
        )
        let shortcutFeedback = NotificationTestFixtures.feedback(
            id: NotificationTestFixtures.settingsFeedbackID,
            scope: .shortcut,
            action: .saveShortcut,
            title: "Shortcut saved."
        )
        model.notificationCenter.publish(setupFeedback, destination: .main)
        model.notificationCenter.publish(shortcutFeedback, destination: .settings)
        model.setupDraft.senderAddress = "invalid"

        model.saveSetup(destination: .main)

        #expect(model.feedback(for: .deliverySetup)?.state == .failed)
        #expect(
            model.notificationFeedback(
                for: .deliverySetup,
                destination: .main
            ) == nil
        )
        #expect(
            model.notificationFeedback(
                for: .shortcut,
                destination: .settings
            )?.id == shortcutFeedback.id
        )
    }

    @Test
    func typedActionsRejectUnsupportedDestinationsAndRequestExactFocus() throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(stores: stores)
        let model = AppModel(dependencies: graph.dependencies)

        #expect(
            !model.performNotificationAction(
                .chooseAnotherShortcut,
                destination: .main
            )
        )
        #expect(model.notificationCenter.focusRequest == nil)

        #expect(
            model.performNotificationAction(
                .chooseAnotherShortcut,
                destination: .settings
            )
        )
        let shortcutRequest = try #require(
            model.notificationCenter.focusRequest
        )
        #expect(shortcutRequest.destination == .settings)
        #expect(shortcutRequest.action == .chooseAnotherShortcut)
        model.notificationCenter.consumeFocusRequest(id: shortcutRequest.id)

        #expect(
            model.performNotificationAction(
                .chooseAnotherFile,
                destination: .main
            )
        )
        let fileRequest = try #require(model.notificationCenter.focusRequest)
        #expect(fileRequest.destination == .main)
        #expect(fileRequest.action == .chooseAnotherFile)
    }

    @Test
    func unknownRecoveryOpensConfirmationWithoutRetryingOrReclassifying() throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(stores: stores)
        let model = AppModel(dependencies: graph.dependencies)

        #expect(
            !model.performNotificationAction(
                .confirmUnknownRetry,
                destination: .settings
            )
        )
        #expect(!model.isShowingResetConfirmation)
    }

    private func eventually(
        _ condition: @escaping @MainActor () -> Bool
    ) async throws {
        for _ in 0..<2_000 {
            if condition() { return }
            await Task.yield()
        }
        throw AppModelNotificationRoutingTestError.timeout
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

private enum AppModelNotificationRoutingTestError: Error {
    case timeout
}
