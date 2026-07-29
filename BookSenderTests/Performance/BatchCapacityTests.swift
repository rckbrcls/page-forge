import Foundation
import Testing
@testable import BookSender

struct BatchCapacityTests {
    @Test
    func mixedTwentyItemBatchKeepsOneActivePipelineAndExactOutcomes() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let outcomes: [TerminalOutcome] = (0..<20).map { index in
            index.isMultiple(of: 4)
                ? .failed(sanitizedFailure("smtp.rejected-\(index)"))
                : .submitted
        }
        let graph = TestDependencyGraph.make(stores: stores, outcomes: outcomes)
        let pipeline = graph.dependencies.pipeline
        let setup = try await graph.dependencies.setupService.save(
            validDraft(),
            replacing: nil
        )
        let urls = try (0..<20).map { index -> URL in
            let url = stores.rootURL.appending(component: "Book-\(index).pdf")
            try Data("%PDF-1.7\n\(index)\n%%EOF\n".utf8).write(to: url)
            return url
        }

        await pipeline.add(urls)
        try await eventually {
            let batch = await pipeline.snapshot()
            return batch.items.count == 20
                && batch.items.allSatisfy { $0.preparation == .ready }
        }
        let summary = try #require(
            await pipeline.confirmation(
                setup: setup,
                kind: .initial
            )
        )
        await pipeline.send(snapshotID: summary.id)
        try await eventually {
            await pipeline.snapshot().phase == .completed
        }

        let batch = await pipeline.snapshot()
        #expect(batch.items.count == 20)
        #expect(batch.completedCount == 20)
        #expect(batch.items.allSatisfy { $0.delivery.isTerminal })
        #expect((await pipeline.deliveryAttempts()).count == 20)
        #expect(SafetyLimits.standard.permitsBatchItemCount(20))
    }

    private func eventually(
        _ condition: @escaping @Sendable () async -> Bool
    ) async throws {
        for _ in 0..<10_000 {
            if await condition() { return }
            await Task.yield()
        }
        throw BatchCapacityTestError.timeout
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

private enum BatchCapacityTestError: Error {
    case timeout
}
