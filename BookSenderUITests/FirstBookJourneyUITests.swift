import XCTest

final class FirstBookJourneyUITests: XCTestCase {
    func testFirstLaunchExposesOnlySetupThenSendSurface() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetSetup"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Delivery Setup"].exists)
        XCTAssertFalse(app.staticTexts["Send Book"].exists)
        XCTAssertFalse(
            app.staticTexts["Connect the email account approved to send books to your Kindle."].exists
        )
        XCTAssertTrue(app.secureTextFields["deliverySetup.appPassword"].exists)
        XCTAssertTrue(app.buttons["deliverySetup.save"].exists)
        XCTAssertFalse(app.staticTexts["Quick Access"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["settings.shortcut"].exists)
    }
}
