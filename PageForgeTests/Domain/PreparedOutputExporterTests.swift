import XCTest
@testable import PageForge

final class PreparedOutputExporterTests: XCTestCase {
    func testExportCopiesPreparedOutputWithoutMovingOrMutatingSourceFiles() throws {
        let fixture = try TemporaryDocumentFactory()
        let original = try fixture.makeEPUB(named: "Original.epub")
        let prepared = try fixture.makeEPUB(named: "Original-kindle-ready.epub")
        let preparedData = try Data(contentsOf: prepared)
        let destination = fixture.directoryURL.appendingPathComponent("export", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        let results = PreparedOutputExporter().export(
            outputs: [makeOutput(source: original, prepared: prepared)],
            destinationDirectory: destination,
            conflictPolicy: .failIfExists
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].state, .succeeded)
        XCTAssertEqual(results[0].destinationURL.lastPathComponent, prepared.lastPathComponent)
        XCTAssertEqual(try Data(contentsOf: results[0].destinationURL), preparedData)
        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path))
        XCTAssertEqual(try Data(contentsOf: prepared), preparedData)
    }

    func testInvalidDestinationReturnsFailureForEveryOutput() throws {
        let fixture = try TemporaryDocumentFactory()
        let first = try fixture.makeEPUB(named: "First-kindle-ready.epub")
        let second = try fixture.makeEPUB(named: "Second-kindle-ready.epub")
        let destinationFile = try fixture.makeUnsupportedFile(named: "not-a-directory.txt")

        let results = PreparedOutputExporter().export(
            outputs: [
                makeOutput(source: first, prepared: first),
                makeOutput(source: second, prepared: second),
            ],
            destinationDirectory: destinationFile,
            conflictPolicy: .failIfExists
        )

        XCTAssertEqual(results.map(\.state), [.failed, .failed])
        XCTAssertTrue(results.allSatisfy { $0.message.contains("writable local destination") })
    }

    func testConflictDoesNotPreventOtherFilesFromBeingCopied() throws {
        let fixture = try TemporaryDocumentFactory()
        let first = try fixture.makeEPUB(named: "First-kindle-ready.epub")
        let second = try fixture.makeEPUB(named: "Second-kindle-ready.epub")
        let destination = fixture.directoryURL.appendingPathComponent("partial", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let conflictingTarget = destination.appendingPathComponent(first.lastPathComponent)
        try Data("existing destination".utf8).write(to: conflictingTarget)

        let results = PreparedOutputExporter().export(
            outputs: [
                makeOutput(source: first, prepared: first),
                makeOutput(source: second, prepared: second),
            ],
            destinationDirectory: destination,
            conflictPolicy: .failIfExists
        )

        XCTAssertEqual(results.map(\.state), [.failed, .succeeded])
        XCTAssertEqual(try String(contentsOf: conflictingTarget, encoding: .utf8), "existing destination")
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: destination.appendingPathComponent(second.lastPathComponent).path
            )
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.path))
    }

    func testConfirmedReplacementReplacesOnlyConflictingDestination() throws {
        let fixture = try TemporaryDocumentFactory()
        let prepared = try fixture.makeFile(
            named: "Replace-kindle-ready.epub",
            contents: Data("new prepared output".utf8)
        )
        let destination = fixture.directoryURL.appendingPathComponent("replace", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let target = destination.appendingPathComponent(prepared.lastPathComponent)
        try Data("old destination".utf8).write(to: target)

        let results = PreparedOutputExporter().export(
            outputs: [makeOutput(source: prepared, prepared: prepared)],
            destinationDirectory: destination,
            conflictPolicy: .replaceConfirmed
        )

        XCTAssertEqual(results.first?.state, .succeeded)
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "new prepared output")
        XCTAssertEqual(try String(contentsOf: prepared, encoding: .utf8), "new prepared output")
    }

    private func makeOutput(source: URL, prepared: URL) -> PreparedOutput {
        PreparedOutput(
            sourceURL: source,
            outputURL: prepared,
            sizeBytes: 0,
            readinessStatus: .ready
        )
    }
}
