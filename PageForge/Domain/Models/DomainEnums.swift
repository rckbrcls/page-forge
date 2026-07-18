import Foundation

enum ReadinessStatus: String, Codable, CaseIterable, Sendable {
    case ready
    case needsFixes = "needs_fixes"
    case blocked
}

enum IssueSeverity: String, Codable, CaseIterable, Sendable {
    case info
    case warning
    case error
    case fixable
}

enum RepairMode: String, Codable, CaseIterable, Sendable {
    case safe
    case aggressive
}

enum ConversionTarget: String, Codable, CaseIterable, Sendable {
    case epub
    case mobi
}

enum OperationKind: String, Codable, CaseIterable, Sendable {
    case readinessAudit
    case readinessPrepare
    case convert
    case repair
    case batchReadiness
    case batchConvert
    case batchRepair
    case metadataInspect
    case metadataUpdate
    case send
    case dependencyCheck
    case setupGuidance
    case updateGuidance
}

enum OperationState: String, Codable, CaseIterable, Sendable {
    case queued
    case running
    case succeeded
    case failed
    case cancelled
}

enum MediaTypeHint: String, Codable, Sendable {
    case epub
    case mobi
    case pdf
    case unknown
}

enum LogLevel: String, Codable, Sendable {
    case info
    case warning
    case error
}
