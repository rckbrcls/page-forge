import Foundation
import Testing
@testable import BookSender

struct FeedbackModelsTests {
    @Test
    func terminalStatesAreExplicit() {
        #expect(FeedbackState.succeeded.isTerminal)
        #expect(FeedbackState.failed.isTerminal)
        #expect(FeedbackState.cancelled.isTerminal)
        #expect(FeedbackState.partial.isTerminal)
        #expect(FeedbackState.unknown.isTerminal)
        #expect(!FeedbackState.acknowledged.isTerminal)
        #expect(!FeedbackState.inProgress.isTerminal)
    }

    @Test
    func legalTransitionsPreserveTerminalImmutability() {
        for terminal in FeedbackState.allCases where terminal.isTerminal {
            #expect(FeedbackState.acknowledged.canTransition(to: terminal))
            #expect(FeedbackState.inProgress.canTransition(to: terminal))
            #expect(!terminal.canTransition(to: .inProgress))
            #expect(!terminal.canTransition(to: .succeeded))
        }
        #expect(
            FeedbackState.acknowledged.canTransition(to: .inProgress)
        )
        #expect(FeedbackState.inProgress.canTransition(to: .inProgress))
        #expect(
            !FeedbackState.acknowledged.canTransition(to: .acknowledged)
        )
    }

    @Test
    func dismissalPoliciesRejectInvalidDelays() {
        #expect(
            FeedbackDismissalPolicy
                .delayed(minimumVisibleDuration: 2)
                .isValid
        )
        #expect(
            !FeedbackDismissalPolicy
                .delayed(minimumVisibleDuration: -1)
                .isValid
        )
        #expect(
            !FeedbackDismissalPolicy
                .delayed(minimumVisibleDuration: .infinity)
                .isValid
        )
    }

    @Test
    func retryUsesANewLifecycleIdentity() {
        let service = ActionFeedbackService()
        let first = service.acknowledged(
            scope: .batch,
            action: .sendBatch,
            title: "Sending books"
        )
        let retry = service.acknowledged(
            scope: .batch,
            action: .sendBatch,
            title: "Retrying books"
        )
        #expect(first.id != retry.id)
    }

    @Test
    func diagnosticCopyHasAnIndependentAccessibilityScope() {
        #expect(
            FeedbackScope.diagnosticCopy.accessibilityIdentifier
                == "diagnosticCopy"
        )
        #expect(
            FeedbackScope.diagnosticCopy
                != FeedbackScope.deliverySetup
        )
    }

    @Test
    func failedFeedbackRetainsPresentation() {
        let failure = testFailure()
        let presentation = FailurePresentationService().presentation(for: failure)
        let feedback = ActionFeedback(
            scope: .deliverySetup,
            action: .saveDeliverySetup,
            state: .failed,
            title: "Setup was not saved",
            dismissal: .explicit,
            failure: presentation
        )
        #expect(feedback.failure?.code == .credentialSave)
        #expect(feedback.occurrenceCount == 1)
    }

    private func testFailure() -> SanitizedFailure {
        SanitizedFailure(
            family: .credential,
            code: .credentialSave,
            message: "The app password could not be stored securely.",
            recoveryAction: .editSetup
        )
    }
}
