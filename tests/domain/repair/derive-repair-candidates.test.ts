import { describe, expect, it } from "vitest";

import { createFinding } from "../../../src/domain/audit/finding-catalog";
import type { InternalPath } from "../../../src/domain/models/archive";
import type { Finding } from "../../../src/domain/models/finding";
import type { HealthReport } from "../../../src/domain/models/health-report";
import type { SelectedEpubId, Sha256Digest } from "../../../src/domain/models/epub-document";
import { deriveRepairCandidates } from "../../../src/domain/repair/derive-repair-candidates";

describe("deriveRepairCandidates", () => {
  it("derives a deterministic manifest media-type correction from audit evidence", () => {
    const finding = createFinding("MANIFEST_MEDIA_TYPE_MISMATCH", {
      location: {
        kind: "manifest_item",
        path: "OEBPS/content.opf" as InternalPath,
        manifestId: "DroidSerif-Bold.ttf",
      },
      targetIdentifier: "DroidSerif-Bold.ttf",
      evidence: { declaredMediaType: "application/x-font-ttf", expectedMediaType: "font/ttf" },
    });
    expect(deriveRepairCandidates(reportWith(finding))).toEqual({
      mediaTypeCorrections: [
        {
          findingId: finding.identity,
          packagePath: "OEBPS/content.opf",
          manifestId: "DroidSerif-Bold.ttf",
          mediaType: "font/ttf",
        },
      ],
    });
  });

  it("derives the remaining deterministic repair facts only from explicit audit evidence", () => {
    const container = createFinding("CONTAINER_MISSING", {
      repairability: "automatic",
      stateImpact: "repairable",
      evidence: { packagePath: "OEBPS/content.opf" },
    });
    const reference = createFinding("CONTENT_LINK_BROKEN", {
      repairability: "automatic",
      stateImpact: "repairable",
      location: { kind: "internal_path", path: "OEBPS/chapter.xhtml" as InternalPath },
      evidence: {
        reference: "images/cover.jpg",
        replacementReference: "../Images/cover.jpg",
        targetPath: "OEBPS/Images/cover.jpg",
      },
    });
    const equivalentPath = createFinding("CONTENT_PATH_CASE_MISMATCH", {
      location: { kind: "internal_path", path: "OEBPS/chapter.xhtml" as InternalPath },
      evidence: {
        existingPath: "OEBPS/Images/cover.jpg",
        referencedPath: "OEBPS/images/cover.jpg",
      },
    });
    const xmlEncoding = createFinding("XML_ENCODING_INVALID", {
      repairability: "automatic",
      stateImpact: "repairable",
      location: { kind: "xml", path: "OEBPS/chapter.xhtml" as InternalPath },
    });

    expect(deriveRepairCandidates(reportWith(container, reference, equivalentPath, xmlEncoding))).toEqual({
      containerRepairs: [{ findingId: container.identity, packagePath: "OEBPS/content.opf" }],
      referenceCorrections: [
        {
          findingId: reference.identity,
          ownerPath: "OEBPS/chapter.xhtml",
          originalReference: "images/cover.jpg",
          replacementReference: "../Images/cover.jpg",
          targetPath: "OEBPS/Images/cover.jpg",
        },
      ],
      equivalentPathCorrections: [
        {
          findingId: equivalentPath.identity,
          sourcePath: "OEBPS/Images/cover.jpg",
          targetPath: "OEBPS/images/cover.jpg",
        },
      ],
      xmlEncodingCorrections: [{ findingId: xmlEncoding.identity, path: "OEBPS/chapter.xhtml" }],
    });
  });

  it("does not derive a unique-reference correction without an explicit replacement", () => {
    const finding = createFinding("CONTENT_LINK_BROKEN", {
      repairability: "automatic",
      stateImpact: "repairable",
      location: { kind: "internal_path", path: "OEBPS/chapter.xhtml" as InternalPath },
      evidence: { reference: "missing.xhtml" },
    });

    expect(deriveRepairCandidates(reportWith(finding))).toEqual({});
  });
});

function reportWith(...findings: Finding[]): HealthReport {
  return {
    sourceId: "book" as SelectedEpubId,
    sourceFingerprint: {
      identity: { device: "1", file: "2" },
      sizeBytes: 10,
      modifiedAtMs: 20,
      sha256: "a".repeat(64) as Sha256Digest,
    },
    epubVersion: "3",
    health: "repairable",
    findings,
    inspectedAtMs: 30,
    durationMs: 10,
    ruleResults: [],
  };
}
