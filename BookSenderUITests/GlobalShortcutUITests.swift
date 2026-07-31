import XCTest

@MainActor
final class GlobalShortcutUITests: XCTestCase {
    func testShortcutRestoresConfiguredMainWindowWithoutStartingDelivery() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetSetup",
            "-configuredSetup",
            "-uiTestPDFs",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Ready"].waitForExistence(timeout: 5))
        app.typeKey("w", modifierFlags: .command)
        app.typeKey("k", modifierFlags: [.command, .option])

        XCTAssertTrue(app.staticTexts["Send Book"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Ready"].exists)
        XCTAssertFalse(
            app.descendants(matching: .any)["notification.application"].exists
        )
        XCTAssertFalse(app.staticTexts["Send Books?"].exists)
        XCTAssertEqual(app.windows.count, 1)
    }
}
