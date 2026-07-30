import Foundation

actor DiagnosticService {
    private struct EventKey: Hashable {
        let operationID: UUID?
        let action: FeedbackAction
        let outcome: DiagnosticOutcome
        let code: DiagnosticCode
        let phase: DiagnosticPhase
        let providerStatus: ProviderStatus?
        let retryDisposition: RetryDisposition
        let context: DiagnosticContext
    }

    private let recorder: any DiagnosticRecording
    private nonisolated let appVersion: String
    private var recordedKeys = Set<EventKey>()

    init(
        recorder: any DiagnosticRecording,
        appVersion: String
    ) {
        self.recorder = recorder
        self.appVersion = appVersion
    }

    nonisolated func makeEvent(
        id: UUID = UUID(),
        occurredAt: Date = Date(),
        action: FeedbackAction,
        outcome: DiagnosticOutcome,
        failure: SanitizedFailure,
        occurrenceCount: Int = 1
    ) -> DiagnosticEvent {
        let context = failure.evidence.context
        let versionedContext = DiagnosticContext(
            appVersion: context.appVersion ?? appVersion,
            operationID: context.operationID,
            setupRevision: context.setupRevision,
            batchTotal: context.batchTotal,
            batchCompleted: context.batchCompleted,
            transmissionStarted: context.transmissionStarted,
            safetyLimit: context.safetyLimit
        )
        let evidence = DiagnosticEvidence(
            phase: failure.evidence.phase,
            severity: failure.evidence.severity,
            retryDisposition: failure.evidence.retryDisposition,
            providerStatus: failure.evidence.providerStatus,
            context: versionedContext
        )
        let safeMessage = FailurePresentationService()
            .presentation(for: failure)
            .summary
        let versionedFailure = SanitizedFailure(
            family: failure.family,
            code: failure.code,
            message: safeMessage,
            recoveryAction: failure.recoveryAction,
            evidence: evidence
        )
        return DiagnosticEvent(
            id: id,
            occurredAt: occurredAt,
            action: action,
            outcome: outcome,
            failure: versionedFailure,
            occurrenceCount: occurrenceCount
        )
    }

    @discardableResult
    func recordOnce(_ event: DiagnosticEvent) async -> Bool {
        let evidence = event.failure.evidence
        let key = EventKey(
            operationID: evidence.context.operationID,
            action: event.action,
            outcome: event.outcome,
            code: event.failure.code,
            phase: evidence.phase,
            providerStatus: evidence.providerStatus,
            retryDisposition: evidence.retryDisposition,
            context: evidence.context
        )
        guard recordedKeys.insert(key).inserted else { return false }
        await recorder.record(event)
        return true
    }
}
