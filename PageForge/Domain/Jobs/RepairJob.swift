import Foundation

struct RepairJobRunner {
    private let service: RepairService

    init(service: RepairService = RepairService()) {
        self.service = service
    }

    func run(
        source: URL,
        mode: RepairMode,
        overwrite: Bool,
        onProgress: ((String) -> Void)?
    ) throws -> RepairResult {
        try service.repair(
            source: source,
            mode: mode,
            overwrite: overwrite,
            onProgress: onProgress
        )
    }
}
