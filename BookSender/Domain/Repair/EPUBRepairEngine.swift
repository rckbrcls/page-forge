import Foundation

struct EPUBRepairEngine: RepairPlanning, ReportComparing {
    private let writer: any EPUBArchiveWriting
    private let workspaceStore: any WorkspaceStoring
    private let auditor: EPUBAuditEngine

    init(
        writer: any EPUBArchiveWriting,
        workspaceStore: any WorkspaceStoring,
        auditor: EPUBAuditEngine = EPUBAuditEngine()
    ) {
        self.writer = writer
        self.workspaceStore = workspaceStore
        self.auditor = auditor
    }

    func plan(for report: AuditReport) -> PreparationPlan {
        guard report.health != .unsafe,
              report.health != .needsReview,
              report.health != .unsupported
        else {
            return PreparationPlan(
                id: UUID(),
                originalAuditIdentifier: report.id,
                actions: [],
                decision: .blocked
            )
        }

        let actions = report.findings.compactMap { finding -> RepairAction? in
            guard case .automatic(let ruleID) = finding.repairability else { return nil }
            switch ruleID {
            case "repair.mimetype":
                return .rebuildMimetype
            case "repair.container":
                guard let package = finding.evidence["package"] else { return nil }
                return .restoreContainer(packagePath: package)
            default:
                return nil
            }
        }
        return PreparationPlan(
            id: UUID(),
            originalAuditIdentifier: report.id,
            actions: actions,
            decision: actions.isEmpty ? .useOriginalSnapshot : .writeWorkingCopy
        )
    }

    func compare(
        original: AuditReport,
        prepared: AuditReport,
        applied: [AppliedRepairAction]
    ) -> RevalidationComparison {
        let originalCodes = Set(original.findings.map(\.code))
        let preparedCodes = Set(prepared.findings.map(\.code))
        let introduced = preparedCodes.subtracting(originalCodes)
        let hasCriticalRegression = prepared.findings.contains {
            introduced.contains($0.code) && $0.severity == .critical
        }
        let allVerified = applied.allSatisfy(\.verified)
        return RevalidationComparison(
            originalReportID: original.id,
            preparedReportID: prepared.id,
            resolvedFindingCodes: originalCodes.subtracting(preparedCodes),
            retainedFindingCodes: originalCodes.intersection(preparedCodes),
            introducedFindingCodes: introduced,
            verifiedActionIDs: Set(applied.filter(\.verified).map(\.id)),
            readiness: !hasCriticalRegression && allVerified && prepared.health == .healthy ? .ready : .blocked
        )
    }

    func prepare(
        source: StagedFileReference,
        workspace: WorkspaceReference,
        displayName: String
    ) async throws -> PreparedBook {
        let originalArchive = ZIPFoundationEPUBArchive(source: source)
        let original = try await auditor.audit(originalArchive, source: source)
        let plan = plan(for: original)
        guard plan.decision != .blocked else {
            throw SanitizedFailure(
                family: .repair,
                code: "repair.blocked",
                message: "This EPUB needs attention before it can be sent.",
                recoveryAction: .reviewBook
            )
        }

        if plan.decision == .useOriginalSnapshot {
            return PreparedBook(
                id: UUID(),
                batchItemID: workspace.itemID,
                file: source,
                originalDisplayName: displayName,
                format: .epub,
                byteCount: fileSize(source.url),
                contentDigest: "",
                comparison: nil
            )
        }

        let partial = try await writer.write(source: source, plan: plan, workspace: workspace)
        let preparedArchive = ZIPFoundationEPUBArchive(source: partial)
        let preparedReport = try await auditor.audit(preparedArchive, source: partial)
        let applied = plan.actions.map {
            AppliedRepairAction(id: UUID(), action: $0, verified: true)
        }
        let comparison = compare(original: original, prepared: preparedReport, applied: applied)
        guard comparison.readiness == .ready else {
            throw SanitizedFailure(
                family: .repair,
                code: "repair.revalidation-failed",
                message: "The prepared EPUB did not pass revalidation.",
                recoveryAction: .reviewBook
            )
        }
        let promoted = try await workspaceStore.promotePartial(
            partial.url.lastPathComponent,
            to: "prepared.epub",
            in: workspace
        )
        return PreparedBook(
            id: UUID(),
            batchItemID: workspace.itemID,
            file: promoted,
            originalDisplayName: displayName,
            format: .epub,
            byteCount: fileSize(promoted.url),
            contentDigest: "",
            comparison: comparison
        )
    }

    private func fileSize(_ url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }
}
