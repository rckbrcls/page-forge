import { describe, expect, it } from "vitest";

import { auditEpub } from "../../../src/domain/audit/audit-epub";
import {
  archiveStructureSafetyFindingCodes,
  archiveStructureSafetyFixtures,
} from "../../fixtures/malicious/zip-structure-fixtures";

describe("archive structure safety", () => {
  it.each(archiveStructureSafetyFixtures)(
    "reports only $findingCode for $name",
    async (fixture) => {
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
    },
  );

  it("covers every archive structure safety finding code", () => {
    expect(new Set(archiveStructureSafetyFixtures.map(({ findingCode }) => findingCode))).toEqual(
      new Set(archiveStructureSafetyFindingCodes),
    );
  });
});
