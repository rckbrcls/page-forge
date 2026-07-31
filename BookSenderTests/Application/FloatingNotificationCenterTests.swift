import Foundation
import Testing
@testable import BookSender

@MainActor
struct FloatingNotificationCenterTests {
    @Test
    func destinationsOwnIndependentSnapshots() {
        let center = FloatingNotificationCenter()
        center.attach(.main)
        center.attach(.settings)

        let mainFeedback = NotificationTestFixtures.feedback()
        let settingsFeedback = NotificationTestFixtures.feedback(
            id: NotificationTestFixtures.settingsFeedbackID,
            scope: .shortcut,
            action: .saveShortcut,
            title: "Shortcut saved."
        )
        center.publish(mainFeedback, destination: .main)
        center.publish(settingsFeedback, destination: .settings)

        #expect(center.snapshot(for: .main).visible.map(\.id) == [
            mainFeedback.id,
        ])
        #expect(center.snapshot(for: .settings).visible.map(\.id) == [
            settingsFeedback.id,
        ])
        #expect(
            center.feedback(for: .shortcut, destination: .main) == nil
        )
    }

    @Test
    func detachedHostQueuesUntilAttachment() {
        let center = FloatingNotificationCenter()
        let feedback = NotificationTestFixtures.feedback()

        center.publish(feedback, destination: .main)
        #expect(center.snapshot(for: .main).visible.isEmpty)
        #expect(center.snapshot(for: .main).queuedCount == 1)

        center.attach(.main)
        #expect(center.snapshot(for: .main).visible.map(\.id) == [feedback.id])
        #expect(center.snapshot(for: .main).queuedCount == 0)
    }

    @Test
    func temporaryLifetimeStartsOnlyAfterVisiblePromotion() async throws {
        let sleeper = ControlledFeedbackSleeper()
        let center = makeFloatingNotificationCenter(sleeper: sleeper)
        let feedback = NotificationTestFixtures.feedback()

        center.publish(feedback, destination: .main)
        #expect(await sleeper.pendingCount() == 0)

        center.attach(.main)
        try await eventually {
            await sleeper.pendingCount() == 1
        }
        #expect(await sleeper.requestedDurations == [4])

        await sleeper.resumeAll()
        try await eventually {
            center.snapshot(for: .main).visible.isEmpty
        }
    }

    @Test
    func actionCanBeginOnlyOnceWhileItIsInFlight() throws {
        let center = FloatingNotificationCenter()
        center.attach(.main)
        let feedback = NotificationTestFixtures.feedback(
            id: UUID(),
            state: .cancelled,
            title: "Book selection cancelled."
        )
        let action = NotificationActionDescriptor(
            label: "Choose Another Book",
            command: .chooseAnotherFile,
            dismissalAfterActivation: .keep
        )
        center.publish(
            feedback,
            destination: .main,
            configuration: FloatingNotificationConfiguration(
                lifetime: .persistentUntilReplaced,
                closePolicy: .shown,
                action: action
            )
        )

        let first = try #require(
            center.beginAction(
                feedbackID: feedback.id,
                destination: .main
            )
        )

        #expect(first == action)
        #expect(
            center.beginAction(
                feedbackID: feedback.id,
                destination: .main
            ) == nil
        )
    }

    @Test
    func actionCompletionAppliesKeepHideAndAwaitReplacementPolicies() throws {
        let center = FloatingNotificationCenter()
        center.attach(.main)

        for (scope, dismissal) in [
            (FeedbackScope.batch, NotificationActionDismissal.keep),
            (.history, .hide),
            (.update, .awaitReplacement),
        ] {
            let feedback = NotificationTestFixtures.feedback(
                id: UUID(),
                scope: scope,
                state: .cancelled,
                title: "Action available."
            )
            let action = NotificationActionDescriptor(
                label: "Review",
                command: .reviewBook,
                dismissalAfterActivation: dismissal
            )
            center.publish(
                feedback,
                destination: .main,
                configuration: FloatingNotificationConfiguration(
                    lifetime: .persistentUntilReplaced,
                    closePolicy: .shown,
                    action: action
                )
            )
            let begun = try #require(
                center.beginAction(
                    feedbackID: feedback.id,
                    destination: .main
                )
            )
            center.completeAction(
                feedbackID: feedback.id,
                destination: .main,
                actionID: begun.id,
                didChangeState: dismissal == .awaitReplacement
            )

            let current = center.feedback(
                for: scope,
                destination: .main
            )
            switch dismissal {
            case .keep:
                #expect(current?.id == feedback.id)
                #expect(
                    center.snapshot(for: .main).visible.first {
                        $0.feedback.id == feedback.id
                    }?.isActionInFlight == false
                )
            case .hide:
                #expect(current?.id == feedback.id)
                #expect(
                    !center.snapshot(for: .main).visible.contains {
                        $0.feedback.id == feedback.id
                    }
                )
            case .awaitReplacement:
                #expect(current?.id == feedback.id)
                #expect(
                    center.snapshot(for: .main).visible.first {
                        $0.feedback.id == feedback.id
                    }?.isActionInFlight == true
                )
            }
        }
    }

    @Test
    func unchangedAwaitReplacementRestoresActionAvailability() throws {
        let center = FloatingNotificationCenter()
        center.attach(.main)
        let feedback = NotificationTestFixtures.feedback(
            id: UUID(),
            state: .cancelled,
            title: "Action available."
        )
        let action = NotificationActionDescriptor(
            label: "Review",
            command: .reviewBook,
            dismissalAfterActivation: .awaitReplacement
        )
        center.publish(
            feedback,
            destination: .main,
            configuration: FloatingNotificationConfiguration(
                lifetime: .persistentUntilReplaced,
                closePolicy: .shown,
                action: action
            )
        )
        let begun = try #require(
            center.beginAction(
                feedbackID: feedback.id,
                destination: .main
            )
        )

        center.completeAction(
            feedbackID: feedback.id,
            destination: .main,
            actionID: begun.id,
            didChangeState: false
        )

        #expect(
            center.beginAction(
                feedbackID: feedback.id,
                destination: .main
            ) == action
        )
    }

    @Test
    func focusRequestIsDestinationScopedAndConsumedOnce() throws {
        let center = FloatingNotificationCenter()
        center.requestFocus(destination: .settings, action: .editSetup)
        let request = try #require(center.focusRequest)

        #expect(request.destination == .settings)
        #expect(request.action == .editSetup)
        center.consumeFocusRequest(id: UUID())
        #expect(center.focusRequest == request)
        center.consumeFocusRequest(id: request.id)
        #expect(center.focusRequest == nil)
        center.consumeFocusRequest(id: request.id)
        #expect(center.focusRequest == nil)
    }

    @Test
    func meaningfulIdentityAndStateAreAnnouncedOnlyOnce() {
        let center = FloatingNotificationCenter()
        center.attach(.main)
        let first = NotificationTestFixtures.feedback(
            id: UUID(),
            state: .cancelled,
            title: "Operation cancelled."
        )
        center.publish(first, destination: .main)

        #expect(
            center.takeAccessibilityAnnouncement(
                feedbackID: first.id,
                destination: .main
            ) == "Operation cancelled."
        )
        #expect(
            center.takeAccessibilityAnnouncement(
                feedbackID: first.id,
                destination: .main
            ) == nil
        )

        let repeated = NotificationTestFixtures.feedback(
            id: UUID(),
            state: .cancelled,
            title: "Operation cancelled."
        )
        center.publish(repeated, destination: .main)
        #expect(
            center.takeAccessibilityAnnouncement(
                feedbackID: first.id,
                destination: .main
            ) == nil
        )

        let service = ActionFeedbackService()
        let acknowledged = service.acknowledged(
            scope: .update,
            action: .checkForUpdates,
            title: "Checking for updates…"
        )
        let progress = service.inProgress(
            from: acknowledged,
            title: "Checking for updates…"
        )
        center.publish(progress, destination: .main)
        #expect(
            center.takeAccessibilityAnnouncement(
                feedbackID: progress.id,
                destination: .main
            ) == "Checking for updates…"
        )
        let success = service.terminal(
            from: progress,
            state: .succeeded,
            title: "Update check opened."
        )
        center.publish(success, destination: .main)
        #expect(
            center.takeAccessibilityAnnouncement(
                feedbackID: success.id,
                destination: .main
            ) == "Update check opened."
        )
    }

    private func eventually(
        _ condition: @escaping @MainActor @Sendable () async -> Bool
    ) async throws {
        for _ in 0..<2_000 {
            if await condition() { return }
            await Task.yield()
        }
        throw FloatingNotificationCenterTestError.timeout
    }
}

private enum FloatingNotificationCenterTestError: Error {
    case timeout
}
