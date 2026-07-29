import Foundation

enum DeliveryStage: String, Codable, Sendable {
    case connecting
    case securing
    case authenticating
    case envelope
    case transmitting
    case awaitingAcceptance
}

enum TerminalOutcome: Equatable, Sendable {
    case submitted
    case failed(SanitizedFailure)
    case cancelled
    case deliveryUnknown
}

enum FailureFamily: String, Codable, Sendable {
    case intake
    case archive
    case xml
    case audit
    case repair
    case filesystem
    case credential
    case delivery
}

struct SanitizedFailure: Error, Codable, Equatable, Sendable {
    let family: FailureFamily
    let code: String
    let message: String
    let recoveryAction: RecoveryAction?
}

enum RecoveryAction: String, Codable, Sendable {
    case editSetup
    case chooseAnotherFile
    case reviewBook
    case retryFailed
    case confirmUnknownRetry
}

struct DeliveryAttempt: Identifiable, Sendable {
    let id: UUID
    let itemID: UUID
    let setupRevision: Int
    var stage: DeliveryStage
    var dataTransmissionStarted: Bool
    let startedAt: Date
    var completedAt: Date?
    var outcome: TerminalOutcome?
}

enum PipelineEvent: Sendable {
    case itemAdded(UUID)
    case itemExcluded(UUID, SanitizedFailure)
    case checking(UUID)
    case preparing(UUID)
    case ready(UUID, PreparedBook)
    case needsAttention(UUID, SanitizedFailure)
    case sending(UUID, DeliveryStage)
    case submitted(UUID)
    case failed(UUID, SanitizedFailure)
    case cancelled(UUID)
    case deliveryUnknown(UUID)
    case batchProgress(completed: Int, total: Int)
    case batchCompleted(UUID)
}
