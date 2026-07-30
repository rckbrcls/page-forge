import Foundation
import Testing
@testable import BookSender

struct SendHistoryPerformanceTests {
    @Test
    func fiveHundredRecordLoadAndPresentationStayUnderOneSecond() async throws {
        let records = (0..<SendHistoryService.maximumRecords).map { index in
            SubmissionRecord(
                id: UUID(),
                displayName: "Performance-\(index).epub",
                acceptedAt: Date(
                    timeIntervalSince1970: TimeInterval(1_700_000_000 + index)
                )
            )
        }
        let service = SendHistoryService(
            store: InMemorySendHistoryStore(records: records)
        )
        let clock = ContinuousClock()

        let elapsed = try await clock.measure {
            let snapshot = try await service.snapshot()
            let formattedRows = snapshot.records.map { record in
                (
                    record.displayName,
                    record.acceptedAt.formatted(
                        date: .abbreviated,
                        time: .shortened
                    )
                )
            }
            #expect(formattedRows.count == SendHistoryService.maximumRecords)
        }

        #expect(elapsed < .seconds(1))
    }
}
