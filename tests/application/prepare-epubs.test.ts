import { describe, expect, expectTypeOf, it, vi } from "vitest";

import {
  prepareEpub,
  type PrepareComparisonPort,
  type PrepareEpubPorts,
  type PrepareInspectionPort,
  type RepairExecutionPort,
} from "../../src/application/prepare-epubs";
import type { ClockPort, FilesystemPort } from "../../src/application/ports";
import type { InternalPath } from "../../src/domain/models/archive";
import type {
  SelectedEpub,
  Sha256Digest,
  SourceFingerprint,
  VerifiedDescriptorId,
} from "../../src/domain/models/epub-document";
import { createFindingIdentity, type Finding } from "../../src/domain/models/finding";
import type { HealthReport } from "../../src/domain/models/health-report";
import type { ProgressEvent } from "../../src/domain/models/operation";
import type {
  AppliedRepair,
  RepairOperationId,
  RepairPlan,
  RevalidationComparison,
} from "../../src/domain/models/repair";
import { ok } from "../../src/domain/models/result";
import { selectedEpub } from "../fixtures/input/fixture-definitions";
import { ProgressRecorder } from "../support/operation-harness";

const source = selectedEpub("/books/book.epub", "book.epub", "acceptance-source");
const temporary = {
  id: "page-forge-temp",
  path: "/books/.page-forge-random.epub",
  prediction: {
    sourcePath: source.sourcePath,
    candidatePath: "/books/book-kindle-ready.epub",
    suffix: 1,
  },
};
const outputFingerprint: SourceFingerprint = {
  identity: { device: "fixture-device", file: "acceptance-output" },
  sizeBytes: 4_128,
  modifiedAtMs: 1_721_476_800_100,
  sha256: "sha256-canonical-output" as Sha256Digest,
};
const originalFingerprint: SourceFingerprint = {
  identity: source.identity,
  sizeBytes: source.sizeBytes,
  modifiedAtMs: source.modifiedAtMs,
  sha256: "sha256-original-before-and-after" as Sha256Digest,
};

function repairableFinding(): Finding {
  const location = { kind: "internal_path" as const, path: "mimetype" as InternalPath };
  return {
    identity: createFindingIdentity("MIMETYPE_COMPRESSED", location),
    code: "MIMETYPE_COMPRESSED",
    severity: "error",
    category: "mimetype",
    title: "Mimetype is compressed",
    description: "The mimetype entry must use STORE.",
    location,
    repairability: "automatic",
    recommendedRepair: "write_canonical_mimetype",
    revalidation: "not_compared",
    evidence: {},
    stateImpact: "repairable",
  };
}

function report(
  inspectedSource: SelectedEpub,
  health: "repairable" | "healthy",
  findings: readonly Finding[],
  fingerprint: SourceFingerprint,
): HealthReport {
  return {
    sourceId: inspectedSource.id,
    sourceFingerprint: fingerprint,
    epubVersion: "3",
    health,
    findings,
    inspectedAtMs: 1_721_476_800_000,
    durationMs: 25,
    ruleResults: [],
  } as HealthReport;
}

const originalFinding = repairableFinding();
const originalReport = report(source, "repairable", [originalFinding], originalFingerprint) as HealthReport & {
  readonly health: "repairable";
};
const repairOperationId = "canonical-mimetype" as RepairOperationId;
const plan: RepairPlan = {
  source,
  originalReport,
  operations: [
    {
      id: repairOperationId,
      kind: "write_canonical_mimetype",
      findingIds: [originalFinding.identity],
      readPaths: ["mimetype" as InternalPath],
      changedPaths: ["mimetype" as InternalPath],
      explanation: "Rewrite the mimetype entry in canonical EPUB form.",
      value: "application/epub+zip",
    },
  ],
  unresolvedFindings: [],
  predictedOutputPath: temporary.prediction.candidatePath,
  createdAtMs: 1_721_476_800_010,
};

const appliedRepair: AppliedRepair = {
  operationId: repairOperationId,
  resolvedFindingIds: [originalFinding.identity],
  changedEntries: ["mimetype" as InternalPath],
  preservedEntryCount: 3,
  outcome: "applied",
};

describe("prepareEpub acceptance", () => {
  it("exposes only local preparation dependencies", () => {
    expectTypeOf<PrepareEpubPorts>().toEqualTypeOf<{
      readonly filesystem: FilesystemPort;
      readonly reconstruction: RepairExecutionPort;
      readonly inspection: PrepareInspectionPort;
      readonly comparison: PrepareComparisonPort;
      readonly clock: ClockPort;
    }>();
  });

  it("preserves original hashes, reinspects canonical disk output, and promotes a Healthy result", async () => {
    const timeline: string[] = [];
    const originalHashes: Sha256Digest[] = [];
    const writtenEntries: Array<{
      readonly path: string;
      readonly value: string;
      readonly compressionMethod: "STORE" | "DEFLATE";
      readonly localHeaderExtraLength: number;
    }> = [];
    const temporarySource = selectedEpub(
      temporary.path,
      ".page-forge-random.epub",
      "temporary-output",
      outputFingerprint,
    );
    const finalReport = report(temporarySource, "healthy", [], outputFingerprint) as HealthReport & {
      readonly health: "healthy";
    };
    const comparison: RevalidationComparison & { readonly successful: true } = {
      before: originalReport,
      after: finalReport,
      repairs: [appliedRepair],
      resolved: [originalFinding.identity],
      remaining: [],
      introduced: [],
      successful: true,
      finalHealth: "healthy",
    };

    const filesystem: FilesystemPort = {
      snapshotSource: vi.fn(async (path: string) => {
        timeline.push(`snapshot:${path}`);
        return ok(path === source.sourcePath ? source : temporarySource);
      }),
      openVerifiedSource: vi.fn(async (snapshot: SelectedEpub) => {
        timeline.push(`open:${snapshot.sourcePath}`);
        return ok({
          id: `descriptor:${snapshot.id}` as VerifiedDescriptorId,
          sourceId: snapshot.id,
          snapshot,
        });
      }),
      fingerprint: vi.fn(async (descriptor) => {
        const digest = descriptor.sourceId === source.id ? originalFingerprint : outputFingerprint;
        timeline.push(`hash:${descriptor.sourceId}`);
        if (descriptor.sourceId === source.id) originalHashes.push(digest.sha256);
        return ok(digest);
      }),
      predictOutput: vi.fn(async () => ok(temporary.prediction)),
      createSameDirectoryTemporary: vi.fn(async () => {
        timeline.push("create-temporary");
        return ok(temporary);
      }),
      promoteNoClobber: vi.fn(async (_temporary, candidate) => {
        timeline.push("promote");
        expect(candidate).toEqual(temporary.prediction);
        return ok({
          path: candidate.candidatePath,
          displayName: "book-kindle-ready.epub",
          fingerprint: outputFingerprint,
        });
      }),
      cleanupTemporary: vi.fn(async () => ok(undefined)),
    };
    const reconstruction: RepairExecutionPort = {
      apply: vi.fn(async (confirmedPlan, target) => {
        timeline.push("reconstruct");
        expect(confirmedPlan).toBe(plan);
        expect(target.path).toBe(temporary.path);
        writtenEntries.push({
          path: "mimetype",
          value: "application/epub+zip",
          compressionMethod: "STORE",
          localHeaderExtraLength: 0,
        });
        return ok([appliedRepair]);
      }),
    };
    const inspection: PrepareInspectionPort = {
      inspect: vi.fn(async (diskSource) => {
        timeline.push(`inspect:${diskSource.sourcePath}`);
        expect(diskSource).toBe(temporarySource);
        return ok(finalReport);
      }),
    };
    const comparisonPort: PrepareComparisonPort = {
      compare: vi.fn((before, after, repairs) => {
        timeline.push("compare");
        expect([before, after, repairs]).toEqual([originalReport, finalReport, [appliedRepair]]);
        return comparison;
      }),
    };
    const progress = new ProgressRecorder<ProgressEvent>();

    const result = await prepareEpub(
      plan,
      {
        filesystem,
        reconstruction,
        inspection,
        comparison: comparisonPort,
        clock: { nowMs: () => 1_721_476_800_100 },
      },
      new AbortController().signal,
      progress.record,
    );

    expect(result.status).toBe("prepared");
    if (result.status !== "prepared") throw new Error("Expected preparation to succeed");
    expect(originalHashes).toEqual([originalFingerprint.sha256, originalFingerprint.sha256]);
    expect(writtenEntries).toEqual([
      {
        path: "mimetype",
        value: "application/epub+zip",
        compressionMethod: "STORE",
        localHeaderExtraLength: 0,
      },
    ]);
    expect(timeline.indexOf(`snapshot:${temporary.path}`)).toBeGreaterThan(timeline.indexOf("reconstruct"));
    expect(timeline.indexOf(`inspect:${temporary.path}`)).toBeGreaterThan(
      timeline.indexOf(`snapshot:${temporary.path}`),
    );
    expect(timeline.indexOf("promote")).toBeGreaterThan(timeline.indexOf("compare"));
    expect(result.prepared).toMatchObject({
      outputPath: "/books/book-kindle-ready.epub",
      displayName: "book-kindle-ready.epub",
      report: { health: "healthy" },
      comparison: { successful: true, finalHealth: "healthy" },
      sourceFingerprint: originalFingerprint,
      outputSnapshot: outputFingerprint,
    });
    expect(result.prepared.outputPath).not.toBe(source.sourcePath);
    expect(progress.events.map(({ phase }) => phase)).toEqual(
      expect.arrayContaining(["reconstructing", "revalidating", "comparing", "promoting", "completed"]),
    );

    // These fields back all five result actions without another read or any network operation.
    expect({
      reveal: result.prepared.outputPath,
      copy: result.prepared.outputPath,
      containingFolder: "/books",
      finalReport: result.prepared.report,
      sendSource: result.prepared.outputSnapshot,
    }).toEqual({
      reveal: "/books/book-kindle-ready.epub",
      copy: "/books/book-kindle-ready.epub",
      containingFolder: "/books",
      finalReport,
      sendSource: outputFingerprint,
    });
  });
});
