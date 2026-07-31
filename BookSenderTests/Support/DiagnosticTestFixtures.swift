import Foundation
@testable import BookSender

enum DiagnosticTestFixtures {
    static let password = "canary-app-password-7T!z"
    static let senderAddress = "private.sender@example.test"
    static let recipientAddress = "private.reader@kindle.test"
    static let smtpHost = "smtp.private.example.test"
    static let sourcePath = "/Users/private/Documents/Secret Book.epub"
    static let filename = "Secret Book.epub"
    static let bookExcerpt = "CANARY_BOOK_CONTENT_DO_NOT_EXPOSE"
    static let messageBytes = "CANARY_MIME_MESSAGE_DO_NOT_EXPOSE"
    static let providerProse =
        "Authentication failed for private.sender@example.test"
    static let providerReply = "535 5.7.8 \(providerProse)"
    static let rawError = "CANARY_RAW_PLATFORM_ERROR_DO_NOT_EXPOSE"

    static let forbiddenValues = [
        password,
        senderAddress,
        recipientAddress,
        smtpHost,
        sourcePath,
        filename,
        bookExcerpt,
        messageBytes,
        providerProse,
        providerReply,
        rawError,
    ]

    static let safeAppVersion = "0.0-test"
    static let safeOperationID = UUID(
        uuidString: "00000000-0000-4000-8000-000000000008"
    )!
    static let safeEventID = UUID(
        uuidString: "00000000-0000-4000-8000-000000000009"
    )!
    static let safeTimestamp = Date(timeIntervalSince1970: 1_754_000_000)
    static let authenticationRejections: [(Int, String)] = [
        (530, "5.7.0"),
        (534, "5.7.9"),
        (535, "5.7.8"),
    ]
    static let envelopeRejections: [(Int, String)] = [
        (450, "4.2.0"),
        (550, "5.1.1"),
    ]

    static func safeFailure(
        code: DiagnosticCode = .smtpAuthenticationRejected,
        phase: DiagnosticPhase = .smtpAuthenticating
    ) -> SanitizedFailure {
        SanitizedFailure(
            family: .delivery,
            code: code,
            message: "Authentication was rejected.",
            recoveryAction: .editSetup,
            evidence: DiagnosticEvidence(
                phase: phase,
                retryDisposition: .editSetup,
                providerStatus: ProviderStatus(
                    replyCode: 535,
                    enhancedStatus: EnhancedStatusCode(parsing: "5.7.8")
                ),
                context: DiagnosticContext(
                    appVersion: safeAppVersion,
                    operationID: safeOperationID,
                    setupRevision: 2,
                    batchTotal: 3,
                    batchCompleted: 1,
                    transmissionStarted: false
                )
            )
        )
    }

    static func safeEvent(
        outcome: DiagnosticOutcome = .failed
    ) -> DiagnosticEvent {
        DiagnosticEvent(
            id: safeEventID,
            occurredAt: safeTimestamp,
            action: .sendBook,
            outcome: outcome,
            failure: safeFailure(),
            occurrenceCount: 2
        )
    }
}
