import XCTest

@MainActor
final class FloatingNotificationAppearanceUITests: XCTestCase {
    func testAccessibilityAppearanceModesKeepCardReadableAndBounded() {
        let app = launch(
            "-AppleReduceMotion",
            "YES",
            "-AppleReduceTransparency",
            "YES",
            "-AppleIncreaseContrast",
            "YES"
        )
        let card = app.descendants(matching: .any)["notification.update"]
        let close = app.buttons["notification.close.update"]

        XCTAssertTrue(card.waitForExistence(timeout: 2))
        XCTAssertTrue(
            app.staticTexts[
                "A longer supporting message wraps within the card while preserving legibility and the central workflow."
            ].exists
        )
        XCTAssertTrue(close.isHittable)
        XCTAssertGreaterThanOrEqual(close.frame.width, 28)
        XCTAssertGreaterThanOrEqual(close.frame.height, 28)
        XCTAssertTrue(app.windows.firstMatch.frame.contains(card.frame))
        XCTAssertLessThanOrEqual(card.frame.width, 360)
    }

    func testMinimumWindowSizeKeepsNotificationOffThePrimaryAction() {
        let app = launch()
        let window = app.windows.firstMatch
        let resizeHandle = window.coordinate(
            withNormalizedOffset: CGVector(dx: 1, dy: 1)
        )
        let smallerTarget = window.coordinate(
            withNormalizedOffset: CGVector(dx: 0.65, dy: 0.65)
        )
        resizeHandle.press(
            forDuration: 0.1,
            thenDragTo: smallerTarget
        )

        let card = app.descendants(matching: .any)["notification.update"]
        let primaryAction = app.buttons["sendBook.send"]
        XCTAssertTrue(card.waitForExistence(timeout: 2))
        XCTAssertTrue(primaryAction.exists)
        XCTAssertGreaterThanOrEqual(window.frame.width, 620)
        XCTAssertGreaterThanOrEqual(window.frame.height, 620)
        XCTAssertFalse(card.frame.intersects(primaryAction.frame))
        XCTAssertTrue(window.frame.contains(card.frame))
    }

    private func launch(_ additionalArguments: String...) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetSetup",
            "-configuredSetup",
            "-uiTestNotificationAppearance",
        ] + additionalArguments
        app.launch()
        XCTAssertTrue(app.staticTexts["Send Book"].waitForExistence(timeout: 5))
        return app
    }
}
