import Foundation

protocol SettingsConfigServicing {
    func load() throws -> AppConfig
    func save(_ config: AppConfig) throws
    func upsertProfile(_ profile: DeliveryProfile, makeDefault: Bool) throws
    func defaultProfile() throws -> DeliveryProfile
}

protocol SettingsSecretServicing {
    func setPassword(profileName: String, secret: String) throws
    func hasPassword(profileName: String) -> Bool
}

protocol SettingsDependencyServicing {
    func calibreStatus() throws -> DependencyStatus
}

protocol SettingsGuidanceProviding {
    func missingToolsMessage(_ status: DependencyStatus) -> String
    func appUpdateGuidance() -> String
    func calibreUpdateGuidance() -> String
    func calibreInstallGuidance() -> String
}

@MainActor
protocol SettingsLogProviding {
    func recent(limit: Int) -> [OperationLogEntry]
}

protocol SendToKindleHandoffOpening {
    func openHandoff()
}

extension ConfigService: SettingsConfigServicing {}
extension SecretService: SettingsSecretServicing {}
extension DependencyService: SettingsDependencyServicing {}
extension SetupGuidanceService: SettingsGuidanceProviding {}
extension LogService: SettingsLogProviding {}
extension DeliveryService: SendToKindleHandoffOpening {}

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
    @Published var recentLogs: [OperationLogEntry] = []
    @Published var defaultOutputDirectory = ""

    private var configService: (any SettingsConfigServicing)?
    private var secretService: (any SettingsSecretServicing)?
    private var dependencyService: (any SettingsDependencyServicing)?
    private var setupGuidance: (any SettingsGuidanceProviding)?
    private var logService: (any SettingsLogProviding)?
    private var handoffService: (any SendToKindleHandoffOpening)?

    init(
        configService: (any SettingsConfigServicing)? = nil,
        secretService: (any SettingsSecretServicing)? = nil,
        dependencyService: (any SettingsDependencyServicing)? = nil,
        setupGuidance: (any SettingsGuidanceProviding)? = nil,
        logService: (any SettingsLogProviding)? = nil,
        handoffService: (any SendToKindleHandoffOpening)? = nil
    ) {
        self.configService = configService
        self.secretService = secretService
        self.dependencyService = dependencyService
        self.setupGuidance = setupGuidance
        self.logService = logService
        self.handoffService = handoffService
    }

    func bind(appState: AppState) {
        configService = appState.configService
        secretService = appState.secretService
        dependencyService = appState.dependencyService
        setupGuidance = appState.setupGuidance
        logService = appState.logService
        handoffService = appState.deliveryService
        reload()
    }

    func reload() {
        guard let configService,
              let secretService,
              let dependencyService,
              let setupGuidance,
              let logService
        else {
            return
        }
        do {
            dependencyStatus = try dependencyService.calibreStatus()
            dependencyMessage = setupGuidance.missingToolsMessage(
                dependencyStatus ?? DependencyStatus()
            )
            let config = try configService.load()
            profiles = config.profiles.values.sorted { $0.name < $1.name }
            selectedProfile = try configService.defaultProfile()
            hasSecret = secretService.hasPassword(profileName: selectedProfile.name)
            defaultOutputDirectory = config.defaultOutputDirectory
            appUpdateText = setupGuidance.appUpdateGuidance()
            calibreUpdateText = setupGuidance.calibreUpdateGuidance()
            calibreInstallText = setupGuidance.calibreInstallGuidance()
            recentLogs = logService.recent(limit: 20)
            statusMessage = "Settings loaded"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectProfile(_ profile: DeliveryProfile) {
        selectedProfile = profile
        hasSecret = secretService?.hasPassword(profileName: profile.name) ?? false
        secretDraft = ""
    }

    func saveProfile() {
        guard let configService, let secretService else { return }
        do {
            try configService.upsertProfile(selectedProfile, makeDefault: true)
            if !secretDraft.isEmpty {
                try secretService.setPassword(
                    profileName: selectedProfile.name,
                    secret: secretDraft
                )
                secretDraft = ""
            }
            reload()
            statusMessage = "Profile saved"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveOutputPreference() {
        guard let configService else { return }
        do {
            var config = try configService.load()
            config.defaultOutputDirectory = defaultOutputDirectory
            try configService.save(config)
            statusMessage = "Output preference saved"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openSendToKindleHandoff() {
        handoffService?.openHandoff()
        statusMessage = "Opened Send to Kindle handoff"
    }
}
