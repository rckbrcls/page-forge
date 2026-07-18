import Foundation

struct RepairService {
    private let dependencyService: DependencyService
    private let runner: CalibreProcessRunner

    init(
        dependencyService: DependencyService = DependencyService(),
        runner: CalibreProcessRunner = CalibreProcessRunner()
    ) {
        self.dependencyService = dependencyService
        self.runner = runner
    }

    func repair(
        source: URL,
        mode: RepairMode = .safe,
        output: URL? = nil,
        overwrite: Bool = false,
        onProgress: ((String) -> Void)? = nil
    ) throws -> RepairResult {
        let input = try FilePathValidator.requireExistingFile(source)
        try FilePathValidator.requireSuffix(input, "epub")
        let defaultPath = OutputPathBuilder.repairedEPUB(for: input)
        let outputPath = try FilePathValidator.prepareOutput(output ?? defaultPath, overwrite: overwrite)

        switch mode {
        case .safe:
            try repairSafe(input: input, output: outputPath, onProgress: onProgress)
        case .aggressive:
            try repairAggressive(input: input, output: outputPath, onProgress: onProgress)
        }
        return RepairResult(inputPath: input, outputPath: outputPath, mode: mode)
    }

    func repairFolder(
        folder: URL,
        mode: RepairMode,
        outputDirectory: URL?,
        overwrite: Bool,
        onProgress: ((String) -> Void)? = nil
    ) throws -> BatchResult<RepairResult> {
        let listing = try FolderEnumerator.files(in: folder, extensions: ["epub"])
        if let outputDirectory {
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        }
        var results: [RepairResult] = []
        var failures: [BatchFailure] = []
        for file in listing.eligible {
            do {
                let out = OutputPathBuilder.resolve(
                    preferred: nil,
                    outputDirectory: outputDirectory,
                    defaultURL: OutputPathBuilder.repairedEPUB(for: file)
                )
                results.append(
                    try repair(
                        source: file,
                        mode: mode,
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

    private func repairSafe(input: URL, output: URL, onProgress: ((String) -> Void)?) throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pageforge-repair-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let structured = tempDir.appendingPathComponent("\(input.deletingPathExtension().lastPathComponent)-structured.epub")
        onProgress?("Step 1/2: Repairing EPUB structure")
        try EPUBRepair.repairStructure(source: input, output: structured)

        onProgress?("Step 2/2: Polishing EPUB")
        let polish = try dependencyService.requirePolish()
        do {
            _ = try runner.run(
                executable: polish,
                arguments: ["--upgrade-book", structured.path, output.path]
            )
        } catch {
            // Prefer delivering the structured repair if polish is unavailable/fails.
            if FileManager.default.fileExists(atPath: output.path) {
                try FileManager.default.removeItem(at: output)
            }
            try FileManager.default.copyItem(at: structured, to: output)
        }
    }

    private func repairAggressive(input: URL, output: URL, onProgress: ((String) -> Void)?) throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pageforge-aggressive-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let convert = try dependencyService.requireConvert()
        let tempMOBI = tempDir.appendingPathComponent("\(input.deletingPathExtension().lastPathComponent).mobi")
        let tempEPUB = tempDir.appendingPathComponent("\(input.deletingPathExtension().lastPathComponent)-roundtrip.epub")

        onProgress?("Step 1/2: EPUB to MOBI")
        _ = try runner.run(executable: convert, arguments: [input.path, tempMOBI.path])
        onProgress?("Step 2/2: MOBI to EPUB")
        _ = try runner.run(executable: convert, arguments: [tempMOBI.path, tempEPUB.path])
        try FileManager.default.copyItem(at: tempEPUB, to: output)
    }
}
