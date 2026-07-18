import Foundation

struct ReadinessAuditJob {
    private let service: ReadinessService

    init(service: ReadinessService = ReadinessService()) {
        self.service = service
    }

    func run(source: URL) throws -> ReadinessReport {
        try service.audit(source: source)
    }
}
