import { describe, expect, it } from "vitest";

import { auditContent } from "../../../src/domain/audit/rules/content";
import { contentRuleFixtures } from "../../fixtures/content/fixture-definitions";

const deferredToUserStory3 = [
  "CONTENT_EXTERNAL_FILE_REFERENCE",
  "CONTENT_SCRIPTED",
  "CONTENT_EXECUTABLE_RESOURCE",
  "CONTENT_INTERACTIVE",
  "CONTENT_ENCRYPTED",
] as const;

describe("content audit rules", () => {
  it.each(contentRuleFixtures)("reports $name according to the finding catalog", (fixture) => {
    expect(fixture.epub.subarray(0, 4)).toEqual(Buffer.from([0x50, 0x4b, 0x03, 0x04]));

    const findings = auditContent(fixture.input);
    const finding = findings.find(({ code }) => code === fixture.expected.code);

    expect(findings.map(({ code }) => code)).toEqual([fixture.expected.code]);
    expect(finding).toBeDefined();
    expect(finding).toMatchObject({
      code: fixture.expected.code,
      severity: fixture.expected.severity,
      stateImpact: fixture.expected.stateImpact,
      repairability: fixture.expected.repairability,
      ...(fixture.expected.recommendedRepair === undefined
        ? {}
        : { recommendedRepair: fixture.expected.recommendedRepair }),
      location: { kind: "internal_path", path: fixture.expected.location },
    });
  });

  it("keeps active and protected content cases in User Story 3", () => {
    const coveredCodes = new Set(
      contentRuleFixtures.flatMap((fixture) =>
        auditContent(fixture.input).map(({ code }) => code),
      ),
    );

    for (const code of deferredToUserStory3) expect(coveredCodes.has(code)).toBe(false);
  });
});
