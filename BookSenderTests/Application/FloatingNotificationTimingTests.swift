import Foundation
import Testing
@testable import BookSender

@MainActor
struct FloatingNotificationTimingTests {
    @Test
    func queuedTemporaryEntryReceivesItsFullVisibleLifetime() async throws {
        let sleeper = ControlledFeedbackSleeper()
        let center = makeFloatingNotificationCenter(sleeper: sleeper)
        center.attach(.main)
        let persistent = persistentFeedback()
        persistent.forEach { center.publish($0, destination: .main) }
        let temporary = NotificationTestFixtures.feedback(
            id: UUID(),
            scope: .update,
            action: .checkForUpdates,
            title: "Update check opened."
        )
        center.publish(temporary, destination: .main)

        #expect(await sleeper.pendingCount() == 0)
        center.close(
            feedbackID: persistent[0].id,
            destination: .main
        )
        try await eventually {
            await sleeper.pendingCount() == 1
        }
        #expect(await sleeper.requestedDurations == [4])

        await sleeper.resumeAll()
        try await eventually {
            center.feedback(for: .update, destination: .main) == nil
        }
    }

    @Test
    func cancelledOldTaskCannotRemoveReplacement() async throws {
        let gate = UncancellableFeedbackGate()
        let center = FloatingNotificationCenter { _ in
            await gate.sleep()
        }
        center.attach(.main)
        let first = NotificationTestFixtures.feedback(id: UUID())
        center.publish(first, destination: .main)
        try await eventually {
            await gate.pendingCount() == 1
        }

        let replacement = NotificationTestFixtures.feedback(
            id: UUID(),
            title: "Replacement result"
        )
        center.publish(replacement, destination: .main)
        try await eventually {
            await gate.pendingCount() == 2
        }
        await gate.resumeFirst()
        await Task.yield()

        #expect(
            center.feedback(for: .batch, destination: .main)?.id
                == replacement.id
        )
    }

    @Test
    func detachingOneHostCancelsOnlyItsTemporaryTasks() async throws {
        let sleeper = ControlledFeedbackSleeper()
        let center = makeFloatingNotificationCenter(sleeper: sleeper)
        center.attach(.main)
        center.attach(.settings)
        center.publish(
            NotificationTestFixtures.feedback(id: UUID()),
            destination: .main
        )
        center.publish(
            NotificationTestFixtures.feedback(
                id: UUID(),
                scope: .shortcut,
                action: .saveShortcut,
                title: "Shortcut saved."
            ),
            destination: .settings
        )
        try await eventually {
            await sleeper.pendingCount() == 2
        }

        center.detach(.main)
        try await eventually {
            await sleeper.pendingCount() == 1
        }

        #expect(center.snapshot(for: .main).visible.isEmpty)
        #expect(center.snapshot(for: .settings).visible.count == 1)
    }

    private func persistentFeedback() -> [ActionFeedback] {
        [
            FeedbackScope.deliverySetup,
            .history,
            .batch,
        ].map {
            NotificationTestFixtures.feedback(
                id: UUID(),
                scope: $0,
                state: .cancelled,
                title: "Persistent result"
            )
        }
    }

    private func eventually(
        _ condition: @escaping @MainActor @Sendable () async -> Bool
    ) async throws {
        for _ in 0..<2_000 {
            if await condition() { return }
            await Task.yield()
        }
        throw FloatingNotificationTimingTestError.timeout
    }
}

private enum FloatingNotificationTimingTestError: Error {
    case timeout
}
