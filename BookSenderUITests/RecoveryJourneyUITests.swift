import XCTest

final class RecoveryJourneyUITests: XCTestCase {
    func testMixedOutcomesPreserveUnknownAndRetryOnlyFailed() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetSetup",
            "-configuredSetup",
            "-uiTestPDFs",
            "-uiTestTwoBooks",
            "-uiTestOutcomeFailed",
            "-uiTestOutcomeUnknown",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Ready"].waitForExistence(timeout: 5))
        app.buttons["sendBook.send"].click()
        XCTAssertTrue(
            app.buttons["sendBook.confirm"].waitForExistence(timeout: 2)
        )
        app.buttons["sendBook.confirm"].click()

        XCTAssertTrue(app.staticTexts["Failed"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts["Delivery Unknown"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.staticTexts["Review Delivery Unknown items before sending them again."].exists)
        XCTAssertTrue(app.buttons["sendBook.retryFailed"].isEnabled)

        app.buttons["sendBook.retryFailed"].click()
        XCTAssertTrue(
            app.staticTexts[
                "Book Sender will send 1 book to ui-test@kindle.com."
            ].waitForExistence(timeout: 2)
        )
        app.buttons["sendBook.confirm"].click()

        XCTAssertTrue(app.staticTexts["Submitted"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Delivery Unknown"].exists)
        XCTAssertFalse(app.buttons["sendBook.retryFailed"].exists)
    }
}
