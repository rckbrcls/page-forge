import { describe, expect, it } from "vitest";

import { auditEpub } from "../../../src/domain/audit/audit-epub";
import { containerPackageFixtures } from "../../fixtures/container/fixture-definitions";

describe("container and package discovery", () => {
  it.each(Object.values(containerPackageFixtures))("reports $name", async (fixture) => {
    const report = await auditEpub({ bytes: fixture.bytes, displayName: fixture.name });

    expect(report.epubVersion).toBe(fixture.epubVersion);
    expect(report.health).toBe(fixture.health);
    expect(
      report.findings.map(({ code, severity, repairability, stateImpact }) => ({
        code,
        severity,
        repairability,
        stateImpact,
      })),
    ).toEqual(fixture.findings);
  });

  it("covers every container and package-discovery finding code", () => {
    const coveredCodes = new Set(
      Object.values(containerPackageFixtures).flatMap((fixture) => fixture.findings.map((finding) => finding.code)),
    );

    expect(coveredCodes).toEqual(
      new Set([
        "CONTAINER_MISSING",
        "CONTAINER_XML_INVALID",
        "CONTAINER_ROOTFILE_MISSING",
        "CONTAINER_ROOTFILE_MULTIPLE",
        "CONTAINER_PACKAGE_MISSING",
        "PACKAGE_NOT_FOUND",
        "PACKAGE_AMBIGUOUS",
        "PACKAGE_XML_INVALID",
        "PACKAGE_VERSION_UNSUPPORTED",
      ]),
    );
  });
});
