import Foundation
import Testing
@testable import BookSender

struct SMTPDeliveryUncertaintyTests {
    @Test
    func missingStartTLSAndProviderRejectionAreSanitizedFailures() throws {
        var startTLS = SMTPStateMachine(
            setup: try setup(mode: .startTLS),
            credential: "secret"
        )
        _ = startTLS.receive(SMTPReply(code: 220, lines: ["ready"]))
        let missing = startTLS.receive(
            SMTPReply(code: 250, lines: ["AUTH PLAIN"])
        )
        #expect(failureCode(in: missing) == .smtpStartTLSUnavailable)

        var rejected = SMTPStateMachine(
            setup: try setup(mode: .implicitTLS),
            credential: "secret"
        )
        _ = rejected.receive(SMTPReply(code: 220, lines: ["ready"]))
        _ = rejected.receive(SMTPReply(code: 250, lines: ["AUTH PLAIN"]))
        let provider = rejected.receive(
            SMTPReply(code: 535, lines: ["5.7.8 provider detail"])
        )
        #expect(failureCode(in: provider) == .smtpAuthenticationRejected)
        #expect(String(describing: provider).contains("provider detail") == false)
    }

    @Test
    func classifiesCancellationAndLossAtDataBoundary() {
        let failure = sanitizedFailure(.smtpConnectionClosed)

        #expect(
            SMTPUncertaintyClassifier.outcome(
                dataTransmissionStarted: false,
                termination: .cancelled
            ) == .cancelled
        )
        let cancelledAfterData = SMTPUncertaintyClassifier.outcome(
            dataTransmissionStarted: true,
            termination: .cancelled
        )
        guard case .deliveryUnknown(let cancelledFailure) = cancelledAfterData else {
            Issue.record("Expected delivery uncertainty after cancellation")
            return
        }
        #expect(cancelledFailure.code == .smtpDeliveryUnknown)
        #expect(
            SMTPUncertaintyClassifier.outcome(
                dataTransmissionStarted: false,
                termination: .failed(failure)
            ) == .failed(failure)
        )
        let failedAfterData = SMTPUncertaintyClassifier.outcome(
            dataTransmissionStarted: true,
            termination: .failed(failure)
        )
        guard case .deliveryUnknown(let failedFailure) = failedAfterData else {
            Issue.record("Expected delivery uncertainty after transport failure")
            return
        }
        #expect(failedFailure.code == .smtpDeliveryUnknown)
    }

    @Test
    func certificateFixtureIsDeterministicAndHostnameScoped() throws {
        let first = try FixtureFactory.localhostTLSIdentity()
        let second = try FixtureFactory.localhostTLSIdentity()

        #expect(first.certificateDER == second.certificateDER)
        #expect(first.privateKeyDER == second.privateKeyDER)
        #expect(first.serverName == "localhost")
        #expect(first.certificateDER.isEmpty == false)
    }

    private func setup(mode: SecurityMode) throws -> DeliverySetup {
        try DeliverySetupValidator().makeSetup(
            from: DeliverySetupDraft(
                senderAddress: "sender@example.com",
                smtpHost: "smtp.example.com",
                smtpPort: "587",
                securityMode: mode,
                username: "sender",
                appPassword: "secret",
                kindleAddress: "reader@kindle.com"
            ),
            credentialReference: CredentialReference(
                service: "test",
                account: "revision-1",
                revision: 1
            ),
            revision: 1
        )
    }

    private func failureCode(in actions: [SMTPAction]) -> DiagnosticCode? {
        for action in actions {
            if case .failed(let failure) = action {
                return failure.code
            }
        }
        return nil
    }
}
