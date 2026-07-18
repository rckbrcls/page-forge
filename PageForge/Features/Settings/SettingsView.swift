import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings")
                    .font(.largeTitle.weight(.semibold))

                section("Calibre status") {
                    Text(viewModel.dependencyMessage)
                        .textSelection(.enabled)
                    if let status = viewModel.dependencyStatus {
                        LabeledContent("ebook-convert") {
                            Text(status.ebookConvertPath?.path ?? "missing")
                        }
                        LabeledContent("ebook-meta") {
                            Text(status.ebookMetaPath?.path ?? "missing")
                        }
                        LabeledContent("ebook-polish") {
                            Text(status.ebookPolishPath?.path ?? "missing")
                        }
                    }
                    Button("Refresh") { viewModel.reload() }
                }

                section("Profiles") {
                    if !viewModel.profiles.isEmpty {
                        Picker("Profile", selection: Binding(
                            get: { viewModel.selectedProfile.name },
                            set: { name in
                                if let profile = viewModel.profiles.first(where: { $0.name == name }) {
                                    viewModel.selectProfile(profile)
                                }
                            }
                        )) {
                            ForEach(viewModel.profiles) { profile in
                                Text(profile.name).tag(profile.name)
                            }
                        }
                    }
                    ProfileEditorView(
                        profile: $viewModel.selectedProfile,
                        secretDraft: $viewModel.secretDraft,
                        hasSecret: viewModel.hasSecret,
                        onSave: viewModel.saveProfile
                    )
                }

                section("Updates") {
                    Text("App update")
                        .font(.headline)
                    Text(viewModel.appUpdateText)
                        .foregroundStyle(.secondary)
                    Text("Calibre update")
                        .font(.headline)
                        .padding(.top, 8)
                    Text(viewModel.calibreUpdateText)
                        .foregroundStyle(.secondary)
                }

                section("Install guidance") {
                    Text(viewModel.calibreInstallText)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                OperationStatusView(
                    message: viewModel.statusMessage,
                    errorMessage: viewModel.errorMessage,
                    isRunning: false
                )
            }
            .padding(28)
        }
        .onAppear { viewModel.bind(appState: appState) }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.weight(.semibold))
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
