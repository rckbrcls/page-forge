import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension Notification.Name {
    static let pageForgeAddFiles = Notification.Name("PageForge.AddFiles")
}

struct MainWorkflowView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openSettings) private var openSettings
    @StateObject private var viewModel = DocumentWorkflowViewModel()
    @State private var showsFileImporter = false

    var body: some View {
        DocumentWorkflowView(viewModel: viewModel) {
            openSettings()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                }
                .help("Open PageForge Settings")
            }
        }
        .fileImporter(
            isPresented: $showsFileImporter,
            allowedContentTypes: supportedTypes,
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                viewModel.addFiles(urls)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pageForgeAddFiles)) { _ in
            showsFileImporter = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.refreshDeliveryProfiles()
        }
        .onAppear { viewModel.bind(appState: appState) }
    }

    private var supportedTypes: [UTType] {
        [
            .pdf,
            UTType(filenameExtension: "epub") ?? .data,
            UTType(filenameExtension: "mobi") ?? .data,
        ]
    }
}
