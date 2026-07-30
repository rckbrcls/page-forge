import XCTest

@MainActor
final class SendHistoryUITests: XCTestCase {
    func testSeededHistoryIsNewestFirstAndKeepsRepeatedNames() {
        let app = launch(
            "-resetHistory",
            "-uiTestHistory"
        )
        selectHistory(in: app)

        let newest = app.staticTexts["Newest Submission.pdf"]
        let repeated = app.staticTexts.matching(
            NSPredicate(format: "label == %@", "Repeated Title.epub")
        )
        XCTAssertTrue(newest.waitForExistence(timeout: 3))
        XCTAssertEqual(repeated.count, 2)
        XCTAssertLessThan(
            newest.frame.minY,
            repeated.element(boundBy: 0).frame.minY
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["sendBook.history.list"].exists
        )
        XCTAssertTrue(app.staticTexts["3 submissions"].exists)
        XCTAssertFalse(app.buttons["Resend"].exists)
        XCTAssertFalse(app.searchFields.firstMatch.exists)
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
            unavailableApp.buttons["sendBook.history.retry"].isHittable
        )
    }

    func testClearCancellationSuccessAndFailurePreserveTheRightState() {
        let app = launch(
            "-resetHistory",
            "-uiTestHistory"
        )
        selectHistory(in: app)
        XCTAssertTrue(
            app.staticTexts["Newest Submission.pdf"]
                .waitForExistence(timeout: 3)
        )

        app.buttons["sendBook.history.clear"].click()
        XCTAssertTrue(app.staticTexts["Clear Send History?"].exists)
        app.alerts.buttons["Cancel"].click()
        XCTAssertTrue(app.staticTexts["Newest Submission.pdf"].exists)

        app.buttons["sendBook.history.clear"].click()
        app.alerts.buttons["Clear History"].click()
        XCTAssertTrue(
            app.staticTexts["No books submitted yet."]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.staticTexts["Send history cleared."].exists)
        XCTAssertFalse(app.buttons["sendBook.history.clear"].isEnabled)
        app.terminate()

        let failingApp = launch(
            "-uiTestHistory",
            "-uiTestHistoryClearFailure"
        )
        selectHistory(in: failingApp)
        XCTAssertTrue(
            failingApp.staticTexts["Newest Submission.pdf"]
                .waitForExistence(timeout: 3)
        )
        failingApp.buttons["sendBook.history.clear"].click()
        failingApp.alerts.buttons["Clear History"].click()
        XCTAssertTrue(
            failingApp.staticTexts["Send history was not cleared."]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(failingApp.staticTexts["Newest Submission.pdf"].exists)
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
            app.staticTexts["Newest Submission.pdf"]
                .waitForExistence(timeout: 3)
        )
        let firstRecord = app.descendants(matching: .any)
            .matching(
                NSPredicate(
                    format: "identifier BEGINSWITH 'sendBook.history.record.'"
                )
            )
            .firstMatch
        XCTAssertTrue(firstRecord.exists)
        XCTAssertTrue(firstRecord.label.contains("Newest Submission.pdf"))
        XCTAssertGreaterThan(firstRecord.label.count, "Newest Submission.pdf".count)
        app.terminate()

        let relaunched = launch()
        selectHistory(in: relaunched)
        XCTAssertTrue(
            relaunched.staticTexts["Newest Submission.pdf"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertEqual(
            relaunched.staticTexts.matching(
                NSPredicate(format: "label == %@", "Repeated Title.epub")
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
        utcApp.launch()
        XCTAssertTrue(
            utcApp.staticTexts["Send Book"].waitForExistence(timeout: 5)
        )
        selectHistory(in: utcApp)
        let utcLabel = historyRowLabel(in: utcApp)
        utcApp.terminate()

        let pacificApp = XCUIApplication()
        pacificApp.launchArguments = utcApp.launchArguments
        pacificApp.launchEnvironment["TZ"] = "America/Los_Angeles"
        pacificApp.launch()
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
        XCTAssertEqual(heading.label, "Send Book")
        XCTAssertTrue(editSetup.isHittable)
        XCTAssertLessThan(tabs.frame.midY, heading.frame.midY)
        XCTAssertLessThan(editSetup.frame.midY, heading.frame.midY)
        tabs.click()
        app.typeKey(.rightArrow, modifierFlags: [])
        XCTAssertTrue(
            app.descendants(matching: .any)["sendBook.history.list"]
                .waitForExistence(timeout: 2)
        )
        XCTAssertEqual(heading.label, "History")
        XCTAssertTrue(app.buttons["sendBook.history.clear"].isHittable)
        app.typeKey(.leftArrow, modifierFlags: [])
        XCTAssertEqual(heading.label, "Send Book")
    }

    private func launch(_ additionalArguments: String...) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetSetup",
            "-configuredSetup",
        ] + additionalArguments
        app.launch()
        XCTAssertTrue(app.staticTexts["Send Book"].waitForExistence(timeout: 5))
        return app
    }

    private func selectHistory(in app: XCUIApplication) {
        let tab = app.descendants(matching: .any)["sendBook.tab.history"]
        XCTAssertTrue(tab.waitForExistence(timeout: 2))
        tab.click()
    }

    private func selectSend(in app: XCUIApplication) {
        let tab = app.descendants(matching: .any)["sendBook.tab.send"]
        XCTAssertTrue(tab.waitForExistence(timeout: 2))
        tab.click()
    }

    private func historyRowLabel(in app: XCUIApplication) -> String {
        let row = app.descendants(matching: .any)
            .matching(
                NSPredicate(
                    format: "identifier BEGINSWITH 'sendBook.history.record.'"
                )
            )
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        return row.label
    }
}
