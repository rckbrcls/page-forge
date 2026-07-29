import XCTest

@MainActor
final class BatchSendUITests: XCTestCase {
    func testSendIsDisabledForAnEmptyBatch() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-configuredSetup"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Send Book"].exists)
        XCTAssertFalse(app.buttons["sendBook.send"].isEnabled)
        XCTAssertTrue(app.buttons["sendBook.dropTarget"].exists)
        XCTAssertFalse(app.buttons["Choose in Finder…"].exists)
        XCTAssertFalse(app.staticTexts["Books are checked and prepared locally before you confirm delivery."].exists)
    }

    func testRealFixtureBecomesReadyAndUsesFrozenConfirmationBeforeSubmission() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetSetup",
            "-configuredSetup",
            "-uiTestPDFs",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Send Book"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts["Ready"].waitForExistence(timeout: 5)
        )
        let send = app.buttons["sendBook.send"]
        XCTAssertTrue(send.isEnabled)
        send.click()

        XCTAssertTrue(app.staticTexts["Send Books?"].waitForExistence(timeout: 2))
        XCTAssertTrue(
            app.staticTexts[
                "Book Sender will send 1 book to ui-test@kindle.com."
            ].exists
        )
        XCTAssertTrue(app.buttons["sendBook.confirm"].isEnabled)
        XCTAssertFalse(app.buttons["sendBook.clear"].isEnabled)

        app.buttons["sendBook.confirm"].click()

        XCTAssertTrue(
            app.staticTexts["Submitted"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.staticTexts["1 submitted"].exists)
        XCTAssertTrue(app.buttons["sendBook.dropTarget"].exists)
        XCTAssertFalse(app.staticTexts["Delivery Unknown"].exists)
    }
}
