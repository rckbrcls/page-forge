import { describe, expect, it } from "vitest";

import { auditEpub } from "../../../src/domain/audit/audit-epub";
import { validAndZipFixtures } from "../../fixtures/valid/fixture-definitions";

describe("valid EPUB and ZIP reports", () => {
  it.each(Object.values(validAndZipFixtures))("reports $name", async (fixture) => {
    const report = await auditEpub({ bytes: fixture.bytes, displayName: fixture.name });

    expect(report.epubVersion).toBe(fixture.epubVersion);
    expect(report.health).toBe(fixture.health);
    expect(report.findings.map(({ code, severity }) => ({ code, severity }))).toEqual(fixture.findings);
  });

  it("keeps fixed-layout information compatible with a Healthy report", async () => {
    const fixture = validAndZipFixtures.fixedLayout;
    const report = await auditEpub({ bytes: fixture.bytes, displayName: fixture.name });

    expect(report.health).toBe("healthy");
    expect(report.findings).toEqual([
      expect.objectContaining({
        code: "CONTENT_FIXED_LAYOUT",
        severity: "info",
        stateImpact: "healthy",
        repairability: "none",
      }),
    ]);
  });
});
