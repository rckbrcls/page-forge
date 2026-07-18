import Foundation

@MainActor
final class LogsViewModel: ObservableObject {
    @Published var entries: [OperationLogEntry] = []

    private weak var appState: AppState?

    func bind(appState: AppState) {
        self.appState = appState
        refresh()
    }

    func refresh() {
        entries = appState?.logService.recent(limit: 200) ?? []
    }
}
