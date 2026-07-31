import XCTest

@MainActor
final class SettingsUITests: XCTestCase {
    func testEditSetupOpensDeliveryAndExposesShortcutTab() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetSetup",
            "-configuredSetup",
            "-uiTestPDFs",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Ready"].waitForExistence(timeout: 5))
        app.buttons["sendBook.editSetup"].click()
        app.typeKey(",", modifierFlags: .command)

        let senderAddress = app.textFields["deliverySetup.senderAddress"]
        XCTAssertTrue(senderAddress.waitForExistence(timeout: 2))
        XCTAssertNotEqual(senderAddress.value as? String, "")

        for label in [
            "Sender Address",
            "SMTP Host",
            "SMTP Port",
            "Security Mode",
            "Username",
            "App Password",
            "Kindle Address",
        ] {
            XCTAssertTrue(app.staticTexts[label].exists)
        }

        let deliveryScroll = app.scrollViews["settings.delivery.scroll"]
        XCTAssertTrue(deliveryScroll.waitForExistence(timeout: 2))
        deliveryScroll.swipeUp()

        let deleteSetup = app.buttons["deliverySetup.delete"]
        XCTAssertTrue(deleteSetup.waitForExistence(timeout: 2))
        XCTAssertTrue(deleteSetup.isHittable)

        let shortcutTab = app.descendants(matching: .any)["settings.tab.shortcut"]
        XCTAssertTrue(shortcutTab.waitForExistence(timeout: 2))
        shortcutTab.click()

        XCTAssertTrue(
            app.descendants(matching: .any)["settings.shortcut"].waitForExistence(timeout: 2)
        )
        XCTAssertTrue(app.switches["settings.shortcut.enabled"].exists)
        XCTAssertFalse(
            app.staticTexts[
                "Reveal the existing Book Sender window from any app."
            ].exists
        )
        XCTAssertFalse(app.staticTexts["Shortcut registered."].exists)
        app.switches["settings.shortcut.enabled"].click()
        XCTAssertFalse(app.staticTexts["Shortcut disabled."].exists)
        XCTAssertEqual(
            app.switches["settings.shortcut.enabled"].value as? String,
            "0"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["notification.shortcut"].exists
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["settings.shortcut"].isEnabled
        )
        XCTAssertFalse(app.buttons["settings.shortcut.disable"].exists)
        XCTAssertFalse(app.staticTexts["Quick Access"].exists)
        XCTAssertFalse(app.staticTexts["Shortcut:"].exists)

        app.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["Send Book"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Ready"].exists)
    }

    func testSettingsSaveAndDeleteUseOnlyCredentialOutcomeCards() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetSetup",
            "-configuredSetup",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Send Book"].waitForExistence(timeout: 5))
        app.typeKey(",", modifierFlags: .command)
        let scroll = app.scrollViews["settings.delivery.scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 2))
        scroll.swipeUp()

        app.buttons["deliverySetup.save"].click()
        let setupCard = app.descendants(matching: .any)[
            "notification.deliverySetup"
        ]
        XCTAssertTrue(setupCard.waitForExistence(timeout: 2))
        XCTAssertTrue(
            app.staticTexts["Setup saved. App password stored securely."].exists
        )
        XCTAssertEqual(
            app.descendants(matching: .any).matching(
                NSPredicate(
                    format: "identifier == %@",
                    "notification.deliverySetup"
                )
            ).count,
            1
        )

        app.buttons["deliverySetup.delete"].click()
        XCTAssertTrue(
            app.staticTexts["Delivery setup deleted."]
                .waitForExistence(timeout: 2)
        )
        XCTAssertEqual(
            app.descendants(matching: .any).matching(
                NSPredicate(
                    format: "identifier == %@",
                    "notification.deliverySetup"
                )
            ).count,
            1
        )
    }
}
