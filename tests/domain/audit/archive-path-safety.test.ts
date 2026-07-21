import { describe, expect, it } from "vitest";

import { auditEpub } from "../../../src/domain/audit/audit-epub";
import {
  archivePathSafetyFindingCodes,
  archivePathSafetyFixtures,
} from "../../fixtures/malicious/path-fixtures";

describe("archive path safety", () => {
  it.each(archivePathSafetyFixtures)("reports only $findingCode for $name", async (fixture) => {
    const report = await auditEpub({ bytes: fixture.bytes, displayName: fixture.name });

    expect(report.health).toBe("unsafe");
    expect(report.findings).toEqual([
      expect.objectContaining({
        code: fixture.findingCode,
        severity: "critical",
        category: "archive",
        repairability: "none",
        stateImpact: "unsafe",
      }),
    ]);
  });

  it("covers every archive path safety finding code", () => {
    expect(new Set(archivePathSafetyFixtures.map(({ findingCode }) => findingCode))).toEqual(
      new Set(archivePathSafetyFindingCodes),
    );
  });
});
