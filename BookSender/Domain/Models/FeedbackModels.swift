import Foundation

enum FeedbackScope: Equatable, Hashable, Sendable {
    case application
    case deliverySetup
    case shortcut
    case batch
    case batchItem(UUID)
    case delivery(UUID)
    case update
    case history

    var accessibilityIdentifier: String {
        switch self {
        case .application: "application"
        case .deliverySetup: "deliverySetup"
        case .shortcut: "shortcut"
        case .batch: "batch"
        case .batchItem(let id): "batchItem.\(id.uuidString)"
        case .delivery(let id): "delivery.\(id.uuidString)"
        case .update: "update"
        case .history: "history"
        }
    }
}

enum FeedbackAction: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case restoreApplication
    case saveDeliverySetup
    case deleteDeliverySetup
    case saveShortcut
    case clearShortcut
    case addBooks
    case removeBook
    case clearBatch
    case startAnotherSend
    case confirmBatch
    case prepareBook
    case sendBook
    case sendBatch
    case cancelOperation
    case dismissConfirmation
    case copyErrorDetails
    case checkForUpdates
    case loadHistory
    case recordHistory
    case clearHistory
}

enum FeedbackState: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case acknowledged
    case inProgress
    case succeeded
    case failed
    case cancelled
    case partial
    case unknown

    var isTerminal: Bool {
        switch self {
        case .succeeded, .failed, .cancelled, .partial, .unknown: true
        case .acknowledged, .inProgress: false
        }
    }

    func canTransition(to next: FeedbackState) -> Bool {
        switch self {
        case .acknowledged:
            return next == .inProgress || next.isTerminal
        case .inProgress:
            return next == .inProgress || next.isTerminal
        case .succeeded, .failed, .cancelled, .partial, .unknown:
            return false
        }
    }
}

enum FeedbackDismissalPolicy: Equatable, Sendable {
    case persistentUntilReplaced
    case explicit
    case replaceOnNextAction
    case delayed(minimumVisibleDuration: TimeInterval)

    var isValid: Bool {
        switch self {
        case .persistentUntilReplaced, .explicit, .replaceOnNextAction:
            return true
        case .delayed(let minimumVisibleDuration):
            return minimumVisibleDuration.isFinite
                && minimumVisibleDuration >= 0
        }
    }
}

typealias FeedbackSleep = @Sendable (TimeInterval) async throws -> Void

struct FailurePresentation: Equatable, Sendable {
    let title: String
    let summary: String
    let explanation: String?
    let impact: String
    let code: DiagnosticCode
    let family: FailureFamily
    let phase: DiagnosticPhase
    let providerStatus: ProviderStatus?
    let retryDisposition: RetryDisposition
    let actionTitle: String?
    let action: RecoveryAction?
    let copyAvailable: Bool

    var message: String {
        summary
    }
}

struct ActionFeedback: Identifiable, Equatable, Sendable {
    let id: UUID
    let scope: FeedbackScope
    let action: FeedbackAction
    let state: FeedbackState
    let title: String
    let message: String?
    let startedAt: Date
    let updatedAt: Date
    let dismissal: FeedbackDismissalPolicy
    let failure: FailurePresentation?
    let occurrenceCount: Int

    init(
        id: UUID = UUID(),
        scope: FeedbackScope,
        action: FeedbackAction,
        state: FeedbackState,
        title: String,
        message: String? = nil,
        startedAt: Date = Date(),
        updatedAt: Date? = nil,
        dismissal: FeedbackDismissalPolicy,
        failure: FailurePresentation? = nil,
        occurrenceCount: Int = 1
    ) {
        precondition(!title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        precondition(occurrenceCount > 0)
        precondition(dismissal.isValid)
        precondition(
            ![FeedbackState.failed, .unknown].contains(state) || failure != nil
        )
        self.id = id
        self.scope = scope
        self.action = action
        self.state = state
        self.title = title
        self.message = message
        self.startedAt = startedAt
        self.updatedAt = updatedAt ?? startedAt
        self.dismissal = dismissal
        self.failure = failure
        self.occurrenceCount = occurrenceCount
    }

    var accessibilityAnnouncement: String {
        [title, message]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}
