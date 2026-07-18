import SwiftUI

struct ConvertView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ConvertViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Convert")
                    .font(.largeTitle.weight(.semibold))
                Text("Convert formats or repair EPUBs. Safe repair is the default path.")
                    .foregroundStyle(.secondary)

                FileDropIntakeView(
                    title: "Drop a book",
                    subtitle: "MOBI/PDF to EPUB, EPUB to MOBI, or EPUB repair.",
                    allowFolders: false
                ) { viewModel.setSource($0) }

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
                        .foregroundStyle(.secondary)
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
            .padding(28)
        }
        .onAppear { viewModel.bind(appState: appState) }
    }
}
