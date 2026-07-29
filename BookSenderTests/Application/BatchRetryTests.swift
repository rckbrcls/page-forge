import Foundation
import Testing
@testable import BookSender

struct BatchRetryTests {
    @Test
    func retrySnapshotIncludesOnlyDefinitiveFailuresInOriginalOrder() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let failed = sanitizedFailure("smtp.rejected")
        let graph = TestDependencyGraph.make(
            stores: stores,
            outcomes: [.failed(failed), .deliveryUnknown, .submitted, .failed(failed)]
        )
        let pipeline = graph.dependencies.pipeline
        let setup = try await graph.dependencies.setupService.save(
            validDraft(),
            replacing: nil
        )
        let urls = try (0..<4).map { index -> URL in
            let url = stores.rootURL.appending(component: "Book-\(index).pdf")
            try Data("%PDF-1.7\n\(index)\n%%EOF\n".utf8).write(to: url)
            return url
        }
        await pipeline.add(urls)
        try await eventually {
            let batch = await pipeline.snapshot()
            return batch.items.count == 4
                && batch.items.allSatisfy { $0.preparation == .ready }
        }
        let initial = try #require(
            await pipeline.confirmation(
                setup: setup,
                kind: .initial
            )
        )
        await pipeline.send(snapshotID: initial.id)
        try await eventually {
            await pipeline.snapshot().phase == .completed
        }
        let firstBatch = await pipeline.snapshot()
        let failedIDs = firstBatch.items.compactMap { item in
            if case .failed = item.delivery { return item.id }
            return nil
        }
        let unknownIDs = Set(firstBatch.items.compactMap { item in
            if case .deliveryUnknown = item.delivery { return item.id }
            return nil
        })

        let retry = try #require(
            await pipeline.confirmation(
                setup: setup,
                kind: .retryFailed
            )
        )
        let retrySnapshot = try #require(
            (await pipeline.snapshot()).activeSnapshot
        )

        #expect(retry.kind == .retryFailed)
        #expect(retry.eligibleCount == 2)
        #expect(retrySnapshot.eligibleItems.map(\.id) == failedIDs)
        #expect(
            retrySnapshot.eligibleItems.allSatisfy {
                $0.priorDefinitiveFailure == failed
            }
        )
        #expect(
            Set(retrySnapshot.eligibleItems.map(\.id))
                .isDisjoint(with: unknownIDs)
        )
        #expect(retry.id != initial.id)
    }

    private func eventually(
        _ condition: @escaping @Sendable () async -> Bool
    ) async throws {
        for _ in 0..<2_000 {
            if await condition() { return }
            await Task.yield()
        }
        throw BatchRetryTestError.timeout
    }

    private func validDraft() -> DeliverySetupDraft {
        DeliverySetupDraft(
            senderAddress: "sender@example.com",
            smtpHost: "smtp.example.com",
            smtpPort: "465",
            securityMode: .implicitTLS,
            username: "sender",
            appPassword: "secret",
            kindleAddress: "reader@kindle.com"
        )
    }
}

private enum BatchRetryTestError: Error {
    case timeout
}
