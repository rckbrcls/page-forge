import XCTest

@MainActor
final class AccessibilityUITests: XCTestCase {
    func testPrimaryJourneyHasKeyboardReachableLabeledStates() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetSetup",
            "-configuredSetup",
            "-uiTestPDFs",
        ]
        app.launchBookSender()

        XCTAssertTrue(app.staticTexts["Ready"].waitForExistence(timeout: 5))
        let feedback = app.descendants(matching: .any)["notification.batch"]
        XCTAssertFalse(feedback.exists)
        XCTAssertTrue(app.buttons["sendBook.dropTarget"].isHittable)
        XCTAssertTrue(app.buttons["sendBook.send"].isHittable)
        XCTAssertTrue(app.buttons["sendBook.editSetup"].isHittable)
        XCTAssertTrue(
            app.descendants(matching: .any)["sendBook.batch.card"].exists
        )
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'sendBook.item.'"))
            .firstMatch
        XCTAssertTrue(row.exists)
        XCTAssertTrue(row.label.contains("Ready"))

        app.buttons["sendBook.send"].click()
        XCTAssertTrue(
            app.buttons["sendBook.confirm"].waitForExistence(timeout: 2)
        )
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(
            app.buttons["sendBook.send"].waitForExistence(timeout: 2)
        )
        XCTAssertFalse(app.buttons["sendBook.confirm"].exists)

        XCTAssertTrue(app.staticTexts["Ready"].exists)
        XCTAssertTrue(app.buttons["sendBook.send"].isEnabled)
        app.typeKey(.tab, modifierFlags: [])
        app.typeKey(.return, modifierFlags: [])
    }

    func testSetupErrorsAreTextualAndDoNotDependOnColor() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetSetup"]
        app.launchBookSender()

        XCTAssertTrue(
            app.buttons["deliverySetup.save"].waitForExistence(timeout: 5)
        )
        app.buttons["deliverySetup.save"].click()

        let senderError = app.descendants(matching: .any)[
            "deliverySetup.error.senderAddress"
        ]
        XCTAssertTrue(senderError.exists)
        XCTAssertEqual(senderError.label, "Error: This field is required.")
        let setupFeedback = app.descendants(matching: .any)[
            "notification.deliverySetup"
        ]
        XCTAssertFalse(setupFeedback.exists)
        XCTAssertTrue(
            app.textFields["deliverySetup.senderAddress"].isHittable
        )
        XCTAssertTrue(
            app.secureTextFields["deliverySetup.appPassword"].isHittable
        )
    }

    func testReduceTransparencyAndIncreaseContrastKeepStateReadable() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetSetup",
            "-configuredSetup",
            "-uiTestPDFs",
            "-AppleReduceTransparency",
            "YES",
            "-AppleIncreaseContrast",
            "YES",
        ]
        app.launchBookSender()

        XCTAssertTrue(app.staticTexts["Send Book"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Ready"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["sendBook.send"].isHittable)
        XCTAssertTrue(app.buttons["sendBook.editSetup"].isHittable)
    }

    func testDeliverySetupAccessibilityOrderStartsWithPrimaryFields() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetSetup"]
        app.launchBookSender()

        XCTAssertTrue(
            app.staticTexts["Delivery Setup"].waitForExistence(timeout: 5)
        )
        let fields = [
            app.textFields["deliverySetup.senderAddress"],
            app.textFields["deliverySetup.smtpHost"],
            app.textFields["deliverySetup.smtpPort"],
            app.textFields["deliverySetup.username"],
            app.secureTextFields["deliverySetup.appPassword"],
            app.textFields["deliverySetup.kindleAddress"],
        ]
        XCTAssertTrue(fields.allSatisfy { $0.exists })
        XCTAssertEqual(
            fields.map { $0.label },
            [
                "Sender Address",
                "SMTP Host",
                "SMTP Port",
                "Username",
                "App Password",
                "Kindle Address",
            ]
        )
    }

    func testContextualBatchSuccessUsesTheAccessibleRowWithoutAnnouncement() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetSetup",
            "-configuredSetup",
            "-uiTestPDFs",
            "-resetHistory",
        ]
        app.launchBookSender()

        XCTAssertTrue(app.staticTexts["Ready"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["1 book ready."].exists)
        XCTAssertTrue(app.buttons["sendBook.send"].isEnabled)
        XCTAssertFalse(
            app.descendants(matching: .any)["notification.batch"].exists
        )
    }

    func testCompletedResetIsLabeledKeyboardReachableAndConfirmsUncertainty() {
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
        let reset = app.buttons["sendBook.sendMore"]
        XCTAssertTrue(reset.waitForExistence(timeout: 5))
        XCTAssertEqual(reset.label, "Send More Books")
        XCTAssertTrue(reset.isHittable)

        app.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(app.staticTexts["Start Another Send?"].exists)
        XCTAssertTrue(
            app.sheets.buttons["Keep Results"].firstMatch.isHittable
        )
        XCTAssertTrue(
            app.sheets.buttons["Send More Books"].firstMatch.isHittable
        )
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(reset.isHittable)
        XCTAssertTrue(app.staticTexts["Delivery Unknown"].exists)
    }

    func testNotificationExpiryPreservesUnderlyingKeyboardFocus() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetSetup",
            "-configuredSetup",
            "-uiTestNotificationAppearance",
        ]
        app.launchBookSender()

        XCTAssertTrue(
            app.buttons["notification.close.update"]
                .waitForExistence(timeout: 2)
        )
        app.typeKey(.tab, modifierFlags: [])
        let focusedBefore = app.descendants(matching: .any).matching(
            NSPredicate(format: "hasKeyboardFocus == YES")
        ).firstMatch
        XCTAssertTrue(focusedBefore.exists)
        let identifier = focusedBefore.identifier

        XCTAssertTrue(
            app.buttons["notification.close.update"]
                .waitForNonExistence(timeout: 6)
        )
        XCTAssertEqual(
            app.descendants(matching: .any).matching(
                NSPredicate(format: "hasKeyboardFocus == YES")
            ).firstMatch.identifier,
            identifier
        )
    }
}

extension XCUIApplication {
    func launchBookSender() {
        launchArguments += [
            "-ApplePersistenceIgnoreState",
            "YES",
        ]
        launch()
    }
}
