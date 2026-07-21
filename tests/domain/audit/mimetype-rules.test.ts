import { describe, expect, it } from "vitest";

import { auditEpub } from "../../../src/domain/audit/audit-epub";
import { mimetypeFixtures } from "../../fixtures/mimetype/fixture-definitions";

describe("EPUB mimetype rules", () => {
  it.each(Object.values(mimetypeFixtures))("reports only $finding.code", async (fixture) => {
    const report = await auditEpub({ bytes: fixture.bytes, displayName: fixture.name });

    expect(report.health).toBe(fixture.health);
    expect(report.epubVersion).toBe("3");
    expect(report.findings).toEqual([
      expect.objectContaining({
        ...fixture.finding,
        category: "mimetype",
        repairability: "automatic",
        stateImpact: "repairable",
      }),
    ]);
  });
});
