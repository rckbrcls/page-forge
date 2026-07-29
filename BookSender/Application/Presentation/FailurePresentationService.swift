import Foundation

struct FailurePresentation: Equatable, Sendable {
    let title: String
    let message: String
    let actionTitle: String?
    let action: RecoveryAction?
}

struct FailurePresentationService: Sendable {
    func presentation(for failure: SanitizedFailure) -> FailurePresentation {
        let title: String
        switch failure.family {
        case .credential, .delivery: title = "Delivery problem"
        case .intake: title = "File not added"
        case .archive, .xml, .audit, .repair: title = "Book needs attention"
        case .filesystem: title = "File access problem"
        }
        let actionTitle: String? = switch failure.recoveryAction {
        case .editSetup: "Edit Setup"
        case .chooseAnotherFile: "Choose Another File"
        case .reviewBook: "Review Details"
        case .retryFailed: "Retry Failed"
        case .confirmUnknownRetry: "Review Delivery"
        case nil: nil
        }
        return FailurePresentation(
            title: title,
            message: failure.message,
            actionTitle: actionTitle,
            action: failure.recoveryAction
        )
    }
}
