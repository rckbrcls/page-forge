import Foundation
@testable import BookSender

enum NotificationTestFixtures {
    static let mainFeedbackID = UUID(
        uuidString: "11111111-1111-1111-1111-111111111111"
    )!
    static let settingsFeedbackID = UUID(
        uuidString: "22222222-2222-2222-2222-222222222222"
    )!
    static let actionID = UUID(
        uuidString: "33333333-3333-3333-3333-333333333333"
    )!
    static let itemID = UUID(
        uuidString: "44444444-4444-4444-4444-444444444444"
    )!
    static let start = Date(timeIntervalSince1970: 1_000)

    static func feedback(
        id: UUID = mainFeedbackID,
        scope: FeedbackScope = .batch,
        action: FeedbackAction = .addBooks,
        state: FeedbackState = .succeeded,
        title: String = "Book added.",
        message: String? = nil,
        dismissal: FeedbackDismissalPolicy? = nil,
        occurrenceCount: Int = 1
    ) -> ActionFeedback {
        let failure: FailurePresentation? = switch state {
        case .failed, .unknown:
            FailurePresentationService().presentation(
                for: SanitizedFailure(
                    family: .delivery,
                    code: .smtpTransport,
                    message: "The operation could not continue.",
                    recoveryAction: .retryFailed
                )
            )
        case .acknowledged, .inProgress, .succeeded, .cancelled, .partial:
            nil
        }
        return ActionFeedback(
            id: id,
            scope: scope,
            action: action,
            state: state,
            title: title,
            message: message,
            startedAt: start,
            dismissal: dismissal ?? defaultDismissal(for: state),
            failure: failure,
            occurrenceCount: occurrenceCount
        )
    }

    static func configuration(
        icon: NotificationIcon = .automatic,
        lifetime: NotificationLifetime = .temporary(seconds: 4),
        closePolicy: NotificationClosePolicy = .shown,
        action: NotificationActionDescriptor? = nil
    ) -> FloatingNotificationConfiguration {
        FloatingNotificationConfiguration(
            icon: icon,
            lifetime: lifetime,
            closePolicy: closePolicy,
            action: action
        )
    }

    static func action(
        id: UUID = actionID,
        command: RecoveryAction = .retryFailed,
        dismissal: NotificationActionDismissal = .awaitReplacement
    ) -> NotificationActionDescriptor {
        NotificationActionDescriptor(
            id: id,
            label: "Retry Failed",
            command: command,
            dismissalAfterActivation: dismissal
        )
    }

    static func entry(
        feedback: ActionFeedback = feedback(),
        destination: NotificationDestination = .main,
        configuration: FloatingNotificationConfiguration = configuration(),
        phase: NotificationPhase = .visible
    ) -> FloatingNotificationEntry {
        FloatingNotificationEntry(
            key: NotificationKey(
                destination: destination,
                scope: feedback.scope
            ),
            feedback: feedback,
            configuration: configuration,
            phase: phase,
            enqueuedAt: start,
            visibleAt: phase == .visible ? start : nil
        )
    }

    static func snapshot(
        destination: NotificationDestination = .main,
        visible: [FloatingNotificationEntry] = [],
        queuedCount: Int = 0,
        isHostAttached: Bool = true
    ) -> NotificationDestinationSnapshot {
        NotificationDestinationSnapshot(
            destination: destination,
            visible: visible,
            queuedCount: queuedCount,
            isHostAttached: isHostAttached
        )
    }

    @MainActor
    static func center(
        sleeper: ControlledFeedbackSleeper? = nil
    ) -> FloatingNotificationCenter {
        guard let sleeper else {
            return FloatingNotificationCenter()
        }
        return FloatingNotificationCenter { duration in
            try await sleeper.sleep(for: duration)
        }
    }

    private static func defaultDismissal(
        for state: FeedbackState
    ) -> FeedbackDismissalPolicy {
        switch state {
        case .acknowledged, .inProgress:
            .replaceOnNextAction
        case .succeeded:
            .delayed(minimumVisibleDuration: 4)
        case .failed, .cancelled, .partial, .unknown:
            .persistentUntilReplaced
        }
    }
}
