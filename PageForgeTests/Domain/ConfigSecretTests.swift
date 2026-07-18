import XCTest
@testable import PageForge

final class ConfigSecretTests: XCTestCase {
    func testConfigDoesNotEncodeSecrets() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pageforge-config-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let configURL = dir.appendingPathComponent("config.json")
        let store = ConfigStore(configURL: configURL)
        var config = AppConfig()
        config.profiles["default"] = DeliveryProfile(
            name: "default",
            senderEmail: "a@example.com",
            kindleEmail: "b@kindle.com"
        )
        try store.save(config)

        let raw = try String(contentsOf: configURL, encoding: .utf8)
        XCTAssertFalse(raw.lowercased().contains("password"))
        XCTAssertFalse(raw.contains("secret"))
        XCTAssertTrue(raw.contains("senderEmail") || raw.contains("sender_email") || raw.contains("a@example.com"))
    }

    func testProfilesDefaultSelectionAndOutputPreferenceRoundTrip() throws {
        let (store, directoryURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let work = DeliveryProfile(name: "work", senderEmail: "work@example.com")
        let personal = DeliveryProfile(name: "personal", senderEmail: "me@example.com")
        let expected = AppConfig(
            defaultProfile: "personal",
            profiles: ["work": work, "personal": personal],
            defaultOutputDirectory: "/Users/example/Books"
        )

        try store.save(expected)

        XCTAssertEqual(try store.load(), expected)
        XCTAssertEqual(try ConfigService(store: store).defaultProfile(), personal)
    }

    func testLegacyConfigDefaultsOutputPreferenceWithoutLosingProfiles() throws {
        let (store, directoryURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let legacyJSON = """
        {
          "defaultProfile" : "default",
          "profiles" : {
            "default" : {
              "defaultOutputDir" : "",
              "kindleEmail" : "reader@kindle.com",
              "name" : "default",
              "senderEmail" : "sender@example.com",
              "smtpHost" : "smtp.example.com",
              "smtpPort" : 587,
              "smtpUsername" : "",
              "useTLS" : true
            }
          }
        }
        """
        try FileManager.default.createDirectory(
            at: store.url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(legacyJSON.utf8).write(to: store.url)

        let config = try store.load()

        XCTAssertEqual(config.defaultOutputDirectory, "")
        XCTAssertEqual(config.profiles["default"]?.kindleEmail, "reader@kindle.com")
    }

    func testSecretExistsOnlyInKeychainAndNeverInConfig() throws {
        let (store, directoryURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let serviceName = "pageforge-tests-\(UUID().uuidString)"
        let secretService = SecretService(store: KeychainSecretStore(service: serviceName))
        let profileName = "private-profile"
        let secret = "fixture-secret-value"
        defer { try? secretService.deletePassword(profileName: profileName) }

        XCTAssertFalse(secretService.hasPassword(profileName: profileName))
        try secretService.setPassword(profileName: profileName, secret: secret)
        XCTAssertTrue(secretService.hasPassword(profileName: profileName))

        try store.save(AppConfig(
            defaultProfile: profileName,
            profiles: [profileName: DeliveryProfile(name: profileName)]
        ))
        let rawConfig = try String(contentsOf: store.url, encoding: .utf8)

        XCTAssertFalse(rawConfig.contains(secret))
        XCTAssertFalse(String(describing: AppConfig()).contains(secret))
    }

    func testProfileIsNotSendReadyWhenKeychainSecretIsMissing() {
        let profile = DeliveryProfile(
            name: "reader",
            senderEmail: "sender@example.com",
            kindleEmail: "reader@kindle.com",
            smtpHost: "smtp.example.com",
            smtpUsername: "sender@example.com"
        )

        XCTAssertFalse(profile.isStructurallySendReady(hasSecret: false))
        XCTAssertTrue(profile.isStructurallySendReady(hasSecret: true))
    }

    private func makeStore() throws -> (ConfigStore, URL) {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pageforge-config-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return (
            ConfigStore(configURL: directoryURL.appendingPathComponent("config.json")),
            directoryURL
        )
    }
}
