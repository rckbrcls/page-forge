import XCTest
@testable import PageForge

@MainActor
final class SettingsViewModelTests: XCTestCase {
    func testReloadUsesInjectedSharedServicesForProfilesPreferencesAndLogs() {
        let personal = DeliveryProfile(name: "personal")
        let config = MockSettingsConfigService(config: AppConfig(
            defaultProfile: personal.name,
            profiles: [personal.name: personal],
            defaultOutputDirectory: "/tmp/Books"
        ))
        let secrets = MockSettingsSecretService(secretProfiles: [personal.name])
        let logs = MockSettingsLogService(entries: [
            OperationLogEntry(level: .info, message: "Shared log entry")
        ])
        let viewModel = makeViewModel(
            config: config,
            secrets: secrets,
            logs: logs
        )

        viewModel.reload()

        XCTAssertEqual(config.loadCount, 1)
        XCTAssertEqual(viewModel.selectedProfile, personal)
        XCTAssertEqual(viewModel.defaultOutputDirectory, "/tmp/Books")
        XCTAssertTrue(viewModel.hasSecret)
        XCTAssertEqual(viewModel.recentLogs.map(\.message), ["Shared log entry"])
        XCTAssertEqual(logs.requestedLimits, [20])
    }

    func testSelectAndSaveProfileUsesSameConfigAndSecretServices() {
        let existing = DeliveryProfile(name: "existing")
        let config = MockSettingsConfigService(config: AppConfig(
            defaultProfile: existing.name,
            profiles: [existing.name: existing]
        ))
        let secrets = MockSettingsSecretService(secretProfiles: [existing.name])
        let viewModel = makeViewModel(config: config, secrets: secrets)
        viewModel.reload()
        viewModel.selectProfile(existing)

        XCTAssertTrue(viewModel.hasSecret)

        viewModel.selectedProfile = DeliveryProfile(
            name: "new-profile",
            senderEmail: "sender@example.com",
            kindleEmail: "reader@kindle.com"
        )
        viewModel.secretDraft = "keychain-only-value"
        viewModel.saveProfile()

        XCTAssertEqual(config.config.defaultProfile, "new-profile")
        XCTAssertEqual(config.upsertedProfileNames, ["new-profile"])
        XCTAssertEqual(secrets.savedProfileNames, ["new-profile"])
        XCTAssertEqual(secrets.savedSecrets["new-profile"], "keychain-only-value")
        XCTAssertEqual(viewModel.secretDraft, "")
        XCTAssertEqual(viewModel.statusMessage, "Profile saved")
        XCTAssertFalse(viewModel.statusMessage?.contains("keychain-only-value") == true)
    }

    func testOutputPreferencePersistsWithoutOwningWorkflowState() {
        let config = MockSettingsConfigService(config: AppConfig())
        let viewModel = makeViewModel(config: config)
        viewModel.defaultOutputDirectory = "/tmp/Kindle Exports"

        viewModel.saveOutputPreference()

        XCTAssertEqual(config.config.defaultOutputDirectory, "/tmp/Kindle Exports")
        XCTAssertEqual(config.saveCount, 1)
        XCTAssertEqual(viewModel.statusMessage, "Output preference saved")
    }

    func testHandoffAndLogAccessUseInjectedSharedInstances() {
        let logs = MockSettingsLogService(entries: [])
        let handoff = MockHandoffService()
        let viewModel = makeViewModel(logs: logs, handoff: handoff)

        viewModel.reload()
        viewModel.openSendToKindleHandoff()

        XCTAssertEqual(logs.requestedLimits, [20])
        XCTAssertEqual(handoff.openCount, 1)
        XCTAssertEqual(viewModel.statusMessage, "Opened Send to Kindle handoff")
    }

    private func makeViewModel(
        config: MockSettingsConfigService = MockSettingsConfigService(config: AppConfig()),
        secrets: MockSettingsSecretService = MockSettingsSecretService(),
        logs: MockSettingsLogService = MockSettingsLogService(),
        handoff: MockHandoffService = MockHandoffService()
    ) -> SettingsViewModel {
        SettingsViewModel(
            configService: config,
            secretService: secrets,
            logService: logs,
            handoffService: handoff
        )
    }
}

private final class MockSettingsConfigService: SettingsConfigServicing {
    var config: AppConfig
    var loadCount = 0
    var saveCount = 0
    var upsertedProfileNames: [String] = []

    init(config: AppConfig) {
        self.config = config
    }

    func load() throws -> AppConfig {
        loadCount += 1
        return config
    }

    func save(_ config: AppConfig) throws {
        saveCount += 1
        self.config = config
    }

    func upsertProfile(_ profile: DeliveryProfile, makeDefault: Bool) throws {
        upsertedProfileNames.append(profile.name)
        config.profiles[profile.name] = profile
        if makeDefault {
            config.defaultProfile = profile.name
        }
    }

    func defaultProfile() throws -> DeliveryProfile {
        config.profiles[config.defaultProfile] ?? DeliveryProfile()
    }
}

private final class MockSettingsSecretService: SettingsSecretServicing {
    private(set) var secretProfiles: Set<String>
    private(set) var savedProfileNames: [String] = []
    private(set) var savedSecrets: [String: String] = [:]

    init(secretProfiles: Set<String> = []) {
        self.secretProfiles = secretProfiles
    }

    func setPassword(profileName: String, secret: String) throws {
        secretProfiles.insert(profileName)
        savedProfileNames.append(profileName)
        savedSecrets[profileName] = secret
    }

    func hasPassword(profileName: String) -> Bool {
        secretProfiles.contains(profileName)
    }
}

@MainActor
private final class MockSettingsLogService: SettingsLogProviding {
    var entries: [OperationLogEntry]
    private(set) var requestedLimits: [Int] = []

    init(entries: [OperationLogEntry] = []) {
        self.entries = entries
    }

    func recent(limit: Int) -> [OperationLogEntry] {
        requestedLimits.append(limit)
        return Array(entries.prefix(limit))
    }
}

private final class MockHandoffService: SendToKindleHandoffOpening {
    private(set) var openCount = 0

    func openHandoff() {
        openCount += 1
    }
}
