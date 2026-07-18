import Foundation

@MainActor
final class OperationJobCoordinator: ObservableObject {
    @Published private(set) var jobs: [OperationJob] = []
    private let logService: LogService

    init(logService: LogService) {
        self.logService = logService
    }

    @discardableResult
    func enqueue(kind: OperationKind, sources: [URL], message: String) -> UUID {
        let job = OperationJob(
            kind: kind,
            state: .queued,
            sourcePaths: sources,
            progressMessage: message
        )
        jobs.insert(job, at: 0)
        logService.append(level: .info, message: message, operationId: job.id)
        return job.id
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

    func start(id: UUID, message: String? = nil) {
        guard let index = jobs.firstIndex(where: { $0.id == id }),
              jobs[index].state == .queued else { return }
        jobs[index].state = .running
        jobs[index].startedAt = Date()
        if let message {
            jobs[index].progressMessage = message
            logService.append(level: .info, message: message, operationId: id)
        }
    }

    func update(id: UUID, message: String, percent: Double? = nil) {
        guard let index = jobs.firstIndex(where: { $0.id == id }),
              jobs[index].state == .queued || jobs[index].state == .running else { return }
        jobs[index].progressMessage = message
        jobs[index].percent = percent
        logService.append(level: .info, message: message, operationId: id)
    }

    func succeed(id: UUID, resultRef: String? = nil, message: String = "Completed") {
        reconcile(
            id: id,
            state: .succeeded,
            resultRef: resultRef,
            message: message
        )
    }

    func fail(id: UUID, message: String) {
        reconcile(
            id: id,
            state: .failed,
            message: message,
            errorMessage: message
        )
    }

    @discardableResult
    func cancelPending(ids: Set<UUID>? = nil, message: String = "Cancelled before starting") -> [UUID] {
        var cancelledIDs: [UUID] = []

        for index in jobs.indices where jobs[index].state == .queued {
            guard ids?.contains(jobs[index].id) ?? true else { continue }
            let id = jobs[index].id
            jobs[index].state = .cancelled
            jobs[index].finishedAt = Date()
            jobs[index].progressMessage = message
            jobs[index].errorMessage = nil
            cancelledIDs.append(id)
            logService.append(level: .info, message: message, operationId: id)
        }

        return cancelledIDs
    }

    func reconcile(
        id: UUID,
        state: OperationState,
        resultRef: String? = nil,
        message: String,
        errorMessage: String? = nil
    ) {
        guard state == .succeeded || state == .failed || state == .cancelled,
              let index = jobs.firstIndex(where: { $0.id == id }),
              jobs[index].state == .running else { return }

        let level: LogLevel
        switch state {
        case .failed:
            level = .error
        case .cancelled:
            level = .warning
        case .succeeded:
            level = .info
        case .queued, .running:
            return
        }

        jobs[index].state = state
        jobs[index].finishedAt = Date()
        jobs[index].resultRef = resultRef
        jobs[index].errorMessage = errorMessage
        jobs[index].progressMessage = message
        logService.append(level: level, message: message, operationId: id)
    }

    var activeJobs: [OperationJob] {
        jobs.filter { $0.state == .running || $0.state == .queued }
    }
}
