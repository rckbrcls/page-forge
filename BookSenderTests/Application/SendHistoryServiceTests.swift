import Foundation
import Testing
@testable import BookSender

struct SendHistoryServiceTests {
    @Test
    func recordsOnceOrdersNewestFirstAndPreservesRepeatedNames() async throws {
        let store = InMemorySendHistoryStore()
        let service = SendHistoryService(store: store)
        let first = HistoryTestFixtures.receipt()
        let second = HistoryTestFixtures.receipt(
            attemptID: HistoryTestFixtures.secondID,
            acceptedAt: HistoryTestFixtures.secondDate
        )

        try await service.record(first)
        try await service.record(first)
        try await service.record(second)
        let snapshot = try await service.snapshot()

        #expect(snapshot.records.map(\.id) == [second.attemptID, first.attemptID])
        #expect(snapshot.records.map(\.displayName) == ["Example.epub", "Example.epub"])
    }

    @Test
    func retainsOnlyTheNewestFiveHundredRecords() async throws {
        let store = InMemorySendHistoryStore()
        let service = SendHistoryService(store: store)

        for offset in 0..<505 {
            try await service.record(
                HistoryTestFixtures.receipt(
                    attemptID: UUID(),
                    displayName: "Book-\(offset).pdf",
                    acceptedAt: Date(timeIntervalSince1970: TimeInterval(offset))
                )
            )
        }
        let snapshot = try await service.snapshot()

        #expect(snapshot.records.count == 500)
        #expect(snapshot.records.first?.displayName == "Book-504.pdf")
        #expect(snapshot.records.last?.displayName == "Book-5.pdf")
    }

    @Test
    func clearPublishesAnEmptySnapshot() async throws {
        let store = InMemorySendHistoryStore(
            records: [HistoryTestFixtures.record()]
        )
        let service = SendHistoryService(store: store)

        try await service.clear()

        #expect(try await service.snapshot().records.isEmpty)
    }

    @Test
    func loadedRecordsAreSortedAndBoundedBeforeSnapshotPublication() async throws {
        let records = (0..<505).map { offset in
            HistoryTestFixtures.record(
                id: UUID(),
                displayName: "Loaded-\(offset).pdf",
                acceptedAt: Date(timeIntervalSince1970: TimeInterval(offset))
            )
        }
        let service = SendHistoryService(
            store: InMemorySendHistoryStore(records: records)
        )

        let snapshot = try await service.snapshot()

        #expect(snapshot.records.count == 500)
        #expect(snapshot.records.first?.displayName == "Loaded-504.pdf")
        #expect(snapshot.records.last?.displayName == "Loaded-5.pdf")
    }

    @Test
    func crossingCapacityWithMultipleAcceptedAttemptsKeepsEachInsertIdempotent() async throws {
        let existing = (0..<499).map { offset in
            HistoryTestFixtures.record(
                id: UUID(),
                displayName: "Existing-\(offset).epub",
                acceptedAt: Date(timeIntervalSince1970: TimeInterval(offset))
            )
        }
        let store = InMemorySendHistoryStore(records: existing)
        let service = SendHistoryService(store: store)
        let newest = (0..<4).map { offset in
            HistoryTestFixtures.receipt(
                attemptID: UUID(),
                displayName: "Newest-\(offset).epub",
                acceptedAt: Date(
                    timeIntervalSince1970: TimeInterval(10_000 + offset)
                )
            )
        }

        for receipt in newest + newest {
            try await service.record(receipt)
        }
        let snapshot = try await service.snapshot()

        #expect(snapshot.records.count == 500)
        #expect(
            Set(snapshot.records.prefix(4).map(\.id))
                == Set(newest.map(\.attemptID))
        )
    }
}
