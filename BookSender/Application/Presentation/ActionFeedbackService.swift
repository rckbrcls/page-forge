import Foundation

struct ActionFeedbackService: Sendable {
    static let transientDuration: TimeInterval = 4

    func acknowledged(
        scope: FeedbackScope,
        action: FeedbackAction,
        title: String,
        message: String? = nil,
        id: UUID = UUID(),
        now: Date = Date()
    ) -> ActionFeedback {
        ActionFeedback(
            id: id,
            scope: scope,
            action: action,
            state: .acknowledged,
            title: title,
            message: message,
            startedAt: now,
            dismissal: .replaceOnNextAction
        )
    }

    func inProgress(
        from feedback: ActionFeedback,
        title: String,
        message: String? = nil,
        now: Date = Date()
    ) -> ActionFeedback {
        precondition(feedback.state.canTransition(to: .inProgress))
        return ActionFeedback(
            id: feedback.id,
            scope: feedback.scope,
            action: feedback.action,
            state: .inProgress,
            title: title,
            message: message,
            startedAt: feedback.startedAt,
            updatedAt: now,
            dismissal: .replaceOnNextAction
        )
    }

    func terminal(
        from feedback: ActionFeedback,
        state: FeedbackState,
        title: String,
        message: String? = nil,
        failure: FailurePresentation? = nil,
        dismissal: FeedbackDismissalPolicy? = nil,
        now: Date = Date(),
        occurrenceCount: Int = 1
    ) -> ActionFeedback {
        precondition(feedback.state.canTransition(to: state))
        return ActionFeedback(
            id: feedback.id,
            scope: feedback.scope,
            action: feedback.action,
            state: state,
            title: title,
            message: message,
            startedAt: feedback.startedAt,
            updatedAt: now,
            dismissal: dismissal ?? defaultDismissal(for: state),
            failure: failure,
            occurrenceCount: occurrenceCount
        )
    }

    private func defaultDismissal(
        for state: FeedbackState
    ) -> FeedbackDismissalPolicy {
        switch state {
        case .succeeded:
            .delayed(
                minimumVisibleDuration: Self.transientDuration
            )
        case .acknowledged, .inProgress:
            .replaceOnNextAction
        case .failed, .cancelled, .partial, .unknown:
            .persistentUntilReplaced
        }
    }

    func reconcile(
        current: ActionFeedback?,
        proposed: ActionFeedback,
        repeatedOccurrence: Bool = false
    ) -> ActionFeedback {
        guard let current,
              current.scope == proposed.scope,
              current.action == proposed.action,
              current.state == proposed.state,
              current.title == proposed.title,
              current.message == proposed.message,
              current.failure == proposed.failure
        else {
            return proposed
        }
        guard repeatedOccurrence else { return current }
        return ActionFeedback(
            id: current.id,
            scope: current.scope,
            action: current.action,
            state: current.state,
            title: current.title,
            message: current.message,
            startedAt: current.startedAt,
            updatedAt: proposed.updatedAt,
            dismissal: current.dismissal,
            failure: current.failure,
            occurrenceCount: current.occurrenceCount + 1
        )
    }

    func shouldAnnounce(
        previous: ActionFeedback?,
        current: ActionFeedback
    ) -> Bool {
        guard previous?.id != current.id || previous?.state != current.state else {
            return false
        }
        switch current.state {
        case .inProgress, .succeeded, .failed, .cancelled, .partial, .unknown:
            return true
        case .acknowledged:
            return false
        }
    }
}
