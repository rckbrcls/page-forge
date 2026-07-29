import Foundation

enum RepairAction: Codable, Equatable, Sendable {
    case rebuildMimetype
    case restoreContainer(packagePath: String)
    case correctMediaType(path: String, mediaType: String)
    case normalizePath(from: String, to: String)
    case repairReference(document: String, from: String, to: String)
    case normalizeXML(path: String)

    var identifier: String {
        switch self {
        case .rebuildMimetype: "repair.mimetype"
        case .restoreContainer: "repair.container"
        case .correctMediaType: "repair.media-type"
        case .normalizePath: "repair.path"
        case .repairReference: "repair.reference"
        case .normalizeXML: "repair.xml"
        }
    }
}

enum PreparationDecision: Codable, Sendable {
    case useOriginalSnapshot
    case writeWorkingCopy
    case blocked
}

struct PreparationPlan: Identifiable, Codable, Sendable {
    let id: UUID
    let originalAuditIdentifier: UUID
    let actions: [RepairAction]
    let decision: PreparationDecision
}

struct AppliedRepairAction: Identifiable, Codable, Sendable {
    let id: UUID
    let action: RepairAction
    let verified: Bool
}

enum ReadinessDecision: String, Codable, Sendable {
    case ready
    case blocked
}

struct RevalidationComparison: Codable, Sendable {
    let originalReportID: UUID
    let preparedReportID: UUID
    let resolvedFindingCodes: Set<FindingCode>
    let retainedFindingCodes: Set<FindingCode>
    let introducedFindingCodes: Set<FindingCode>
    let verifiedActionIDs: Set<UUID>
    let readiness: ReadinessDecision
}

struct PreparedBook: Identifiable, Sendable {
    let id: UUID
    let batchItemID: UUID
    let file: StagedFileReference
    let originalDisplayName: String
    let format: BookFormat
    let byteCount: Int64
    let contentDigest: String
    let comparison: RevalidationComparison?
}
