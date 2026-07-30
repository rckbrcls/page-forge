import Foundation
@testable import BookSender

enum HistoryTestFixtures {
    static let firstID = UUID(
        uuidString: "00000000-0000-0000-0000-000000000001"
    )!
    static let secondID = UUID(
        uuidString: "00000000-0000-0000-0000-000000000002"
    )!
    static let batchID = UUID(
        uuidString: "00000000-0000-0000-0000-000000000010"
    )!
    static let snapshotID = UUID(
        uuidString: "00000000-0000-0000-0000-000000000011"
    )!
    static let itemID = UUID(
        uuidString: "00000000-0000-0000-0000-000000000012"
    )!
    static let firstDate = Date(timeIntervalSince1970: 1_700_000_000)
    static let secondDate = Date(timeIntervalSince1970: 1_700_000_100)

    static func record(
        id: UUID = firstID,
        displayName: String = "Example.epub",
        acceptedAt: Date = firstDate
    ) -> SubmissionRecord {
        SubmissionRecord(
            id: id,
            displayName: displayName,
            acceptedAt: acceptedAt
        )
    }

    static func receipt(
        attemptID: UUID = firstID,
        displayName: String = "Example.epub",
        acceptedAt: Date = firstDate
    ) -> SubmissionReceipt {
        SubmissionReceipt(
            attemptID: attemptID,
            batchID: batchID,
            snapshotID: snapshotID,
            itemID: itemID,
            displayName: displayName,
            acceptedAt: acceptedAt
        )
    }

    static func envelope(
        records: [SubmissionRecord] = [record()]
    ) -> SendHistoryEnvelope {
        SendHistoryEnvelope(records: records)
    }
}
