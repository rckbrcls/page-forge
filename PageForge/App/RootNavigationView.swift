import SwiftUI

struct RootNavigationView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationSplitView {
            List(AppDestination.allCases, selection: $appState.destination) { destination in
                Label(destination.rawValue, systemImage: destination.systemImage)
                    .tag(destination)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
            .navigationTitle("PageForge")
        } detail: {
            switch appState.destination {
            case .readiness:
                ReadinessView()
            case .convert:
                ConvertView()
            case .batch:
                BatchView()
            case .send:
                SendView()
            case .metadata:
                MetadataView()
            case .settings:
                SettingsView()
            case .logs:
                LogsView()
            }
        }
    }
}
