import XCTest

final class FirstBookJourneyUITests: XCTestCase {
    func testFirstLaunchExposesOnlySetupThenSendSurface() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetSetup"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Delivery Setup"].exists)
        XCTAssertFalse(app.staticTexts["Send Book"].exists)
        XCTAssertTrue(app.secureTextFields["deliverySetup.appPassword"].exists)
    }
}
