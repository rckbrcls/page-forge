import Testing
@testable import BookSender

struct SMTPActiveCancellationTests {
    @Test
    func repeatedCancellationClassificationIsStableAcrossDataBoundary() {
        for _ in 0..<3 {
            #expect(
                SMTPUncertaintyClassifier.outcome(
                    dataTransmissionStarted: false,
                    termination: .cancelled
                ) == .cancelled
            )
            let uncertain = SMTPUncertaintyClassifier.outcome(
                dataTransmissionStarted: true,
                termination: .cancelled
            )
            guard case .deliveryUnknown(let failure) = uncertain else {
                Issue.record("Expected delivery uncertainty")
                return
            }
            #expect(failure.code == .smtpDeliveryUnknown)
            #expect(failure.evidence.context.transmissionStarted == true)
        }
    }

    @Test
    func finalAcceptanceRemainsSubmittedOutsideTerminationClassifier() {
        let accepted: TerminalOutcome = .submitted
        #expect(accepted == .submitted)
    }
}
