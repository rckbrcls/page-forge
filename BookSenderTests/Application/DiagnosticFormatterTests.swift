import Testing
@testable import BookSender

struct DiagnosticFormatterTests {
    @Test
    func formatsDeterministicFieldsInStableOrder() {
        let copy = DiagnosticFormatter().format(DiagnosticTestFixtures.safeEvent())

        let expectedOrder = [
            "Book Sender 0.0-test",
            "Time:",
            "Event:",
            "Operation:",
            "Action: Send book",
            "Outcome: Failed",
            "Code: smtp.authentication-rejected",
            "Subsystem: Delivery",
            "Phase: Authenticating",
            "Severity: Error",
            "Provider status: 535 5.7.8",
            "Setup revision: 2",
            "Batch: 1 of 3",
            "Transmission started: No",
            "Occurrence count: 2",
            "Next step: Edit Setup",
        ]
        var priorOffset = -1
        for field in expectedOrder {
            let range = copy.text.range(of: field)
            #expect(range != nil)
            if let range {
                let offset = copy.text.distance(
                    from: copy.text.startIndex,
                    to: range.lowerBound
                )
                #expect(offset >= priorOffset)
                priorOffset = offset
            }
        }
    }

    @Test
    func omitsUnavailableOptionalFieldsAndRawCanaries() {
        let failure = SanitizedFailure(
            family: .archive,
            code: .archiveOpen,
            message: DiagnosticTestFixtures.rawError,
            recoveryAction: .reviewBook,
            evidence: DiagnosticEvidence(
                phase: .archiveSafety,
                retryDisposition: .reviewBook
            )
        )
        let event = DiagnosticEvent(
            occurredAt: DiagnosticTestFixtures.safeTimestamp,
            action: .prepareBook,
            outcome: .failed,
            failure: failure
        )

        let text = DiagnosticFormatter().format(event).text

        #expect(!text.contains("Provider status:"))
        #expect(!text.contains("Operation:"))
        #expect(!text.contains("Setup revision:"))
        for forbidden in DiagnosticTestFixtures.forbiddenValues {
            #expect(!text.contains(forbidden))
        }
    }
}
