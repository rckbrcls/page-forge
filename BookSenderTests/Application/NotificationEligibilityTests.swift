import Testing
@testable import BookSender

struct NotificationEligibilityTests {
    @Test
    func catalogueClassifiesEveryFeedbackActionExactlyOnce() {
        #expect(catalogue.count == FeedbackAction.allCases.count)
        #expect(Set(catalogue.map(\.action)) == Set(FeedbackAction.allCases))
        #expect(Set(catalogue.map(\.action)).count == catalogue.count)

        let currentProducers = catalogue.filter { !$0.reasons.isEmpty }
        #expect(
            Set(currentProducers.map(\.action)) == Set([
                .saveDeliverySetup,
                .deleteDeliverySetup,
                .copyErrorDetails,
                .recordHistory,
            ])
        )
        #expect(
            catalogue.filter { $0.classification == .notApplicable }.map(\.action)
                == [.prepareBook, .sendBook]
        )
        #expect(catalogue.allSatisfy { !$0.rationale.isEmpty })
    }

    @Test
    func publicationIntentDefaultsToContextualAndRequiresTerminalState() {
        let contextual = NotificationPublicationIntent.contextual
        let floating = NotificationPublicationIntent.floating(.clipboardWrite)

        for state in FeedbackState.allCases {
            #expect(contextual.approvedReason(for: state) == nil)
            if state.isTerminal {
                #expect(floating.approvedReason(for: state) == .clipboardWrite)
            } else {
                #expect(floating.approvedReason(for: state) == nil)
            }
        }
    }

    @Test
    func reservedReasonsHaveNoCurrentProductionProducer() {
        let currentReasons = Set(catalogue.flatMap(\.reasons))

        #expect(!currentReasons.contains(.consequentialHiddenFailure))
        #expect(!currentReasons.contains(.auxiliarySystemActionFailure))
        #expect(Set(NotificationReason.allCases).count == 6)
    }

    @Test
    func publicationPolicyValuesAreSendable() {
        requireSendable(NotificationPublicationIntent.self)
        requireSendable(NotificationReason.self)
    }

    private func requireSendable<T: Sendable>(_: T.Type) {}
}

private enum ExpectedNotificationClassification: Equatable, Sendable {
    case contextual
    case mixed
    case notify
    case notApplicable
}

private struct ExpectedNotificationDecision: Sendable {
    let action: FeedbackAction
    let classification: ExpectedNotificationClassification
    let reasons: [NotificationReason]
    let rationale: String
}

private let catalogue: [ExpectedNotificationDecision] = [
    .init(action: .restoreApplication, classification: .contextual, reasons: [], rationale: "The visible route and screen communicate restoration."),
    .init(action: .saveDeliverySetup, classification: .mixed, reasons: [.protectedCredentialPersistence], rationale: "Only successful protected persistence is invisible."),
    .init(action: .deleteDeliverySetup, classification: .notify, reasons: [.protectedCredentialDeletion], rationale: "The Keychain deletion result is invisible."),
    .init(action: .saveShortcut, classification: .contextual, reasons: [], rationale: "The recorder, switch, and registration state remain visible."),
    .init(action: .clearShortcut, classification: .contextual, reasons: [], rationale: "The switch and registration state communicate the result."),
    .init(action: .addBooks, classification: .contextual, reasons: [], rationale: "The drop target, rows, and aggregate state communicate intake."),
    .init(action: .removeBook, classification: .contextual, reasons: [], rationale: "The row visibly disappears."),
    .init(action: .clearBatch, classification: .contextual, reasons: [], rationale: "The list and primary action visibly reset."),
    .init(action: .startAnotherSend, classification: .contextual, reasons: [], rationale: "The completed list visibly resets."),
    .init(action: .confirmBatch, classification: .contextual, reasons: [], rationale: "The confirmation sheet is the result."),
    .init(action: .prepareBook, classification: .notApplicable, reasons: [], rationale: "Per-book preparation state owns this result."),
    .init(action: .sendBook, classification: .notApplicable, reasons: [], rationale: "Per-book delivery state owns this result."),
    .init(action: .sendBatch, classification: .contextual, reasons: [], rationale: "Rows and aggregate delivery state remain durable."),
    .init(action: .cancelOperation, classification: .contextual, reasons: [], rationale: "Batch phase and row outcomes communicate cancellation."),
    .init(action: .dismissConfirmation, classification: .contextual, reasons: [], rationale: "Modal dismissal is immediately visible."),
    .init(action: .copyErrorDetails, classification: .notify, reasons: [.clipboardWrite], rationale: "Clipboard mutation is otherwise invisible."),
    .init(action: .checkForUpdates, classification: .contextual, reasons: [], rationale: "The standard update interface is visible when it opens."),
    .init(action: .loadHistory, classification: .contextual, reasons: [], rationale: "Loading, unavailable, empty, and list states remain visible."),
    .init(action: .recordHistory, classification: .notify, reasons: [.submissionHistoryPersistence], rationale: "Only failure after accepted SMTP delivery is hidden."),
    .init(action: .clearHistory, classification: .contextual, reasons: [], rationale: "The alert, list, count, and empty state communicate clearing."),
]
