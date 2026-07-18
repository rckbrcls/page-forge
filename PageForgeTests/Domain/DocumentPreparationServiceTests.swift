import XCTest
@testable import PageForge

final class DocumentPreparationServiceTests: XCTestCase {
    func testEPUBDelegatesToReadinessWithKindleReadyOutputAndPreservesSource() throws {
        let fixture = try TemporaryDocumentFactory()
        let source = try fixture.makeEPUB(named: "Novel.epub")
        let original = try Data(contentsOf: source)
        let readiness = ReadinessPreparingSpy()
        readiness.handler = { input, output, overwrite, _ in
            XCTAssertEqual(input, source)
            XCTAssertEqual(output?.lastPathComponent, "Novel-kindle-ready.epub")
            XCTAssertFalse(overwrite)
            try Data("prepared".utf8).write(to: output!)
            return ReadinessReport(inputPath: input, status: .ready, outputPath: output)
        }
        let service = DocumentPreparationService(
            readinessService: readiness,
            conversionService: EPUBConvertingSpy()
        )

        let result = try service.prepare(source: source, format: .epub, overwrite: false) { _ in }

        XCTAssertEqual(result.sourceURL, source)
        XCTAssertEqual(result.preparedOutput?.outputURL.lastPathComponent, "Novel-kindle-ready.epub")
        XCTAssertEqual(try Data(contentsOf: source), original)
        XCTAssertEqual(readiness.calls.count, 1)
    }

    func testMOBIDelegatesToReadinessAndPreservesConversionContext() throws {
        let fixture = try TemporaryDocumentFactory()
        let source = try fixture.makeMOBI(named: "Archive.mobi")
        let readiness = ReadinessPreparingSpy()
        readiness.handler = { input, output, _, _ in
            try Data("prepared".utf8).write(to: output!)
            return ReadinessReport(
                inputPath: input,
                status: .ready,
                outputPath: output,
                convertedFrom: input
            )
        }
        let service = DocumentPreparationService(
            readinessService: readiness,
            conversionService: EPUBConvertingSpy()
        )

        let result = try service.prepare(source: source, format: .mobi, overwrite: false) { _ in }

        XCTAssertEqual(result.report.convertedFrom, source)
        XCTAssertEqual(result.preparedOutput?.outputURL.lastPathComponent, "Archive-kindle-ready.epub")
    }

    func testPDFConvertsBeforeReadinessRemapsSourceAddsOCRWarningAndCleansWorkingFiles() throws {
        let fixture = try TemporaryDocumentFactory()
        let source = try fixture.makePDF(named: "Scan.pdf")
        let original = try Data(contentsOf: source)
        let workingRoot = fixture.directoryURL.appendingPathComponent("working", isDirectory: true)
        try FileManager.default.createDirectory(at: workingRoot, withIntermediateDirectories: true)
        let events = EventRecorder()
        let converter = EPUBConvertingSpy()
        converter.handler = { input, output, _, _ in
            events.values.append("convert")
            XCTAssertEqual(input, source)
            XCTAssertTrue(output.path.hasPrefix(workingRoot.path))
            try Data("temporary epub".utf8).write(to: output)
            return ConversionResult(inputPath: input, outputPath: output)
        }
        let readiness = ReadinessPreparingSpy()
        readiness.handler = { input, output, _, _ in
            events.values.append("readiness")
            XCTAssertTrue(FileManager.default.fileExists(atPath: input.path))
            XCTAssertEqual(output?.lastPathComponent, "Scan-kindle-ready.epub")
            try Data("prepared".utf8).write(to: output!)
            return ReadinessReport(inputPath: input, status: .ready, outputPath: output)
        }
        let service = DocumentPreparationService(
            readinessService: readiness,
            conversionService: converter,
            temporaryDirectory: workingRoot
        )

        let result = try service.prepare(source: source, format: .pdf, overwrite: false) { _ in }

        XCTAssertEqual(events.values, ["convert", "readiness"])
        XCTAssertEqual(result.sourceURL, source)
        XCTAssertEqual(result.report.inputPath, source)
        XCTAssertEqual(result.report.convertedFrom, source)
        XCTAssertTrue(result.report.issues.contains(where: { $0.code == "pdf_no_ocr" && $0.severity == .warning }))
        XCTAssertEqual(result.preparedOutput?.sourceURL, source)
        XCTAssertEqual(try Data(contentsOf: source), original)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: workingRoot.path).isEmpty)
    }

    func testExistingOutputFailsBeforeDelegationWhenOverwriteIsDisabled() throws {
        let fixture = try TemporaryDocumentFactory()
        let source = try fixture.makeEPUB(named: "Existing.epub")
        _ = try fixture.makeEPUB(named: "Existing-kindle-ready.epub")
        let readiness = ReadinessPreparingSpy()
        let service = DocumentPreparationService(
            readinessService: readiness,
            conversionService: EPUBConvertingSpy()
        )

        XCTAssertThrowsError(
            try service.prepare(source: source, format: .epub, overwrite: false) { _ in }
        ) { error in
            guard case DomainError.filesystem(let message) = error else {
                return XCTFail("Expected a filesystem error, got \(error)")
            }
            XCTAssertTrue(message.contains("already exists"))
        }
        XCTAssertTrue(readiness.calls.isEmpty)
    }

    func testMissingConversionDependencyPropagatesAndCleansPDFWorkingDirectory() throws {
        let fixture = try TemporaryDocumentFactory()
        let source = try fixture.makePDF(named: "Dependency.pdf")
        let workingRoot = fixture.directoryURL.appendingPathComponent("dependency-working", isDirectory: true)
        try FileManager.default.createDirectory(at: workingRoot, withIntermediateDirectories: true)
        let converter = EPUBConvertingSpy()
        converter.handler = { _, _, _, _ in
            throw DomainError.dependency("ebook-convert is unavailable")
        }
        let readiness = ReadinessPreparingSpy()
        let service = DocumentPreparationService(
            readinessService: readiness,
            conversionService: converter,
            temporaryDirectory: workingRoot
        )

        XCTAssertThrowsError(
            try service.prepare(source: source, format: .pdf, overwrite: false) { _ in }
        ) { error in
            XCTAssertEqual(error as? DomainError, .dependency("ebook-convert is unavailable"))
        }
        XCTAssertTrue(readiness.calls.isEmpty)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: workingRoot.path).isEmpty)
    }

    func testReadyReportWithoutReadableOutputFailsVerification() throws {
        let fixture = try TemporaryDocumentFactory()
        let source = try fixture.makeEPUB(named: "Missing.epub")
        let readiness = ReadinessPreparingSpy()
        readiness.handler = { input, output, _, _ in
            ReadinessReport(inputPath: input, status: .ready, outputPath: output)
        }
        let service = DocumentPreparationService(
            readinessService: readiness,
            conversionService: EPUBConvertingSpy()
        )

        XCTAssertThrowsError(
            try service.prepare(source: source, format: .epub, overwrite: false) { _ in }
        ) { error in
            guard case DomainError.filesystem(let message) = error else {
                return XCTFail("Expected a filesystem error, got \(error)")
            }
            XCTAssertTrue(message.contains("missing or unreadable"))
        }
    }
}

private final class ReadinessPreparingSpy: ReadinessPreparing {
    struct Call {
        var source: URL
        var output: URL?
        var overwrite: Bool
    }

    var calls: [Call] = []
    var handler: ((URL, URL?, Bool, ((String) -> Void)?) throws -> ReadinessReport)?

    func prepare(
        source: URL,
        output: URL?,
        outputDirectory: URL?,
        overwrite: Bool,
        onProgress: ((String) -> Void)?
    ) throws -> ReadinessReport {
        XCTAssertNil(outputDirectory)
        calls.append(Call(source: source, output: output, overwrite: overwrite))
        guard let handler else {
            throw DomainError.validation("Unexpected readiness call")
        }
        return try handler(source, output, overwrite, onProgress)
    }
}

private final class EPUBConvertingSpy: EPUBConverting {
    var handler: ((URL, URL, Bool, ((String) -> Void)?) throws -> ConversionResult)?

    func convertToEPUB(
        source: URL,
        output: URL?,
        overwrite: Bool,
        onProgress: ((String) -> Void)?
    ) throws -> ConversionResult {
        guard let output, let handler else {
            throw DomainError.validation("Unexpected conversion call")
        }
        return try handler(source, output, overwrite, onProgress)
    }
}

private final class EventRecorder {
    var values: [String] = []
}
