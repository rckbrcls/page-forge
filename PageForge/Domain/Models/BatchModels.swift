import Foundation

struct BatchFailure: Equatable, Sendable {
    var path: URL
    var message: String
}

struct BatchResult<T: Equatable & Sendable>: Equatable, Sendable {
    var results: [T]
    var skipped: [URL]
    var failures: [BatchFailure]

    init(results: [T] = [], skipped: [URL] = [], failures: [BatchFailure] = []) {
        self.results = results
        self.skipped = skipped
        self.failures = failures
    }
}

struct ReadinessBatchResult: Equatable, Sendable {
    var reports: [ReadinessReport]
    var skipped: [URL]
    var failures: [BatchFailure]

    var readyCount: Int {
        reports.filter { $0.status == .ready }.count
    }

    var needsFixesCount: Int {
        reports.filter { $0.status == .needsFixes }.count
    }

    var blockedCount: Int {
        reports.filter { $0.status == .blocked }.count
    }
}
