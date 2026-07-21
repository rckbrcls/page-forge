import { describe, expect, it } from "vitest";

import { auditPackageRules } from "../../../src/domain/audit/rules/package";
import { readingOrderRuleFixtures, type ReadingOrderFindingCode } from "../../fixtures/package/reading-order-fixtures";

const expectedContracts = {
  SPINE_MISSING: ["error", "needs_review"],
  SPINE_ITEMREF_MISSING_ID: ["error", "needs_review"],
  SPINE_ITEM_NOT_IN_MANIFEST: ["error", "needs_review"],
  SPINE_READING_ORDER_INVALID: ["error", "needs_review"],
  NAVIGATION_MISSING: ["warning", "needs_review"],
  NAVIGATION_AMBIGUOUS: ["warning", "needs_review"],
  COVER_MISSING: ["warning", "healthy"],
  COVER_AMBIGUOUS: ["warning", "healthy"],
} as const satisfies Record<ReadingOrderFindingCode, readonly [string, string]>;

describe("spine, reading order, navigation, and cover rules", () => {
  it.each(readingOrderRuleFixtures)("reports $expectedCode for $name", (fixture) => {
    const findings = auditPackageRules(fixture.packageDocument, fixture.entryIndex);
    const matches = findings.filter((finding) => finding.code === fixture.expectedCode);

    expect(matches).toHaveLength(1);
    expect(matches[0]).toMatchObject({
      code: fixture.expectedCode,
      severity: expectedContracts[fixture.expectedCode][0],
      stateImpact: expectedContracts[fixture.expectedCode][1],
      repairability: "none",
      category: "package",
      revalidation: "not_compared",
    });
  });

  it("does not offer an automatic repair for ambiguous navigation or covers", () => {
    const ambiguousFixtures = readingOrderRuleFixtures.filter(({ expectedCode }) =>
      ["NAVIGATION_AMBIGUOUS", "COVER_AMBIGUOUS"].includes(expectedCode),
    );

    for (const fixture of ambiguousFixtures) {
      const finding = auditPackageRules(fixture.packageDocument, fixture.entryIndex).find(
        ({ code }) => code === fixture.expectedCode,
      );
      expect(finding).toMatchObject({
        repairability: "none",
        stateImpact: fixture.expectedCode === "COVER_AMBIGUOUS" ? "healthy" : "needs_review",
      });
      expect(finding?.recommendedRepair).toBeUndefined();
    }
  });
});
