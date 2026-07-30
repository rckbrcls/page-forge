import Foundation
import Testing
@testable import BookSender

struct DiagnosticServiceTests {
    @Test
    func recordsOneTerminalEventPerOperationAndCode() async {
        let recorder = DiagnosticRecorderSpy()
        let service = DiagnosticService(
            recorder: recorder,
            appVersion: DiagnosticTestFixtures.safeAppVersion
        )
        let failure = failureWithOperation()
        let event = service.makeEvent(
            id: DiagnosticTestFixtures.safeEventID,
            occurredAt: DiagnosticTestFixtures.safeTimestamp,
            action: .sendBook,
            outcome: .failed,
            failure: failure
        )

        #expect(await service.recordOnce(event))
        #expect(await service.recordOnce(event) == false)
        #expect(await recorder.events.count == 1)
        #expect(
            await recorder.events.first?.failure.evidence.context.appVersion
                == DiagnosticTestFixtures.safeAppVersion
        )
    }

    @Test
    func keepsRawCanariesOutOfTypedEvent() async {
        let service = DiagnosticService(
            recorder: NoopDiagnosticRecorder(),
            appVersion: DiagnosticTestFixtures.safeAppVersion
        )
        let event = service.makeEvent(
            action: .sendBook,
            outcome: .failed,
            failure: failureWithOperation()
        )
        let description = String(describing: event)
        for value in DiagnosticTestFixtures.forbiddenValues {
            #expect(!description.contains(value))
        }
    }

    private func failureWithOperation() -> SanitizedFailure {
        SanitizedFailure(
            family: .delivery,
            code: .smtpAuthenticationRejected,
            message: "Authentication was rejected.",
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
    }
}
