import Foundation
import Testing
@testable import BookSender

struct SMTPStateMachineTests {
    @Test
    func decodesFragmentedBoundedMultilineReplies() throws {
        var decoder = SMTPReplyDecoder()
        let data = FixtureFactory.smtpReply(
            code: 250,
            lines: ["localhost", "STARTTLS", "AUTH PLAIN LOGIN"]
        )
        let midpoint = data.count / 2

        #expect(try decoder.append(data.prefix(midpoint)).isEmpty)
        let replies = try decoder.append(data.suffix(from: midpoint))

        #expect(replies.count == 1)
        #expect(replies.first?.code == 250)
        #expect(replies.first?.lines == ["localhost", "STARTTLS", "AUTH PLAIN LOGIN"])
    }

    @Test
    func rejectsReplyLineAndMultilineCountPastLimits() {
        var lineDecoder = SMTPReplyDecoder(
            limits: makeSafetyLimits(maximumSMTPLineBytes: 8)
        )
        #expect(throws: SanitizedFailure.self) {
            _ = try lineDecoder.append(Data("250 too-long\r\n".utf8))
        }

        var countDecoder = SMTPReplyDecoder(
            limits: makeSafetyLimits(maximumSMTPReplyLines: 1)
        )
        #expect(throws: SanitizedFailure.self) {
            _ = try countDecoder.append(
                FixtureFactory.smtpReply(code: 250, lines: ["one", "two"])
            )
        }
    }

    @Test
    func completesImplicitTLSPlainFlowThroughFinalAcceptance() throws {
        var machine = SMTPStateMachine(
            setup: try setup(mode: .implicitTLS),
            credential: "secret"
        )

        #expect(machine.receive(reply(220, "ready")) == [write("EHLO localhost")])
        let auth = machine.receive(reply(250, "AUTH PLAIN LOGIN"))
        #expect(auth.count == 1)
        if case .write(let line, let containsSecret) = auth[0] {
            #expect(line.hasPrefix("AUTH PLAIN "))
            #expect(containsSecret)
        } else {
            Issue.record("Expected AUTH PLAIN")
        }
        #expect(machine.receive(reply(235, "ok")) == [write("MAIL FROM:<sender@example.com>")])
        #expect(machine.receive(reply(250, "ok")) == [write("RCPT TO:<reader@kindle.com>")])
        #expect(machine.receive(reply(250, "ok")) == [write("DATA")])
        #expect(machine.receive(reply(354, "continue")) == [.beginMessageData])
        #expect(
            machine.receive(reply(250, "accepted"))
                == [write("QUIT"), .accepted]
        )
    }

    @Test
    func supportsPlainAuthenticationChallengeWithoutSendingBeforeTLS() throws {
        var machine = SMTPStateMachine(
            setup: try setup(mode: .implicitTLS),
            credential: "secret"
        )
        _ = machine.receive(reply(220, "ready"))
        _ = machine.receive(reply(250, "AUTH PLAIN"))
        let challenge = machine.receive(reply(334, "continue"))

        #expect(secretWrite(challenge))
        #expect(
            machine.receive(reply(235, "ok"))
                == [write("MAIL FROM:<sender@example.com>")]
        )
    }

    @Test
    func requiresStartTLSAndSecondEHLOBeforeLoginAuthentication() throws {
        var machine = SMTPStateMachine(
            setup: try setup(mode: .startTLS),
            credential: "secret"
        )
        #expect(machine.receive(reply(220, "ready")) == [write("EHLO localhost")])
        #expect(
            machine.receive(reply(250, "STARTTLS"))
                == [write("STARTTLS")]
        )
        #expect(machine.receive(reply(220, "ready")) == [.upgradeTLS])
        #expect(machine.didUpgradeTLS() == [write("EHLO localhost")])
        #expect(
            machine.receive(reply(250, "AUTH LOGIN"))
                == [write("AUTH LOGIN")]
        )
        let username = machine.receive(reply(334, "username"))
        let password = machine.receive(reply(334, "password"))
        #expect(secretWrite(username))
        #expect(secretWrite(password))
        #expect(machine.receive(reply(235, "ok")) == [write("MAIL FROM:<sender@example.com>")])
    }

    @Test(arguments: [
        (530, "5.7.0"),
        (534, "5.7.9"),
        (535, "5.7.8"),
    ])
    func mapsAuthenticationRejectionsToAuthenticationEvidence(
        code: Int,
        enhanced: String
    ) throws {
        var machine = SMTPStateMachine(
            setup: try setup(mode: .implicitTLS),
            credential: "secret"
        )
        _ = machine.receive(reply(220, "ready"))
        _ = machine.receive(reply(250, "AUTH PLAIN"))

        let failure = try #require(
            firstFailure(
                in: machine.receive(
                    SMTPReply(
                        code: code,
                        lines: ["\(enhanced) private provider prose"],
                        providerStatus: ProviderStatus(
                            replyCode: code,
                            enhancedStatus: EnhancedStatusCode(parsing: enhanced)
                        )
                    )
                )
            )
        )

        #expect(failure.code == .smtpAuthenticationRejected)
        #expect(failure.evidence.phase == .smtpAuthenticating)
        #expect(failure.evidence.retryDisposition == .editSetup)
        #expect(failure.evidence.providerStatus?.replyCode == code)
        #expect(failure.message.contains("private provider prose") == false)
    }

    @Test
    func distinguishesSenderRecipientDataAndFinalAcceptanceRejections() throws {
        let scenarios: [(SMTPFailurePoint, DiagnosticCode, DiagnosticPhase)] = [
            (.sender, .smtpSenderRejected, .smtpSender),
            (.recipient, .smtpRecipientRejected, .smtpRecipient),
            (.data, .smtpDataRejected, .smtpData),
            (
                .finalAcceptance,
                .smtpFinalAcceptanceRejected,
                .smtpFinalAcceptance
            ),
        ]

        for scenario in scenarios {
            for replyCode in [450, 550] {
                var machine = SMTPStateMachine(
                    setup: try setup(mode: .implicitTLS),
                    credential: "secret"
                )
                advance(&machine, to: scenario.0)
                let failure = try #require(
                    firstFailure(
                        in: machine.receive(
                            reply(
                                replyCode,
                                replyCode == 450
                                    ? "4.0.0 rejected"
                                    : "5.0.0 rejected"
                            )
                        )
                    )
                )
                #expect(failure.code == scenario.1)
                #expect(failure.evidence.phase == scenario.2)
                #expect(
                    failure.evidence.providerStatus?.replyCode == replyCode
                )
                if replyCode == 450 {
                    #expect(failure.evidence.retryDisposition == .retrySafe)
                    #expect(failure.recoveryAction == .retryFailed)
                } else if scenario.0 == .data
                            || scenario.0 == .finalAcceptance {
                    #expect(
                        failure.evidence.retryDisposition == .reviewBook
                    )
                    #expect(failure.recoveryAction == .reviewBook)
                }
            }
        }
    }

    @Test
    func mapsGreetingAndTLSFailuresBeforeAuthentication() throws {
        var greeting = SMTPStateMachine(
            setup: try setup(mode: .implicitTLS),
            credential: "secret"
        )
        let greetingFailure = try #require(
            firstFailure(in: greeting.receive(reply(421, "4.3.2 unavailable")))
        )
        #expect(greetingFailure.code == .smtpGreeting)
        #expect(greetingFailure.evidence.phase == .smtpSecuring)
        #expect(greetingFailure.evidence.retryDisposition == .retrySafe)

        var startTLS = SMTPStateMachine(
            setup: try setup(mode: .startTLS),
            credential: "secret"
        )
        _ = startTLS.receive(reply(220, "ready"))
        _ = startTLS.receive(reply(250, "STARTTLS"))
        let tlsFailure = try #require(
            firstFailure(in: startTLS.receive(reply(454, "4.7.0 unavailable")))
        )
        #expect(tlsFailure.code == .smtpStartTLS)
        #expect(tlsFailure.evidence.phase == .smtpSecuring)
    }

    private func setup(mode: SecurityMode) throws -> DeliverySetup {
        try DeliverySetupValidator().makeSetup(
            from: DeliverySetupDraft(
                senderAddress: "sender@example.com",
                smtpHost: "smtp.example.com",
                smtpPort: mode == .implicitTLS ? "465" : "587",
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

    private func reply(_ code: Int, _ line: String) -> SMTPReply {
        SMTPReply(code: code, lines: [line])
    }

    private func advance(
        _ machine: inout SMTPStateMachine,
        to point: SMTPFailurePoint
    ) {
        _ = machine.receive(reply(220, "ready"))
        _ = machine.receive(reply(250, "AUTH PLAIN"))
        _ = machine.receive(reply(235, "ok"))
        guard point != .sender else { return }
        _ = machine.receive(reply(250, "ok"))
        guard point != .recipient else { return }
        _ = machine.receive(reply(250, "ok"))
        guard point != .data else { return }
        _ = machine.receive(reply(354, "continue"))
    }

    private func firstFailure(in actions: [SMTPAction]) -> SanitizedFailure? {
        actions.compactMap { action -> SanitizedFailure? in
            guard case .failed(let failure) = action else { return nil }
            return failure
        }.first
    }

    private func write(_ line: String) -> SMTPAction {
        .write(line: "\(line)\r\n", containsSecret: false)
    }

    private func secretWrite(_ actions: [SMTPAction]) -> Bool {
        guard actions.count == 1,
              case .write(_, let containsSecret) = actions[0]
        else {
            return false
        }
        return containsSecret
    }
}

private enum SMTPFailurePoint {
    case sender
    case recipient
    case data
    case finalAcceptance
}
