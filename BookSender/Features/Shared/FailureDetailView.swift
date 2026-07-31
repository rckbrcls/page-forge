import Foundation
import SwiftUI

struct FailureDetailView: View {
    let presentation: FailurePresentation
    let diagnosticEvent: DiagnosticEvent?
    let copyErrorDetails: () -> Void
    var performRecovery: ((RecoveryAction) -> Void)?

    @State private var isExpanded = false
    @FocusState private var isRecoveryFocused: Bool

    init(
        presentation: FailurePresentation,
        diagnosticEvent: DiagnosticEvent?,
        copyErrorDetails: @escaping () -> Void,
        performRecovery: ((RecoveryAction) -> Void)? = nil
    ) {
        self.presentation = presentation
        self.diagnosticEvent = diagnosticEvent
        self.copyErrorDetails = copyErrorDetails
        self.performRecovery = performRecovery
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                isExpanded.toggle()
            } label: {
                Label(
                    isExpanded ? "Hide Error Details" : "Show Error Details",
                    systemImage: "chevron.right"
                )
                .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.plain)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            .accessibilityHint(
                "Shows the safe diagnostic code, phase, impact, and next step."
            )
            .accessibilityIdentifier("failure.details.toggle")

            if isExpanded {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    detailRow("Summary", presentation.summary)
                    if let explanation = presentation.explanation {
                        detailRow("Cause", explanation)
                    }
                    detailRow("Impact", presentation.impact)
                    detailRow("Code", presentation.code.rawValue)
                    detailRow("Subsystem", familyTitle(presentation.family))
                    detailRow("Phase", phaseTitle(presentation.phase))
                    detailRow(
                        "Retry",
                        retryTitle(presentation.retryDisposition)
                    )
                    if let providerStatus = presentation.providerStatus {
                        detailRow(
                            "Provider status",
                            providerStatusTitle(providerStatus)
                        )
                    }
                    if let event = matchingEvent {
                        detailRow("Session reference", event.id.uuidString)
                        safeContextRows(event.failure.evidence.context)
                    }
                }
                .font(.caption)
                .textSelection(.enabled)
                .accessibilityIdentifier("failure.details.content")

                HStack(spacing: 12) {
                    if presentation.copyAvailable, matchingEvent != nil {
                        Button("Copy Error Details", action: copyErrorDetails)
                            .accessibilityHint(
                                "Copies only the sanitized current diagnostic."
                            )
                            .accessibilityIdentifier("failure.copy")
                    }
                    if let title = presentation.actionTitle,
                       let action = presentation.action,
                       let performRecovery {
                        Button(title) {
                            performRecovery(action)
                        }
                        .focused($isRecoveryFocused)
                        .accessibilityHint(recoveryHint(action))
                        .accessibilityIdentifier("failure.recovery")
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var matchingEvent: DiagnosticEvent? {
        guard diagnosticEvent?.failure.code == presentation.code else {
            return nil
        }
        return diagnosticEvent
    }

    @ViewBuilder
    private func detailRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
        }
    }

    @ViewBuilder
    private func safeContextRows(_ context: DiagnosticContext) -> some View {
        if let appVersion = context.appVersion {
            detailRow("App version", appVersion)
        }
        if let operationID = context.operationID {
            detailRow("Operation", operationID.uuidString)
        }
        if let setupRevision = context.setupRevision {
            detailRow("Setup revision", "\(setupRevision)")
        }
        if let batchCompleted = context.batchCompleted,
           let batchTotal = context.batchTotal {
            detailRow("Batch progress", "\(batchCompleted) of \(batchTotal)")
        }
        if let transmissionStarted = context.transmissionStarted {
            detailRow(
                "Transmission started",
                transmissionStarted ? "Yes" : "No"
            )
        }
        if let safetyLimit = context.safetyLimit {
            detailRow("Safety limit", safetyLimit.rawValue)
        }
    }

    private func providerStatusTitle(_ status: ProviderStatus) -> String {
        [
            "\(status.replyCode)",
            status.enhancedStatus?.description,
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }

    private func familyTitle(_ family: FailureFamily) -> String {
        switch family {
        case .intake: "Intake"
        case .archive: "Archive"
        case .xml: "XML"
        case .audit: "Audit"
        case .repair: "Repair"
        case .filesystem: "Filesystem"
        case .credential: "Credential"
        case .delivery: "Delivery"
        case .shortcut: "Shortcut"
        }
    }

    private func phaseTitle(_ phase: DiagnosticPhase) -> String {
        switch phase {
        case .bootstrap: "Bootstrap"
        case .preferenceRead: "Reading preferences"
        case .preferenceWrite: "Writing preferences"
        case .credentialRead: "Reading credential"
        case .credentialWrite: "Writing credential"
        case .credentialDelete: "Deleting credential"
        case .inputValidation: "Input validation"
        case .intake: "Intake"
        case .workspaceStaging: "Workspace staging"
        case .archiveSafety: "Archive safety"
        case .xmlParsing: "XML parsing"
        case .structuralAudit: "Structural audit"
        case .repairPlanning: "Repair planning"
        case .workingCopyWrite: "Working copy write"
        case .revalidation: "Revalidation"
        case .shortcutRegistration: "Shortcut registration"
        case .updateCheck: "Update check"
        case .smtpConnecting: "Connecting"
        case .smtpSecuring: "Securing"
        case .smtpAuthenticating: "Authenticating"
        case .smtpSender: "Sender envelope"
        case .smtpRecipient: "Recipient envelope"
        case .smtpData: "Message data"
        case .smtpFinalAcceptance: "Final acceptance"
        case .clipboardWrite: "Clipboard write"
        case .historyLoad: "History load"
        case .historyRecord: "History record"
        case .historyClear: "History clear"
        case .cleanup: "Cleanup"
        }
    }

    private func retryTitle(_ disposition: RetryDisposition) -> String {
        switch disposition {
        case .notRetryable: "Not automatically retryable"
        case .editSetup: "Edit setup before retrying"
        case .retrySafe: "Retry is safe"
        case .checkBeforeRetry: "Check the destination before retrying"
        case .chooseAnotherFile: "Choose another file"
        case .reviewBook: "Review the book"
        case .restartApplication: "Restart Book Sender"
        }
    }

    private func recoveryHint(_ action: RecoveryAction) -> String {
        switch action {
        case .editSetup: "Opens the saved delivery settings."
        case .chooseAnotherFile: "Returns to book selection."
        case .reviewBook: "Keeps these details open for review."
        case .retryFailed: "Retries only conclusively failed books."
        case .confirmUnknownRetry:
            "Check Kindle first because this delivery may have succeeded."
        case .chooseAnotherShortcut: "Moves focus to the shortcut recorder."
        case .retryHistoryLoad: "Retries loading the local send history."
        case .retryHistoryClear: "Retries clearing the local send history."
        }
    }
}
