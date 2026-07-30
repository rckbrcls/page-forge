import Foundation

enum SendBookTab: String, CaseIterable, Hashable, Sendable {
    case send
    case history

    static let `default`: SendBookTab = .send

    var title: String {
        switch self {
        case .send: "Send"
        case .history: "History"
        }
    }
}

struct SubmissionReceipt: Equatable, Sendable {
    let attemptID: UUID
    let batchID: UUID
    let snapshotID: UUID
    let itemID: UUID
    let displayName: String
    let acceptedAt: Date

    var record: SubmissionRecord {
        SubmissionRecord(
            id: attemptID,
            displayName: displayName,
            acceptedAt: acceptedAt
        )
    }
}

struct SubmissionRecord: Identifiable, Codable, Equatable, Hashable, Sendable {
    static let maximumDisplayNameCharacters = 240

    let id: UUID
    let displayName: String
    let acceptedAt: Date

    init(id: UUID, displayName: String, acceptedAt: Date) {
        precondition(
            Self.isValid(displayName: displayName),
            "Submission display names must be sanitized before persistence."
        )
        precondition(
            acceptedAt.timeIntervalSinceReferenceDate.isFinite,
            "Submission acceptance dates must be finite."
        )
        self.id = id
        self.displayName = displayName
        self.acceptedAt = acceptedAt
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let displayName = try container.decode(String.self, forKey: .displayName)
        let acceptedAt = try container.decode(Date.self, forKey: .acceptedAt)
        guard Self.isValid(displayName: displayName),
              acceptedAt.timeIntervalSinceReferenceDate.isFinite
        else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Submission record fields are invalid."
                )
            )
        }
        self.id = id
        self.displayName = displayName
        self.acceptedAt = acceptedAt
    }

    static func newestFirst(
        _ lhs: SubmissionRecord,
        _ rhs: SubmissionRecord
    ) -> Bool {
        if lhs.acceptedAt != rhs.acceptedAt {
            return lhs.acceptedAt > rhs.acceptedAt
        }
        return lhs.id.uuidString > rhs.id.uuidString
    }

    private static func isValid(displayName: String) -> Bool {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed == displayName,
              displayName.count <= maximumDisplayNameCharacters
        else {
            return false
        }
        return displayName.unicodeScalars.allSatisfy {
            !CharacterSet.controlCharacters.contains($0)
        }
    }
}

struct SendHistoryEnvelope: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let records: [SubmissionRecord]

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        records: [SubmissionRecord]
    ) {
        self.schemaVersion = schemaVersion
        self.records = records
    }
}

struct SendHistorySnapshot: Equatable, Sendable {
    let records: [SubmissionRecord]
    let loadedAt: Date

    static var empty: SendHistorySnapshot {
        SendHistorySnapshot(records: [], loadedAt: Date())
    }
}

enum SendHistoryLoadState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case unavailable(HistoryFailure)
}

enum HistoryOperation: String, Codable, Equatable, Sendable {
    case load
    case record
    case clear
}

enum HistoryFailureCode: String, Codable, Equatable, Sendable {
    case unavailable
    case read
    case decode
    case unsupportedSchema
    case limit
    case write
    case clear
}

struct HistoryFailure: Error, Codable, Equatable, Sendable {
    let operation: HistoryOperation
    let code: HistoryFailureCode

    init(operation: HistoryOperation, code: HistoryFailureCode) {
        self.operation = operation
        self.code = code
    }
}
