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
    case deliveryUnknown(SanitizedFailure)
}

enum FailureFamily: String, Codable, CaseIterable, Hashable, Sendable {
    case intake
    case archive
    case xml
    case audit
    case repair
    case filesystem
    case credential
    case delivery
    case shortcut
}

struct SanitizedFailure: Error, Codable, Equatable, Hashable, Sendable {
    let family: FailureFamily
    let code: DiagnosticCode
    let message: String
    let recoveryAction: RecoveryAction?
    let evidence: DiagnosticEvidence

    init(
        family: FailureFamily,
        code: DiagnosticCode,
        message: String,
        recoveryAction: RecoveryAction?,
        evidence: DiagnosticEvidence? = nil
    ) {
        precondition(
            family == code.expectedFamily,
            "Diagnostic code must match its failure family."
        )
        self.family = family
        self.code = code
        self.message = message
        self.recoveryAction = recoveryAction
        self.evidence = evidence ?? DiagnosticEvidence.inferred(
            family: family,
            code: code,
            recoveryAction: recoveryAction
        )
    }
}

enum RecoveryAction: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case editSetup
    case chooseAnotherFile
    case reviewBook
    case retryFailed
    case confirmUnknownRetry
    case chooseAnotherShortcut
    case retryHistoryLoad
    case retryHistoryClear
}

struct DeliveryAttempt: Identifiable, Sendable {
    let id: UUID
    let snapshotID: UUID
    let itemID: UUID
    let setupRevision: Int
    var stage: DeliveryStage
    var dataTransmissionStarted: Bool
    let startedAt: Date
    var completedAt: Date?
    var outcome: TerminalOutcome?
}

struct DeliveryProgress: Sendable {
    let stage: DeliveryStage
    let dataTransmissionStarted: Bool
}

struct PipelineEvent: Sendable {
    enum Kind: Sendable {
        case batchChanged
        case intakeOutcome(UUID)
        case checking(UUID)
        case preparing(UUID)
        case ready(UUID)
        case needsAttention(UUID, SanitizedFailure)
        case sending(UUID, DeliveryProgress)
        case submitted(SubmissionReceipt)
        case historyPersistenceFailed(SubmissionReceipt, HistoryFailure)
        case failed(UUID, SanitizedFailure)
        case cancelled(UUID)
        case deliveryUnknown(UUID, SanitizedFailure)
        case batchProgress(completed: Int, total: Int)
        case batchCompleted(UUID)
    }

    let batchID: UUID
    let kind: Kind
}
