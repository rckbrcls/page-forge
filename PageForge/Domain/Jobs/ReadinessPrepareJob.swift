import Foundation

struct ReadinessPrepareJob {
    private let service: ReadinessService

    init(service: ReadinessService = ReadinessService()) {
        self.service = service
    }

    func run(
        source: URL,
        overwrite: Bool,
        onProgress: ((String) -> Void)?
    ) throws -> ReadinessReport {
        try service.prepare(
            source: source,
            overwrite: overwrite,
            onProgress: onProgress
        )
    }
}
