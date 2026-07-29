import AppKit

@MainActor
final class WindowCoordinator {
    private weak var window: NSWindow?

    func capture(_ window: NSWindow?) {
        guard let window else { return }
        self.window = window
    }

    func reveal() {
        NSApp.activate(ignoringOtherApps: true)
        if let window {
            window.makeKeyAndOrderFront(nil)
        } else {
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }
}
