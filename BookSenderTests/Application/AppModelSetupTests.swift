import Foundation
import Testing
@testable import BookSender

@MainActor
struct AppModelSetupTests {
    @Test
    func incompleteLoadStaysOnSetupWithoutBypassState() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(stores: stores)
        let model = AppModel(dependencies: graph.dependencies)
        model.notificationCenter.attach(.main)

        #expect(model.hasResolvedInitialSetup == false)
        await eventually { model.hasResolvedInitialSetup }
        #expect(model.setup == nil)
        #expect(model.route == .deliverySetup)
        #expect(model.items.isEmpty)
        #expect(noMainNotifications(in: model))
        #expect(model.feedback(for: .application)?.state == .succeeded)
        #expect(
            model.feedback(for: .application)?.title
                == "Delivery setup required."
        )
    }

    @Test
    func completeLoadRoutesDirectlyToSendBookAfterInitialResolution() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(stores: stores)
        let reference = CredentialReference(
            service: stores.keychainServiceName,
            account: "existing",
            revision: 1
        )
        let setup = try DeliverySetupValidator().makeSetup(
            from: validDraft(),
            credentialReference: reference,
            revision: 1
        )
        await graph.credentials.insert("provider-secret", for: reference)
        await graph.preferences.setResult(.value(setup))

        let model = AppModel(dependencies: graph.dependencies)
        model.notificationCenter.attach(.main)

        #expect(model.hasResolvedInitialSetup == false)
        await eventually { model.hasResolvedInitialSetup }
        #expect(model.route == .sendBook)
        #expect(model.setup == setup)
        #expect(model.setupDraft.appPassword.isEmpty)
        #expect(noMainNotifications(in: model))
    }

    @Test
    func successfulSaveRoutesToSendBookAndClearsPasswordDraft() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(stores: stores)
        let model = AppModel(dependencies: graph.dependencies)
        model.notificationCenter.attach(.main)
        model.setupDraft = validDraft()

        model.saveSetup()
        await eventually { model.setup != nil && !model.isSavingSetup }

        #expect(model.route == .sendBook)
        #expect(model.setupDraft.appPassword.isEmpty)
        #expect(model.setupErrors.isEmpty)
        #expect(model.feedback(for: .deliverySetup)?.state == .succeeded)
        #expect(
            model.feedback(for: .deliverySetup)?.title
                == "Setup saved. App password stored securely."
        )
        #expect(
            model.notificationCenter.snapshot(for: .main).visible.count == 1
        )
        #expect(
            model.notificationFeedback(
                for: .deliverySetup,
                destination: .main
            )?.state == .succeeded
        )
        #expect(String(describing: model).contains("provider-secret") == false)
    }

    @Test
    func replacementAndRepeatedSaveKeepDurableSecretFreeSuccess() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(stores: stores)
        let model = AppModel(dependencies: graph.dependencies)
        model.notificationCenter.attach(.main)
        model.setupDraft = validDraft()

        model.saveSetup()
        model.saveSetup()
        await eventually { model.setup != nil && !model.isSavingSetup }

        #expect((await graph.preferences.savedSetups).count == 1)
        model.setupDraft.appPassword = "replacement-secret"
        model.saveSetup()
        await eventually { model.setup?.revision == 2 && !model.isSavingSetup }

        let feedback = try #require(model.feedback(for: .deliverySetup))
        #expect(feedback.state == .succeeded)
        #expect(feedback.dismissal == .persistentUntilReplaced)
        #expect(feedback.title == "Setup saved. App password stored securely.")
        #expect(
            model.notificationCenter.snapshot(for: .main).visible.filter {
                $0.feedback.scope == .deliverySetup
            }.count == 1
        )
        #expect(model.setupDraft.appPassword.isEmpty)
        #expect(String(describing: feedback).contains("replacement-secret") == false)
    }

    @Test
    func failedValidationPreservesDraftAndRoute() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(stores: stores)
        let model = AppModel(dependencies: graph.dependencies)
        model.notificationCenter.attach(.main)
        model.setupDraft.senderAddress = "invalid"

        model.saveSetup()

        #expect(model.route == .deliverySetup)
        #expect(model.setupDraft.senderAddress == "invalid")
        #expect(model.setupErrors[.senderAddress] != nil)
        #expect(model.feedback(for: .deliverySetup)?.state == .failed)
        #expect(noMainNotifications(in: model))
    }

    @Test
    func missingCredentialReturnsToSetupWithSafePrefill() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(stores: stores)
        let setup = try DeliverySetupValidator().makeSetup(
            from: validDraft(),
            credentialReference: CredentialReference(
                service: stores.keychainServiceName,
                account: "missing",
                revision: 1
            ),
            revision: 1
        )
        await graph.preferences.setResult(.value(setup))
        let model = AppModel(dependencies: graph.dependencies)
        model.notificationCenter.attach(.main)

        #expect(model.hasResolvedInitialSetup == false)
        await eventually { model.hasResolvedInitialSetup }

        #expect(model.route == .deliverySetup)
        #expect(model.setup == nil)
        #expect(model.setupMessage != nil)
        #expect(model.setupDraft.senderAddress == "reader@example.com")
        #expect(model.setupDraft.appPassword.isEmpty)
        #expect(noMainNotifications(in: model))
        await eventually { model.currentDiagnosticEvent != nil }
        #expect(
            model.currentDiagnosticEvent?.failure.code == .credentialMissing
        )
        #expect(
            model.currentDiagnosticEvent?.failure.evidence.phase
                == .credentialRead
        )
    }

    @Test
    func updateCheckAcknowledgementDoesNotCreateCompetingFailureState() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(stores: stores)
        let model = AppModel(dependencies: graph.dependencies)
        model.notificationCenter.attach(.main)
        await eventually { model.hasResolvedInitialSetup }

        model.acknowledgeUpdateCheck()

        #expect(model.feedback(for: .update)?.state == .succeeded)
        #expect(
            model.feedback(for: .update)?.title == "Update check opened."
        )
        #expect(noMainNotifications(in: model))
        #expect(model.currentDiagnosticEvent == nil)
    }

    private func eventually(
        _ condition: @escaping @MainActor () -> Bool
    ) async {
        for _ in 0..<200 where !condition() {
            await Task.yield()
        }
    }

    private func validDraft() -> DeliverySetupDraft {
        DeliverySetupDraft(
            senderAddress: "reader@example.com",
            smtpHost: "smtp.example.com",
            smtpPort: "465",
            securityMode: .implicitTLS,
            username: "reader",
            appPassword: "provider-secret",
            kindleAddress: "reader@kindle.com"
        )
    }

    private func noMainNotifications(in model: AppModel) -> Bool {
        NotificationTestFixtures.hasNoPresentation(
            in: model.notificationCenter,
            destination: .main
        )
    }
}
