import XCTest

@MainActor
final class FirstBookJourneyUITests: XCTestCase {
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
        let smtpPort = app.textFields["deliverySetup.smtpPort"]
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
        replaceText(in: smtpHost, with: "smtp.example.com")
        replaceText(in: smtpPort, with: "465")
        replaceText(in: username, with: "reader")
        replaceText(in: appPassword, with: "ui-test-secret")
        replaceText(in: kindleAddress, with: "reader@kindle.com")

        app.buttons["deliverySetup.save"].click()
        XCTAssertTrue(app.staticTexts["Send Book"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Delivery Setup"].exists)
        XCTAssertFalse(app.staticTexts["ui-test-secret"].exists)

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
        element.doubleClick()
        element.typeKey("a", modifierFlags: .command)
        element.typeText(value)
    }
}
