import Foundation
import Testing
@testable import BookSender

struct EPUBRepairEngineTests {
    @Test
    func plansOnlySupportedAutomaticActionsInStableOrder() {
        let report = AuditReport(
            id: UUID(),
            findings: [
                finding(.mimetypeNotFirst, rule: "repair.mimetype"),
                finding(
                    .containerMissing,
                    rule: "repair.container",
                    evidence: ["package": "OEBPS/content.opf"]
                ),
                finding(.mimetypeCompressed, rule: "repair.mimetype"),
            ],
            inspectedAt: Date()
        )
        let engine = EPUBRepairEngine(
            writer: FailingArchiveWriter(
                failure: sanitizedFailure("unused", family: .repair)
            ),
            workspaceStore: WorkspaceStore()
        )

        let plan = engine.plan(for: report)

        #expect(
            plan.actions == [
                .rebuildMimetype,
                .restoreContainer(packagePath: "OEBPS/content.opf"),
            ]
        )
        #expect(
            plan.expectedPostconditions
                == [.mimetypeNotFirst, .containerMissing, .mimetypeCompressed]
        )
    }

    @Test
    func blocksAmbiguousOrUnsupportedAutomaticEvidence() {
        let report = AuditReport(
            id: UUID(),
            findings: [
                finding(.referenceAmbiguous, rule: "repair.reference"),
            ],
            inspectedAt: Date()
        )
        let engine = EPUBRepairEngine(
            writer: FailingArchiveWriter(
                failure: sanitizedFailure("unused", family: .repair)
            ),
            workspaceStore: WorkspaceStore()
        )

        #expect(engine.plan(for: report).decision == .blocked)
    }

    @Test
    func comparisonRejectsIntroducedCriticalFinding() {
        let original = AuditReport(
            id: UUID(),
            findings: [finding(.mimetypeInvalid, rule: "repair.mimetype")],
            inspectedAt: Date()
        )
        let prepared = AuditReport(
            id: UUID(),
            findings: [
                HealthFinding(
                    id: UUID(),
                    code: .remoteReference,
                    severity: .critical,
                    location: nil,
                    messageKey: "remote",
                    repairability: .forbidden,
                    evidence: [:]
                ),
            ],
            inspectedAt: Date()
        )
        let engine = EPUBRepairEngine(
            writer: FailingArchiveWriter(
                failure: sanitizedFailure("unused", family: .repair)
            ),
            workspaceStore: WorkspaceStore()
        )

        let comparison = engine.compare(
            original: original,
            prepared: prepared,
            applied: [
                AppliedRepairAction(
                    id: UUID(),
                    action: .rebuildMimetype,
                    verified: true
                ),
            ]
        )

        #expect(comparison.readiness == .blocked)
        #expect(comparison.introducedFindingCodes == [.remoteReference])
    }

    private func finding(
        _ code: FindingCode,
        rule: String,
        evidence: [String: String] = [:]
    ) -> HealthFinding {
        HealthFinding(
            id: UUID(),
            code: code,
            severity: .error,
            location: nil,
            messageKey: code.rawValue,
            repairability: .automatic(ruleID: rule),
            evidence: evidence
        )
    }
}
