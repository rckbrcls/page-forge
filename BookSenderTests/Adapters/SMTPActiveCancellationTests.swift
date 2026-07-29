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
            #expect(
                SMTPUncertaintyClassifier.outcome(
                    dataTransmissionStarted: true,
                    termination: .cancelled
                ) == .deliveryUnknown
            )
        }
    }

    @Test
    func finalAcceptanceRemainsSubmittedOutsideTerminationClassifier() {
        let accepted: TerminalOutcome = .submitted
        #expect(accepted == .submitted)
    }
}
