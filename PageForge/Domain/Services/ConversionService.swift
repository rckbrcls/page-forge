import Foundation

struct ConversionService {
    private let dependencyService: DependencyService
    private let runner: CalibreProcessRunner

    init(
        dependencyService: DependencyService = DependencyService(),
        runner: CalibreProcessRunner = CalibreProcessRunner()
    ) {
        self.dependencyService = dependencyService
        self.runner = runner
    }

    func convertToEPUB(
        source: URL,
        output: URL? = nil,
        overwrite: Bool = false,
        onProgress: ((String) -> Void)? = nil
    ) throws -> ConversionResult {
        try convert(source: source, target: .epub, output: output, overwrite: overwrite, onProgress: onProgress)
    }

    func convertToMOBI(
        source: URL,
        output: URL? = nil,
        overwrite: Bool = false,
        onProgress: ((String) -> Void)? = nil
    ) throws -> ConversionResult {
        try convert(source: source, target: .mobi, output: output, overwrite: overwrite, onProgress: onProgress)
    }

    func convertFolder(
        folder: URL,
        target: ConversionTarget,
        outputDirectory: URL?,
        overwrite: Bool,
        onProgress: ((String) -> Void)? = nil
    ) throws -> BatchResult<ConversionResult> {
        let inputDir = try FilePathValidator.requireExistingDirectory(folder)
        let extensions: Set<String> = target == .epub ? ["mobi", "pdf"] : ["epub"]
        let listing = try FolderEnumerator.files(in: inputDir, extensions: extensions)
        if let outputDirectory {
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        }

        var results: [ConversionResult] = []
        var failures: [BatchFailure] = []
        for file in listing.eligible {
            do {
                let defaultOut = OutputPathBuilder.converted(for: file, target: target)
                let out = OutputPathBuilder.resolve(
                    preferred: nil,
                    outputDirectory: outputDirectory,
                    defaultURL: defaultOut
                )
                results.append(
                    try convert(
                        source: file,
                        target: target,
                        output: out,
                        overwrite: overwrite,
                        onProgress: onProgress
                    )
                )
            } catch {
                failures.append(BatchFailure(path: file, message: error.localizedDescription))
            }
        }
        return BatchResult(results: results, skipped: listing.skipped, failures: failures)
    }

    private func convert(
        source: URL,
        target: ConversionTarget,
        output: URL?,
        overwrite: Bool,
        onProgress: ((String) -> Void)?
    ) throws -> ConversionResult {
        let input = try FilePathValidator.requireExistingFile(source)
        switch target {
        case .epub:
            try FilePathValidator.requireSuffixes(input, ["mobi", "pdf"])
        case .mobi:
            try FilePathValidator.requireSuffix(input, "epub")
        }

        let defaultPath = OutputPathBuilder.converted(for: input, target: target)
        let outputPath = try FilePathValidator.prepareOutput(
            output ?? defaultPath,
            overwrite: overwrite
        )
        let executable = try dependencyService.requireConvert()
        onProgress?("Converting \(input.lastPathComponent) to \(target.rawValue.uppercased())")
        do {
            _ = try runner.run(executable: executable, arguments: [input.path, outputPath.path])
        } catch {
            throw DomainError.conversion(error.localizedDescription)
        }
        return ConversionResult(inputPath: input, outputPath: outputPath)
    }
}
