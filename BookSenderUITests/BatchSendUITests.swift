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
        XCTAssertTrue(app.staticTexts["1 book ready."].exists)
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
        XCTAssertTrue(app.staticTexts["1 book submitted."].exists)
        XCTAssertTrue(app.staticTexts["1 submitted"].exists)
        XCTAssertTrue(app.buttons["sendBook.sendMore"].isEnabled)
        XCTAssertTrue(app.buttons["sendBook.dropTarget"].exists)
        XCTAssertFalse(app.staticTexts["Delivery Unknown"].exists)
        XCTAssertTrue(
            app.staticTexts["1 book submitted."]
                .waitForNonExistence(timeout: 6)
        )
        XCTAssertTrue(app.buttons["sendBook.sendMore"].exists)
    }

    func testSubmittedBatchStartsAnotherSendWithoutRelaunching() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetSetup",
            "-configuredSetup",
            "-uiTestPDFs",
            "-resetHistory",
            "-uiTestReintakeAfterReset",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Ready"].waitForExistence(timeout: 5))
        app.buttons["sendBook.send"].click()
        XCTAssertTrue(
            app.buttons["sendBook.confirm"].waitForExistence(timeout: 2)
        )
        app.buttons["sendBook.confirm"].click()
        XCTAssertTrue(
            app.buttons["sendBook.sendMore"].waitForExistence(timeout: 5)
        )

        app.buttons["sendBook.sendMore"].click()

        XCTAssertTrue(
            app.staticTexts["Ready for another send."]
                .waitForExistence(timeout: 2)
        )
        XCTAssertTrue(
            app.staticTexts["Ready"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.staticTexts["UITest-1.pdf"].exists)
        XCTAssertTrue(app.buttons["sendBook.send"].isEnabled)
        XCTAssertFalse(app.buttons["sendBook.sendMore"].exists)
    }

    func testFailedCompletedBatchKeepsRetryAlongsideReset() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetSetup",
            "-configuredSetup",
            "-uiTestPDFs",
            "-uiTestOutcomeFailed",
            "-resetHistory",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Ready"].waitForExistence(timeout: 5))
        app.buttons["sendBook.send"].click()
        XCTAssertTrue(
            app.buttons["sendBook.confirm"].waitForExistence(timeout: 2)
        )
        app.buttons["sendBook.confirm"].click()

        XCTAssertTrue(app.staticTexts["Failed"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["sendBook.retryFailed"].isHittable)
        XCTAssertTrue(app.buttons["sendBook.sendMore"].isHittable)
        XCTAssertFalse(app.buttons["sendBook.dropTarget"].isEnabled)
    }

    func testUnknownResetCanBeCancelledOrConfirmed() {
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
            app.buttons["sendBook.sendMore"].waitForExistence(timeout: 5)
        )

        app.buttons["sendBook.sendMore"].click()
        XCTAssertTrue(app.staticTexts["Start Another Send?"].exists)
        app.alerts.buttons["Keep Results"].click()
        XCTAssertTrue(app.staticTexts["Delivery Unknown"].exists)
        XCTAssertTrue(app.buttons["sendBook.sendMore"].isEnabled)

        app.buttons["sendBook.sendMore"].click()
        app.alerts.buttons["Send More Books"].click()
        XCTAssertTrue(
            app.staticTexts["Ready for another send."]
                .waitForExistence(timeout: 2)
        )
        XCTAssertFalse(app.staticTexts["Delivery Unknown"].exists)
    }

    func testBlockedEPUBShowsActionableDetailsAndDisclosureToggles() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetSetup",
            "-configuredSetup",
            "-uiTestInvalidEPUB",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Send Book"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts["Needs Attention"].waitForExistence(timeout: 5)
        )
        let explanation = app.staticTexts[
            "The EPUB archive is not safe to process."
        ]
        XCTAssertTrue(explanation.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["1 book needs attention."].exists)

        let details = app.buttons.matching(
            NSPredicate(format: "label == %@", "Details")
        ).firstMatch
        XCTAssertTrue(details.exists)
        details.click()
        XCTAssertTrue(explanation.waitForNonExistence(timeout: 2))
        details.click()
        XCTAssertTrue(explanation.waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["sendBook.send"].isEnabled)
    }

    func testTwentyItemMixedBatchKeepsAggregateAndEveryTerminalRow() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetSetup",
            "-configuredSetup",
            "-uiTestPDFs",
            "-uiTestTwentyBooks",
            "-uiTestOutcomeFailed",
            "-uiTestOutcomeUnknown",
        ]
        app.launch()

        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label == %@", "Ready")
            ).element(boundBy: 19).waitForExistence(timeout: 10)
        )
        app.buttons["sendBook.send"].click()
        XCTAssertTrue(
            app.buttons["sendBook.confirm"].waitForExistence(timeout: 2)
        )
        app.buttons["sendBook.confirm"].click()

        XCTAssertTrue(
            app.staticTexts["Delivery finished with mixed results."]
                .waitForExistence(timeout: 15)
        )
        XCTAssertEqual(
            app.staticTexts
                .matching(
                    NSPredicate(
                        format: "label BEGINSWITH 'UITest-'"
                    )
                )
                .count,
            20
        )
        XCTAssertTrue(app.staticTexts["Failed"].exists)
        XCTAssertTrue(app.staticTexts["Delivery Unknown"].exists)
        XCTAssertTrue(app.staticTexts["Submitted"].exists)
        XCTAssertTrue(app.buttons["sendBook.sendMore"].isEnabled)
        XCTAssertTrue(app.buttons["sendBook.retryFailed"].isEnabled)
    }

    func testRemoveClearAndCancellationPublishTerminalFeedback() {
        let editingApp = XCUIApplication()
        editingApp.launchArguments = [
            "-uiTesting",
            "-resetSetup",
            "-configuredSetup",
            "-uiTestPDFs",
            "-uiTestTwoBooks",
        ]
        editingApp.launch()

        XCTAssertTrue(
            editingApp.staticTexts.matching(
                NSPredicate(format: "label == %@", "Ready")
            ).element(boundBy: 1).waitForExistence(timeout: 5)
        )
        editingApp.buttons["Remove UITest-1.pdf"].click()
        XCTAssertTrue(
            editingApp.staticTexts["Book removed."]
                .waitForExistence(timeout: 2)
        )
        editingApp.buttons["sendBook.clear"].click()
        XCTAssertTrue(
            editingApp.staticTexts["Batch cleared."]
                .waitForExistence(timeout: 2)
        )
        XCTAssertFalse(editingApp.staticTexts["UITest-2.pdf"].exists)
        editingApp.terminate()

        let cancellationApp = XCUIApplication()
        cancellationApp.launchArguments = [
            "-uiTesting",
            "-resetSetup",
            "-configuredSetup",
            "-uiTestPDFs",
            "-uiTestSlowDelivery",
        ]
        cancellationApp.launch()

        XCTAssertTrue(
            cancellationApp.staticTexts["Ready"]
                .waitForExistence(timeout: 5)
        )
        cancellationApp.buttons["sendBook.send"].click()
        XCTAssertTrue(
            cancellationApp.buttons["sendBook.confirm"]
                .waitForExistence(timeout: 2)
        )
        cancellationApp.buttons["sendBook.confirm"].click()
        XCTAssertTrue(
            cancellationApp.buttons["sendBook.cancel"]
                .waitForExistence(timeout: 2)
        )
        XCTAssertFalse(cancellationApp.buttons["sendBook.sendMore"].exists)
        cancellationApp.buttons["sendBook.cancel"].click()

        XCTAssertTrue(
            cancellationApp.staticTexts["Operation cancelled."]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(cancellationApp.staticTexts["Cancelled"].exists)
        XCTAssertFalse(cancellationApp.buttons["sendBook.cancel"].exists)
        XCTAssertTrue(cancellationApp.buttons["sendBook.sendMore"].isEnabled)
    }

    func testControlledSMTPFailuresExposeEveryPhaseAndNumericStatus() {
        let scenarios: [
            (
                argument: String,
                code: String,
                phase: String,
                replyCode: String
            )
        ] = [
            (
                "-uiTestSMTPConnecting",
                "smtp.connection-closed",
                "Connecting",
                "421"
            ),
            (
                "-uiTestSMTPSecuring",
                "smtp.secure-channel",
                "Securing",
                "454"
            ),
            (
                "-uiTestSMTPAuthenticating",
                "smtp.authentication-rejected",
                "Authenticating",
                "535"
            ),
            (
                "-uiTestSMTPSender",
                "smtp.sender-rejected",
                "Sender envelope",
                "550"
            ),
            (
                "-uiTestSMTPRecipient",
                "smtp.recipient-rejected",
                "Recipient envelope",
                "550"
            ),
            (
                "-uiTestSMTPData",
                "smtp.data-rejected",
                "Message data",
                "450"
            ),
            (
                "-uiTestSMTPFinalAcceptance",
                "smtp.final-acceptance-rejected",
                "Final acceptance",
                "550"
            ),
        ]

        for scenario in scenarios {
            let app = XCUIApplication()
            app.launchArguments = [
                "-uiTesting",
                "-resetSetup",
                "-configuredSetup",
                "-uiTestPDFs",
                scenario.argument,
            ]
            app.launch()

            XCTAssertTrue(
                app.staticTexts["Ready"].waitForExistence(timeout: 5)
            )
            app.buttons["sendBook.send"].click()
            XCTAssertTrue(
                app.buttons["sendBook.confirm"].waitForExistence(timeout: 2)
            )
            app.buttons["sendBook.confirm"].click()
            XCTAssertTrue(
                app.staticTexts["Failed"].waitForExistence(timeout: 5)
            )
            let details = app.buttons["failure.details.toggle"].firstMatch
            XCTAssertTrue(details.waitForExistence(timeout: 2))
            details.click()

            XCTAssertTrue(
                app.staticTexts[scenario.code].waitForExistence(timeout: 2)
            )
            XCTAssertTrue(app.staticTexts[scenario.phase].exists)
            XCTAssertTrue(app.staticTexts[scenario.replyCode].exists)
            XCTAssertFalse(
                app.staticTexts[
                    DiagnosticUITestCanary.providerProse
                ].exists
            )
            app.terminate()
        }
    }
}

private enum DiagnosticUITestCanary {
    static let providerProse = "private provider prose"
}
