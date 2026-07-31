import XCTest

@MainActor
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
        XCTAssertTrue(app.staticTexts["Delivery finished with mixed results."].exists)
        XCTAssertTrue(app.staticTexts["Review Delivery Unknown items before sending them again."].exists)
        XCTAssertTrue(app.buttons["sendBook.retryFailed"].isEnabled)

        let details = app.buttons["failure.details.toggle"].firstMatch
        XCTAssertTrue(details.waitForExistence(timeout: 2))
        details.click()
        XCTAssertTrue(
            app.staticTexts["smtp.ui-test-rejected"]
                .waitForExistence(timeout: 2)
        )
        XCTAssertTrue(app.staticTexts["Delivery"].exists)
        let copy = app.buttons["failure.copy"].firstMatch
        XCTAssertTrue(copy.waitForExistence(timeout: 2))
        copy.click()
        XCTAssertTrue(
            app.staticTexts["Error details copied."]
                .waitForExistence(timeout: 2)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "notification.diagnosticCopy"
            ].exists
        )
        XCTAssertTrue(app.staticTexts["Failed"].exists)
        app.buttons["notification.close.diagnosticCopy"].click()
        XCTAssertFalse(
            app.descendants(matching: .any)[
                "notification.diagnosticCopy"
            ].exists
        )
        XCTAssertTrue(app.staticTexts["smtp.ui-test-rejected"].exists)
        XCTAssertTrue(app.staticTexts["Failed"].exists)

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

    func testClipboardFailureKeepsOriginalDiagnosticVisible() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetSetup",
            "-configuredSetup",
            "-uiTestPDFs",
            "-uiTestOutcomeFailed",
            "-uiTestClipboardFailure",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Ready"].waitForExistence(timeout: 5))
        app.buttons["sendBook.send"].click()
        XCTAssertTrue(
            app.buttons["sendBook.confirm"].waitForExistence(timeout: 2)
        )
        app.buttons["sendBook.confirm"].click()
        XCTAssertTrue(app.staticTexts["Failed"].waitForExistence(timeout: 5))

        let details = app.buttons["failure.details.toggle"].firstMatch
        XCTAssertTrue(details.waitForExistence(timeout: 2))
        details.click()
        XCTAssertTrue(
            app.staticTexts["smtp.ui-test-rejected"]
                .waitForExistence(timeout: 2)
        )
        app.buttons["failure.copy"].firstMatch.click()

        XCTAssertTrue(
            app.staticTexts["Error details were not copied."]
                .waitForExistence(timeout: 2)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "notification.diagnosticCopy"
            ].exists
        )
        XCTAssertTrue(
            app.staticTexts["The original error remains visible."].exists
        )
        XCTAssertTrue(app.staticTexts["smtp.ui-test-rejected"].exists)
        XCTAssertTrue(app.staticTexts["Failed"].exists)
    }

    func testUnknownNotificationRequiresConfirmationAndNeverRetriesSilently() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetSetup",
            "-configuredSetup",
            "-uiTestPDFs",
            "-uiTestOutcomeUnknown",
            "-resetHistory",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Ready"].waitForExistence(timeout: 5))
        app.buttons["sendBook.send"].click()
        XCTAssertTrue(
            app.buttons["sendBook.confirm"].waitForExistence(timeout: 2)
        )
        app.buttons["sendBook.confirm"].click()

        XCTAssertTrue(
            app.staticTexts["Delivery Unknown"].waitForExistence(timeout: 5)
        )
        let review = app.buttons["notification.action.batch"]
        XCTAssertTrue(review.waitForExistence(timeout: 2))
        XCTAssertEqual(review.label, "Check Kindle Before Retrying")
        review.click()

        XCTAssertTrue(app.staticTexts["Start Another Send?"].exists)
        XCTAssertTrue(app.alerts.buttons["Keep Results"].isHittable)
        XCTAssertTrue(app.alerts.buttons["Send More Books"].isHittable)
        app.alerts.buttons["Keep Results"].click()
        XCTAssertTrue(app.staticTexts["Delivery Unknown"].exists)
        XCTAssertFalse(app.staticTexts["Submitted"].exists)
    }
}
