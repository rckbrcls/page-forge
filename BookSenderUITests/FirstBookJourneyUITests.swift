import XCTest

@MainActor
final class FirstBookJourneyUITests: XCTestCase {
    func testConfiguredLaunchShowsNoPrimaryScreenUntilSetupResolves() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-configuredSetup",
            "-uiTestSlowSetupLoad",
        ]
        app.launch()

        XCTAssertTrue(
            app.progressIndicators["app.bootstrap.progress"]
                .waitForExistence(timeout: 2)
        )
        XCTAssertFalse(app.staticTexts["Delivery Setup"].exists)
        XCTAssertFalse(app.staticTexts["Send Book"].exists)

        XCTAssertTrue(app.staticTexts["Send Book"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Delivery Setup"].exists)
        XCTAssertFalse(app.progressIndicators["app.bootstrap.progress"].exists)
        XCTAssertFalse(app.staticTexts["ui-test-secret"].exists)
    }

    func testFirstLaunchValidatesSavesAndRelaunchesWithoutBypass() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetSetup"]
        app.launch()

        XCTAssertTrue(
            app.staticTexts["Delivery Setup"].waitForExistence(timeout: 5)
        )
        XCTAssertFalse(app.staticTexts["Send Book"].exists)
        XCTAssertEqual(app.windows.count, 1)

        let senderAddress = app.textFields["deliverySetup.senderAddress"]
        let smtpHost = app.textFields["deliverySetup.smtpHost"]
        let username = app.textFields["deliverySetup.username"]
        let appPassword = app.secureTextFields["deliverySetup.appPassword"]
        let kindleAddress = app.textFields["deliverySetup.kindleAddress"]

        XCTAssertEqual(senderAddress.placeholderValue, "Sender Address")
        XCTAssertEqual(smtpHost.placeholderValue, "SMTP Host")
        XCTAssertEqual(username.placeholderValue, "Username")
        XCTAssertEqual(appPassword.placeholderValue, "App Password")
        XCTAssertEqual(kindleAddress.placeholderValue, "Kindle Address")
        XCTAssertFalse(app.staticTexts["Sender Address"].exists)
        XCTAssertFalse(app.staticTexts["SMTP Host"].exists)
        XCTAssertFalse(app.staticTexts["SMTP Port"].exists)
        XCTAssertFalse(app.staticTexts["Security Mode"].exists)
        XCTAssertFalse(app.staticTexts["Username"].exists)
        XCTAssertFalse(app.staticTexts["App Password"].exists)
        XCTAssertFalse(app.staticTexts["Kindle Address"].exists)
        XCTAssertTrue(app.buttons["deliverySetup.save"].exists)
        XCTAssertFalse(app.staticTexts["Quick Access"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["settings.shortcut"].exists)

        senderAddress.click()
        senderAddress.typeText("invalid")
        app.buttons["deliverySetup.save"].click()
        XCTAssertTrue(
            app.staticTexts["Enter a valid email address."]
                .waitForExistence(timeout: 2)
        )

        replaceText(in: senderAddress, with: "reader@example.com")
        app.typeKey(.tab, modifierFlags: [])
        app.typeText("smtp.example.com")
        app.typeKey(.tab, modifierFlags: [])
        app.typeText("465")
        app.typeKey(.tab, modifierFlags: [])
        app.typeText("reader")
        app.typeKey(.tab, modifierFlags: [])
        app.typeText("ui-test-secret")
        app.typeKey(.tab, modifierFlags: [])
        app.typeText("reader@kindle.com")

        app.buttons["deliverySetup.save"].click()
        XCTAssertTrue(app.staticTexts["Send Book"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts[
                "Setup saved. App password stored securely."
            ].waitForExistence(timeout: 2)
        )
        XCTAssertTrue(
            app.staticTexts[
                "Setup saved. App password stored securely."
            ].waitForNonExistence(timeout: 6)
        )
        XCTAssertFalse(app.staticTexts["Delivery Setup"].exists)
        XCTAssertFalse(app.staticTexts["ui-test-secret"].exists)
        app.buttons["sendBook.editSetup"].click()
        app.typeKey(",", modifierFlags: .command)
        let clearedPassword = app.secureTextFields[
            "deliverySetup.appPassword"
        ]
        XCTAssertTrue(clearedPassword.waitForExistence(timeout: 2))
        XCTAssertEqual(clearedPassword.value as? String, "")

        app.terminate()
        let relaunched = XCUIApplication()
        relaunched.launchArguments = ["-uiTesting"]
        relaunched.launch()

        XCTAssertTrue(
            relaunched.staticTexts["Send Book"].waitForExistence(timeout: 5)
        )
        XCTAssertFalse(relaunched.staticTexts["Delivery Setup"].exists)
        XCTAssertFalse(relaunched.staticTexts["ui-test-secret"].exists)
        XCTAssertEqual(relaunched.windows.count, 1)
    }

    private func replaceText(
        in element: XCUIElement,
        with value: String
    ) {
        element.click()
        element.typeKey("a", modifierFlags: .command)
        element.typeText(value)
    }
}
