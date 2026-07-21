import { describe, expect, it, vi } from "vitest";

import { inspectEpubs } from "../../src/application/inspect-epubs";
import { auditEpub, type AuditEpubPorts } from "../../src/domain/audit/audit-epub";
import { createFinding } from "../../src/domain/audit/finding-catalog";
import { FINDING_CODES } from "../../src/domain/audit/finding-codes";
import type {
  Sha256Digest,
  VerifiedDescriptorId,
} from "../../src/domain/models/epub-document";
import { ok } from "../../src/domain/models/result";
import { selectedEpub } from "../fixtures/input/fixture-definitions";

const source = selectedEpub("/fixtures/traversal.epub", "traversal.epub", "unsafe-traversal");
const fingerprint = {
  identity: source.identity,
  sizeBytes: source.sizeBytes,
  modifiedAtMs: source.modifiedAtMs,
  sha256: "sha256-unsafe-traversal" as Sha256Digest,
};

describe("unsafe inspection", () => {
  it("accounts for every later rule without reading content, repairing, or creating output", async () => {
    const timeline: string[] = [];
    const terminalFinding = createFinding("ARCHIVE_PATH_TRAVERSAL", {
      location: { kind: "archive_entry", entryIndex: 3 },
      evidence: { originalName: "../../outside.xhtml" },
    });
    const ports: AuditEpubPorts = {
      filesystem: {
        openVerifiedSource: vi.fn(async (selected) => {
          timeline.push("open-source-read-only");
          return ok({
            id: "descriptor:unsafe-traversal" as VerifiedDescriptorId,
            sourceId: selected.id,
            snapshot: selected,
          });
        }),
        fingerprint: vi.fn(async () => {
          timeline.push("fingerprint-source");
          return ok(fingerprint);
        }),
      },
      archive: {
        preflightArchive: vi.fn(async () => {
          timeline.push("archive-preflight");
          return ok({
            outcome: {
              terminal: true,
              findings: [terminalFinding],
              ruleResults: [],
            },
          });
        }),
      },
      xml: {
        parseContainer: vi.fn(async () => {
          throw new Error("Terminal preflight must not parse container XML");
        }),
        parsePackage: vi.fn(async () => {
          throw new Error("Terminal preflight must not parse package XML");
        }),
        parseContentReferences: vi.fn(async () => {
          throw new Error("Terminal preflight must not parse content XML");
        }),
      },
      clock: { nowMs: vi.fn(() => 1_721_476_800_000) },
    };

    const operation = await inspectEpubs(
      { items: [source], rejections: [], selectedAtMs: 1_721_476_800_000 },
      {
        inspection: {
          inspect: (selected, signal) => auditEpub(selected, ports, signal),
        },
        clock: ports.clock,
      },
      new AbortController().signal,
      vi.fn(),
    );

    const result = operation.results[0];
    expect(result.status).toBe("inspected");
    if (result.status !== "inspected") throw new Error("Expected an inspected result");

    expect(result.report).toMatchObject({
      health: "unsafe",
      sourceFingerprint: fingerprint,
      findings: [terminalFinding],
    });
    expect(result.report.ruleResults).toHaveLength(FINDING_CODES.length);
    expect(result.report.ruleResults.find(({ ruleId }) => ruleId === "finding:ARCHIVE_PATH_TRAVERSAL"))
      .toMatchObject({ outcome: { status: "completed" }, findingIds: [terminalFinding.identity] });

    const laterResults = result.report.ruleResults.filter(
      ({ ruleId }) => ruleId !== "finding:ARCHIVE_PATH_TRAVERSAL",
    );
    expect(laterResults).toHaveLength(FINDING_CODES.length - 1);
    expect(laterResults.every(({ outcome }) =>
      outcome.status === "not_run_after_terminal_finding" && outcome.reason.length > 0,
    )).toBe(true);
    expect(timeline).toEqual(["open-source-read-only", "fingerprint-source", "archive-preflight"]);
    expect(ports.xml.parseContainer).not.toHaveBeenCalled();
    expect(ports.xml.parsePackage).not.toHaveBeenCalled();
    expect(ports.xml.parseContentReferences).not.toHaveBeenCalled();
    expect(operation.results.some(({ status }) => status === "prepared")).toBe(false);
    expect(JSON.stringify(operation)).not.toContain("outputPath");
    expect(source).toEqual(selectedEpub(
      "/fixtures/traversal.epub",
      "traversal.epub",
      "unsafe-traversal",
    ));
  });
});
