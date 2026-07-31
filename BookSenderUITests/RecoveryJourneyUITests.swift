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
        app.launchBookSender()

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
        XCTAssertTrue(app.staticTexts["0 submitted"].exists)
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
        let diagnosticCard = app.descendants(matching: .any)[
            "notification.diagnosticCopy"
        ]
        XCTAssertTrue(
            diagnosticCard.waitForExistence(timeout: 2)
        )
        XCTAssertTrue(diagnosticCard.label.contains("Error details copied."))
        XCTAssertTrue(
            app.buttons["notification.close.diagnosticCopy"].exists
        )
        copy.click()
        XCTAssertEqual(
            app.buttons.matching(
                NSPredicate(
                    format: "identifier == %@",
                    "notification.close.diagnosticCopy"
                )
            ).count,
            1
        )
        XCTAssertTrue(app.staticTexts["Failed"].exists)
        app.buttons["notification.close.diagnosticCopy"].click()
        XCTAssertFalse(
            app.buttons["notification.close.diagnosticCopy"].exists
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
        app.launchBookSender()

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

        let diagnosticCard = app.descendants(matching: .any)[
            "notification.diagnosticCopy"
        ]
        XCTAssertTrue(
            diagnosticCard.waitForExistence(timeout: 2)
        )
        XCTAssertTrue(
            diagnosticCard.label.contains("Error details were not copied.")
        )
        XCTAssertTrue(
            app.buttons["notification.close.diagnosticCopy"].exists
        )
        XCTAssertTrue(
            diagnosticCard.label.contains("The original error remains visible.")
        )
        XCTAssertTrue(app.staticTexts["smtp.ui-test-rejected"].exists)
        XCTAssertTrue(app.staticTexts["Failed"].exists)
    }

    func testUnknownInlineRecoveryRequiresConfirmationAndNeverRetriesSilently() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetSetup",
            "-configuredSetup",
            "-uiTestPDFs",
            "-uiTestOutcomeUnknown",
            "-resetHistory",
        ]
        app.launchBookSender()

        XCTAssertTrue(app.staticTexts["Ready"].waitForExistence(timeout: 5))
        app.buttons["sendBook.send"].click()
        XCTAssertTrue(
            app.buttons["sendBook.confirm"].waitForExistence(timeout: 2)
        )
        app.buttons["sendBook.confirm"].click()

        XCTAssertTrue(
            app.staticTexts["Delivery Unknown"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.staticTexts[
            "Review Delivery Unknown items before sending them again."
        ].exists)
        XCTAssertFalse(
            app.descendants(matching: .any)["notification.batch"].exists
        )
        let review = app.buttons["sendBook.sendMore"]
        XCTAssertTrue(review.waitForExistence(timeout: 2))
        review.click()

        XCTAssertTrue(app.staticTexts["Start Another Send?"].exists)
        XCTAssertTrue(
            app.sheets.buttons["Keep Results"].firstMatch.isHittable
        )
        XCTAssertTrue(
            app.sheets.buttons["Send More Books"].firstMatch.isHittable
        )
        app.sheets.buttons["Keep Results"].firstMatch.click()
        XCTAssertTrue(app.staticTexts["Delivery Unknown"].exists)
        XCTAssertFalse(app.staticTexts["Submitted"].exists)
    }
}
