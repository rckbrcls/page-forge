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
        model.notificationCenter.attach(.main)
        model.setupDraft = validDraft()

        model.saveSetup()
        try await eventually {
            model.notificationFeedback(
                for: .deliverySetup,
                destination: .main
            )?.state == .succeeded
        }
        #expect(
            model.notificationFeedback(
                for: .deliverySetup,
                destination: .main
            ) != nil
        )
        #expect(model.feedback(for: .deliverySetup)?.state == .succeeded)
        #expect(await sleeper.requestedDurations.contains(4))

        await sleeper.resumeAll()
        try await eventually {
            model.notificationFeedback(
                for: .deliverySetup,
                destination: .main
            ) == nil
        }
        #expect(model.feedback(for: .deliverySetup)?.state == .succeeded)
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
        model.notificationCenter.attach(.main)

        model.addBooks([])
        let failureID = try #require(
            model.notificationFeedback(for: .batch, destination: .main)?.id
        )
        await sleeper.resumeAll()
        await Task.yield()

        #expect(
            model.notificationFeedback(for: .batch, destination: .main)?.id
                == failureID
        )
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
        model.notificationCenter.attach(.main)
        try await eventually { model.hasResolvedInitialSetup }
        try await eventuallyAsync {
            await gate.pendingCount() == 1
        }
        await gate.resumeFirst()
        try await eventually {
            model.notificationFeedback(
                for: .application,
                destination: .main
            ) == nil
        }
        model.setupDraft = validDraft()
        model.saveSetup()
        try await eventually {
            model.notificationFeedback(
                for: .deliverySetup,
                destination: .main
            )?.state == .succeeded
        }
        let firstID = try #require(
            model.notificationFeedback(
                for: .deliverySetup,
                destination: .main
            )?.id
        )

        model.saveSetup()
        try await eventually {
            model.notificationFeedback(
                for: .deliverySetup,
                destination: .main
            )?.state == .succeeded
                && model.notificationFeedback(
                    for: .deliverySetup,
                    destination: .main
                )?.id != firstID
        }
        let replacementID = try #require(
            model.notificationFeedback(
                for: .deliverySetup,
                destination: .main
            )?.id
        )
        try await eventuallyAsync {
            await gate.pendingCount() == 2
        }

        await gate.resumeFirst()
        await Task.yield()
        #expect(
            model.notificationFeedback(
                for: .deliverySetup,
                destination: .main
            )?.id == replacementID
        )

        await gate.resumeFirst()
        try await eventually {
            model.notificationFeedback(
                for: .deliverySetup,
                destination: .main
            ) == nil
        }
        #expect(model.feedback(for: .deliverySetup)?.id == replacementID)
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
        model.notificationCenter.attach(.main)
        model.setupDraft = validDraft()

        model.saveSetup()
        model.acknowledgeUpdateCheck()
        try await eventually {
            model.notificationFeedback(
                for: .deliverySetup,
                destination: .main
            )?.state == .succeeded
                && model.notificationFeedback(
                    for: .update,
                    destination: .main
                )?.state == .succeeded
        }
        try await eventuallyAsync {
            await sleeper.pendingCount() >= 2
        }

        #expect(await sleeper.requestedDurations.allSatisfy { $0 == 4 })
        #expect(await sleeper.requestedDurations.allSatisfy { $0 <= 5 })
        await sleeper.resumeAll()
        try await eventually {
            model.notificationFeedback(
                for: .deliverySetup,
                destination: .main
            ) == nil
                && model.notificationFeedback(
                    for: .update,
                    destination: .main
                ) == nil
        }
        #expect(model.feedback(for: .deliverySetup)?.state == .succeeded)
        #expect(model.feedback(for: .update)?.state == .succeeded)
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
