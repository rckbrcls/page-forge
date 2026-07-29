import XCTest

final class BatchSendUITests: XCTestCase {
    func testSendIsDisabledForAnEmptyBatch() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-configuredSetup"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Send Book"].exists)
        XCTAssertFalse(app.buttons["sendBook.send"].isEnabled)
        XCTAssertTrue(app.buttons["sendBook.dropTarget"].exists)
        XCTAssertFalse(app.buttons["Choose in Finder…"].exists)
        XCTAssertFalse(app.staticTexts["Books are checked and prepared locally before you confirm delivery."].exists)
    }
}
