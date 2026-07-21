import { describe, expect, it } from "vitest";

import { createFinding } from "../../../src/domain/audit/finding-catalog";
import { createRepairPlan } from "../../../src/domain/repair/create-repair-plan";
import type { InternalPath } from "../../../src/domain/models/archive";
import type { SelectedEpub, SelectedEpubId, Sha256Digest } from "../../../src/domain/models/epub-document";
import type { Finding } from "../../../src/domain/models/finding";
import type { HealthReport } from "../../../src/domain/models/health-report";
import type { RepairKind } from "../../../src/domain/models/repair";

const path = (value: string) => value as InternalPath;
const sourceId = "selected-book" as SelectedEpubId;

const source: SelectedEpub = {
  id: sourceId,
  sourcePath: "/Books/Book.epub",
  displayName: "Book.epub",
  readable: true,
  identity: { device: "17", file: "42" },
  sizeBytes: 4_096,
  modifiedAtMs: 1_700_000_000_000,
};

function repairableReport(findings: readonly Finding[]): HealthReport & { health: "repairable" } {
  return {
    sourceId,
    sourceFingerprint: {
      identity: source.identity,
      sizeBytes: source.sizeBytes,
      modifiedAtMs: source.modifiedAtMs,
      sha256: "a".repeat(64) as Sha256Digest,
    },
    epubVersion: "3",
    health: "repairable",
    findings,
    inspectedAtMs: 1_700_000_001_000,
    durationMs: 25,
    ruleResults: [],
  };
}

const mimetypeFinding = createFinding("MIMETYPE_COMPRESSED", {
  location: { kind: "internal_path", path: path("mimetype") },
});
const mediaTypeFinding = createFinding("MANIFEST_MEDIA_TYPE_MISMATCH", {
  location: {
    kind: "manifest_item",
    path: path("EPUB/package.opf"),
    manifestId: "cover",
  },
  targetIdentifier: "cover",
  evidence: { declaredMediaType: "application/octet-stream", inferredMediaType: "image/jpeg" },
});
const ambiguousLinkFinding = createFinding("CONTENT_LINK_BROKEN", {
  location: { kind: "xml", path: path("EPUB/chapter.xhtml"), line: 8, column: 15 },
  targetIdentifier: "../Images/cover.jpg",
  repairability: "none",
  stateImpact: "needs_review",
});

describe("createRepairPlan", () => {
  it("creates only allowlisted operations and links every operation to its findings", () => {
    const report = repairableReport([mimetypeFinding, mediaTypeFinding]);
    const result = createRepairPlan(
      source,
      report,
      {
        mediaTypeCorrections: [
          {
            findingId: mediaTypeFinding.identity,
            packagePath: path("EPUB/package.opf"),
            manifestId: "cover",
            mediaType: "image/jpeg",
          },
        ],
      },
      "/Books/Book-kindle-ready.epub",
    );

    expect(result.ok).toBe(true);
    if (!result.ok) throw new Error(result.failure.safeMessage);

    const allowlist = new Set<RepairKind>([
      "write_canonical_mimetype",
      "rebuild_container_for_single_opf",
      "correct_manifest_media_type",
      "correct_unique_reference",
      "normalize_equivalent_internal_path",
      "normalize_xml_encoding",
      "rebuild_epub_archive",
    ]);
    const originalFindingIds = new Set(report.findings.map(({ identity }) => identity));

    expect(result.value.operations.length).toBeGreaterThan(0);
    for (const operation of result.value.operations) {
      expect(allowlist.has(operation.kind)).toBe(true);
      expect(operation.findingIds.length).toBeGreaterThan(0);
      expect(operation.findingIds.every((id) => originalFindingIds.has(id))).toBe(true);
      expect(operation.explanation.trim()).not.toBe("");
    }
  });

  it("records exact deterministic targets and the archive entries each operation may change", () => {
    const report = repairableReport([mimetypeFinding, mediaTypeFinding]);
    const result = createRepairPlan(
      source,
      report,
      {
        mediaTypeCorrections: [
          {
            findingId: mediaTypeFinding.identity,
            packagePath: path("EPUB/package.opf"),
            manifestId: "cover",
            mediaType: "image/jpeg",
          },
        ],
      },
      "/Books/Book-kindle-ready.epub",
    );

    expect(result.ok).toBe(true);
    if (!result.ok) throw new Error(result.failure.safeMessage);

    expect(result.value.operations).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          kind: "write_canonical_mimetype",
          findingIds: [mimetypeFinding.identity],
          changedPaths: [path("mimetype")],
          value: "application/epub+zip",
        }),
        expect.objectContaining({
          kind: "correct_manifest_media_type",
          findingIds: [mediaTypeFinding.identity],
          readPaths: [path("EPUB/package.opf")],
          changedPaths: [path("EPUB/package.opf")],
          packagePath: path("EPUB/package.opf"),
          manifestId: "cover",
          mediaType: "image/jpeg",
        }),
      ]),
    );

    const packaging = result.value.operations.at(-1);
    expect(packaging).toEqual(
      expect.objectContaining({
        kind: "rebuild_epub_archive",
        changedPaths: expect.arrayContaining([path("mimetype"), path("EPUB/package.opf")]),
      }),
    );
  });

  it("keeps findings without one deterministic target unresolved with a reviewable reason", () => {
    const report = repairableReport([mimetypeFinding, ambiguousLinkFinding]);
    const result = createRepairPlan(source, report, { referenceCorrections: [] }, "/Books/Book-kindle-ready.epub");

    expect(result.ok).toBe(true);
    if (!result.ok) throw new Error(result.failure.safeMessage);

    expect(result.value.unresolvedFindings).toEqual([
      {
        finding: ambiguousLinkFinding,
        reason: expect.stringMatching(/unique|ambiguous|deterministic/i),
      },
    ]);
    expect(result.value.operations.some(({ findingIds }) => findingIds.includes(ambiguousLinkFinding.identity))).toBe(
      false,
    );
  });

  it("never emits an operation outside the closed allowlist", () => {
    const invalidFinding = {
      ...mimetypeFinding,
      identity: `${mimetypeFinding.identity}-invalid`,
      recommendedRepair: "execute_external_converter",
    } as unknown as Finding;

    const result = createRepairPlan(
      source,
      repairableReport([mimetypeFinding, invalidFinding]),
      {},
      "/Books/Book-kindle-ready.epub",
    );

    expect(result.ok).toBe(true);
    if (!result.ok) throw new Error(result.failure.safeMessage);
    expect(result.value.operations.map(({ kind }) => kind)).not.toContain("execute_external_converter");
    expect(result.value.unresolvedFindings).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          finding: invalidFinding,
          reason: expect.stringMatching(/allow|support|permitted/i),
        }),
      ]),
    );
  });

  it("rejects a stale source snapshot instead of planning against changed bytes", () => {
    const staleSource = { ...source, sizeBytes: source.sizeBytes + 1 };
    const result = createRepairPlan(
      staleSource,
      repairableReport([mimetypeFinding]),
      {},
      "/Books/Book-kindle-ready.epub",
    );

    expect(result.ok).toBe(false);
    if (result.ok) throw new Error("Expected stale source detection");
    expect(result.failure).toMatchObject({
      category: "repair",
      code: "REPAIR_PLAN_STALE",
      phase: "planning",
      retryable: false,
    });
  });

  it("retains the collision-safe predicted path without creating or rewriting it", () => {
    const predictedOutput = "/Books/Book-kindle-ready-3.epub";
    const result = createRepairPlan(source, repairableReport([mimetypeFinding]), {}, predictedOutput);

    expect(result.ok).toBe(true);
    if (!result.ok) throw new Error(result.failure.safeMessage);
    expect(result.value.predictedOutputPath).toBe(predictedOutput);
    expect(result.value.predictedOutputPath).not.toBe(source.sourcePath);
  });
});
