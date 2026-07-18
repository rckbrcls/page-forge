import Foundation

struct ReadinessIssue: Identifiable, Equatable, Sendable {
    let id: UUID
    let code: String
    let severity: IssueSeverity
    let message: String
    let path: String?

    init(
        id: UUID = UUID(),
        code: String,
        severity: IssueSeverity,
        message: String,
        path: String? = nil
    ) {
        self.id = id
        self.code = code
        self.severity = severity
        self.message = message
        self.path = path
    }
}

struct ReadinessReport: Equatable, Sendable {
    var inputPath: URL
    var status: ReadinessStatus
    var issues: [ReadinessIssue]
    var outputPath: URL?
    var convertedFrom: URL?
    var handoffURL: String

    init(
        inputPath: URL,
        status: ReadinessStatus,
        issues: [ReadinessIssue] = [],
        outputPath: URL? = nil,
        convertedFrom: URL? = nil,
        handoffURL: String = "https://www.amazon.com/sendtokindle"
    ) {
        self.inputPath = inputPath
        self.status = status
        self.issues = issues
        self.outputPath = outputPath
        self.convertedFrom = convertedFrom
        self.handoffURL = handoffURL
    }

    var fixableIssues: [ReadinessIssue] {
        issues.filter { $0.severity == .fixable }
    }

    var warningIssues: [ReadinessIssue] {
        issues.filter { $0.severity == .warning }
    }

    var blockingIssues: [ReadinessIssue] {
        issues.filter { $0.severity == .error }
    }

    var isReady: Bool {
        status == .ready
    }
}

struct PreparationRequest: Equatable, Sendable {
    var source: EbookSource
    var outputPath: URL?
    var overwrite: Bool
}
