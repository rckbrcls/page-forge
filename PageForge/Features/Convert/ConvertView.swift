import SwiftUI

struct ConvertView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ConvertViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Convert")
                    .appLargeTitleStyle()
                Text("Convert formats or repair EPUBs. Safe repair is the default path.")
                    .foregroundStyle(Color.Theme.textSecondary)

                FileDropIntakeView(
                    title: "Drop a book",
                    subtitle: "MOBI/PDF to EPUB, EPUB to MOBI, or EPUB repair.",
                    allowFolders: false
                ) { viewModel.setSource($0) }

                VStack(alignment: .leading, spacing: 12) {
                    if let sourceURL = viewModel.sourceURL {
                        LabeledContent("Selected") {
                            Text(sourceURL.path).textSelection(.enabled)
                        }
                    }

                    Picker("Operation", selection: $viewModel.operation) {
                        ForEach(ConvertViewModel.Operation.allCases) { op in
                            Text(op.rawValue).tag(op)
                        }
                    }
                    .pickerStyle(.menu)

                    if viewModel.operation == .pdfToEpub {
                        Text("PDF conversion uses Calibre directly and does not perform OCR. Scanned PDFs may produce poor or empty EPUB output.")
                            .font(.callout)
                            .foregroundStyle(Color.Theme.textSecondary)
                    }

                    if viewModel.operation == .aggressiveRepair {
                        Toggle("I understand aggressive repair rewrites via MOBI roundtrip", isOn: $viewModel.confirmAggressive)
                    }

                    Toggle("Overwrite output", isOn: $viewModel.overwrite)
                        .toggleStyle(.checkbox)

                    Button("Run") { viewModel.run() }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isRunning)

                    OperationStatusView(
                        message: viewModel.statusMessage,
                        errorMessage: viewModel.errorMessage,
                        isRunning: viewModel.isRunning
                    )

                    if let outputPath = viewModel.outputPath {
                        LabeledContent("Output") {
                            Text(outputPath.path).textSelection(.enabled)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
            }
            .padding(28)
        }
        .themedScreenBackground()
        .onAppear { viewModel.bind(appState: appState) }
    }
}
