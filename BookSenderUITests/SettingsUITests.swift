import XCTest

@MainActor
final class SettingsUITests: XCTestCase {
    func testEditSetupOpensDeliveryAndExposesShortcutTab() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetSetup",
            "-configuredSetup",
            "-uiTestPDFs",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Ready"].waitForExistence(timeout: 5))
        app.buttons["sendBook.editSetup"].click()
        app.typeKey(",", modifierFlags: .command)

        let senderAddress = app.textFields["deliverySetup.senderAddress"]
        XCTAssertTrue(senderAddress.waitForExistence(timeout: 2))
        XCTAssertNotEqual(senderAddress.value as? String, "")

        for label in [
            "Sender Address",
            "SMTP Host",
            "SMTP Port",
            "Security Mode",
            "Username",
            "App Password",
            "Kindle Address",
        ] {
            XCTAssertTrue(app.staticTexts[label].exists)
        }

        let shortcutTab = app.descendants(matching: .any)["settings.tab.shortcut"]
        XCTAssertTrue(shortcutTab.waitForExistence(timeout: 2))
        shortcutTab.click()

        XCTAssertTrue(
            app.descendants(matching: .any)["settings.shortcut"].waitForExistence(timeout: 2)
        )
        XCTAssertTrue(app.switches["settings.shortcut.enabled"].exists)
        XCTAssertTrue(
            app.staticTexts["Shortcut registered."]
                .waitForExistence(timeout: 2)
        )
        app.switches["settings.shortcut.enabled"].click()
        XCTAssertTrue(
            app.staticTexts["Shortcut disabled."]
                .waitForExistence(timeout: 2)
        )
        XCTAssertFalse(app.buttons["settings.shortcut.disable"].exists)
        XCTAssertFalse(app.staticTexts["Quick Access"].exists)
        XCTAssertFalse(app.staticTexts["Shortcut:"].exists)

        app.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["Send Book"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Ready"].exists)
    }
}
