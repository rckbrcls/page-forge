import { describe, expect, it } from "vitest";

import { auditPackageRules } from "../../../src/domain/audit/rules/package";
import {
  manifestRuleFixtures,
  type ManifestFindingCode,
} from "../../fixtures/package/manifest-fixtures";

const expectedContracts = {
  METADATA_TITLE_MISSING: ["warning", "needs_review", "none"],
  METADATA_IDENTIFIER_MISSING: ["warning", "needs_review", "none"],
  METADATA_LANGUAGE_MISSING: ["warning", "needs_review", "none"],
  PACKAGE_UNIQUE_IDENTIFIER_INVALID: ["error", "needs_review", "none"],
  MANIFEST_MISSING: ["error", "needs_review", "none"],
  MANIFEST_ID_DUPLICATE: ["error", "needs_review", "none"],
  MANIFEST_HREF_DUPLICATE: ["warning", "needs_review", "none"],
  MANIFEST_RESOURCE_MISSING: ["error", "needs_review", "none"],
  MANIFEST_MEDIA_TYPE_MISMATCH: ["warning", "repairable", "automatic"],
  MANIFEST_MEDIA_TYPE_UNKNOWN: ["warning", "needs_review", "none"],
} as const satisfies Record<ManifestFindingCode, readonly [string, string, string]>;

describe("package metadata and manifest rules", () => {
  it.each(manifestRuleFixtures)("reports $expectedCode for $name", (fixture) => {
    const findings = auditPackageRules(fixture.packageDocument, fixture.entryIndex);
    const matches = findings.filter((finding) => finding.code === fixture.expectedCode);

    expect(matches).toHaveLength(1);
    expect(matches[0]).toMatchObject({
      code: fixture.expectedCode,
      severity: expectedContracts[fixture.expectedCode][0],
      stateImpact: expectedContracts[fixture.expectedCode][1],
      repairability: expectedContracts[fixture.expectedCode][2],
      category: "package",
      revalidation: "not_compared",
    });
  });

  it("offers only the catalogued deterministic media-type repair", () => {
    const fixture = manifestRuleFixtures.find(
      ({ expectedCode }) => expectedCode === "MANIFEST_MEDIA_TYPE_MISMATCH",
    );
    expect(fixture).toBeDefined();

    const finding = auditPackageRules(fixture!.packageDocument, fixture!.entryIndex).find(
      ({ code }) => code === fixture!.expectedCode,
    );

    expect(finding).toMatchObject({
      repairability: "automatic",
      recommendedRepair: "correct_manifest_media_type",
    });
  });
});
