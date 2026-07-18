import XCTest
@testable import PageForge

final class RepairServiceTests: XCTestCase {
    func testDefaultRepairedFilename() {
        let source = URL(fileURLWithPath: "/tmp/novel.epub")
        let output = OutputPathBuilder.repairedEPUB(for: source)
        XCTAssertTrue(output.lastPathComponent.hasSuffix("-repaired.epub"))
    }

    func testOverwriteGuard() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pageforge-overwrite-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let existing = dir.appendingPathComponent("out.epub")
        try Data("x".utf8).write(to: existing)

        XCTAssertThrowsError(try FilePathValidator.prepareOutput(existing, overwrite: false))
        let prepared = try FilePathValidator.prepareOutput(existing, overwrite: true)
        XCTAssertEqual(prepared.path, existing.path)
        XCTAssertFalse(FileManager.default.fileExists(atPath: existing.path))
    }
}
