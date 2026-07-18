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
                }

                section("Calibre") {
                    CalibreSettingsSection()
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

                section("Output") {
                    TextField("Default save folder", text: $viewModel.defaultOutputDirectory)
                    Text("Leave empty to choose a folder each time.")
                        .font(.caption)
                        .foregroundStyle(Color.Theme.textSecondary)
                    Button("Save Output Preference") {
                        viewModel.saveOutputPreference()
                    }
                }

                section("Troubleshooting") {
                    HStack {
                        Button("Refresh Logs") { viewModel.reload() }
                        Button("Open Send to Kindle Handoff") {
                            viewModel.openSendToKindleHandoff()
                        }
                    }
                    if viewModel.recentLogs.isEmpty {
                        Text("No log entries yet.")
                            .foregroundStyle(Color.Theme.textSecondary)
                    } else {
                        ForEach(viewModel.recentLogs) { entry in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.message)
                                    .textSelection(.enabled)
                                Text(entry.timestamp.formatted(date: .abbreviated, time: .standard))
                                    .font(.caption)
                                    .foregroundStyle(Color.Theme.textSecondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
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
        .onAppear {
            viewModel.bind(appState: appState)
            appState.refreshCalibre()
        }
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
