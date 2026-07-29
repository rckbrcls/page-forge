import Foundation

enum FindingSeverity: Int, Codable, Comparable, Sendable {
    case info
    case warning
    case error
    case critical

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

enum Repairability: Codable, Equatable, Sendable {
    case notApplicable
    case automatic(ruleID: String)
    case manualReview
    case forbidden
}

enum BookHealth: String, Codable, Sendable {
    case healthy
    case repairable
    case needsReview = "needs_review"
    case unsupported
    case unsafe
}

enum FindingCode: String, CaseIterable, Codable, Sendable {
    case archiveUnsafePath = "ARCHIVE_UNSAFE_PATH"
    case archiveDuplicatePath = "ARCHIVE_DUPLICATE_PATH"
    case archiveUnsupportedEntry = "ARCHIVE_UNSUPPORTED_ENTRY"
    case archiveEncrypted = "ARCHIVE_ENCRYPTED"
    case archiveLimitExceeded = "ARCHIVE_LIMIT_EXCEEDED"
    case mimetypeMissing = "MIMETYPE_MISSING"
    case mimetypeInvalid = "MIMETYPE_INVALID"
    case mimetypeNotFirst = "MIMETYPE_NOT_FIRST"
    case mimetypeCompressed = "MIMETYPE_COMPRESSED"
    case containerMissing = "CONTAINER_MISSING"
    case containerInvalid = "CONTAINER_INVALID"
    case packageMissing = "PACKAGE_MISSING"
    case packageAmbiguous = "PACKAGE_AMBIGUOUS"
    case packageInvalid = "PACKAGE_INVALID"
    case manifestMediaTypeMismatch = "MANIFEST_MEDIA_TYPE_MISMATCH"
    case referenceMissing = "REFERENCE_MISSING"
    case referenceAmbiguous = "REFERENCE_AMBIGUOUS"
    case encryptedContent = "ENCRYPTED_CONTENT"
    case activeContent = "ACTIVE_CONTENT"
    case remoteReference = "REMOTE_REFERENCE"
    case xmlUnsafe = "XML_UNSAFE"
}

struct HealthFinding: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let code: FindingCode
    let severity: FindingSeverity
    let location: String?
    let messageKey: String
    let repairability: Repairability
    let evidence: [String: String]
}

struct AuditReport: Identifiable, Codable, Sendable {
    let id: UUID
    let findings: [HealthFinding]
    let inspectedAt: Date

    var health: BookHealth {
        if findings.contains(where: {
            $0.severity == .critical || $0.repairability == .forbidden
        }) {
            return .unsafe
        }
        if findings.contains(where: { $0.repairability == .manualReview }) {
            return .needsReview
        }
        if findings.contains(where: {
            if case .automatic = $0.repairability { return true }
            return false
        }) {
            return .repairable
        }
        return findings.contains(where: { $0.severity >= .error })
            ? .unsupported
            : .healthy
    }
}
