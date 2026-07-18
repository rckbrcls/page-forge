import SwiftUI

struct LogsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = LogsViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Logs")
                    .font(.largeTitle.weight(.semibold))
                Spacer()
                Button("Refresh") { viewModel.refresh() }
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)

            if viewModel.entries.isEmpty {
                Text("No log entries yet.")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 28)
                Spacer()
            } else {
                List(viewModel.entries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.level.rawValue.uppercased())
                                .font(.caption.weight(.bold))
                                .foregroundStyle(entry.level == .error ? .red : .secondary)
                            Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(entry.message)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .onAppear {
            viewModel.bind(appState: appState)
        }
        .onReceive(appState.logService.objectWillChange) { _ in
            viewModel.refresh()
        }
    }
}
