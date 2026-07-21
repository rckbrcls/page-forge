import { describe, expect, expectTypeOf, it, vi } from "vitest";

import {
  inspectEpubs,
  type InspectEpubPort,
  type InspectEpubsPorts,
} from "../../src/application/inspect-epubs";
import type { ClockPort } from "../../src/application/ports";
import { FINDING_CODES } from "../../src/domain/audit/finding-codes";
import type {
  SelectedEpub,
  SelectedEpubId,
  SelectionSnapshot,
  Sha256Digest,
} from "../../src/domain/models/epub-document";
import type { HealthReport } from "../../src/domain/models/health-report";
import type { ProgressEvent } from "../../src/domain/models/operation";
import type { ProcessingFailure } from "../../src/domain/models/processing-failure";
import { err, ok, type Result } from "../../src/domain/models/result";
import { selectedEpub } from "../fixtures/input/fixture-definitions";
import { ProgressRecorder } from "../support/operation-harness";

const sourceA = selectedEpub("/fixtures/a.epub", "a.epub", "a");
const sourceB = selectedEpub("/fixtures/b.epub", "b.epub", "b");
const sourceC = selectedEpub("/fixtures/c.epub", "c.epub", "c");

function completeReport(source: SelectedEpub, health: HealthReport["health"]): HealthReport {
  return {
    sourceId: source.id,
    sourceFingerprint: {
      identity: source.identity,
      sizeBytes: source.sizeBytes,
      modifiedAtMs: source.modifiedAtMs,
      sha256: `sha256-${source.displayName}` as Sha256Digest,
    },
    epubVersion: "3",
    health,
    findings: [],
    inspectedAtMs: 1_721_476_800_000,
    durationMs: 25,
    ruleResults: FINDING_CODES.map((code) => ({
      ruleId: `finding:${code}`,
      outcome: { status: "completed" },
      findingIds: [],
    })),
  };
}

const readFailure: ProcessingFailure = {
  category: "archive",
  code: "ARCHIVE_READ_FAILED",
  safeMessage: "The EPUB could not be read.",
  retryable: true,
  phase: "preflight",
};

class FakeInspectEpubPort implements InspectEpubPort {
  readonly calls: SelectedEpubId[] = [];
  active = 0;
  maxActive = 0;

  async inspect(
    source: SelectedEpub,
    _signal: AbortSignal,
  ): Promise<Result<HealthReport, ProcessingFailure>> {
    this.calls.push(source.id);
    this.active += 1;
    this.maxActive = Math.max(this.maxActive, this.active);
    await Promise.resolve();
    this.active -= 1;
    if (source.id === sourceB.id) return err(readFailure);
    return ok(completeReport(source, source.id === sourceA.id ? "healthy" : "repairable"));
  }
}

const snapshot: SelectionSnapshot = {
  items: [sourceA, sourceB, sourceC],
  rejections: [],
  selectedAtMs: 1_721_476_800_000,
};

describe("inspectEpubs", () => {
  it("exposes only local read inspection and clock dependencies", () => {
    expectTypeOf<InspectEpubsPorts>().toEqualTypeOf<{
      readonly inspection: InspectEpubPort;
      readonly clock: ClockPort;
    }>();
  });

  it("inspects one EPUB at a time, isolates failures, and preserves snapshot order", async () => {
    const inspection = new FakeInspectEpubPort();
    const clock: ClockPort = { nowMs: vi.fn(() => 1_721_476_800_000) };
    const progress = new ProgressRecorder<ProgressEvent>();

    const operation = await inspectEpubs(
      snapshot,
      { inspection, clock },
      new AbortController().signal,
      progress.record,
    );

    expect(inspection.calls).toEqual([sourceA.id, sourceB.id, sourceC.id]);
    expect(inspection.maxActive).toBe(1);
    expect(operation).toMatchObject({
      intent: "inspect",
      items: [sourceA, sourceB, sourceC],
      phase: "completed",
      cancellationRequested: false,
    });
    expect(operation.results.map((result) => result.status)).toEqual([
      "inspected",
      "failed",
      "inspected",
    ]);
    expect(operation.results[1]).toMatchObject({ status: "failed", failure: readFailure });
  });

  it("returns complete reports without dropping or rewriting rule accounting", async () => {
    const inspection = new FakeInspectEpubPort();
    const operation = await inspectEpubs(
      { ...snapshot, items: [sourceA] },
      { inspection, clock: { nowMs: () => 1_721_476_800_000 } },
      new AbortController().signal,
      vi.fn(),
    );

    const result = operation.results[0];
    expect(result.status).toBe("inspected");
    if (result.status !== "inspected") throw new Error("Expected an inspected result");
    expect(result.report).toEqual(completeReport(sourceA, "healthy"));
    expect(result.report.ruleResults.map(({ ruleId }) => ruleId)).toEqual(
      FINDING_CODES.map((code) => `finding:${code}`),
    );
    expect(result.report.ruleResults).toHaveLength(FINDING_CODES.length);
  });
});
