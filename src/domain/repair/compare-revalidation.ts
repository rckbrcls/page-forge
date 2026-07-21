import type { AppliedRepairReference, Finding, FindingIdentity } from "../models/finding";
import type { HealthReport } from "../models/health-report";
import type { ProcessingFailure } from "../models/processing-failure";
import type {
  AppliedRepair,
  PreparationResult,
  RevalidationComparison,
  TemporaryCleanupStatus,
} from "../models/repair";

type UnsuccessfulPreparationResult = Extract<
  PreparationResult,
  { readonly status: "unsuccessful" }
>;

interface UnsuccessfulPreparationEvidence<F extends ProcessingFailure = ProcessingFailure> {
  readonly failure: F;
  readonly originalReport: HealthReport;
  readonly repairedReport?: HealthReport;
  readonly comparison?: RevalidationComparison;
  readonly cleanup: TemporaryCleanupStatus;
}

export function compareReports(
  before: HealthReport,
  after: HealthReport,
  repairs: readonly AppliedRepair[],
): RevalidationComparison {
  const beforeIds = new Set(before.findings.map(({ identity }) => identity));
  const afterIds = new Set(after.findings.map(({ identity }) => identity));
  const repairByFinding = confirmedRepairReferences(repairs);

  const comparedBefore = enrichReport(before, repairByFinding, (identity) =>
    afterIds.has(identity) ? "remaining" : "resolved",
  );
  const comparedAfter = enrichReport(after, repairByFinding, (identity) =>
    beforeIds.has(identity) ? "remaining" : "introduced",
  );

  const resolved = comparedBefore.findings
    .filter(({ revalidation }) => revalidation === "resolved")
    .map(({ identity }) => identity);
  const remaining = comparedBefore.findings
    .filter(({ revalidation }) => revalidation === "remaining")
    .map(({ identity }) => identity);
  const introduced = comparedAfter.findings.filter(
    ({ revalidation }) => revalidation === "introduced",
  );
  const hasIntroducedError = introduced.some(
    ({ severity }) => severity === "error" || severity === "critical",
  );
  const everyRepairSucceeded = repairs.every(
    ({ outcome }) => outcome === "applied" || outcome === "already_satisfied",
  );

  return {
    before: comparedBefore,
    after: comparedAfter,
    repairs,
    resolved,
    remaining,
    introduced,
    successful: after.health === "healthy" && !hasIntroducedError && everyRepairSucceeded,
    finalHealth: after.health,
  };
}

export function createUnsuccessfulPreparationResult<F extends ProcessingFailure>(
  evidence: UnsuccessfulPreparationEvidence<F>,
): UnsuccessfulPreparationResult & { readonly failure: F } {
  return { status: "unsuccessful", ...evidence };
}

function confirmedRepairReferences(
  repairs: readonly AppliedRepair[],
): ReadonlyMap<FindingIdentity, AppliedRepairReference> {
  const references = new Map<FindingIdentity, AppliedRepairReference>();

  for (const repair of repairs) {
    if (repair.outcome === "failed") continue;

    for (const findingId of repair.resolvedFindingIds) {
      if (!references.has(findingId)) {
        references.set(findingId, { operationId: repair.operationId });
      }
    }
  }

  return references;
}

function enrichReport(
  report: HealthReport,
  repairByFinding: ReadonlyMap<FindingIdentity, AppliedRepairReference>,
  revalidationFor: (identity: FindingIdentity) => Finding["revalidation"],
): HealthReport {
  return {
    ...report,
    findings: report.findings.map((occurrence) => {
      const appliedRepair = repairByFinding.get(occurrence.identity);
      const enriched = {
        ...occurrence,
        revalidation: revalidationFor(occurrence.identity),
      };

      if (appliedRepair === undefined) {
        const { appliedRepair: _staleReference, ...withoutAppliedRepair } = enriched;
        return withoutAppliedRepair;
      }

      return { ...enriched, appliedRepair };
    }),
  };
}
