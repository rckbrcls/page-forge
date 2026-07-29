import Foundation

enum BookFormat: String, Codable, Sendable {
    case epub
    case pdf
}

struct SourceIdentity: Codable, Hashable, Sendable {
    let resourceIdentifier: String
    let byteCount: Int64
    let modificationDate: Date
    let fingerprint: String
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
}

enum DeliveryState: Equatable, Sendable {
    case notScheduled
    case sending(DeliveryStage)
    case submitted
    case failed(SanitizedFailure)
    case cancelled
    case deliveryUnknown
}

struct BatchItem: Identifiable, Sendable {
    let id: UUID
    let displayName: String
    let sourceIdentity: SourceIdentity
    let format: BookFormat
    let stagedSource: StagedFileReference
    var health: BookHealth?
    var preparation: PreparationState
    var delivery: DeliveryState
    var findings: [HealthFinding]
    var appliedActions: [AppliedRepairAction]
    var preparedBook: PreparedBook?
}

enum BatchPhase: Sendable {
    case editing
    case preparing
    case readyForConfirmation
    case sending
    case cancelling
    case completed
}

struct CurrentBatch: Identifiable, Sendable {
    let id: UUID
    var items: [BatchItem]
    var phase: BatchPhase
    var confirmedSnapshotIdentifier: UUID?
}

struct ConfirmedBatchSnapshot: Identifiable, Sendable {
    let id: UUID
    let setupRevision: Int
    let destination: EmailAddress
    let eligibleItemIDs: [UUID]
    let excludedItemIDs: [UUID]
    let confirmedAt: Date
}
