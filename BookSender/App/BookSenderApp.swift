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
                    DeliverySetupView(model: model, shortcutService: shortcutService)
                case .sendBook:
                    SendBookView(model: model)
                }
            }
            .background(WindowCapture(coordinator: model.windowCoordinator))
            .frame(minWidth: 620, minHeight: 620)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

private struct WindowCapture: NSViewRepresentable {
    let coordinator: WindowCoordinator

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { coordinator.capture(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { coordinator.capture(nsView.window) }
    }
}
