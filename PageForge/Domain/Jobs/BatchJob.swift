import Foundation

struct BatchJobRunner {
    private let readiness: ReadinessService
    private let conversion: ConversionService
    private let repair: RepairService

    init(
        readiness: ReadinessService = ReadinessService(),
        conversion: ConversionService = ConversionService(),
        repair: RepairService = RepairService()
    ) {
        self.readiness = readiness
        self.conversion = conversion
        self.repair = repair
    }

    func readinessBatch(
        folder: URL,
        prepare: Bool,
        outputDirectory: URL?,
        overwrite: Bool,
        onProgress: ((String) -> Void)?
    ) throws -> ReadinessBatchResult {
        try readiness.auditFolder(
            folder: folder,
            prepare: prepare,
            outputDirectory: outputDirectory,
            overwrite: overwrite,
            onProgress: onProgress
        )
    }

    func convertBatch(
        folder: URL,
        target: ConversionTarget,
        outputDirectory: URL?,
        overwrite: Bool,
        onProgress: ((String) -> Void)?
    ) throws -> BatchResult<ConversionResult> {
        try conversion.convertFolder(
            folder: folder,
            target: target,
            outputDirectory: outputDirectory,
            overwrite: overwrite,
            onProgress: onProgress
        )
    }

    func repairBatch(
        folder: URL,
        mode: RepairMode,
        outputDirectory: URL?,
        overwrite: Bool,
        onProgress: ((String) -> Void)?
    ) throws -> BatchResult<RepairResult> {
        try repair.repairFolder(
            folder: folder,
            mode: mode,
            outputDirectory: outputDirectory,
            overwrite: overwrite,
            onProgress: onProgress
        )
    }
}
