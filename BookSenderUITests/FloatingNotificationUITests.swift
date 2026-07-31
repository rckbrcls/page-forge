import XCTest

@MainActor
final class FloatingNotificationUITests: XCTestCase {
    func testContextualBatchStateDoesNotCreateOrMoveANotification() {
        let app = launch("-uiTestPDFs")

        let dropTarget = app.buttons["sendBook.dropTarget"]
        let batchCard = app.descendants(matching: .any)["sendBook.batch.card"]
        let send = app.buttons["sendBook.send"]
        XCTAssertTrue(app.staticTexts["Ready"].waitForExistence(timeout: 5))

        let before = [dropTarget.frame, batchCard.frame, send.frame]
        let host = app.descendants(matching: .any)["notification.host.main"]
        let notification = app.descendants(matching: .any)[
            "notification.batch"
        ]
        XCTAssertTrue(host.exists)
        XCTAssertFalse(notification.exists)
        XCTAssertEqual(before, [dropTarget.frame, batchCard.frame, send.frame])
        XCTAssertTrue(app.staticTexts["Ready"].exists)
    }

    func testNativeConfirmationRemainsTheActiveDecisionSurface() {
        let app = launch("-uiTestPDFs")
        XCTAssertTrue(app.staticTexts["Ready"].waitForExistence(timeout: 5))
        app.buttons["sendBook.send"].click()

        let confirmation = app.buttons["sendBook.confirm"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 2))
        XCTAssertTrue(confirmation.isHittable)
        XCTAssertTrue(app.buttons["Cancel"].isHittable)
        XCTAssertFalse(
            app.descendants(matching: .any)
                .matching(
                    NSPredicate(
                        format: "identifier BEGINSWITH 'notification.action.'"
                    )
                )
                .firstMatch
                .isHittable
        )
    }

    func testReusableCardSupportsThePermittedControlMatrix() throws {
        let app = launch("-uiTestNotificationMatrix")

        let closeOnly = app.staticTexts["Close-only notification"]
        let actionOnly = app.staticTexts["Action-only notification"]
        let noControl = app.staticTexts["No-control notification"]
        XCTAssertTrue(noControl.waitForExistence(timeout: 2))
        XCTAssertTrue(closeOnly.exists)
        XCTAssertTrue(actionOnly.exists)

        XCTAssertTrue(
            app.buttons["notification.close.update"].isHittable
        )
        XCTAssertFalse(app.buttons["notification.action.update"].exists)
        XCTAssertTrue(
            app.buttons["notification.action.deliverySetup"].isHittable
        )
        XCTAssertFalse(
            app.buttons["notification.close.deliverySetup"].exists
        )
        XCTAssertFalse(app.buttons["notification.action.history"].exists)
        XCTAssertFalse(app.buttons["notification.close.history"].exists)

        let host = app.descendants(matching: .any)["notification.host.main"]
        let noControlMessage = app.staticTexts[
            "The content remains aligned without empty controls."
        ]
        XCTAssertLessThanOrEqual(noControlMessage.frame.width, host.frame.width)
        XCTAssertTrue(noControlMessage.exists)

        app.buttons["notification.close.update"].click()
        XCTAssertTrue(
            app.buttons["notification.action.batch"]
                .waitForExistence(timeout: 2)
        )
        XCTAssertEqual(
            app.buttons["notification.action.batch"].label,
            "Choose Another Book"
        )
        XCTAssertEqual(
            app.buttons["notification.close.batch"].label,
            "Dismiss notification"
        )
        let orderedControls = app.buttons.matching(
            NSPredicate(
                format: "identifier == %@ OR identifier == %@",
                "notification.action.batch",
                "notification.close.batch"
            )
        ).allElementsBoundByIndex
            .map(\.identifier)
        XCTAssertLessThan(
            try XCTUnwrap(
                orderedControls.firstIndex(
                    of: "notification.action.batch"
                )
            ),
            try XCTUnwrap(
                orderedControls.firstIndex(
                    of: "notification.close.batch"
                )
            )
        )
    }

    func testPassiveCardAddsNoInteractiveAccessibilityStop() {
        let app = launch("-uiTestNotificationMatrix")
        let passive = app.staticTexts["No-control notification"]

        XCTAssertTrue(passive.waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["notification.action.history"].exists)
        XCTAssertFalse(app.buttons["notification.close.history"].exists)
        XCTAssertTrue(
            app.staticTexts[
                "The content remains aligned without empty controls."
            ].exists
        )
    }

    func testTypedRecoveryOpensSettingsAndFocusesTheRequestedField() {
        let app = launch("-uiTestNotificationMatrix")
        let action = app.buttons["notification.action.deliverySetup"]
        XCTAssertTrue(action.waitForExistence(timeout: 2))

        action.click()

        let password = app.secureTextFields[
            "deliverySetup.appPassword"
        ]
        XCTAssertTrue(password.waitForExistence(timeout: 2))
        XCTAssertTrue(
            app.secureTextFields.matching(
                NSPredicate(
                    format: "identifier == %@ AND hasKeyboardFocus == YES",
                    "deliverySetup.appPassword"
                )
            ).firstMatch.exists
        )
    }

    func testFourthCardWaitsAndReceivesItsFullLifetimeAfterPromotion() {
        let app = launch("-uiTestNotificationStack")
        let cards = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'notification.'")
        )

        XCTAssertTrue(
            app.descendants(matching: .any)["notification.deliverySetup"]
                .waitForExistence(timeout: 2)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["notification.history"].exists
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["notification.batch"].exists
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["notification.update"].exists
        )
        XCTAssertEqual(
            cards.allElementsBoundByIndex.filter {
                $0.identifier.components(separatedBy: ".").count == 2
            }.count,
            3
        )

        app.buttons["notification.close.deliverySetup"].click()

        let promoted = app.descendants(matching: .any)[
            "notification.update"
        ]
        XCTAssertTrue(promoted.waitForExistence(timeout: 2))
        XCTAssertTrue(promoted.exists)
        XCTAssertTrue(promoted.waitForNonExistence(timeout: 6))
    }

    func testStackRemainsInTheMainWindowAcrossSettingsNavigation() {
        let app = launch("-uiTestNotificationStack")
        let mainHost = app.descendants(matching: .any)[
            "notification.host.main"
        ]
        XCTAssertTrue(mainHost.waitForExistence(timeout: 2))

        app.typeKey(",", modifierFlags: .command)

        let settingsHost = app.descendants(matching: .any)[
            "notification.host.settings"
        ]
        XCTAssertTrue(settingsHost.waitForExistence(timeout: 2))
        XCTAssertTrue(
            mainHost.descendants(matching: .any)["notification.batch"].exists
        )
        XCTAssertFalse(
            settingsHost.descendants(matching: .any)[
                "notification.batch"
            ].exists
        )
    }

    private func launch(_ additionalArguments: String...) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetSetup",
            "-configuredSetup",
            "-resetHistory",
        ] + additionalArguments
        app.launchBookSender()
        XCTAssertTrue(app.staticTexts["Send Book"].waitForExistence(timeout: 5))
        return app
    }
}
