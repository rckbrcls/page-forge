import XCTest
@testable import PageForge

final class ReadinessServiceTests: XCTestCase {
    func testOutputPathContracts() {
        let source = URL(fileURLWithPath: "/tmp/book.epub")
        XCTAssertEqual(
            OutputPathBuilder.kindleReadyEPUB(for: source).lastPathComponent,
            "book-kindle-ready.epub"
        )
        XCTAssertEqual(
            OutputPathBuilder.repairedEPUB(for: source).lastPathComponent,
            "book-repaired.epub"
        )
    }

    func testUnsupportedFormatIsBlocked() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("pageforge-test-\(UUID().uuidString).txt")
        try "hello".write(to: temp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: temp) }

        let report = try ReadinessService().audit(source: temp)
        XCTAssertEqual(report.status, .blocked)
        XCTAssertEqual(report.issues.first?.code, "unsupported_format")
    }

    func testMobiNeedsConversionIsNeedsFixes() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("pageforge-test-\(UUID().uuidString).mobi")
        try Data("mobi".utf8).write(to: temp)
        defer { try? FileManager.default.removeItem(at: temp) }

        let report = try ReadinessService().audit(source: temp)
        XCTAssertEqual(report.status, .needsFixes)
        XCTAssertEqual(report.issues.first?.code, "mobi_conversion_needed")
    }
}
