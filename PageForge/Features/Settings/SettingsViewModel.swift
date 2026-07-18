import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var dependencyStatus: DependencyStatus?
    @Published var dependencyMessage = ""
    @Published var profiles: [DeliveryProfile] = []
    @Published var selectedProfile = DeliveryProfile()
    @Published var secretDraft = ""
    @Published var hasSecret = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?
    @Published var appUpdateText = ""
    @Published var calibreUpdateText = ""
    @Published var calibreInstallText = ""

    private weak var appState: AppState?

    func bind(appState: AppState) {
        self.appState = appState
        reload()
    }

    func reload() {
        guard let appState else { return }
        do {
            dependencyStatus = try appState.dependencyService.calibreStatus()
            dependencyMessage = appState.setupGuidance.missingToolsMessage(dependencyStatus ?? DependencyStatus())
            let config = try appState.configService.load()
            profiles = config.profiles.values.sorted { $0.name < $1.name }
            selectedProfile = try appState.configService.defaultProfile()
            hasSecret = appState.secretService.hasPassword(profileName: selectedProfile.name)
            appUpdateText = appState.setupGuidance.appUpdateGuidance()
            calibreUpdateText = appState.setupGuidance.calibreUpdateGuidance()
            calibreInstallText = appState.setupGuidance.calibreInstallGuidance()
            statusMessage = "Settings loaded"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectProfile(_ profile: DeliveryProfile) {
        selectedProfile = profile
        hasSecret = appState?.secretService.hasPassword(profileName: profile.name) ?? false
        secretDraft = ""
    }

    func saveProfile() {
        guard let appState else { return }
        do {
            try appState.configService.upsertProfile(selectedProfile, makeDefault: true)
            if !secretDraft.isEmpty {
                try appState.secretService.setPassword(profileName: selectedProfile.name, secret: secretDraft)
                secretDraft = ""
            }
            reload()
            statusMessage = "Profile saved"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
