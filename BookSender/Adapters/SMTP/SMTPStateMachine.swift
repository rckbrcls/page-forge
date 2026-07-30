import Foundation

enum SMTPAction: Equatable, Sendable {
    case write(line: String, containsSecret: Bool)
    case upgradeTLS
    case beginMessageData
    case accepted
    case failed(SanitizedFailure)
}

struct SMTPStateMachine: Sendable {
    private enum State: Equatable, Sendable {
        case greeting
        case ehloBeforeTLS
        case startTLS
        case ehloAfterTLS
        case authPlain(challengeResponseSent: Bool)
        case authLoginUsername
        case authLoginPassword
        case authenticated
        case mailFrom
        case recipient
        case data
        case finalAcceptance
        case completed
    }

    private let setup: DeliverySetup
    private let credential: String
    private var state: State
    private var isTLSActive: Bool
    private var capabilities = Set<String>()

    init(setup: DeliverySetup, credential: String) {
        self.setup = setup
        self.credential = credential
        state = .greeting
        isTLSActive = setup.securityMode == .implicitTLS
    }

    var diagnosticPhase: DiagnosticPhase {
        switch state {
        case .greeting:
            .smtpConnecting
        case .ehloBeforeTLS, .startTLS, .ehloAfterTLS:
            .smtpSecuring
        case .authPlain, .authLoginUsername, .authLoginPassword, .authenticated:
            .smtpAuthenticating
        case .mailFrom:
            .smtpSender
        case .recipient:
            .smtpRecipient
        case .data:
            .smtpData
        case .finalAcceptance, .completed:
            .smtpFinalAcceptance
        }
    }

    mutating func receive(_ reply: SMTPReply) -> [SMTPAction] {
        switch state {
        case .greeting:
            guard reply.code == 220 else {
                return fail(
                    .smtpGreeting,
                    phase: .smtpSecuring,
                    retryDisposition: .retrySafe,
                    recoveryAction: .retryFailed,
                    providerStatus: reply.providerStatus
                )
            }
            state = setup.securityMode == .startTLS
                ? .ehloBeforeTLS
                : .ehloAfterTLS
            return [command("EHLO localhost")]

        case .ehloBeforeTLS:
            guard reply.code == 250 else {
                return fail(
                    .smtpEHLO,
                    phase: .smtpSecuring,
                    retryDisposition: .editSetup,
                    recoveryAction: .editSetup,
                    providerStatus: reply.providerStatus
                )
            }
            capabilities = parseCapabilities(reply)
            guard capabilities.contains("STARTTLS") else {
                return fail(
                    .smtpStartTLSUnavailable,
                    phase: .smtpSecuring,
                    retryDisposition: .editSetup,
                    recoveryAction: .editSetup
                )
            }
            state = .startTLS
            return [command("STARTTLS")]

        case .startTLS:
            guard reply.code == 220 else {
                return fail(
                    .smtpStartTLS,
                    phase: .smtpSecuring,
                    retryDisposition: .editSetup,
                    recoveryAction: .editSetup,
                    providerStatus: reply.providerStatus
                )
            }
            state = .ehloAfterTLS
            return [.upgradeTLS]

        case .ehloAfterTLS:
            guard reply.code == 250, isTLSActive else {
                return fail(
                    .smtpSecureEHLO,
                    phase: .smtpSecuring,
                    retryDisposition: .editSetup,
                    recoveryAction: .editSetup,
                    providerStatus: reply.providerStatus
                )
            }
            capabilities = parseCapabilities(reply)
            if capabilities.contains("AUTH PLAIN") || capabilities.contains("PLAIN") {
                state = .authPlain(challengeResponseSent: false)
                return [
                    command(
                        "AUTH PLAIN \(plainAuthenticationResponse())",
                        containsSecret: true
                    ),
                ]
            }
            if capabilities.contains("AUTH LOGIN") || capabilities.contains("LOGIN") {
                state = .authLoginUsername
                return [command("AUTH LOGIN")]
            }
            return fail(
                .smtpAuthenticationUnavailable,
                phase: .smtpAuthenticating,
                retryDisposition: .editSetup,
                recoveryAction: .editSetup
            )

        case .authPlain(let challengeResponseSent):
            if reply.code == 334, !challengeResponseSent {
                state = .authPlain(challengeResponseSent: true)
                return [
                    command(
                        plainAuthenticationResponse(),
                        containsSecret: true
                    ),
                ]
            }
            guard reply.code == 235 else {
                return authenticationFailure(reply)
            }
            state = .mailFrom
            return [command("MAIL FROM:<\(setup.senderAddress.value)>")]

        case .authLoginUsername:
            guard reply.code == 334 else {
                return authenticationFailure(reply)
            }
            state = .authLoginPassword
            return [
                command(
                    Data(setup.username.utf8).base64EncodedString(),
                    containsSecret: true
                ),
            ]

        case .authLoginPassword:
            guard reply.code == 334 else {
                return authenticationFailure(reply)
            }
            state = .authenticated
            return [
                command(
                    Data(credential.utf8).base64EncodedString(),
                    containsSecret: true
                ),
            ]

        case .authenticated:
            guard reply.code == 235 else {
                return authenticationFailure(reply)
            }
            state = .mailFrom
            return [command("MAIL FROM:<\(setup.senderAddress.value)>")]

        case .mailFrom:
            guard reply.code == 250 else {
                let transient = (400...499).contains(reply.code)
                return fail(
                    .smtpSenderRejected,
                    phase: .smtpSender,
                    retryDisposition: transient ? .retrySafe : .editSetup,
                    recoveryAction: transient ? .retryFailed : .editSetup,
                    providerStatus: reply.providerStatus
                )
            }
            state = .recipient
            return [command("RCPT TO:<\(setup.kindleAddress.value)>")]

        case .recipient:
            guard reply.code == 250 || reply.code == 251 else {
                let transient = (400...499).contains(reply.code)
                return fail(
                    .smtpRecipientRejected,
                    phase: .smtpRecipient,
                    retryDisposition: transient ? .retrySafe : .editSetup,
                    recoveryAction: transient ? .retryFailed : .editSetup,
                    providerStatus: reply.providerStatus
                )
            }
            state = .data
            return [command("DATA")]

        case .data:
            guard reply.code == 354 else {
                let transient = (400...499).contains(reply.code)
                return fail(
                    .smtpDataRejected,
                    phase: .smtpData,
                    retryDisposition: transient
                        ? .retrySafe
                        : .reviewBook,
                    recoveryAction: transient
                        ? .retryFailed
                        : .reviewBook,
                    providerStatus: reply.providerStatus
                )
            }
            state = .finalAcceptance
            return [.beginMessageData]

        case .finalAcceptance:
            guard reply.code == 250 else {
                let transient = (400...499).contains(reply.code)
                return fail(
                    .smtpFinalAcceptanceRejected,
                    phase: .smtpFinalAcceptance,
                    retryDisposition: transient
                        ? .retrySafe
                        : .reviewBook,
                    recoveryAction: transient
                        ? .retryFailed
                        : .reviewBook,
                    providerStatus: reply.providerStatus
                )
            }
            state = .completed
            return [command("QUIT"), .accepted]

        case .completed:
            return []
        }
    }

    mutating func didUpgradeTLS() -> [SMTPAction] {
        guard state == .ehloAfterTLS else {
            return fail(
                .smtpStartTLSState,
                phase: .smtpSecuring,
                retryDisposition: .notRetryable,
                recoveryAction: .editSetup
            )
        }
        isTLSActive = true
        capabilities.removeAll(keepingCapacity: true)
        return [command("EHLO localhost")]
    }

    private func parseCapabilities(_ reply: SMTPReply) -> Set<String> {
        var parsed = Set<String>()
        for line in reply.lines {
            let upper = line
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            if upper.hasPrefix("AUTH ") {
                let mechanisms = upper.dropFirst(5).split(separator: " ")
                for mechanism in mechanisms {
                    parsed.insert("AUTH \(mechanism)")
                    parsed.insert(String(mechanism))
                }
            } else if let first = upper.split(separator: " ").first {
                parsed.insert(String(first))
            }
        }
        return parsed
    }

    private func command(
        _ line: String,
        containsSecret: Bool = false
    ) -> SMTPAction {
        .write(line: "\(line)\r\n", containsSecret: containsSecret)
    }

    private func plainAuthenticationResponse() -> String {
        Data("\u{0}\(setup.username)\u{0}\(credential)".utf8)
            .base64EncodedString()
    }

    private mutating func authenticationFailure(
        _ reply: SMTPReply
    ) -> [SMTPAction] {
        let isCredentialRejection = [530, 534, 535].contains(reply.code)
        let isTransient = (400...499).contains(reply.code)
        return fail(
            .smtpAuthenticationRejected,
            phase: .smtpAuthenticating,
            retryDisposition: isCredentialRejection || !isTransient
                ? .editSetup
                : .retrySafe,
            recoveryAction: isCredentialRejection || !isTransient
                ? .editSetup
                : .retryFailed,
            providerStatus: reply.providerStatus
        )
    }

    private mutating func fail(
        _ code: DiagnosticCode,
        phase: DiagnosticPhase,
        retryDisposition: RetryDisposition,
        recoveryAction: RecoveryAction,
        providerStatus: ProviderStatus? = nil
    ) -> [SMTPAction] {
        state = .completed
        return [
            .failed(
                SanitizedFailure(
                    family: .delivery,
                    code: code,
                    message: "The SMTP delivery could not be completed.",
                    recoveryAction: recoveryAction,
                    evidence: DiagnosticEvidence(
                        phase: phase,
                        retryDisposition: retryDisposition,
                        providerStatus: providerStatus
                    )
                )
            ),
        ]
    }
}
