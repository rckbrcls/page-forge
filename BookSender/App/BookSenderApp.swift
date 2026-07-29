import AppKit
import Combine
import Sparkle
import SwiftUI

@main
struct BookSenderApp: App {
    @State private var model: AppModel
    private let shortcutService: ShortcutService
    private let updaterController: SPUStandardUpdaterController

    init() {
        let model = AppModel()
        _model = State(initialValue: model)
        shortcutService = ShortcutService(windowCoordinator: model.windowCoordinator)
        shortcutService.start()
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        updaterController.updater.updateCheckInterval = 86_400
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
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater) {
                    updaterController.checkForUpdates(nil)
                }
            }
        }

        Settings {
            BookSenderSettingsView(model: model, shortcutService: shortcutService)
        }
    }
}

private struct CheckForUpdatesView: View {
    @StateObject private var viewModel: CheckForUpdatesViewModel
    private let checkForUpdates: () -> Void

    init(updater: SPUUpdater, checkForUpdates: @escaping () -> Void) {
        _viewModel = StateObject(
            wrappedValue: CheckForUpdatesViewModel(updater: updater)
        )
        self.checkForUpdates = checkForUpdates
    }

    var body: some View {
        Button("Check for Updates…", action: checkForUpdates)
            .disabled(!viewModel.canCheckForUpdates)
    }
}

@MainActor
private final class CheckForUpdatesViewModel: ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    private var observation: NSKeyValueObservation?

    init(updater: SPUUpdater) {
        observation = updater.observe(
            \.canCheckForUpdates,
            options: [.initial, .new]
        ) { [weak self] updater, _ in
            DispatchQueue.main.async {
                self?.canCheckForUpdates = updater.canCheckForUpdates
            }
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
