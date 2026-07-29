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

        await eventually { model.route == .deliverySetup }
        #expect(model.setup == nil)
        #expect(model.items.isEmpty)
    }

    @Test
    func successfulSaveRoutesToSendBookAndClearsPasswordDraft() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(stores: stores)
        let model = AppModel(dependencies: graph.dependencies)
        model.setupDraft = validDraft()

        model.saveSetup()
        await eventually { model.setup != nil && !model.isSavingSetup }

        #expect(model.route == .sendBook)
        #expect(model.setupDraft.appPassword.isEmpty)
        #expect(model.setupErrors.isEmpty)
        #expect(String(describing: model).contains("provider-secret") == false)
    }

    @Test
    func failedValidationPreservesDraftAndRoute() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(stores: stores)
        let model = AppModel(dependencies: graph.dependencies)
        model.setupDraft.senderAddress = "invalid"

        model.saveSetup()

        #expect(model.route == .deliverySetup)
        #expect(model.setupDraft.senderAddress == "invalid")
        #expect(model.setupErrors[.senderAddress] != nil)
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

        await eventually { model.setupMessage != nil }

        #expect(model.route == .deliverySetup)
        #expect(model.setup == nil)
        #expect(model.setupDraft.senderAddress == "reader@example.com")
        #expect(model.setupDraft.appPassword.isEmpty)
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
}
