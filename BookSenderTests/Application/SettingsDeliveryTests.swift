import Foundation
import Testing
@testable import BookSender

@MainActor
struct SettingsDeliveryTests {
    @Test
    func blankPasswordEditPreservesCredentialAndIdleBatch() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(stores: stores)
        let model = AppModel(dependencies: graph.dependencies)
        model.notificationCenter.attach(.main)
        model.setupDraft = validDraft()
        model.saveSetup()
        try await eventually { model.setup != nil }
        let originalReference = try #require(model.setup?.credentialReference)
        let pdf = try FixtureFactory.makePDF(valid: true, in: stores.rootURL)
        model.addBooks([pdf])
        try await eventually { model.items.first?.preparation == .ready }
        let batchID = model.batch.id

        model.setupDraft.smtpPort = "587"
        model.setupDraft.securityMode = .startTLS
        model.setupDraft.appPassword = ""
        model.saveSetup()
        try await eventually { model.setup?.revision == 2 }

        #expect(model.setup?.credentialReference.account == originalReference.account)
        #expect(model.batch.id == batchID)
        #expect(model.items.count == 1)
        #expect(model.feedback(for: .deliverySetup)?.state == .succeeded)
        #expect(
            model.notificationCenter.snapshot(for: .main).visible.filter {
                $0.feedback.scope == .deliverySetup
            }.count == 1
        )
    }

    @Test
    func deleteClearsSavedSetupAndPublishesTerminalFeedback() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(stores: stores)
        let model = AppModel(dependencies: graph.dependencies)
        model.notificationCenter.attach(.main)
        model.setupDraft = validDraft()
        model.saveSetup()
        try await eventually { model.setup != nil }

        model.deleteSetup()
        try await eventually { model.setup == nil && !model.isSavingSetup }

        #expect(model.route == .deliverySetup)
        #expect(model.feedback(for: .deliverySetup)?.state == .succeeded)
        #expect(model.feedback(for: .deliverySetup)?.title == "Delivery setup deleted.")
        #expect(
            model.notificationCenter.snapshot(for: .main).visible.filter {
                $0.feedback.scope == .deliverySetup
            }.count == 1
        )
    }

    @Test
    func deleteKeychainFailurePublishesOnePartialCardAndKeepsSetupDeleted() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(stores: stores)
        let model = AppModel(dependencies: graph.dependencies)
        model.notificationCenter.attach(.main)
        model.setupDraft = validDraft()
        model.saveSetup()
        try await eventually { model.setup != nil }
        await graph.credentials.setDeleteFailure(
            sanitizedFailure(.credentialDelete, family: .credential)
        )

        model.deleteSetup()
        try await eventually { model.setup == nil && !model.isSavingSetup }

        #expect(model.route == .deliverySetup)
        #expect(model.feedback(for: .deliverySetup)?.state == .partial)
        #expect(
            model.feedback(for: .deliverySetup)?.failure?.code
                == .credentialDelete
        )
        #expect(
            model.notificationCenter.snapshot(for: .main).visible.filter {
                $0.feedback.scope == .deliverySetup
            }.count == 1
        )
    }

    @Test
    func failedPreferenceEditKeepsPreviousSetupAndExplainsRollback() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(stores: stores)
        let model = AppModel(dependencies: graph.dependencies)
        model.notificationCenter.attach(.main)
        model.setupDraft = validDraft()
        model.saveSetup()
        try await eventually { model.setup != nil }
        let previous = try #require(model.setup)
        await graph.preferences.setSaveFailure(
            SanitizedFailure(
                family: .credential,
                code: .preferencesInvalidRevision,
                message: "Delivery settings were not saved.",
                recoveryAction: .editSetup
            )
        )

        model.setupDraft.smtpPort = "587"
        model.setupDraft.securityMode = .startTLS
        model.saveSetup()
        try await eventually {
            model.feedback(for: .deliverySetup)?.state == .failed
        }

        #expect(model.setup == previous)
        #expect(
            model.feedback(for: .deliverySetup)?.failure?.code
                == .preferencesInvalidRevision
        )
        #expect(model.setupDraft.smtpPort == "587")
        #expect(
            NotificationTestFixtures.hasNoPresentation(
                in: model.notificationCenter,
                destination: .main
            )
        )
    }

    @Test
    func activeConfirmationDisablesDeliverySave() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(stores: stores)
        let model = AppModel(dependencies: graph.dependencies)
        model.setupDraft = validDraft()
        model.saveSetup()
        try await eventually { model.setup != nil }
        let pdf = try FixtureFactory.makePDF(valid: true, in: stores.rootURL)
        model.addBooks([pdf])
        try await eventually { model.items.first?.preparation == .ready }
        model.requestSendConfirmation()
        try await eventually { model.isShowingConfirmation }

        #expect(model.canSaveSetup == false)
        model.dismissConfirmation()
        try await eventually { model.batch.activeConfirmation == nil }
        #expect(model.canSaveSetup)
    }

    private func eventually(
        _ condition: @escaping @MainActor () -> Bool
    ) async throws {
        for _ in 0..<2_000 {
            if condition() { return }
            await Task.yield()
        }
        throw SettingsDeliveryTestError.timeout
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

private enum SettingsDeliveryTestError: Error {
    case timeout
}
