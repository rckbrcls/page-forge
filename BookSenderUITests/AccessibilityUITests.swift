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
        app.launch()

        XCTAssertTrue(app.staticTexts["Ready"].waitForExistence(timeout: 5))
        let feedback = app.descendants(matching: .any)["notification.batch"]
        XCTAssertTrue(feedback.exists)
        XCTAssertEqual(feedback.value as? String, "Succeeded")
        XCTAssertTrue(app.buttons["sendBook.dropTarget"].isHittable)
        XCTAssertTrue(app.buttons["sendBook.send"].isHittable)
        XCTAssertTrue(app.buttons["sendBook.editSetup"].isHittable)
        XCTAssertTrue(
            app.descendants(matching: .any)["sendBook.batch.card"].exists
        )
        XCTAssertTrue(app.descendants(matching: .any)["sendBook.batch"].exists)
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
        app.launch()

        XCTAssertTrue(
            app.buttons["deliverySetup.save"].waitForExistence(timeout: 5)
        )
        app.buttons["deliverySetup.save"].click()

        XCTAssertTrue(app.staticTexts["This field is required."].exists)
        let setupFeedback = app.descendants(matching: .any)[
            "notification.deliverySetup"
        ]
        XCTAssertTrue(setupFeedback.exists)
        XCTAssertEqual(setupFeedback.value as? String, "Failed")
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
        app.launch()

        XCTAssertTrue(app.staticTexts["Send Book"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Ready"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["sendBook.send"].isHittable)
        XCTAssertTrue(app.buttons["sendBook.editSetup"].isHittable)
    }

    func testDeliverySetupAccessibilityOrderStartsWithPrimaryFields() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetSetup"]
        app.launch()

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

    func testTransientBatchSuccessAppearsOnceThenCollapses() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetSetup",
            "-configuredSetup",
            "-uiTestPDFs",
            "-resetHistory",
        ]
        app.launch()

        let success = app.staticTexts["1 book ready."]
        XCTAssertTrue(success.waitForExistence(timeout: 5))
        XCTAssertEqual(
            app.staticTexts.matching(
                NSPredicate(format: "label == %@", "1 book ready.")
            ).count,
            1
        )
        XCTAssertTrue(success.waitForNonExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["Ready"].exists)
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
        app.launch()

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
        XCTAssertTrue(app.alerts.buttons["Keep Results"].isHittable)
        XCTAssertTrue(app.alerts.buttons["Send More Books"].isHittable)
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
        app.launch()

        XCTAssertTrue(
            app.descendants(matching: .any)["notification.update"]
                .waitForExistence(timeout: 2)
        )
        app.typeKey(.tab, modifierFlags: [])
        let focusedBefore = app.descendants(matching: .any).matching(
            NSPredicate(format: "hasKeyboardFocus == YES")
        ).firstMatch
        XCTAssertTrue(focusedBefore.exists)
        let identifier = focusedBefore.identifier

        XCTAssertTrue(
            app.descendants(matching: .any)["notification.update"]
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
