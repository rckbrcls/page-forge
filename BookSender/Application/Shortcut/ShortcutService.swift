import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let showBookSender = Self("showBookSender")
}

@MainActor
final class ShortcutService {
    private let windowCoordinator: WindowCoordinator

    init(windowCoordinator: WindowCoordinator) {
        self.windowCoordinator = windowCoordinator
    }

    func start() {
        KeyboardShortcuts.onKeyUp(for: .showBookSender) { [weak windowCoordinator] in
            windowCoordinator?.reveal()
        }
    }

    func disable() {
        KeyboardShortcuts.reset(.showBookSender)
    }
}
