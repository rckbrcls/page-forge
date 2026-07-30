import Testing
@testable import BookSender

struct DiagnosticRedactionTests {
    @Test
    func canaryMatrixIsAbsentFromPresentationEventAndCopy() async {
        let recorder = DiagnosticRecorderSpy()
        let service = DiagnosticService(
            recorder: recorder,
            appVersion: DiagnosticTestFixtures.safeAppVersion
        )
        let rawBoundaryFailure = SanitizedFailure(
            family: .delivery,
            code: .smtpAuthenticationRejected,
            message: DiagnosticTestFixtures.forbiddenValues.joined(
                separator: "\n"
            ),
            recoveryAction: .editSetup,
            evidence: DiagnosticEvidence(
                phase: .smtpAuthenticating,
                retryDisposition: .editSetup,
                providerStatus: ProviderStatus(
                    replyCode: 535,
                    enhancedStatus: EnhancedStatusCode(parsing: "5.7.8")
                ),
                context: DiagnosticContext(
                    operationID: DiagnosticTestFixtures.safeOperationID
                )
            )
        )
        let event = service.makeEvent(
            action: .sendBook,
            outcome: .failed,
            failure: rawBoundaryFailure
        )
        _ = await service.recordOnce(event)
        let presentation = FailurePresentationService()
            .presentation(for: event.failure)
        let copy = DiagnosticFormatter().format(event)
        let rendered = [
            String(describing: presentation),
            String(describing: await recorder.events),
            copy.text,
        ].joined(separator: "\n")

        for forbidden in DiagnosticTestFixtures.forbiddenValues {
            #expect(!rendered.contains(forbidden))
        }
        #expect(rendered.contains("535"))
        #expect(rendered.contains("5.7.8"))
    }
}
