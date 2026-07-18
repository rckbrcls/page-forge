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
}
