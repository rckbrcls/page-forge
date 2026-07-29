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
        #expect(failureCode(in: missing) == "smtp.starttls-unavailable")

        var rejected = SMTPStateMachine(
            setup: try setup(mode: .implicitTLS),
            credential: "secret"
        )
        let provider = rejected.receive(
            SMTPReply(code: 535, lines: ["provider detail"])
        )
        #expect(failureCode(in: provider) == "smtp.provider-535")
        #expect(String(describing: provider).contains("provider detail") == false)
    }

    @Test
    func classifiesCancellationAndLossAtDataBoundary() {
        let failure = sanitizedFailure("smtp.connection-closed")

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
        #expect(
            SMTPUncertaintyClassifier.outcome(
                dataTransmissionStarted: false,
                termination: .failed(failure)
            ) == .failed(failure)
        )
        #expect(
            SMTPUncertaintyClassifier.outcome(
                dataTransmissionStarted: true,
                termination: .failed(failure)
            ) == .deliveryUnknown
        )
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

    private func failureCode(in actions: [SMTPAction]) -> String? {
        for action in actions {
            if case .failed(let failure) = action {
                return failure.code
            }
        }
        return nil
    }
}
