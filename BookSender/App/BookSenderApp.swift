import AppKit
import SwiftUI

@main
struct BookSenderApp: App {
    @State private var model: AppModel
    private let shortcutService: ShortcutService

    init() {
        let model = AppModel()
        _model = State(initialValue: model)
        shortcutService = ShortcutService(windowCoordinator: model.windowCoordinator)
        shortcutService.start()
    }

    var body: some Scene {
        WindowGroup("Book Sender", id: "main") {
            Group {
                switch model.route {
                case .deliverySetup:
                    DeliverySetupView(model: model, presentation: .onboarding)
                case .sendBook:
                    SendBookView(model: model)
                }
            }
            .frame(
                minWidth: 620,
                maxWidth: .infinity,
                minHeight: 620,
                maxHeight: .infinity
            )
            .background {
                WindowGlassBackdrop(coordinator: model.windowCoordinator)
                    .ignoresSafeArea()
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }

        Settings {
            BookSenderSettingsView(model: model, shortcutService: shortcutService)
        }
    }
}

private struct WindowGlassBackdrop: NSViewRepresentable {
    let coordinator: WindowCoordinator

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        DispatchQueue.main.async { configure(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        DispatchQueue.main.async { configure(nsView.window) }
    }

    @MainActor
    private func configure(_ window: NSWindow?) {
        guard let window else { return }

        window.isOpaque = false
        window.backgroundColor = .clear
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        coordinator.capture(window)
    }
}
