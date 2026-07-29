import Foundation

enum BookFormat: String, Codable, Sendable {
    case epub
    case pdf
}

struct SourceIdentity: Codable, Hashable, Sendable {
    let resourceIdentifier: String
    let byteCount: Int64
    let modificationDate: Date
    let stagedContentDigest: String
}

struct StagedFileReference: Codable, Hashable, Sendable {
    let identifier: UUID
    let url: URL
}

enum PreparationState: Equatable, Sendable {
    case waiting
    case checking
    case preparing
    case ready
    case needsAttention(SanitizedFailure)
    case excluded(SanitizedFailure)
    case cancelled

    var isTerminal: Bool {
        switch self {
        case .ready, .needsAttention, .excluded, .cancelled: true
        case .waiting, .checking, .preparing: false
        }
    }
}

enum DeliveryState: Equatable, Sendable {
    case notScheduled
    case sending(DeliveryStage)
    case submitted
    case failed(SanitizedFailure)
    case cancelled
    case deliveryUnknown

    var isTerminal: Bool {
        switch self {
        case .submitted, .failed, .cancelled, .deliveryUnknown: true
        case .notScheduled, .sending: false
        }
    }
}

struct BatchItem: Identifiable, Sendable {
    let id: UUID
    let displayName: String
    let sourceIdentity: SourceIdentity?
    let format: BookFormat?
    let stagedSource: StagedFileReference?
    var health: BookHealth?
    var preparation: PreparationState
    var delivery: DeliveryState
    var findings: [HealthFinding]
    var appliedActions: [AppliedRepairAction]
    var preparedBook: PreparedBook?
}

enum IntakeOutcome: Sendable {
    case accepted(BatchItem)
    case excluded(BatchItem)
    case cancelled(BatchItem)

    var item: BatchItem {
        switch self {
        case .accepted(let item), .excluded(let item), .cancelled(let item):
            item
        }
    }
}

enum BatchPhase: String, Codable, Equatable, Sendable {
    case editing
    case importing
    case preparing
    case readyForConfirmation
    case sending
    case cancelling
    case completed

    var permitsEditing: Bool {
        self == .editing || self == .readyForConfirmation || self == .completed
    }

    var hasConfirmedSend: Bool {
        self == .sending || self == .cancelling
    }
}

enum ConfirmedBatchKind: String, Codable, Sendable {
    case initial
    case retryFailed
}

struct ConfirmedBatchItem: Identifiable, Sendable {
    let id: UUID
    let displayName: String
    let preparedFile: StagedFileReference
    let format: BookFormat
    let byteCount: Int64
    let contentDigest: String
    let priorDefinitiveFailure: SanitizedFailure?
}

struct ConfirmedBatchSnapshot: Identifiable, Sendable {
    let id: UUID
    let setup: ValidatedDeliverySetup
    let eligibleItems: [ConfirmedBatchItem]
    let excludedItemIDs: [UUID]
    let confirmedAt: Date
    let kind: ConfirmedBatchKind
}

struct ConfirmedBatchSummary: Identifiable, Sendable {
    let id: UUID
    let destination: String
    let eligibleCount: Int
    let excludedCount: Int
    let kind: ConfirmedBatchKind
}

struct CurrentBatch: Identifiable, Sendable {
    let id: UUID
    var items: [BatchItem]
    var phase: BatchPhase
    var activeSnapshot: ConfirmedBatchSnapshot?
    var completedCount: Int

    init(
        id: UUID,
        items: [BatchItem],
        phase: BatchPhase,
        activeSnapshot: ConfirmedBatchSnapshot? = nil,
        completedCount: Int = 0
    ) {
        self.id = id
        self.items = items
        self.phase = phase
        self.activeSnapshot = activeSnapshot
        self.completedCount = completedCount
    }
}

struct BatchItemPresentation: Identifiable, Sendable {
    let id: UUID
    let displayName: String
    let format: BookFormat?
    let health: BookHealth?
    let preparation: PreparationState
    let delivery: DeliveryState
    let findings: [HealthFinding]
    let appliedActions: [AppliedRepairAction]

    init(_ item: BatchItem) {
        id = item.id
        displayName = item.displayName
        format = item.format
        health = item.health
        preparation = item.preparation
        delivery = item.delivery
        findings = item.findings
        appliedActions = item.appliedActions
    }
}

struct BatchPresentation: Identifiable, Sendable {
    let id: UUID
    let items: [BatchItemPresentation]
    let phase: BatchPhase
    let activeConfirmation: ConfirmedBatchSummary?
    let completedCount: Int

    init(_ batch: CurrentBatch) {
        id = batch.id
        items = batch.items.map(BatchItemPresentation.init)
        phase = batch.phase
        activeConfirmation = batch.activeSnapshot.map {
            ConfirmedBatchSummary(
                id: $0.id,
                destination: $0.setup.kindleAddress.value,
                eligibleCount: $0.eligibleItems.count,
                excludedCount: $0.excludedItemIDs.count,
                kind: $0.kind
            )
        }
        completedCount = batch.completedCount
    }

    static var empty: BatchPresentation {
        BatchPresentation(
            CurrentBatch(id: UUID(), items: [], phase: .editing)
        )
    }
}
