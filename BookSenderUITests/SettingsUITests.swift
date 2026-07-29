import XCTest

final class SettingsUITests: XCTestCase {
    func testEditSetupOpensDeliveryAndExposesShortcutTab() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-configuredSetup"]
        app.launch()

        app.buttons["sendBook.editSetup"].click()

        let senderAddress = app.textFields["deliverySetup.senderAddress"]
        XCTAssertTrue(senderAddress.waitForExistence(timeout: 2))
        XCTAssertNotEqual(senderAddress.value as? String, "")

        let shortcutTab = app.descendants(matching: .any)["settings.tab.shortcut"]
        XCTAssertTrue(shortcutTab.waitForExistence(timeout: 2))
        shortcutTab.click()

        XCTAssertTrue(
            app.descendants(matching: .any)["settings.shortcut"].waitForExistence(timeout: 2)
        )
        XCTAssertTrue(app.buttons["settings.shortcut.disable"].exists)
    }
}
