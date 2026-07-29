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

    private let windowCoordinator: WindowCoordinator

    init(windowCoordinator: WindowCoordinator) {
        self.windowCoordinator = windowCoordinator
    }

    func start() {
        KeyboardShortcuts.onKeyUp(for: .showBookSender) { [weak windowCoordinator] in
            windowCoordinator?.reveal()
        }

        setRegistrationEnabled(storedIsEnabled)
    }

    func setEnabled(_ isEnabled: Bool) {
        UserDefaults.standard.set(isEnabled, forKey: Self.isEnabledDefaultsKey)
        setRegistrationEnabled(isEnabled)
    }

    private var storedIsEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.isEnabledDefaultsKey) as? Bool ?? true
    }

    private func setRegistrationEnabled(_ isEnabled: Bool) {
        if isEnabled {
            if KeyboardShortcuts.getShortcut(for: .showBookSender) == nil {
                KeyboardShortcuts.reset(.showBookSender)
            }
            KeyboardShortcuts.enable(.showBookSender)
        } else {
            KeyboardShortcuts.disable(.showBookSender)
        }
    }
}
