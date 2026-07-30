import Foundation
import Testing
@testable import BookSender

@MainActor
struct ShortcutServiceTests {
    @Test
    func publishesRegisteredDisabledAndConflictStates() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(stores: stores)
        let model = AppModel(dependencies: graph.dependencies)
        let registrar = FakeGlobalShortcutRegistrar(description: "⌘⌥K")
        let coordinator = WindowCoordinator(activateApplication: {})
        let service = ShortcutService(
            model: model,
            windowCoordinator: coordinator,
            defaults: stores.defaults,
            registrar: registrar
        )

        service.start()
        #expect(model.shortcutPreference.registrationState == .registered)
        #expect(model.shortcutPreference.keyCombinationDescription == "⌘⌥K")
        #expect(model.feedback(for: .shortcut)?.state == .succeeded)

        service.setEnabled(false)
        #expect(model.shortcutPreference.registrationState == .disabled)
        #expect(model.feedback(for: .shortcut)?.title == "Shortcut disabled.")
        #expect(registrar.disableCount == 1)

        registrar.description = nil
        service.shortcutChanged()
        #expect(model.shortcutPreference.registrationState == .disabled)

        service.setEnabled(true)
        registrar.description = nil
        service.shortcutChanged()
        #expect(
            model.shortcutPreference.registrationState
                == .conflict(message: "Choose another shortcut.")
        )
        #expect(model.feedback(for: .shortcut)?.state == .failed)
        #expect(
            model.feedback(for: .shortcut)?.failure?.code == .shortcutConflict
        )
        for _ in 0..<200 where model.currentDiagnosticEvent == nil {
            await Task.yield()
        }
        #expect(
            model.currentDiagnosticEvent?.failure.evidence.phase
                == .shortcutRegistration
        )
    }

    @Test
    func invocationReconcilesRouteAndRequestsOnlyMainWindowReveal() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(stores: stores)
        _ = try await graph.dependencies.setupService.save(
            DeliverySetupDraft(
                senderAddress: "sender@example.com",
                smtpHost: "smtp.example.com",
                smtpPort: "465",
                securityMode: .implicitTLS,
                username: "sender",
                appPassword: "secret",
                kindleAddress: "reader@kindle.com"
            ),
            replacing: nil
        )
        let model = AppModel(dependencies: graph.dependencies)
        let registrar = FakeGlobalShortcutRegistrar(description: "⌘⌥K")
        var reopenCount = 0
        let coordinator = WindowCoordinator(activateApplication: {})
        coordinator.registerOpenMainWindow { reopenCount += 1 }
        let service = ShortcutService(
            model: model,
            windowCoordinator: coordinator,
            defaults: stores.defaults,
            registrar: registrar
        )
        service.start()

        registrar.invoke()
        for _ in 0..<200 where model.route != .sendBook {
            await Task.yield()
        }

        #expect(model.route == .sendBook)
        #expect(reopenCount == 1)
        registrar.invoke()
        await Task.yield()
        #expect(reopenCount == 1)
        #expect(model.isShowingConfirmation == false)
    }
}

@MainActor
private final class FakeGlobalShortcutRegistrar: GlobalShortcutRegistering {
    var description: String?
    var restoreValue = "⌘⌥K"
    private var handler: (@MainActor () -> Void)?
    private(set) var enableCount = 0
    private(set) var disableCount = 0

    init(description: String?) {
        self.description = description
    }

    func onKeyUp(_ action: @escaping @MainActor () -> Void) {
        handler = action
    }

    func shortcutDescription() -> String? {
        description
    }

    func restoreDefault() {
        description = restoreValue
    }

    func enable() {
        enableCount += 1
    }

    func disable() {
        disableCount += 1
    }

    func invoke() {
        handler?()
    }
}
