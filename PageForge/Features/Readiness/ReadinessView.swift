import SwiftUI

struct ReadinessView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ReadinessViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Readiness")
                    .font(.largeTitle.weight(.semibold))
                Text("Drop an ebook to diagnose Kindle readiness. Prepare writes a separate kindle-ready file.")
                    .foregroundStyle(.secondary)

                ReadinessDependencyBanner(message: viewModel.dependencyMessage)

                FileDropIntakeView(
                    title: "Drop EPUB or MOBI",
                    subtitle: "Audit does not modify the original file.",
                    allowFolders: false
                ) { url in
                    viewModel.setSource(url)
                }

                if let sourceURL = viewModel.sourceURL {
                    LabeledContent("Selected") {
                        Text(sourceURL.path)
                            .textSelection(.enabled)
                    }
                }

                HStack(spacing: 12) {
                    Button("Audit") { viewModel.audit() }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isRunning)
                    Button("Prepare / Fix") { viewModel.prepare() }
                        .disabled(viewModel.isRunning)
                    Toggle("Overwrite output", isOn: $viewModel.overwrite)
                        .toggleStyle(.checkbox)
                    Spacer()
                    Button("Open Handoff") { viewModel.openHandoff() }
                    Button("Send Prepared…") { viewModel.sendPrepared() }
                }

                OperationStatusView(
                    message: viewModel.statusMessage,
                    errorMessage: viewModel.errorMessage,
                    isRunning: viewModel.isRunning
                )

                if let report = viewModel.report {
                    reportSection(report)
                }
            }
            .padding(28)
        }
        .onAppear {
            viewModel.bind(appState: appState)
        }
    }

    @ViewBuilder
    private func reportSection(_ report: ReadinessReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Report")
                    .font(.title2.weight(.semibold))
                StatusChip(status: report.status)
                Spacer()
            }
            if let output = report.outputPath {
                LabeledContent("Output") {
                    Text(output.path).textSelection(.enabled)
                }
            }
            if report.issues.isEmpty {
                Text("No issues found.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(report.issues) { issue in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(issue.severity.rawValue.uppercased())
                                .font(.caption.weight(.bold))
                                .foregroundStyle(severityColor(issue.severity))
                            Text(issue.code)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(issue.message)
                        if let path = issue.path {
                            Text(path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    private func severityColor(_ severity: IssueSeverity) -> Color {
        switch severity {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .fixable: return .purple
        }
    }
}
