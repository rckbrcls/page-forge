import Foundation
import Testing
@testable import BookSender

struct ActionFeedbackServiceTests {
    @Test
    func progressesWithoutChangingLifecycleIdentity() {
        let service = ActionFeedbackService()
        let start = Date(timeIntervalSince1970: 10)
        let acknowledged = service.acknowledged(
            scope: .deliverySetup,
            action: .saveDeliverySetup,
            title: "Saving setup",
            now: start
        )
        let progress = service.inProgress(
            from: acknowledged,
            title: "Saving setup",
            now: start.addingTimeInterval(1)
        )
        let success = service.terminal(
            from: progress,
            state: .succeeded,
            title: "Setup saved",
            message: "App password stored securely.",
            now: start.addingTimeInterval(2)
        )

        #expect(acknowledged.id == progress.id)
        #expect(progress.id == success.id)
        #expect(success.state == .succeeded)
        #expect(
            success.dismissal
                == .delayed(minimumVisibleDuration: 4)
        )
    }

    @Test
    func actionableTerminalStatesRemainPersistent() {
        let service = ActionFeedbackService()
        let failure = SanitizedFailure(
            family: .credential,
            code: .credentialRead,
            message: "The app password is unavailable.",
            recoveryAction: .editSetup
        )
        let presentation = FailurePresentationService().presentation(for: failure)
        let states: [FeedbackState] = [
            .failed, .cancelled, .partial, .unknown,
        ]

        for state in states {
            let start = service.acknowledged(
                scope: .deliverySetup,
                action: .saveDeliverySetup,
                title: "Saving setup"
            )
            let terminal = service.terminal(
                from: start,
                state: state,
                title: "Setup needs attention",
                failure: state == .failed || state == .unknown
                    ? presentation
                    : nil
            )
            #expect(terminal.dismissal == .persistentUntilReplaced)
        }
    }

    @Test
    func unchangedFeedbackDoesNotAnnounceAgain() {
        let service = ActionFeedbackService()
        let feedback = service.acknowledged(
            scope: .batch,
            action: .sendBatch,
            title: "Sending books"
        )
        let progress = service.inProgress(
            from: feedback,
            title: "Sending books"
        )
        #expect(service.shouldAnnounce(previous: nil, current: progress))
        #expect(!service.shouldAnnounce(previous: progress, current: progress))
    }

    @Test
    func repeatedFailureIncrementsOccurrenceWithoutStackingIdentity() {
        let service = ActionFeedbackService()
        let failure = SanitizedFailure(
            family: .credential,
            code: .credentialRead,
            message: "The app password is unavailable.",
            recoveryAction: .editSetup
        )
        let presentation = FailurePresentationService().presentation(for: failure)
        let start = service.acknowledged(
            scope: .deliverySetup,
            action: .saveDeliverySetup,
            title: "Saving setup"
        )
        let terminal = service.terminal(
            from: start,
            state: .failed,
            title: "Setup was not saved",
            failure: presentation
        )
        let repeated = service.reconcile(
            current: terminal,
            proposed: terminal,
            repeatedOccurrence: true
        )
        #expect(repeated.id == terminal.id)
        #expect(repeated.occurrenceCount == 2)
        #expect(
            service.shouldAnnounce(previous: terminal, current: repeated)
                == false
        )
    }

    @Test
    func aggregateBatchProgressSuppressesUnchangedAnnouncementNoise() {
        let service = ActionFeedbackService()
        let start = service.acknowledged(
            scope: .batch,
            action: .sendBatch,
            title: "Sending 20 books"
        )
        let progress = service.inProgress(
            from: start,
            title: "Sending books",
            message: "8 of 20 finished."
        )
        let unchanged = service.reconcile(
            current: progress,
            proposed: progress
        )

        #expect(service.shouldAnnounce(previous: nil, current: progress))
        #expect(!service.shouldAnnounce(previous: progress, current: unchanged))
    }

    @Test
    func notificationProjectionUsesSemanticDefaults() {
        let service = ActionFeedbackService()
        let start = service.acknowledged(
            scope: .batch,
            action: .addBooks,
            title: "Adding book…"
        )
        let success = service.terminal(
            from: start,
            state: .succeeded,
            title: "Book added."
        )

        let configuration = service.notificationConfiguration(for: success)

        #expect(configuration.icon == .automatic)
        #expect(configuration.lifetime == .temporary(seconds: 4))
        #expect(configuration.closePolicy == .shown)
        #expect(configuration.action == nil)
    }

    @Test
    func projectionRetainsOneTypedRecoveryAction() {
        let service = ActionFeedbackService()
        let failure = SanitizedFailure(
            family: .credential,
            code: .credentialRead,
            message: "The app password is unavailable.",
            recoveryAction: .editSetup
        )
        let start = service.acknowledged(
            scope: .deliverySetup,
            action: .saveDeliverySetup,
            title: "Saving setup…"
        )
        let terminal = service.terminal(
            from: start,
            state: .failed,
            title: "Setup was not saved.",
            failure: FailurePresentationService().presentation(for: failure)
        )

        let configuration = service.notificationConfiguration(for: terminal)

        #expect(configuration.lifetime == .persistentUntilReplaced)
        #expect(configuration.action?.command == .editSetup)
        #expect(configuration.action?.label == "Edit Setup")
        #expect(
            configuration.action?.dismissalAfterActivation
                == .awaitReplacement
        )
    }

    @Test
    func projectionHonorsSafeIconCloseAndDurationOverrides() {
        let service = ActionFeedbackService()
        let start = service.acknowledged(
            scope: .update,
            action: .checkForUpdates,
            title: "Opening update check…"
        )
        let success = service.terminal(
            from: start,
            state: .succeeded,
            title: "Update check opened."
        )

        let configuration = service.notificationConfiguration(
            for: success,
            icon: .none,
            closePolicy: .hidden,
            temporaryDuration: 8
        )

        #expect(configuration.icon == .none)
        #expect(configuration.closePolicy == .hidden)
        #expect(configuration.lifetime == .temporary(seconds: 5))
    }
}
