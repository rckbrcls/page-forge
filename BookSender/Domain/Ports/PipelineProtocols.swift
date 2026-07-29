import Foundation

protocol EPUBAuditing: Sendable {
    func audit(
        _ archive: any EPUBArchiveReading,
        source: StagedFileReference
    ) async throws -> AuditReport
}

protocol RepairPlanning: Sendable {
    func plan(for report: AuditReport) -> PreparationPlan
}

protocol ReportComparing: Sendable {
    func compare(
        original: AuditReport,
        prepared: AuditReport,
        applied: [AppliedRepairAction]
    ) -> RevalidationComparison
}

protocol EPUBPreparing: Sendable {
    func prepare(
        source: StagedFileReference,
        workspace: WorkspaceReference,
        displayName: String
    ) async -> PreparationResult
}

protocol PDFEligibilityChecking: Sendable {
    func prepare(
        itemID: UUID,
        source: StagedFileReference,
        displayName: String
    ) async -> PreparationResult
}

protocol BatchPipelining: Actor {
    nonisolated var events: AsyncStream<PipelineEvent> { get }

    func snapshot() -> CurrentBatch
    func add(_ urls: [URL])
    func remove(_ itemID: UUID) async
    func clear() async
    func confirmation(
        setup: ValidatedDeliverySetup,
        kind: ConfirmedBatchKind
    ) -> ConfirmedBatchSummary?
    func releaseConfirmation(_ snapshotID: UUID)
    func send(snapshotID: UUID)
    func cancel() async
}
