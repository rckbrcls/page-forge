import Foundation

struct PreparationProgress: Equatable, Sendable {
    var message: String
    var fraction: Double?

    init(message: String, fraction: Double? = nil) {
        self.message = message
        self.fraction = fraction.map { min(max($0, 0), 1) }
    }
}

struct DocumentPreparationResult: Equatable, Sendable {
    var sourceURL: URL
    var report: ReadinessReport
    var preparedOutput: PreparedOutput?
}

protocol DocumentPreparing {
    func prepare(
        source: URL,
        format: DocumentFormat,
        overwrite: Bool,
        progress: @escaping (PreparationProgress) -> Void
    ) throws -> DocumentPreparationResult
}

protocol ReadinessPreparing {
    func prepare(
        source: URL,
        output: URL?,
        outputDirectory: URL?,
        overwrite: Bool,
        onProgress: ((String) -> Void)?
    ) throws -> ReadinessReport
}

protocol EPUBConverting {
    func convertToEPUB(
        source: URL,
        output: URL?,
        overwrite: Bool,
        onProgress: ((String) -> Void)?
    ) throws -> ConversionResult
}

extension ReadinessService: ReadinessPreparing {}
extension ConversionService: EPUBConverting {}

struct DocumentPreparationService: DocumentPreparing {
    private let readinessService: any ReadinessPreparing
    private let conversionService: any EPUBConverting
    private let fileManager: FileManager
    private let temporaryDirectory: URL

    init(
        readinessService: any ReadinessPreparing = ReadinessService(),
        conversionService: any EPUBConverting = ConversionService(),
        fileManager: FileManager = .default,
        temporaryDirectory: URL? = nil
    ) {
        self.readinessService = readinessService
        self.conversionService = conversionService
        self.fileManager = fileManager
        self.temporaryDirectory = temporaryDirectory ?? fileManager.temporaryDirectory
    }

    func prepare(
        source: URL,
        format: DocumentFormat,
        overwrite: Bool = false,
        progress: @escaping (PreparationProgress) -> Void
    ) throws -> DocumentPreparationResult {
        let input = try FilePathValidator.requireExistingFile(source)
        guard fileManager.isReadableFile(atPath: input.path) else {
            throw DomainError.filesystem("Input file is not readable: \(input.path)")
        }
        try validate(input, matches: format)

        let finalOutput = OutputPathBuilder.kindleReadyEPUB(for: input)
        _ = try FilePathValidator.prepareOutput(finalOutput, overwrite: overwrite)

        switch format {
        case .epub, .mobi:
            return try prepareWithReadiness(
                source: input,
                originalSource: input,
                output: finalOutput,
                format: format,
                overwrite: overwrite,
                progress: progress
            )
        case .pdf:
            return try preparePDF(
                source: input,
                output: finalOutput,
                overwrite: overwrite,
                progress: progress
            )
        }
    }

    private func preparePDF(
        source: URL,
        output: URL,
        overwrite: Bool,
        progress: @escaping (PreparationProgress) -> Void
    ) throws -> DocumentPreparationResult {
        let workingDirectory = temporaryDirectory
            .appendingPathComponent("pageforge-pdf-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: workingDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: workingDirectory) }

        let intermediate = workingDirectory
            .appendingPathComponent(source.deletingPathExtension().lastPathComponent)
            .appendingPathExtension("epub")

        progress(PreparationProgress(message: "Converting PDF to EPUB"))
        _ = try conversionService.convertToEPUB(
            source: source,
            output: intermediate,
            overwrite: true,
            onProgress: { progress(PreparationProgress(message: $0)) }
        )

        var result = try prepareWithReadiness(
            source: intermediate,
            originalSource: source,
            output: output,
            format: .pdf,
            overwrite: overwrite,
            progress: progress
        )
        result.report.inputPath = source
        result.report.convertedFrom = source
        if !result.report.issues.contains(where: { $0.code == "pdf_no_ocr" }) {
            result.report.issues.append(
                ReadinessIssue(
                    code: "pdf_no_ocr",
                    severity: .warning,
                    message: "PDF conversion does not perform OCR. Scanned PDFs may produce poor results.",
                    path: source.lastPathComponent
                )
            )
        }
        return result
    }

    private func prepareWithReadiness(
        source: URL,
        originalSource: URL,
        output: URL,
        format: DocumentFormat,
        overwrite: Bool,
        progress: @escaping (PreparationProgress) -> Void
    ) throws -> DocumentPreparationResult {
        progress(
            PreparationProgress(
                message: format == .mobi ? "Converting MOBI to EPUB" : "Preparing EPUB for Kindle"
            )
        )
        var report = try readinessService.prepare(
            source: source,
            output: output,
            outputDirectory: nil,
            overwrite: overwrite,
            onProgress: { progress(PreparationProgress(message: $0)) }
        )

        report.inputPath = originalSource
        if format == .pdf {
            report.convertedFrom = originalSource
        }

        progress(PreparationProgress(message: "Verifying output"))
        let preparedOutput = try verifiedOutput(
            for: report,
            source: originalSource,
            expectedURL: output
        )
        return DocumentPreparationResult(
            sourceURL: originalSource,
            report: report,
            preparedOutput: preparedOutput
        )
    }

    private func verifiedOutput(
        for report: ReadinessReport,
        source: URL,
        expectedURL: URL
    ) throws -> PreparedOutput? {
        guard report.status != .blocked else { return nil }
        guard report.outputPath?.standardizedFileURL == expectedURL.standardizedFileURL,
              fileManager.isReadableFile(atPath: expectedURL.path)
        else {
            throw DomainError.filesystem("Prepared output is missing or unreadable: \(expectedURL.path)")
        }

        let attributes = try fileManager.attributesOfItem(atPath: expectedURL.path)
        let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        return PreparedOutput(
            sourceURL: source,
            outputURL: expectedURL,
            sizeBytes: size,
            readinessStatus: report.status
        )
    }

    private func validate(_ source: URL, matches format: DocumentFormat) throws {
        guard source.pathExtension.lowercased() == format.rawValue else {
            throw DomainError.validation(
                "Expected a \(format.rawValue.uppercased()) file, got: \(source.lastPathComponent)"
            )
        }
    }
}
