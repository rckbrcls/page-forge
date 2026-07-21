import { describe, expect, it } from "vitest";

import { createFinding } from "../../../src/domain/audit/finding-catalog";
import { createRepairPlan } from "../../../src/domain/repair/create-repair-plan";
import type { InternalPath } from "../../../src/domain/models/archive";
import type { SelectedEpub, SelectedEpubId, Sha256Digest } from "../../../src/domain/models/epub-document";
import type { HealthReport } from "../../../src/domain/models/health-report";
import { ambiguousRepairRefusalFixtures } from "../../fixtures/ambiguous/fixture-definitions";

const sourceId = "ambiguous-book" as SelectedEpubId;
const source: SelectedEpub = {
  id: sourceId,
  sourcePath: "/Books/Ambiguous.epub",
  displayName: "Ambiguous.epub",
  readable: true,
  identity: { device: "17", file: "66" },
  sizeBytes: 8_192,
  modifiedAtMs: 1_700_000_000_000,
};
const mimetypeFinding = createFinding("MIMETYPE_COMPRESSED", {
  location: { kind: "internal_path", path: "mimetype" as InternalPath },
});

describe("ambiguous and editorial repair refusal", () => {
  it.each(ambiguousRepairRefusalFixtures)("refuses $name", (fixture) => {
    const report: HealthReport & { readonly health: "repairable" } = {
      sourceId,
      sourceFingerprint: {
        identity: source.identity,
        sizeBytes: source.sizeBytes,
        modifiedAtMs: source.modifiedAtMs,
        sha256: "a".repeat(64) as Sha256Digest,
      },
      epubVersion: "3",
      health: "repairable",
      findings: [mimetypeFinding, fixture.finding],
      inspectedAtMs: 1_700_000_001_000,
      durationMs: 25,
      ruleResults: [],
    };

    const result = createRepairPlan(source, report, fixture.candidates, "/Books/Ambiguous-kindle-ready.epub");

    expect(result.ok).toBe(true);
    if (!result.ok) throw new Error(result.failure.safeMessage);

    expect(result.value.unresolvedFindings).toEqual([
      {
        finding: fixture.finding,
        reason: expect.stringMatching(fixture.expectedReason),
      },
    ]);
    expect(result.value.operations.some(({ findingIds }) => findingIds.includes(fixture.finding.identity))).toBe(false);
    expect(result.value.operations.map(({ kind }) => kind)).not.toContain(fixture.proposedAction);

    const changedPaths = new Set(result.value.operations.flatMap((operation) => operation.changedPaths));
    for (const protectedPath of fixture.protectedPaths) {
      expect(changedPaths.has(protectedPath)).toBe(false);
    }
  });

  it("covers the complete v1 ambiguity and editorial-refusal policy", () => {
    expect(ambiguousRepairRefusalFixtures.map(({ policyArea }) => policyArea)).toEqual([
      "opf",
      "cover",
      "navigation",
      "reference",
      "metadata",
      "manifest",
      "chapter",
      "xhtml",
      "script",
      "font",
      "css",
    ]);
  });
});
