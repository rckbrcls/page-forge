import Foundation
import Testing
@testable import BookSender

struct DiagnosticModelsTests {
    @Test
    func stableCodesAreUniqueAndStructured() {
        let values = DiagnosticCode.allCases.map(\.rawValue)
        #expect(Set(values).count == values.count)
        #expect(
            values.allSatisfy {
                $0.first?.isLetter == true
                    && $0.contains(".")
                    && $0.contains(" ") == false
            }
        )
    }

    @Test(arguments: FailureFamily.allCases)
    func unexpectedCodesRetainTheirOwningFamily(family: FailureFamily) {
        #expect(
            DiagnosticCode.unexpected(for: family).expectedFamily == family
        )
    }

    @Test(arguments: [
        ("5.7.8", 5, 7, 8),
        ("4.2.0", 4, 2, 0),
        ("2.0.0", 2, 0, 0),
    ])
    func parsesEnhancedStatus(
        value: String,
        expectedClass: Int,
        expectedSubject: Int,
        expectedDetail: Int
    ) {
        let status = EnhancedStatusCode(parsing: value)
        #expect(status?.statusClass == expectedClass)
        #expect(status?.subject == expectedSubject)
        #expect(status?.detail == expectedDetail)
        #expect(status?.description == value)
    }

    @Test(arguments: ["3.0.0", "5.1000.1", "5.7", "5.7.x", ""])
    func rejectsInvalidEnhancedStatus(value: String) {
        #expect(EnhancedStatusCode(parsing: value) == nil)
    }

    @Test(arguments: [199, 600, -1])
    func rejectsInvalidProviderReplyCode(value: Int) {
        #expect(ProviderStatus(replyCode: value) == nil)
    }

    @Test
    func validatesBoundedContext() {
        #expect(DiagnosticContext(batchTotal: 2, batchCompleted: 1).isValid)
        #expect(!DiagnosticContext(batchTotal: 1, batchCompleted: 2).isValid)
        #expect(!DiagnosticContext(setupRevision: -1).isValid)
    }

    @Test
    func infersAuthenticationRecoveryWithoutProviderText() {
        let failure = SanitizedFailure(
            family: .delivery,
            code: .smtpAuthenticationRejected,
            message: "Authentication was rejected.",
            recoveryAction: .editSetup
        )
        #expect(failure.evidence.phase == .smtpAuthenticating)
        #expect(failure.evidence.retryDisposition == .editSetup)
        #expect(failure.evidence.providerStatus == nil)
    }

    @Test
    func infersSafeLimitAndUncertainRetryEvidence() {
        let limited = SanitizedFailure(
            family: .archive,
            code: .archiveEntryLimit,
            message: "The archive entry exceeded its limit.",
            recoveryAction: .reviewBook
        )
        let unknown = SanitizedFailure.deliveryUnknown()

        #expect(limited.evidence.phase == .archiveSafety)
        #expect(
            limited.evidence.context.safetyLimit == .archiveEntries
        )
        #expect(unknown.evidence.phase == .smtpFinalAcceptance)
        #expect(
            unknown.evidence.retryDisposition == .checkBeforeRetry
        )
        #expect(
            unknown.evidence.context.transmissionStarted == true
        )
    }

    @Test
    func diagnosticEventsSupportStableHashIdentity() {
        let event = DiagnosticTestFixtures.safeEvent()

        #expect(Set([event, event]).count == 1)
    }
}
