import { describe, expect, it } from "vitest";

import { deriveHealth } from "../../../src/domain/audit/derive-health";
import { auditActiveContent } from "../../../src/domain/audit/rules/active-content";
import { activeProtectedContentFixtures } from "../../fixtures/encrypted/fixture-definitions";

describe("active and protected content audit", () => {
  it.each(activeProtectedContentFixtures)("detects $name without using active capabilities", (fixture) => {
    expect(fixture.epub.subarray(0, 4)).toEqual(Buffer.from([0x50, 0x4b, 0x03, 0x04]));

    const findings = auditActiveContent(fixture.input);

    expect(findings.map(({ code }) => code)).toEqual([fixture.expected.code]);
    expect(findings[0]).toMatchObject({
      code: fixture.expected.code,
      severity: fixture.expected.severity,
      stateImpact: fixture.expected.stateImpact,
      repairability: fixture.expected.repairability,
      location: { kind: "internal_path", path: fixture.expected.location },
    });
    expect(findings[0]?.recommendedRepair).toBeUndefined();
    expect(deriveHealth(findings)).toBe(fixture.expected.stateImpact === "unsafe" ? "unsafe" : "needs_review");
    expect(fixture.forbiddenEffects).toEqual({
      payloadReads: 0,
      networkAccesses: 0,
      decryptions: 0,
    });
  });

  it("covers every v1 active, external, remote, executable, and protected-content code", () => {
    expect(activeProtectedContentFixtures.map(({ expected }) => expected.code)).toEqual([
      "CONTENT_EXTERNAL_FILE_REFERENCE",
      "CONTENT_EXECUTABLE_RESOURCE",
      "CONTENT_SCRIPTED",
      "CONTENT_INTERACTIVE",
      "CONTENT_REMOTE_RESOURCE",
      "CONTENT_ENCRYPTED",
    ]);
  });
});
