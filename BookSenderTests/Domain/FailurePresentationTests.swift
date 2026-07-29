import Testing
@testable import BookSender

struct FailurePresentationTests {
    @Test(arguments: FailureFamily.allCasesForTesting)
    func neverPresentsRawErrorMaterial(family: FailureFamily) {
        let rawSecret = "provider-password"
        let failure = SanitizedFailure(
            family: family,
            code: "\(family.rawValue).safe",
            message: "The operation could not continue.",
            recoveryAction: .retryFailed
        )
        let presentation = FailurePresentationService().presentation(for: failure)
        #expect(presentation.message.contains(rawSecret) == false)
        #expect(presentation.action == .retryFailed)
    }
}

private extension FailureFamily {
    static let allCasesForTesting: [FailureFamily] = [
        .intake, .archive, .xml, .audit, .repair, .filesystem, .credential,
        .delivery, .shortcut,
    ]
}
