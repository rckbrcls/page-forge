import Foundation
import Testing
@testable import BookSender

struct HistoryModelsTests {
    @Test
    func receiptProjectsOnlyTheDurableRecordFields() throws {
        let receipt = HistoryTestFixtures.receipt()
        let data = try JSONEncoder().encode(receipt.record)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(Set(object.keys) == ["id", "displayName", "acceptedAt"])
        #expect(receipt.record.id == receipt.attemptID)
        #expect(receipt.record.displayName == receipt.displayName)
        #expect(receipt.record.acceptedAt == receipt.acceptedAt)
    }

    @Test
    func orderingUsesAcceptanceThenIdentifierDescending() {
        let first = HistoryTestFixtures.record()
        let newer = HistoryTestFixtures.record(
            id: HistoryTestFixtures.secondID,
            acceptedAt: HistoryTestFixtures.secondDate
        )
        let tiedHigherID = HistoryTestFixtures.record(
            id: HistoryTestFixtures.secondID,
            acceptedAt: HistoryTestFixtures.firstDate
        )

        #expect(
            SubmissionRecord.newestFirst(newer, first)
        )
        #expect(
            SubmissionRecord.newestFirst(tiedHigherID, first)
        )
    }

    @Test
    func sendTabIsTheDefaultSelection() {
        #expect(SendBookTab.default == .send)
        #expect(SendBookTab.allCases == [.send, .history])
    }

    @Test
    func decodingRejectsUnsafeOrUnboundedDisplayNames() throws {
        let unsafeNames = [
            "",
            " padded.epub",
            "line\nbreak.epub",
            String(
                repeating: "a",
                count: SubmissionRecord.maximumDisplayNameCharacters + 1
            ),
        ]
        let decoder = JSONDecoder()

        for displayName in unsafeNames {
            let object: [String: Any] = [
                "id": HistoryTestFixtures.firstID.uuidString,
                "displayName": displayName,
                "acceptedAt": HistoryTestFixtures.firstDate
                    .timeIntervalSinceReferenceDate,
            ]
            let data = try JSONSerialization.data(withJSONObject: object)
            #expect(throws: DecodingError.self) {
                _ = try decoder.decode(SubmissionRecord.self, from: data)
            }
        }
    }

    @Test
    func envelopeUsesTheCurrentVersionAndKeepsRecordsImmutable() {
        let record = HistoryTestFixtures.record()
        let envelope = SendHistoryEnvelope(records: [record])
        let snapshot = SendHistorySnapshot(
            records: envelope.records,
            loadedAt: HistoryTestFixtures.secondDate
        )

        #expect(envelope.schemaVersion == 1)
        #expect(snapshot.records == [record])
        #expect(snapshot.loadedAt == HistoryTestFixtures.secondDate)
    }
}
