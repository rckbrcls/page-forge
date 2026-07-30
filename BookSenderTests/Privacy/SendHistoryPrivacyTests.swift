import Foundation
import Testing
@testable import BookSender

struct SendHistoryPrivacyTests {
    @Test
    func encodedRecordHasAnExactThreeFieldAllowList() throws {
        let data = try JSONEncoder().encode(HistoryTestFixtures.record())
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(Set(object.keys) == ["id", "displayName", "acceptedAt"])
        let forbidden = [
            "sourcePath", "sourceURL", "bookContent", "senderAddress",
            "kindleAddress", "credential", "smtpReply", "batchID",
            "snapshotID", "itemID", "diagnostic", "telemetryID",
        ]
        #expect(forbidden.allSatisfy { object[$0] == nil })
    }

    @Test
    func encodedEnvelopeContainsNoReceiptOrDeliveryContext() throws {
        let data = try JSONEncoder().encode(
            SendHistoryEnvelope(records: [HistoryTestFixtures.record()])
        )
        let text = try #require(String(data: data, encoding: .utf8))
        let forbiddenFragments = [
            "batchID", "snapshotID", "itemID", "sourcePath", "sourceURL",
            "senderAddress", "kindleAddress", "username", "credential",
            "smtpReply", "provider", "diagnostic", "remoteID", "bookContent",
        ]

        #expect(
            forbiddenFragments.allSatisfy {
                !text.localizedCaseInsensitiveContains($0)
            }
        )
    }
}
