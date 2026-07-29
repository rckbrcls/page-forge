import AppKit

@MainActor
final class WindowCoordinator {
    private weak var mainWindow: NSWindow?
    private var openMainWindow: (() -> Void)?
    private var isReopenPending = false
    private let activateApplication: () -> Void

    init(
        activateApplication: @escaping () -> Void = {
            NSApp.activate(ignoringOtherApps: true)
        }
    ) {
        self.activateApplication = activateApplication
    }

    func captureMainWindow(_ window: NSWindow?) {
        guard let window else { return }
        mainWindow = window
        isReopenPending = false
    }

    func registerOpenMainWindow(_ action: @escaping () -> Void) {
        openMainWindow = action
    }

    func reveal() {
        activateApplication()
        if let mainWindow {
            mainWindow.makeKeyAndOrderFront(nil)
        } else if !isReopenPending {
            isReopenPending = true
            openMainWindow?()
        }
    }
}
