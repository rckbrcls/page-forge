import Foundation

struct EbookSource: Identifiable, Equatable, Sendable {
    let id: UUID
    let path: URL
    let displayName: String
    let kind: Kind
    let mediaTypeHint: MediaTypeHint
    let isReadable: Bool

    enum Kind: String, Sendable {
        case file
        case folder
    }

    init(url: URL) {
        let resolved = url.standardizedFileURL
        let isDirectory = (try? resolved.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        self.id = UUID()
        self.path = resolved
        self.displayName = resolved.lastPathComponent
        self.kind = isDirectory ? .folder : .file
        self.mediaTypeHint = MediaTypeHint.from(extension: resolved.pathExtension)
        self.isReadable = FileManager.default.isReadableFile(atPath: resolved.path)
    }
}

extension MediaTypeHint {
    static func from(extension ext: String) -> MediaTypeHint {
        switch ext.lowercased() {
        case "epub": return .epub
        case "mobi": return .mobi
        case "pdf": return .pdf
        default: return .unknown
        }
    }
}

struct DependencyStatus: Equatable, Sendable {
    var ebookConvertPath: URL?
    var ebookMetaPath: URL?
    var ebookPolishPath: URL?

    var isReady: Bool {
        ebookConvertPath != nil && ebookMetaPath != nil && ebookPolishPath != nil
    }

    var missingTools: [String] {
        var missing: [String] = []
        if ebookConvertPath == nil { missing.append("ebook-convert") }
        if ebookMetaPath == nil { missing.append("ebook-meta") }
        if ebookPolishPath == nil { missing.append("ebook-polish") }
        return missing
    }
}

struct OperationJob: Identifiable, Equatable, Sendable {
    let id: UUID
    var kind: OperationKind
    var state: OperationState
    var sourcePaths: [URL]
    var progressMessage: String?
    var percent: Double?
    var startedAt: Date
    var finishedAt: Date?
    var errorMessage: String?
    var resultRef: String?

    init(
        id: UUID = UUID(),
        kind: OperationKind,
        state: OperationState = .queued,
        sourcePaths: [URL],
        progressMessage: String? = nil,
        percent: Double? = nil,
        startedAt: Date = Date(),
        finishedAt: Date? = nil,
        errorMessage: String? = nil,
        resultRef: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.state = state
        self.sourcePaths = sourcePaths
        self.progressMessage = progressMessage
        self.percent = percent
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.errorMessage = errorMessage
        self.resultRef = resultRef
    }
}

struct OperationLogEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let operationId: UUID?
    let message: String

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: LogLevel,
        operationId: UUID? = nil,
        message: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.operationId = operationId
        self.message = message
    }
}
