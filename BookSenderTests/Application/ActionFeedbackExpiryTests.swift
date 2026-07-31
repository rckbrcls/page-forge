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
    func contextualFailureCreatesNoExpiryTask() async throws {
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
        try await eventually { model.hasResolvedInitialSetup }

        model.addBooks([])

        #expect(model.feedback(for: .batch)?.state == .failed)
        #expect(
            model.notificationFeedback(for: .batch, destination: .main) == nil
        )
        #expect(await sleeper.pendingCount() == 0)
        #expect(await sleeper.requestedDurations.isEmpty)
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
    func contextualUpdateDoesNotAddAnExpiryTaskBesideApprovedSetup() async throws {
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
        }
        try await eventuallyAsync {
            await sleeper.pendingCount() == 1
        }

        #expect(await sleeper.requestedDurations == [4])
        #expect(model.feedback(for: .update)?.state == .succeeded)
        #expect(
            model.notificationFeedback(for: .update, destination: .main) == nil
        )
        await sleeper.resumeAll()
        try await eventually {
            model.notificationFeedback(
                for: .deliverySetup,
                destination: .main
            ) == nil
        }
        #expect(model.feedback(for: .deliverySetup)?.state == .succeeded)
        #expect(model.feedback(for: .update)?.state == .succeeded)
    }

    @Test
    func approvedClipboardFailureRemainsPersistentWithoutAnExpiryTask() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let sleeper = ControlledFeedbackSleeper()
        let graph = TestDependencyGraph.make(
            stores: stores,
            feedbackSleep: { duration in
                try await sleeper.sleep(for: duration)
            }
        )
        await graph.credentials.setSaveFailure(
            sanitizedFailure(.credentialSave, family: .credential)
        )
        graph.diagnosticClipboard.error = .writeFailed
        let model = AppModel(dependencies: graph.dependencies)
        model.notificationCenter.attach(.main)
        model.setupDraft = validDraft()
        model.saveSetup()
        try await eventually { model.currentDiagnosticEvent != nil }

        model.copyCurrentErrorDetails()

        #expect(
            model.notificationFeedback(
                for: .diagnosticCopy,
                destination: .main
            )?.state == .failed
        )
        #expect(await sleeper.pendingCount() == 0)
        #expect(await sleeper.requestedDurations.isEmpty)
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
