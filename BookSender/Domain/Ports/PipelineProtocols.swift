import Foundation

protocol EPUBAuditing: Sendable {
    func audit(_ archive: any EPUBArchiveReading) async throws -> AuditReport
}

protocol RepairPlanning: Sendable {
    func plan(for report: AuditReport) -> PreparationPlan
}

protocol ReportComparing: Sendable {
    func compare(original: AuditReport, prepared: AuditReport, applied: [AppliedRepairAction]) -> RevalidationComparison
}

protocol EPUBPreparing: Sendable {
    func prepare(
        source: StagedFileReference,
        workspace: WorkspaceReference,
        archive: any EPUBArchiveReading
    ) async throws -> PreparedBook
}
