import { afterEach, describe, expect, it, vi } from "vitest";

import { createInspectionDeadline, inspectArchiveLimits } from "../../../src/adapters/archive/archive-limits";
import { ARCHIVE_LIMITS } from "../../../src/domain/audit/limits";
import { archiveLimitFixtures, inspectionTimeoutFixture } from "../../fixtures/malicious/limit-fixtures";

describe("archive safety limits", () => {
  it.each(archiveLimitFixtures)("classifies $name", ({ metadata, expectedCodes }) => {
    const findings = inspectArchiveLimits(metadata, ARCHIVE_LIMITS);

    expect(findings.map(({ code }) => code)).toEqual(expectedCodes);
    for (const finding of findings) {
      expect(finding).toMatchObject({
        severity: "critical",
        stateImpact: "unsafe",
        repairability: "none",
      });
    }
  });

  it("excludes directory metadata from per-entry and aggregate ratios", () => {
    const findings = inspectArchiveLimits(
      {
        sourceBytes: 1,
        entryCount: 1,
        entries: [{ kind: "directory", compressedSize: 0, expandedSize: 1 }],
        compressedFileBytes: 0,
        expandedFileBytes: 0,
      },
      ARCHIVE_LIMITS,
    );

    expect(findings).toEqual([]);
  });

  it("uses a fake clock to abort immediately at the 120-second inspection deadline", () => {
    vi.useFakeTimers();
    const parent = new AbortController();
    const deadline = createInspectionDeadline(parent.signal, inspectionTimeoutFixture.timeoutMs);

    vi.advanceTimersByTime(inspectionTimeoutFixture.beforeMs);
    expect(deadline.signal.aborted).toBe(false);

    vi.advanceTimersByTime(1);
    expect(deadline.signal.aborted).toBe(true);
    expect(deadline.signal.reason).toMatchObject({
      code: inspectionTimeoutFixture.findingCode,
    });

    vi.advanceTimersByTime(inspectionTimeoutFixture.aboveMs - inspectionTimeoutFixture.atMs);
    expect(deadline.signal.aborted).toBe(true);

    deadline.dispose();
  });

  it("composes user cancellation and clears the pending deadline", () => {
    vi.useFakeTimers();
    const parent = new AbortController();
    const deadline = createInspectionDeadline(parent.signal, inspectionTimeoutFixture.timeoutMs);

    parent.abort("user cancelled");

    expect(deadline.signal.aborted).toBe(true);
    expect(deadline.signal.reason).toBe("user cancelled");
    expect(vi.getTimerCount()).toBe(0);
    deadline.dispose();
  });
});

afterEach(() => {
  vi.useRealTimers();
});
