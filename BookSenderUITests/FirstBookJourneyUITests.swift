import XCTest

final class FirstBookJourneyUITests: XCTestCase {
    func testFirstLaunchExposesOnlySetupThenSendSurface() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetSetup"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Delivery Setup"].exists)
        XCTAssertFalse(app.staticTexts["Send Book"].exists)
        XCTAssertFalse(
            app.staticTexts["Connect the email account approved to send books to your Kindle."].exists
        )

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
    }
}
