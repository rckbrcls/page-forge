import SwiftUI

struct LogsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = LogsViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Logs")
                    .appLargeTitleStyle()
                Spacer()
                Button("Refresh") { viewModel.refresh() }
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)

            if viewModel.entries.isEmpty {
                Text("No log entries yet.")
                    .foregroundStyle(Color.Theme.textSecondary)
                    .padding(.horizontal, 28)
                Spacer()
            } else {
                List(viewModel.entries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.level.rawValue.uppercased())
                                .font(.caption.weight(.bold))
                                .foregroundStyle(
                                    entry.level == .error
                                        ? Color.Theme.destructive
                                        : Color.Theme.textSecondary
                                )
                            Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                                .font(.caption)
                                .foregroundStyle(Color.Theme.textSecondary)
                        }
                        Text(entry.message)
                            .textSelection(.enabled)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle(cornerRadius: 16)
                    .listRowInsets(.init(top: 6, leading: 28, bottom: 6, trailing: 28))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .themedScreenBackground()
        .onAppear {
            viewModel.bind(appState: appState)
        }
        .onReceive(appState.logService.objectWillChange) { _ in
            viewModel.refresh()
        }
    }
}
