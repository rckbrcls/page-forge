import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let showBookSender = Self(
        "showBookSender",
        initial: .init(.k, modifiers: [.command, .option])
    )
}

@MainActor
final class ShortcutService {
    static let isEnabledDefaultsKey = "shortcut.showBookSender.isEnabled"

    private weak var model: AppModel?
    private let windowCoordinator: WindowCoordinator
    private let defaults: UserDefaults
    private let registrar: any GlobalShortcutRegistering

    init(
        model: AppModel,
        windowCoordinator: WindowCoordinator,
        defaults: UserDefaults = .standard,
        registrar: any GlobalShortcutRegistering = KeyboardShortcutsRegistrar()
    ) {
        self.model = model
        self.windowCoordinator = windowCoordinator
        self.defaults = defaults
        self.registrar = registrar
    }

    func start() {
        registrar.onKeyUp {
            [weak model, weak windowCoordinator] in
            Task { @MainActor in
                await model?.reconcileRouteForShortcut()
                windowCoordinator?.reveal()
            }
        }
        setRegistrationEnabled(storedIsEnabled)
    }

    func setEnabled(_ isEnabled: Bool) {
        defaults.set(isEnabled, forKey: Self.isEnabledDefaultsKey)
        setRegistrationEnabled(isEnabled)
    }

    func shortcutChanged() {
        publishPreference(isEnabled: storedIsEnabled)
    }

    private var storedIsEnabled: Bool {
        defaults.object(forKey: Self.isEnabledDefaultsKey) as? Bool ?? true
    }

    private func setRegistrationEnabled(_ isEnabled: Bool) {
        if isEnabled {
            if registrar.shortcutDescription() == nil {
                registrar.restoreDefault()
            }
            registrar.enable()
        } else {
            registrar.disable()
        }
        publishPreference(isEnabled: isEnabled)
    }

    private func publishPreference(isEnabled: Bool) {
        guard isEnabled else {
            model?.updateShortcutPreference(
                ShortcutPreference(
                    isEnabled: false,
                    keyCombinationDescription: nil,
                    registrationState: .disabled
                )
            )
            model?.publishShortcutFeedback(
                action: .clearShortcut,
                state: .succeeded,
                title: "Shortcut disabled."
            )
            return
        }
        if let description = registrar.shortcutDescription() {
            model?.updateShortcutPreference(
                ShortcutPreference(
                    isEnabled: true,
                    keyCombinationDescription: description,
                    registrationState: .registered
                )
            )
            model?.publishShortcutFeedback(
                action: .saveShortcut,
                state: .succeeded,
                title: "Shortcut registered."
            )
        } else {
            let failure = SanitizedFailure(
                family: .shortcut,
                code: .shortcutConflict,
                message: "The selected shortcut is unavailable.",
                recoveryAction: .chooseAnotherShortcut,
                evidence: DiagnosticEvidence(
                    phase: .shortcutRegistration,
                    retryDisposition: .notRetryable
                )
            )
            model?.updateShortcutPreference(
                ShortcutPreference(
                    isEnabled: true,
                    keyCombinationDescription: nil,
                    registrationState: .conflict(
                        message: "Choose another shortcut."
                    )
                )
            )
            model?.publishShortcutFeedback(
                action: .saveShortcut,
                state: .failed,
                title: "Shortcut unavailable.",
                failure: failure
            )
        }
    }
}

@MainActor
protocol GlobalShortcutRegistering: AnyObject {
    func onKeyUp(_ action: @escaping @MainActor () -> Void)
    func shortcutDescription() -> String?
    func restoreDefault()
    func enable()
    func disable()
}

@MainActor
final class KeyboardShortcutsRegistrar: GlobalShortcutRegistering {
    func onKeyUp(_ action: @escaping @MainActor () -> Void) {
        KeyboardShortcuts.onKeyUp(for: .showBookSender) {
            Task { @MainActor in action() }
        }
    }

    func shortcutDescription() -> String? {
        KeyboardShortcuts.getShortcut(for: .showBookSender)
            .map { String(describing: $0) }
    }

    func restoreDefault() {
        KeyboardShortcuts.reset(.showBookSender)
    }

    func enable() {
        KeyboardShortcuts.enable(.showBookSender)
    }

    func disable() {
        KeyboardShortcuts.disable(.showBookSender)
    }
}
