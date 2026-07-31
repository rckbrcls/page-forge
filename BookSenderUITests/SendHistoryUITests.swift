import XCTest

@MainActor
final class SendHistoryUITests: XCTestCase {
    func testSeededHistoryIsNewestFirstAndKeepsRepeatedNames() {
        let app = launch(
            "-resetHistory",
            "-uiTestHistory"
        )
        selectHistory(in: app)

        let newest = historyRow(in: app, containing: "Newest Submission.pdf")
        let repeated = historyRows(in: app).matching(
            NSPredicate(format: "label CONTAINS %@", "Repeated Title.epub")
        )
        XCTAssertTrue(app.staticTexts["3 submissions"].waitForExistence(timeout: 3))
        XCTAssertTrue(newest.exists)
        XCTAssertEqual(repeated.count, 2)
        XCTAssertLessThan(
            newest.frame.minY,
            repeated.element(boundBy: 0).frame.minY
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["sendBook.history.list"].exists
        )
        XCTAssertTrue(app.staticTexts["3 submissions"].exists)
        let historyList = app.descendants(matching: .any)[
            "sendBook.history.list"
        ]
        XCTAssertFalse(
            historyList.descendants(matching: .searchField).firstMatch.exists
        )
    }

    func testEmptyAndUnavailableHistoryAreDistinct() {
        let emptyApp = launch("-resetHistory")
        selectHistory(in: emptyApp)
        let emptyState = emptyApp.staticTexts["No books submitted yet."]
        XCTAssertTrue(emptyState.waitForExistence(timeout: 3))
        XCTAssertLessThan(
            abs(emptyState.frame.midX - emptyApp.windows.firstMatch.frame.midX),
            48
        )
        XCTAssertFalse(
            emptyApp.staticTexts["Send History Unavailable"].exists
        )
        emptyApp.terminate()
        XCTAssertTrue(emptyApp.wait(for: .notRunning, timeout: 5))

        let unavailableApp = launch(
            "-resetHistory",
            "-uiTestHistoryUnavailable"
        )
        selectHistory(in: unavailableApp)
        XCTAssertTrue(
            unavailableApp.staticTexts["Send History Unavailable"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertFalse(
            unavailableApp.staticTexts["No books submitted yet."].exists
        )
        XCTAssertTrue(
            unavailableApp.buttons["Retry"].isHittable
        )
        XCTAssertFalse(
            unavailableApp.descendants(matching: .any)["notification.history"]
                .exists
        )
    }

    func testClearCancellationSuccessAndFailurePreserveTheRightState() {
        let app = launch(
            "-resetHistory",
            "-uiTestHistory"
        )
        selectHistory(in: app)
        XCTAssertTrue(
            historyRow(in: app, containing: "Newest Submission.pdf")
                .waitForExistence(timeout: 3)
        )

        app.buttons["sendBook.history.clear"].click()
        XCTAssertTrue(app.staticTexts["Clear Send History?"].exists)
        app.sheets.buttons["Cancel"].firstMatch.click()
        XCTAssertTrue(
            historyRow(in: app, containing: "Newest Submission.pdf").exists
        )

        app.buttons["sendBook.history.clear"].click()
        app.sheets.buttons["Clear History"].firstMatch.click()
        XCTAssertTrue(
            app.staticTexts["No books submitted yet."]
                .waitForExistence(timeout: 3)
        )
        XCTAssertFalse(app.staticTexts["Send history cleared."].exists)
        XCTAssertFalse(
            app.descendants(matching: .any)["notification.history"].exists
        )
        XCTAssertFalse(app.buttons["sendBook.history.clear"].isEnabled)
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))

        let failingApp = launch(
            "-uiTestHistory",
            "-uiTestHistoryClearFailure"
        )
        selectHistory(in: failingApp)
        XCTAssertTrue(
            historyRow(in: failingApp, containing: "Newest Submission.pdf")
                .waitForExistence(timeout: 3)
        )
        failingApp.buttons["sendBook.history.clear"].click()
        let confirmClear = failingApp.sheets.buttons["Clear History"].firstMatch
        XCTAssertTrue(confirmClear.waitForExistence(timeout: 2))
        confirmClear.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)
        ).click()
        let details = failingApp.buttons["failure.details.toggle"]
        XCTAssertTrue(
            details.waitForExistence(timeout: 3)
        )
        details.click()
        XCTAssertTrue(
            failingApp.staticTexts[
                "Book Sender could not remove the local submission record."
            ].waitForExistence(timeout: 2)
        )
        XCTAssertFalse(
            failingApp.descendants(matching: .any)["notification.history"].exists
        )
        XCTAssertTrue(
            historyRow(
                in: failingApp,
                containing: "Newest Submission.pdf"
            ).exists
        )
    }

    func testAcceptedDeliveryHistoryWriteFailurePublishesOnePersistentCard() {
        let app = launch(
            "-resetHistory",
            "-uiTestPDFs",
            "-uiTestHistoryWriteFailure"
        )

        XCTAssertTrue(app.staticTexts["Ready"].waitForExistence(timeout: 5))
        app.buttons["sendBook.send"].click()
        XCTAssertTrue(
            app.buttons["sendBook.confirm"].waitForExistence(timeout: 2)
        )
        app.buttons["sendBook.confirm"].click()

        XCTAssertTrue(app.staticTexts["Submitted"].waitForExistence(timeout: 5))
        let historyClose = app.buttons["notification.close.history"]
        XCTAssertTrue(historyClose.waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.staticTexts["Book sent, but history was not updated."].exists
        )
        XCTAssertEqual(
            app.buttons.matching(
                NSPredicate(
                    format: "identifier == %@",
                    "notification.close.history"
                )
            ).count,
            1
        )
        XCTAssertFalse(app.buttons["sendBook.retryFailed"].exists)
        XCTAssertFalse(app.buttons["sendBook.confirm"].exists)

        selectHistory(in: app)
        XCTAssertTrue(
            app.staticTexts["No books submitted yet."]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(historyClose.exists)
    }

    func testHistoryPersistsAcrossRelaunchAndUsesReadableDateTimeRows() {
        let app = launch(
            "-resetHistory",
            "-uiTestHistory",
            "-AppleLocale",
            "en_US"
        )
        selectHistory(in: app)
        XCTAssertTrue(
            historyRow(in: app, containing: "Newest Submission.pdf")
                .waitForExistence(timeout: 3)
        )
        let firstRecord = historyRow(
            in: app,
            containing: "Newest Submission.pdf"
        )
        XCTAssertTrue(firstRecord.exists)
        XCTAssertTrue(firstRecord.label.contains("Newest Submission.pdf"))
        XCTAssertGreaterThan(firstRecord.label.count, "Newest Submission.pdf".count)
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))

        let relaunched = launch()
        selectHistory(in: relaunched)
        XCTAssertTrue(
            historyRow(in: relaunched, containing: "Newest Submission.pdf")
                .waitForExistence(timeout: 3)
        )
        XCTAssertEqual(
            historyRows(in: relaunched).matching(
                NSPredicate(format: "label CONTAINS %@", "Repeated Title.epub")
            ).count,
            2
        )
    }

    func testHistoryRowsUseTheCurrentTimeZoneAtPresentationTime() {
        let utcApp = XCUIApplication()
        utcApp.launchArguments = [
            "-uiTesting",
            "-resetSetup",
            "-configuredSetup",
            "-resetHistory",
            "-uiTestHistory",
            "-AppleLocale",
            "en_US",
        ]
        utcApp.launchEnvironment["TZ"] = "UTC"
        utcApp.launchBookSender()
        XCTAssertTrue(
            utcApp.staticTexts["Send Book"].waitForExistence(timeout: 5)
        )
        selectHistory(in: utcApp)
        let utcLabel = historyRowLabel(in: utcApp)
        utcApp.terminate()
        XCTAssertTrue(utcApp.wait(for: .notRunning, timeout: 5))

        let pacificApp = XCUIApplication()
        pacificApp.launchArguments = utcApp.launchArguments
        pacificApp.launchEnvironment["TZ"] = "America/Los_Angeles"
        pacificApp.launchBookSender()
        XCTAssertTrue(
            pacificApp.staticTexts["Send Book"].waitForExistence(timeout: 5)
        )
        selectHistory(in: pacificApp)
        let pacificLabel = historyRowLabel(in: pacificApp)

        XCTAssertNotEqual(utcLabel, pacificLabel)
        XCTAssertTrue(utcLabel.contains("Newest Submission.pdf"))
        XCTAssertTrue(pacificLabel.contains("Newest Submission.pdf"))
    }

    func testTabSwitchingPreservesReadyAndActiveBatchState() {
        let readyApp = launch(
            "-resetHistory",
            "-uiTestPDFs"
        )
        XCTAssertTrue(
            readyApp.staticTexts["Ready"].waitForExistence(timeout: 5)
        )
        selectHistory(in: readyApp)
        XCTAssertTrue(
            readyApp.staticTexts["No books submitted yet."]
                .waitForExistence(timeout: 3)
        )
        selectSend(in: readyApp)
        XCTAssertTrue(readyApp.staticTexts["Ready"].exists)
        XCTAssertTrue(readyApp.buttons["sendBook.send"].isEnabled)
        readyApp.terminate()
        XCTAssertTrue(readyApp.wait(for: .notRunning, timeout: 5))

        let activeApp = launch(
            "-resetHistory",
            "-uiTestPDFs",
            "-uiTestSlowDelivery"
        )
        XCTAssertTrue(
            activeApp.staticTexts["Ready"].waitForExistence(timeout: 5)
        )
        activeApp.buttons["sendBook.send"].click()
        XCTAssertTrue(
            activeApp.buttons["sendBook.confirm"].waitForExistence(timeout: 2)
        )
        activeApp.buttons["sendBook.confirm"].click()
        XCTAssertTrue(
            activeApp.buttons["sendBook.cancel"].waitForExistence(timeout: 2)
        )
        selectHistory(in: activeApp)
        XCTAssertTrue(
            activeApp.descendants(matching: .any)["sendBook.tabs"].exists
        )
        selectSend(in: activeApp)
        XCTAssertTrue(activeApp.buttons["sendBook.cancel"].isHittable)
    }

    func testTabsAndClearAreKeyboardReachableWithAccessibleLabels() {
        let app = launch(
            "-resetHistory",
            "-uiTestHistory"
        )
        let tabs = app.descendants(matching: .any)["sendBook.tabs"]
        let send = app.descendants(matching: .any)["sendBook.tab.send"]
        let history = app.descendants(matching: .any)["sendBook.tab.history"]

        XCTAssertTrue(tabs.isHittable)
        XCTAssertEqual(send.label, "Send")
        XCTAssertEqual(history.label, "History")
        let heading = app.staticTexts["sendBook.title"]
        let editSetup = app.buttons["sendBook.editSetup"]
        XCTAssertTrue(heading.exists)
        XCTAssertTrue(app.staticTexts["Send Book"].exists)
        XCTAssertTrue(editSetup.isHittable)
        XCTAssertLessThan(tabs.frame.midY, heading.frame.midY)
        XCTAssertLessThan(editSetup.frame.midY, heading.frame.midY)
        XCTAssertTrue(send.isHittable)
        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(
            app.descendants(matching: .any)["sendBook.history.list"]
                .waitForExistence(timeout: 2)
        )
        XCTAssertTrue(app.staticTexts["History"].exists)
        XCTAssertTrue(app.buttons["sendBook.history.clear"].isHittable)
        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["Send Book"].exists)
        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["History"].exists)
    }

    private func launch(_ additionalArguments: String...) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetSetup",
            "-configuredSetup",
        ] + additionalArguments
        app.launchBookSender()
        XCTAssertTrue(app.staticTexts["Send Book"].waitForExistence(timeout: 8))
        return app
    }

    private func selectHistory(in app: XCUIApplication) {
        let tab = app.descendants(matching: .any)["sendBook.tab.history"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        tab.click()
    }

    private func selectSend(in app: XCUIApplication) {
        let tab = app.descendants(matching: .any)["sendBook.tab.send"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        tab.click()
    }

    private func historyRowLabel(in app: XCUIApplication) -> String {
        let row = historyRows(in: app).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        return row.label
    }

    private func historyRows(in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(
            NSPredicate(
                format: "identifier BEGINSWITH 'sendBook.history.record.'"
            )
        )
    }

    private func historyRow(
        in app: XCUIApplication,
        containing displayName: String
    ) -> XCUIElement {
        historyRows(in: app).matching(
            NSPredicate(format: "label CONTAINS %@", displayName)
        ).firstMatch
    }
}
