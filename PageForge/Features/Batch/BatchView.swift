import AppKit
import SwiftUI

struct BatchView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = BatchViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Batch")
                    .font(.largeTitle.weight(.semibold))
                Text("Process a folder of books with progress and summary counts.")
                    .foregroundStyle(.secondary)

                FileDropIntakeView(
                    title: "Drop a folder",
                    subtitle: "Or choose a directory of ebooks.",
                    allowFolders: true
                ) { viewModel.setFolder($0) }

                if let folderURL = viewModel.folderURL {
                    LabeledContent("Folder") {
                        Text(folderURL.path).textSelection(.enabled)
                    }
                }

                Picker("Operation", selection: $viewModel.operation) {
                    ForEach(BatchViewModel.Operation.allCases) { op in
                        Text(op.rawValue).tag(op)
                    }
                }

                HStack {
                    Button("Choose Output Directory…") { pickOutputDirectory() }
                    if let outputDirectory = viewModel.outputDirectory {
                        Text(outputDirectory.path)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                Toggle("Overwrite outputs", isOn: $viewModel.overwrite)
                    .toggleStyle(.checkbox)

                Button("Run Batch") { viewModel.run() }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isRunning)

                OperationStatusView(
                    message: viewModel.statusMessage,
                    errorMessage: viewModel.errorMessage,
                    isRunning: viewModel.isRunning
                )

                if let summary = viewModel.summary {
                    Text(summary)
                        .font(.body.weight(.medium))
                        .textSelection(.enabled)
                }
            }
            .padding(28)
        }
        .onAppear { viewModel.bind(appState: appState) }
    }

    private func pickOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.setOutputDirectory(url)
        }
    }
}
