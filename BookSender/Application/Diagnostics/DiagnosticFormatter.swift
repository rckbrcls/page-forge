import Foundation

struct DiagnosticFormatter: Sendable {
    func format(_ event: DiagnosticEvent) -> DiagnosticCopy {
        let failure = event.failure
        let evidence = failure.evidence
        let context = evidence.context
        let presentation = FailurePresentationService()
            .presentation(for: failure)
        var lines: [String] = [
            "Book Sender \(context.appVersion ?? "Unknown version")",
            "Time: \(timestamp(event.occurredAt))",
            "Event: \(event.id.uuidString)",
        ]
        if let operationID = context.operationID {
            lines.append("Operation: \(operationID.uuidString)")
        }
        lines.append("Action: \(actionTitle(event.action))")
        lines.append("Outcome: \(outcomeTitle(event.outcome))")
        lines.append("Code: \(failure.code.rawValue)")
        lines.append("Subsystem: \(familyTitle(failure.family))")
        lines.append("Phase: \(phaseTitle(evidence.phase))")
        lines.append("Severity: \(severityTitle(evidence.severity))")
        lines.append("Retry: \(retryTitle(evidence.retryDisposition))")
        if let providerStatus = evidence.providerStatus {
            let enhanced = providerStatus.enhancedStatus.map {
                " \($0.description)"
            } ?? ""
            lines.append(
                "Provider status: \(providerStatus.replyCode)\(enhanced)"
            )
        }
        if let setupRevision = context.setupRevision {
            lines.append("Setup revision: \(setupRevision)")
        }
        if let completed = context.batchCompleted,
           let total = context.batchTotal {
            lines.append("Batch: \(completed) of \(total)")
        }
        if let transmissionStarted = context.transmissionStarted {
            lines.append(
                "Transmission started: \(transmissionStarted ? "Yes" : "No")"
            )
        }
        if let safetyLimit = context.safetyLimit {
            lines.append("Safety limit: \(safetyLimit.rawValue)")
        }
        lines.append("Occurrence count: \(event.occurrenceCount)")
        if let nextStep = presentation.actionTitle {
            lines.append("Next step: \(nextStep)")
        }
        return DiagnosticCopy(text: lines.joined(separator: "\n"))
    }

    private func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds,
        ]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    private func actionTitle(_ action: FeedbackAction) -> String {
        switch action {
        case .restoreApplication: "Restore application"
        case .saveDeliverySetup: "Save delivery setup"
        case .deleteDeliverySetup: "Delete delivery setup"
        case .saveShortcut: "Save shortcut"
        case .clearShortcut: "Clear shortcut"
        case .addBooks: "Add books"
        case .removeBook: "Remove book"
        case .clearBatch: "Clear batch"
        case .startAnotherSend: "Start another send"
        case .confirmBatch: "Confirm batch"
        case .prepareBook: "Prepare book"
        case .sendBook: "Send book"
        case .sendBatch: "Send batch"
        case .cancelOperation: "Cancel operation"
        case .dismissConfirmation: "Dismiss confirmation"
        case .copyErrorDetails: "Copy error details"
        case .checkForUpdates: "Check for updates"
        case .loadHistory: "Load send history"
        case .recordHistory: "Record submission"
        case .clearHistory: "Clear send history"
        }
    }

    private func outcomeTitle(_ outcome: DiagnosticOutcome) -> String {
        switch outcome {
        case .failed: "Failed"
        case .uncertain: "Uncertain"
        }
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

    private func severityTitle(_ severity: DiagnosticSeverity) -> String {
        switch severity {
        case .info: "Info"
        case .warning: "Warning"
        case .error: "Error"
        case .critical: "Critical"
        }
    }

    private func retryTitle(_ disposition: RetryDisposition) -> String {
        switch disposition {
        case .notRetryable: "Not retryable"
        case .editSetup: "Edit setup"
        case .retrySafe: "Retry safe"
        case .checkBeforeRetry: "Check before retry"
        case .chooseAnotherFile: "Choose another file"
        case .reviewBook: "Review book"
        case .restartApplication: "Restart application"
        }
    }
}
