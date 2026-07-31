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
        app.launchBookSender()

        let bootstrapProgress = app.descendants(matching: .any)[
            "app.bootstrap.progress"
        ]
        XCTAssertTrue(
            bootstrapProgress.waitForExistence(timeout: 2)
        )
        XCTAssertFalse(app.staticTexts["Delivery Setup"].exists)
        XCTAssertFalse(app.staticTexts["Send Book"].exists)

        XCTAssertTrue(app.staticTexts["Send Book"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Delivery Setup"].exists)
        XCTAssertFalse(bootstrapProgress.exists)
        XCTAssertFalse(app.staticTexts["ui-test-secret"].exists)
    }

    func testFirstLaunchValidatesSavesAndRelaunchesWithoutBypass() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetSetup"]
        app.launchBookSender()

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
        let senderError = app.descendants(matching: .any)[
            "deliverySetup.error.senderAddress"
        ]
        XCTAssertTrue(
            senderError.waitForExistence(timeout: 2)
        )
        XCTAssertEqual(
            senderError.label,
            "Error: Enter a valid email address."
        )

        replaceText(in: senderAddress, with: "reader@example.com")
        replaceText(in: smtpHost, with: "smtp.example.com")
        replaceText(in: smtpPort, with: "465")
        replaceText(in: username, with: "reader")
        replaceText(in: appPassword, with: "ui-test-secret")
        replaceText(in: kindleAddress, with: "reader@kindle.com")

        app.buttons["deliverySetup.save"].click()
        XCTAssertTrue(app.staticTexts["Send Book"].waitForExistence(timeout: 5))
        let setupCard = app.descendants(matching: .any)[
            "notification.deliverySetup"
        ]
        XCTAssertTrue(
            setupCard.waitForExistence(timeout: 2)
        )
        XCTAssertTrue(
            setupCard.label.contains(
                "Setup saved. App password stored securely."
            )
        )
        XCTAssertTrue(
            setupCard.waitForNonExistence(timeout: 6)
        )
        XCTAssertFalse(app.staticTexts["Delivery Setup"].exists)
        XCTAssertFalse(app.staticTexts["ui-test-secret"].exists)

        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))
        let relaunched = XCUIApplication()
        relaunched.launchArguments = ["-uiTesting"]
        relaunched.launchBookSender()

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
