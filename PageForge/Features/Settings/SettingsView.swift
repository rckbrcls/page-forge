import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings")
                    .appLargeTitleStyle()

                section("Appearance") {
                    Picker("Theme", selection: Binding(
                        get: { themeManager.currentTheme },
                        set: { themeManager.setTheme($0) }
                    )) {
                        ForEach(AppTheme.allCases) { theme in
                            Label(theme.displayName, systemImage: theme.systemImage)
                                .tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("Choose whether PageForge follows the system appearance or always uses a light or dark theme.")
                        .font(.caption)
                        .foregroundStyle(Color.Theme.textSecondary)
                }

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
                        .foregroundStyle(Color.Theme.textSecondary)
                    Text("Calibre update")
                        .font(.headline)
                        .padding(.top, 8)
                    Text(viewModel.calibreUpdateText)
                        .foregroundStyle(Color.Theme.textSecondary)
                }

                section("Install guidance") {
                    Text(viewModel.calibreInstallText)
                        .foregroundStyle(Color.Theme.textSecondary)
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
        .themedScreenBackground()
        .onAppear { viewModel.bind(appState: appState) }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.weight(.semibold))
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}
