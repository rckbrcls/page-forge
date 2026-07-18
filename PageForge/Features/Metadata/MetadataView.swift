import SwiftUI

struct MetadataView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = MetadataViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Metadata")
                    .appLargeTitleStyle()
                Text("Inspect and lightly edit title/author.")
                    .foregroundStyle(Color.Theme.textSecondary)

                FileDropIntakeView(
                    title: "Drop a book",
                    subtitle: "Uses Calibre ebook-meta.",
                    allowFolders: false
                ) { viewModel.setSource($0) }

                VStack(alignment: .leading, spacing: 12) {
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
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()

                if !viewModel.raw.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Raw metadata")
                            .font(.headline)
                        Text(viewModel.raw)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                }
            }
            .padding(28)
        }
        .themedScreenBackground()
        .onAppear { viewModel.bind(appState: appState) }
    }
}
