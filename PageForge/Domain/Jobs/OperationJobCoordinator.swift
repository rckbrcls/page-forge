import Foundation

@MainActor
final class OperationJobCoordinator: ObservableObject {
    @Published private(set) var jobs: [OperationJob] = []
    private let logService: LogService

    init(logService: LogService) {
        self.logService = logService
    }

    @discardableResult
    func start(kind: OperationKind, sources: [URL], message: String) -> UUID {
        let job = OperationJob(
            kind: kind,
            state: .running,
            sourcePaths: sources,
            progressMessage: message
        )
        jobs.insert(job, at: 0)
        logService.append(level: .info, message: message, operationId: job.id)
        return job.id
    }

    func update(id: UUID, message: String, percent: Double? = nil) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[index].progressMessage = message
        jobs[index].percent = percent
        logService.append(level: .info, message: message, operationId: id)
    }

    func succeed(id: UUID, resultRef: String? = nil, message: String = "Completed") {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[index].state = .succeeded
        jobs[index].finishedAt = Date()
        jobs[index].progressMessage = message
        jobs[index].resultRef = resultRef
        logService.append(level: .info, message: message, operationId: id)
    }

    func fail(id: UUID, message: String) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[index].state = .failed
        jobs[index].finishedAt = Date()
        jobs[index].errorMessage = message
        jobs[index].progressMessage = message
        logService.append(level: .error, message: message, operationId: id)
    }

    var activeJobs: [OperationJob] {
        jobs.filter { $0.state == .running || $0.state == .queued }
    }
}
