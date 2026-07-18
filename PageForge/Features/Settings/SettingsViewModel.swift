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

@MainActor
protocol SettingsLogProviding {
    func recent(limit: Int) -> [OperationLogEntry]
}

protocol SendToKindleHandoffOpening {
    func openHandoff()
}

extension ConfigService: SettingsConfigServicing {}
extension SecretService: SettingsSecretServicing {}
extension LogService: SettingsLogProviding {}
extension DeliveryService: SendToKindleHandoffOpening {}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var profiles: [DeliveryProfile] = []
    @Published var selectedProfile = DeliveryProfile()
    @Published var secretDraft = ""
    @Published var hasSecret = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?
    @Published var recentLogs: [OperationLogEntry] = []
    @Published var defaultOutputDirectory = ""

    private var configService: (any SettingsConfigServicing)?
    private var secretService: (any SettingsSecretServicing)?
    private var logService: (any SettingsLogProviding)?
    private var handoffService: (any SendToKindleHandoffOpening)?

    init(
        configService: (any SettingsConfigServicing)? = nil,
        secretService: (any SettingsSecretServicing)? = nil,
        logService: (any SettingsLogProviding)? = nil,
        handoffService: (any SendToKindleHandoffOpening)? = nil
    ) {
        self.configService = configService
        self.secretService = secretService
        self.logService = logService
        self.handoffService = handoffService
    }

    func bind(appState: AppState) {
        configService = appState.configService
        secretService = appState.secretService
        logService = appState.logService
        handoffService = appState.deliveryService
        reload()
    }

    func reload() {
        guard let configService,
              let secretService,
              let logService
        else {
            return
        }
        do {
            let config = try configService.load()
            profiles = config.profiles.values.sorted { $0.name < $1.name }
            selectedProfile = try configService.defaultProfile()
            hasSecret = secretService.hasPassword(profileName: selectedProfile.name)
            defaultOutputDirectory = config.defaultOutputDirectory
            recentLogs = logService.recent(limit: 20)
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
