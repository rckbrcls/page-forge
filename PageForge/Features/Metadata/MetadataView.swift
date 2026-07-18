import SwiftUI

struct MetadataView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = MetadataViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Metadata")
                    .font(.largeTitle.weight(.semibold))
                Text("Inspect and lightly edit title/author.")
                    .foregroundStyle(.secondary)

                FileDropIntakeView(
                    title: "Drop a book",
                    subtitle: "Uses Calibre ebook-meta.",
                    allowFolders: false
                ) { viewModel.setSource($0) }

                if let sourceURL = viewModel.sourceURL {
                    LabeledContent("Selected") {
                        Text(sourceURL.path).textSelection(.enabled)
                    }
                }

                TextField("Title", text: $viewModel.titleText)
                TextField("Author", text: $viewModel.authorText)

                HStack {
                    Button("Inspect") { viewModel.inspect() }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isRunning)
                    Button("Update") { viewModel.update() }
                        .disabled(viewModel.isRunning)
                }

                OperationStatusView(
                    message: viewModel.statusMessage,
                    errorMessage: viewModel.errorMessage,
                    isRunning: viewModel.isRunning
                )

                if !viewModel.raw.isEmpty {
                    Text("Raw metadata")
                        .font(.headline)
                    Text(viewModel.raw)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(12)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(28)
        }
        .onAppear { viewModel.bind(appState: appState) }
    }
}
