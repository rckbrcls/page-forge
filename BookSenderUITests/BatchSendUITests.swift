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
        XCTAssertFalse(app.staticTexts["1 book ready."].exists)
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
        XCTAssertTrue(app.buttons["sendBook.sendMore"].isEnabled)
        XCTAssertTrue(app.buttons["sendBook.dropTarget"].exists)
        XCTAssertFalse(app.staticTexts["Delivery Unknown"].exists)
        XCTAssertFalse(app.staticTexts["1 book submitted."].exists)
        XCTAssertTrue(app.buttons["sendBook.sendMore"].exists)
        XCTAssertFalse(
            app.descendants(matching: .any)["notification.batch"].exists
        )
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
        XCTAssertFalse(
            app.descendants(matching: .any)["notification.batch"].exists
        )

        app.buttons["sendBook.retryFailed"].click()
        XCTAssertTrue(
            app.buttons["sendBook.confirm"].waitForExistence(timeout: 2)
        )
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(app.staticTexts["Failed"].exists)
        XCTAssertTrue(app.buttons["sendBook.retryFailed"].isHittable)
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
        XCTAssertTrue(app.buttons["sendBook.send"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["Delivery Unknown"].exists)
        XCTAssertFalse(
            app.descendants(matching: .any)["notification.batch"].exists
        )
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
        XCTAssertFalse(
            app.descendants(matching: .any)["notification.batch"].exists
        )
    }

    func testRemoveClearAndCancellationUseOnlyDurableWorkflowState() {
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
        XCTAssertFalse(editingApp.staticTexts["UITest-1.pdf"].exists)
        XCTAssertTrue(editingApp.staticTexts["UITest-2.pdf"].exists)
        XCTAssertFalse(
            editingApp.descendants(matching: .any)["notification.batch"].exists
        )
        editingApp.buttons["sendBook.clear"].click()
        XCTAssertFalse(editingApp.staticTexts["UITest-2.pdf"].exists)
        XCTAssertFalse(
            editingApp.descendants(matching: .any)["notification.batch"].exists
        )
        XCTAssertFalse(editingApp.buttons["sendBook.send"].isEnabled)
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
            cancellationApp.staticTexts["Cancelled"].waitForExistence(timeout: 5)
        )
        XCTAssertFalse(cancellationApp.buttons["sendBook.cancel"].exists)
        XCTAssertTrue(cancellationApp.buttons["sendBook.sendMore"].isEnabled)
        XCTAssertFalse(
            cancellationApp.descendants(matching: .any)["notification.batch"]
                .exists
        )
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

    func testTwoAndThreeBookBatchesUseExactlyOneNearFullDividerPerBoundary() {
        for (argument, count) in [
            ("-uiTestTwoBooks", 2),
            ("-uiTestThreeBooks", 3),
        ] {
            let app = launchDividerBatch(
                argument,
                extraArguments: [
                    "-AppleIncreaseContrast",
                    "YES",
                ]
            )
            waitForReadyRows(count, in: app)

            let batch = app.descendants(matching: .any)["sendBook.batch"]
            let dividers = dividerElements(in: app)
            XCTAssertEqual(dividers.count, count - 1)
            assertDividerGeometry(dividers, inside: batch)

            if count == 3 {
                let window = app.windows.firstMatch
                let originalFrame = window.frame
                let resizeHandle = window.coordinate(
                    withNormalizedOffset: CGVector(dx: 1, dy: 1)
                )
                let largerTarget = window.coordinate(
                    withNormalizedOffset: CGVector(dx: 1.15, dy: 1.15)
                )
                resizeHandle.press(
                    forDuration: 0.1,
                    thenDragTo: largerTarget
                )
                XCTAssertGreaterThanOrEqual(
                    window.frame.width,
                    originalFrame.width
                )
                assertDividerGeometry(
                    dividerElements(in: app),
                    inside: batch
                )
            }

            let finalRow = try? XCTUnwrap(
                batch.descendants(matching: .any).matching(
                    NSPredicate(
                        format: "identifier BEGINSWITH 'sendBook.item.' AND NOT identifier CONTAINS '.remove.' AND NOT identifier CONTAINS '.divider.'"
                    )
                ).allElementsBoundByIndex.last
            )
            let finalID = finalRow?.identifier.replacingOccurrences(
                of: "sendBook.item.",
                with: ""
            )
            XCTAssertFalse(
                app.descendants(matching: .any)[
                    "sendBook.item.divider.\(finalID ?? "")"
                ].exists
            )
            app.terminate()
        }
    }

    func testExpandedDetailsKeepTheDividerAfterTheCompleteRow() {
        let app = launchDividerBatch(
            "-uiTestTwoBooks",
            extraArguments: ["-uiTestOutcomeFailed"]
        )
        waitForReadyRows(2, in: app)
        app.buttons["sendBook.send"].click()
        XCTAssertTrue(
            app.buttons["sendBook.confirm"].waitForExistence(timeout: 2)
        )
        app.buttons["sendBook.confirm"].click()
        XCTAssertTrue(app.staticTexts["Failed"].waitForExistence(timeout: 5))

        let divider = try? XCTUnwrap(dividerElements(in: app).first)
        let before = divider?.frame
        let details = app.buttons["failure.details.toggle"].firstMatch
        XCTAssertTrue(details.waitForExistence(timeout: 2))
        details.click()

        XCTAssertGreaterThan(divider?.frame.minY ?? 0, before?.minY ?? 0)
        XCTAssertEqual(
            divider?.frame.width ?? 0,
            before?.width ?? 0,
            accuracy: 1
        )
        assertDividerGeometry(
            divider.map { [$0] } ?? [],
            inside: app.descendants(matching: .any)["sendBook.batch"]
        )
    }

    func testTwentyBookDividerGeometrySurvivesListReuseAfterScrolling() {
        let app = launchDividerBatch("-uiTestTwentyBooks")
        waitForReadyRows(20, in: app)
        let batch = app.descendants(matching: .any)["sendBook.batch"]

        let before = visibleDividers(in: app, intersecting: batch.frame)
        XCTAssertFalse(before.isEmpty)
        assertDividerGeometry(before, inside: batch)

        batch.swipeUp()

        let after = visibleDividers(in: app, intersecting: batch.frame)
        XCTAssertFalse(after.isEmpty)
        assertDividerGeometry(after, inside: batch)
    }

    private func launchDividerBatch(
        _ countArgument: String,
        extraArguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetSetup",
            "-configuredSetup",
            "-uiTestPDFs",
            countArgument,
        ] + extraArguments
        app.launch()
        XCTAssertTrue(app.staticTexts["Send Book"].waitForExistence(timeout: 5))
        return app
    }

    private func waitForReadyRows(
        _ count: Int,
        in app: XCUIApplication
    ) {
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label == %@", "Ready")
            ).element(boundBy: count - 1).waitForExistence(timeout: 10)
        )
    }

    private func dividerElements(
        in app: XCUIApplication
    ) -> [XCUIElement] {
        app.descendants(matching: .any).matching(
            NSPredicate(
                format: "identifier BEGINSWITH 'sendBook.item.divider.'"
            )
        ).allElementsBoundByIndex
    }

    private func visibleDividers(
        in app: XCUIApplication,
        intersecting frame: CGRect
    ) -> [XCUIElement] {
        dividerElements(in: app).filter {
            !$0.frame.isEmpty && $0.frame.intersects(frame)
        }
    }

    private func assertDividerGeometry(
        _ dividers: [XCUIElement],
        inside batch: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for divider in dividers {
            let ratio = divider.frame.width / batch.frame.width
            XCTAssertGreaterThanOrEqual(
                ratio,
                0.90,
                file: file,
                line: line
            )
            let leading = divider.frame.minX - batch.frame.minX
            let trailing = batch.frame.maxX - divider.frame.maxX
            XCTAssertEqual(
                leading,
                trailing,
                accuracy: 12,
                file: file,
                line: line
            )
            XCTAssertTrue(
                batch.frame.contains(divider.frame),
                file: file,
                line: line
            )
        }
    }
}

private enum DiagnosticUITestCanary {
    static let providerProse = "private provider prose"
}
