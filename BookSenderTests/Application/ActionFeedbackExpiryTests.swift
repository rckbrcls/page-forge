import Foundation
import Testing
@testable import BookSender

@MainActor
struct ActionFeedbackExpiryTests {
    @Test
    func successfulFeedbackExpiresOnlyAfterTheInjectedSleeperCompletes() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let sleeper = ControlledFeedbackSleeper()
        let graph = TestDependencyGraph.make(
            stores: stores,
            feedbackSleep: { duration in
                try await sleeper.sleep(for: duration)
            }
        )
        let model = AppModel(dependencies: graph.dependencies)
        model.setupDraft = validDraft()

        model.saveSetup()
        try await eventually {
            model.feedback(for: .deliverySetup)?.state == .succeeded
        }
        #expect(model.feedback(for: .deliverySetup) != nil)
        #expect(await sleeper.requestedDurations.contains(4))

        await sleeper.resumeAll()
        try await eventually {
            model.feedback(for: .deliverySetup) == nil
        }
    }

    @Test
    func actionableFailureDoesNotExpire() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let sleeper = ControlledFeedbackSleeper()
        let graph = TestDependencyGraph.make(
            stores: stores,
            feedbackSleep: { duration in
                try await sleeper.sleep(for: duration)
            }
        )
        let model = AppModel(dependencies: graph.dependencies)

        model.addBooks([])
        let failureID = try #require(model.feedback(for: .batch)?.id)
        await sleeper.resumeAll()
        await Task.yield()

        #expect(model.feedback(for: .batch)?.id == failureID)
        #expect(model.feedback(for: .batch)?.state == .failed)
    }

    @Test
    func replacementRestartsExpiryAndCancelledTaskCannotRemoveNewFeedback() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let gate = UncancellableFeedbackGate()
        let graph = TestDependencyGraph.make(
            stores: stores,
            feedbackSleep: { _ in
                await gate.sleep()
            }
        )
        let model = AppModel(dependencies: graph.dependencies)
        try await eventually { model.hasResolvedInitialSetup }
        try await eventuallyAsync {
            await gate.pendingCount() == 1
        }
        await gate.resumeFirst()
        try await eventually {
            model.feedback(for: .application) == nil
        }
        model.setupDraft = validDraft()
        model.saveSetup()
        try await eventually {
            model.feedback(for: .deliverySetup)?.state == .succeeded
        }
        let firstID = try #require(
            model.feedback(for: .deliverySetup)?.id
        )

        model.saveSetup()
        try await eventually {
            model.feedback(for: .deliverySetup)?.state == .succeeded
                && model.feedback(for: .deliverySetup)?.id != firstID
        }
        let replacementID = try #require(
            model.feedback(for: .deliverySetup)?.id
        )
        try await eventuallyAsync {
            await gate.pendingCount() == 2
        }

        await gate.resumeFirst()
        await Task.yield()
        #expect(model.feedback(for: .deliverySetup)?.id == replacementID)

        await gate.resumeFirst()
        try await eventually {
            model.feedback(for: .deliverySetup) == nil
        }
    }

    @Test
    func independentScopesOwnIndependentFourSecondExpiryTasks() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let sleeper = ControlledFeedbackSleeper()
        let graph = TestDependencyGraph.make(
            stores: stores,
            feedbackSleep: { duration in
                try await sleeper.sleep(for: duration)
            }
        )
        let model = AppModel(dependencies: graph.dependencies)
        model.setupDraft = validDraft()

        model.saveSetup()
        model.acknowledgeUpdateCheck()
        try await eventually {
            model.feedback(for: .deliverySetup)?.state == .succeeded
                && model.feedback(for: .update)?.state == .succeeded
        }
        try await eventuallyAsync {
            await sleeper.pendingCount() >= 2
        }

        #expect(await sleeper.requestedDurations.allSatisfy { $0 == 4 })
        #expect(await sleeper.requestedDurations.allSatisfy { $0 <= 5 })
        await sleeper.resumeAll()
        try await eventually {
            model.feedback(for: .deliverySetup) == nil
                && model.feedback(for: .update) == nil
        }
    }

    private func eventually(
        _ condition: @escaping @MainActor () -> Bool
    ) async throws {
        for _ in 0..<2_000 {
            if condition() { return }
            await Task.yield()
        }
        throw ActionFeedbackExpiryTestError.timeout
    }

    private func eventuallyAsync(
        _ condition: @escaping @Sendable () async -> Bool
    ) async throws {
        for _ in 0..<2_000 {
            if await condition() { return }
            await Task.yield()
        }
        throw ActionFeedbackExpiryTestError.timeout
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

private enum ActionFeedbackExpiryTestError: Error {
    case timeout
}
