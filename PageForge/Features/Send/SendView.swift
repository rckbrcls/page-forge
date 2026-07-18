import SwiftUI

struct SendView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = SendViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Send to Kindle")
                    .font(.largeTitle.weight(.semibold))
                Text("SMTP delivery through a local profile, or handoff to Amazon Send to Kindle.")
                    .foregroundStyle(.secondary)

                FileDropIntakeView(
                    title: "Drop a ready ebook",
                    subtitle: "Usually a kindle-ready EPUB.",
                    allowFolders: false
                ) { viewModel.setSource($0) }

                if let sourceURL = viewModel.sourceURL {
                    LabeledContent("Selected") {
                        Text(sourceURL.path).textSelection(.enabled)
                    }
                }

                Picker("Profile", selection: $viewModel.selectedProfileName) {
                    ForEach(viewModel.profiles) { profile in
                        Text("\(profile.name) (\(viewModel.profileReadyLabel(for: profile)))")
                            .tag(profile.name)
                    }
                }

                HStack {
                    Button("Send via SMTP") { viewModel.send() }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isRunning)
                    Button("Open Handoff") { viewModel.openHandoff() }
                    Button("Reload Profiles") { viewModel.reloadProfiles() }
                }

                OperationStatusView(
                    message: viewModel.statusMessage,
                    errorMessage: viewModel.errorMessage,
                    isRunning: viewModel.isRunning
                )

                if let result = viewModel.lastResult {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Last send")
                            .font(.headline)
                        Text("From \(result.senderEmail) to \(result.kindleEmail)")
                        Text("Profile: \(result.profileName)")
                        Text(result.inputPath.path)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(28)
        }
        .onAppear { viewModel.bind(appState: appState) }
    }
}
