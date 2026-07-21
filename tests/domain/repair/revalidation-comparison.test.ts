import { describe, expect, it } from "vitest";

import { createFinding } from "../../../src/domain/audit/finding-catalog";
import { compareReports, createUnsuccessfulPreparationResult } from "../../../src/domain/repair/compare-revalidation";
import type { InternalPath } from "../../../src/domain/models/archive";
import type { SelectedEpubId, Sha256Digest, SourceFingerprint } from "../../../src/domain/models/epub-document";
import type { Finding } from "../../../src/domain/models/finding";
import type { HealthReport, HealthState } from "../../../src/domain/models/health-report";
import type { ProcessingFailure } from "../../../src/domain/models/processing-failure";
import type { AppliedRepair, RepairOperationId } from "../../../src/domain/models/repair";

const path = (value: string) => value as InternalPath;
const sourceId = "selected-book" as SelectedEpubId;
const fingerprint: SourceFingerprint = {
  identity: { device: "17", file: "42" },
  sizeBytes: 4_096,
  modifiedAtMs: 1_700_000_000_000,
  sha256: "a".repeat(64) as Sha256Digest,
};

function report(health: HealthState, findings: readonly Finding[]): HealthReport {
  return {
    sourceId,
    sourceFingerprint: fingerprint,
    epubVersion: "3",
    health,
    findings,
    inspectedAtMs: 1_700_000_001_000,
    durationMs: 25,
    ruleResults: [],
  } as HealthReport;
}

const resolvedFinding = createFinding("MIMETYPE_COMPRESSED", {
  location: { kind: "internal_path", path: path("mimetype") },
});
const remainingFinding = createFinding("CONTENT_REMOTE_RESOURCE", {
  location: { kind: "xml", path: path("EPUB/chapter.xhtml"), line: 4, column: 9 },
  targetIdentifier: "https://example.test/image.jpg",
});
const introducedFinding = createFinding("CONTENT_IMAGE_MISSING", {
  location: { kind: "xml", path: path("EPUB/chapter.xhtml"), line: 12, column: 7 },
  targetIdentifier: "Images/missing.jpg",
});
const operationId = "repair-mimetype" as RepairOperationId;
const appliedRepair: AppliedRepair = {
  operationId,
  resolvedFindingIds: [resolvedFinding.identity],
  changedEntries: [path("mimetype")],
  preservedEntryCount: 8,
  outcome: "applied",
};

function repairFailure(
  code: "REPAIR_TIMEOUT" | "REVALIDATION_TIMEOUT" | "REPAIR_WRITE_FAILED",
  phase: "reconstructing" | "revalidating",
): ProcessingFailure {
  return {
    category: "repair",
    code,
    safeMessage: code === "REPAIR_TIMEOUT" ? "Repair timed out." : "Revalidation failed.",
    retryable: true,
    phase,
    facts: { timeoutMs: 120_000 },
  };
}

describe("compareReports", () => {
  it("classifies resolved, remaining, and introduced findings by stable identity", () => {
    const before = report("repairable", [resolvedFinding, remainingFinding]);
    const after = report("needs_review", [remainingFinding, introducedFinding]);

    const comparison = compareReports(before, after, [appliedRepair]);

    expect(comparison.resolved).toEqual([resolvedFinding.identity]);
    expect(comparison.remaining).toEqual([remainingFinding.identity]);
    expect(comparison.introduced).toEqual([expect.objectContaining({ identity: introducedFinding.identity })]);
    expect(comparison.finalHealth).toBe("needs_review");
  });

  it("enriches both report occurrences without mutating the input reports", () => {
    const before = report("repairable", [resolvedFinding, remainingFinding]);
    const after = report("needs_review", [remainingFinding, introducedFinding]);

    const comparison = compareReports(before, after, [appliedRepair]);

    expect(comparison.before.findings).toEqual([
      expect.objectContaining({
        identity: resolvedFinding.identity,
        appliedRepair: { operationId },
        revalidation: "resolved",
      }),
      expect.objectContaining({ identity: remainingFinding.identity, revalidation: "remaining" }),
    ]);
    expect(comparison.after.findings).toEqual([
      expect.objectContaining({ identity: remainingFinding.identity, revalidation: "remaining" }),
      expect.objectContaining({ identity: introducedFinding.identity, revalidation: "introduced" }),
    ]);
    expect(before.findings.every(({ revalidation }) => revalidation === "not_compared")).toBe(true);
    expect(after.findings.every(({ revalidation }) => revalidation === "not_compared")).toBe(true);
  });

  it("does not report success when any confirmed operation failed", () => {
    const failedRepair: AppliedRepair = {
      ...appliedRepair,
      outcome: "failed",
      failure: repairFailure("REPAIR_WRITE_FAILED", "reconstructing"),
    };

    const comparison = compareReports(report("repairable", [resolvedFinding]), report("healthy", []), [failedRepair]);

    expect(comparison.finalHealth).toBe("healthy");
    expect(comparison.successful).toBe(false);
    expect(comparison.repairs).toEqual([failedRepair]);
  });

  it.each<HealthState>(["repairable", "needs_review", "unsupported", "unsafe"])(
    "rejects final non-Healthy state %s even when no new error is introduced",
    (health) => {
      const comparison = compareReports(report("repairable", [resolvedFinding]), report(health, [remainingFinding]), [
        appliedRepair,
      ]);

      expect(comparison.finalHealth).toBe(health);
      expect(comparison.successful).toBe(false);
    },
  );

  it("rejects a newly introduced Error even if an inconsistent caller labels the report Healthy", () => {
    const comparison = compareReports(report("repairable", [resolvedFinding]), report("healthy", [introducedFinding]), [
      appliedRepair,
    ]);

    expect(introducedFinding.severity).toBe("error");
    expect(comparison.introduced).toHaveLength(1);
    expect(comparison.successful).toBe(false);
  });

  it("accepts applied and proven already-satisfied operations only with final Healthy evidence", () => {
    const alreadySatisfied: AppliedRepair = {
      ...appliedRepair,
      operationId: "already-canonical" as RepairOperationId,
      outcome: "already_satisfied",
      changedEntries: [],
    };
    const comparison = compareReports(report("repairable", [resolvedFinding]), report("healthy", []), [
      appliedRepair,
      alreadySatisfied,
    ]);

    expect(comparison.successful).toBe(true);
    expect(comparison.finalHealth).toBe("healthy");
  });
});

describe("unsuccessful revalidation evidence", () => {
  it.each([
    ["REPAIR_TIMEOUT", "reconstructing"],
    ["REVALIDATION_TIMEOUT", "revalidating"],
  ] as const)("retains original evidence for %s without exposing a prepared output", (code, phase) => {
    const before = report("repairable", [resolvedFinding]);
    const failure = repairFailure(code, phase);

    const result = createUnsuccessfulPreparationResult({
      failure,
      originalReport: before,
      cleanup: { status: "completed" },
    });

    expect(result).toEqual({
      status: "unsuccessful",
      failure,
      originalReport: before,
      cleanup: { status: "completed" },
    });
    expect(result).not.toHaveProperty("prepared");
  });

  it("retains complete before/after comparison evidence after unsuccessful revalidation", () => {
    const before = report("repairable", [resolvedFinding]);
    const after = report("needs_review", [introducedFinding]);
    const comparison = compareReports(before, after, [appliedRepair]);
    const failure: ProcessingFailure = {
      category: "repair",
      code: "REVALIDATION_NEW_ERROR",
      safeMessage: "Revalidation introduced an error.",
      retryable: false,
      phase: "comparing",
      facts: { introducedCount: 1 },
    };

    const result = createUnsuccessfulPreparationResult({
      failure,
      originalReport: before,
      repairedReport: after,
      comparison,
      cleanup: { status: "completed" },
    });

    expect(result).toMatchObject({
      status: "unsuccessful",
      failure,
      originalReport: before,
      repairedReport: after,
      comparison: {
        successful: false,
        finalHealth: "needs_review",
        resolved: [resolvedFinding.identity],
        introduced: [expect.objectContaining({ identity: introducedFinding.identity })],
      },
      cleanup: { status: "completed" },
    });
    expect(result).not.toHaveProperty("prepared");
  });
});
