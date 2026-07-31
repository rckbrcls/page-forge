import Testing
@testable import BookSender

struct FailurePresentationTests {
    @Test(arguments: DiagnosticCode.allCases)
    func catalogCoversEveryStableCode(code: DiagnosticCode) {
        let family = code.expectedFamily
        let failure = SanitizedFailure(
            family: family,
            code: code,
            message: "Generic adapter fallback must not become catalog copy.",
            recoveryAction: recovery(for: code)
        )

        let presentation = FailurePresentationService().presentation(for: failure)

        #expect(!presentation.title.isEmpty)
        #expect(!presentation.summary.isEmpty)
        #expect(!presentation.impact.isEmpty)
        #expect(presentation.explanation?.isEmpty == false)
        #expect(presentation.code == code)
        #expect(presentation.family == family)
        #expect(presentation.summary.contains("Generic adapter fallback") == false)
        #expect(
            presentation.summary.localizedCaseInsensitiveContains("problem")
                == false
        )
        #expect(
            presentation.summary.localizedCaseInsensitiveContains(
                "could not continue"
            ) == false
        )
    }

    @Test(arguments: FailureFamily.allCases)
    func neverPresentsRawErrorMaterial(family: FailureFamily) {
        let rawSecret = "provider-password"
        let failure = SanitizedFailure(
            family: family,
            code: DiagnosticCode.unexpected(for: family),
            message: "The operation could not continue.",
            recoveryAction: .retryFailed
        )
        let presentation = FailurePresentationService().presentation(for: failure)
        #expect(presentation.message.contains(rawSecret) == false)
    }

    @Test
    func preservesSafeProviderStatusAndPhaseWithoutProviderProse() {
        let failure = SanitizedFailure(
            family: .delivery,
            code: .smtpAuthenticationRejected,
            message: "PRIVATE PROVIDER PROSE",
            recoveryAction: .editSetup,
            evidence: DiagnosticEvidence(
                phase: .smtpAuthenticating,
                retryDisposition: .editSetup,
                providerStatus: ProviderStatus(
                    replyCode: 535,
                    enhancedStatus: EnhancedStatusCode(parsing: "5.7.8")
                )
            )
        )
        let presentation = FailurePresentationService().presentation(for: failure)

        #expect(presentation.phase == .smtpAuthenticating)
        #expect(presentation.providerStatus?.replyCode == 535)
        #expect(presentation.summary.contains("PRIVATE PROVIDER PROSE") == false)
        #expect(presentation.actionTitle == "Edit Setup")
    }

    @Test
    func historyFailuresKeepSubmissionTruthAndUseSafeRecovery() {
        let failure = SanitizedFailure(
            family: .filesystem,
            code: .historyWrite,
            message: "/private/path/history-v1.json provider-secret",
            recoveryAction: nil,
            evidence: DiagnosticEvidence(
                phase: .historyRecord,
                retryDisposition: .notRetryable
            )
        )

        let presentation = FailurePresentationService().presentation(for: failure)

        #expect(presentation.title == "Submission was sent but not recorded")
        #expect(presentation.summary.contains("/private/path") == false)
        #expect(presentation.summary.contains("provider-secret") == false)
        #expect(presentation.action == nil)
        #expect(presentation.phase == .historyRecord)
    }

    private func recovery(for code: DiagnosticCode) -> RecoveryAction? {
        switch code.expectedFamily {
        case .intake: .chooseAnotherFile
        case .archive, .xml, .audit, .repair, .filesystem: .reviewBook
        case .credential, .delivery: .editSetup
        case .shortcut: .chooseAnotherShortcut
        }
    }
}
