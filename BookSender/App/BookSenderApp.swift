import AppKit
import Combine
import Sparkle
import SwiftUI

@main
struct BookSenderApp: App {
    @NSApplicationDelegateAdaptor(BookSenderApplicationDelegate.self)
    private var applicationDelegate
    @State private var model: AppModel
    private let shortcutService: ShortcutService
    private let updaterController: SPUStandardUpdaterController

    init() {
        let dependencies = AppDependencies.forCurrentInvocation()
        let model = AppModel(dependencies: dependencies)
        _model = State(initialValue: model)
        shortcutService = ShortcutService(
            model: model,
            windowCoordinator: model.windowCoordinator,
            defaults: dependencies.shortcutDefaults
        )
        shortcutService.start()
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        updaterController.updater.updateCheckInterval = 86_400
    }

    var body: some Scene {
        Window("Book Sender", id: "main") {
            MainWindowContent(model: model)
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
        .windowToolbarStyle(.unified(showsTitle: false))
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater) {
                    model.acknowledgeUpdateCheck()
                    updaterController.checkForUpdates(nil)
                }
            }
        }

        Settings {
            BookSenderSettingsView(model: model, shortcutService: shortcutService)
        }
    }
}

@MainActor
private final class BookSenderApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        false
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
        coordinator.captureMainWindow(window)
    }
}

private struct MainWindowContent: View {
    @Environment(\.openWindow) private var openWindow
    @Bindable var model: AppModel

    var body: some View {
        Group {
            if model.hasResolvedInitialSetup {
                switch model.route {
                case .deliverySetup:
                    DeliverySetupView(model: model, presentation: .onboarding)
                case .sendBook:
                    SendBookView(model: model)
                }
            } else {
                InitialSetupPlaceholder()
            }
        }
        .onAppear {
            model.windowCoordinator.registerOpenMainWindow {
                openWindow(id: "main")
            }
        }
    }
}

private struct InitialSetupPlaceholder: View {
    @State private var isShowingProgress = false

    var body: some View {
        Group {
            if isShowingProgress {
                ProgressView("Opening Book Sender…")
                    .controlSize(.small)
                    .accessibilityIdentifier("app.bootstrap.progress")
            } else {
                Color.clear
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            do {
                try await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                isShowingProgress = true
            } catch {
                return
            }
        }
    }
}
