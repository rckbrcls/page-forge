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
        XCTAssertTrue(app.buttons["sendBook.dropTarget"].isHittable)
        XCTAssertTrue(app.buttons["sendBook.send"].isHittable)
        XCTAssertTrue(app.buttons["sendBook.editSetup"].isHittable)
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
}
