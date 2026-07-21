import { describe, expect, expectTypeOf, it } from "vitest";

import { ARCHIVE_LIMITS, OPERATION_LIMITS, XML_LIMITS } from "../../../src/domain/audit/limits";
import type { Finding, Severity } from "../../../src/domain/models/finding";
import type { HealthReport, HealthState } from "../../../src/domain/models/health-report";
import type { BatchItemResult, ProcessingPhase } from "../../../src/domain/models/operation";
import type { PreparationResult, RepairKind } from "../../../src/domain/models/repair";

const healthStates = ["healthy", "repairable", "needs_review", "unsupported", "unsafe"] as const;
const severities = ["info", "warning", "error", "critical"] as const;
const repairKinds = [
  "write_canonical_mimetype",
  "rebuild_container_for_single_opf",
  "correct_manifest_media_type",
  "correct_unique_reference",
  "normalize_equivalent_internal_path",
  "normalize_xml_encoding",
  "rebuild_epub_archive",
] as const;
const phases = [
  "selecting",
  "preflight",
  "inspecting_container",
  "inspecting_package",
  "inspecting_content",
  "planning",
  "awaiting_confirmation",
  "reconstructing",
  "revalidating",
  "comparing",
  "promoting",
  "checking_delivery_eligibility",
  "awaiting_delivery_confirmation",
  "connecting",
  "transmitting",
  "completed",
  "failed",
  "cancelled",
] as const;

describe("domain model contracts", () => {
  it("keeps health, severity, repair, and phase unions closed", () => {
    expectTypeOf<(typeof healthStates)[number]>().toEqualTypeOf<HealthState>();
    expectTypeOf<(typeof severities)[number]>().toEqualTypeOf<Severity>();
    expectTypeOf<(typeof repairKinds)[number]>().toEqualTypeOf<RepairKind>();
    expectTypeOf<(typeof phases)[number]>().toEqualTypeOf<ProcessingPhase>();
  });

  it("keeps repairability independent from severity and health impact", () => {
    expectTypeOf<Finding>().toHaveProperty("severity").toEqualTypeOf<Severity>();
    expectTypeOf<Finding>().toHaveProperty("repairability").toEqualTypeOf<"none" | "automatic">();
    expectTypeOf<Finding>().toHaveProperty("stateImpact").toEqualTypeOf<HealthState>();
    expectTypeOf<HealthReport>().toHaveProperty("health").toEqualTypeOf<HealthState>();
  });

  it("preserves terminal result discriminants", () => {
    expectTypeOf<BatchItemResult["status"]>().toEqualTypeOf<
      "pending" | "in_progress" | "inspected" | "prepared" | "submitted" | "failed" | "cancelled" | "delivery_unknown"
    >();
    expectTypeOf<PreparationResult["status"]>().toEqualTypeOf<"prepared" | "unsuccessful" | "cancelled">();
  });

  it("allows only the documented operation paths", () => {
    const transitions = {
      selecting: ["preflight", "checking_delivery_eligibility", "failed", "cancelled"],
      preflight: ["inspecting_container", "failed", "cancelled"],
      inspecting_container: ["inspecting_package", "completed", "failed", "cancelled"],
      inspecting_package: ["inspecting_content", "completed", "failed", "cancelled"],
      inspecting_content: ["planning", "completed", "failed", "cancelled"],
      planning: ["awaiting_confirmation", "failed", "cancelled"],
      awaiting_confirmation: ["reconstructing", "failed", "cancelled"],
      reconstructing: ["revalidating", "failed", "cancelled"],
      revalidating: ["comparing", "failed", "cancelled"],
      comparing: ["promoting", "failed", "cancelled"],
      promoting: ["completed", "failed", "cancelled"],
      checking_delivery_eligibility: ["awaiting_delivery_confirmation", "failed", "cancelled"],
      awaiting_delivery_confirmation: ["connecting", "failed", "cancelled"],
      connecting: ["transmitting", "failed", "cancelled"],
      transmitting: ["completed", "failed", "cancelled"],
      completed: [],
      failed: [],
      cancelled: [],
    } as const satisfies Record<ProcessingPhase, readonly ProcessingPhase[]>;

    expect(transitions.completed).toEqual([]);
    expect(transitions.failed).toEqual([]);
    expect(transitions.cancelled).toEqual([]);
    expect(transitions.reconstructing).not.toContain("promoting");
    expect(transitions.transmitting).not.toContain("connecting");
  });

  it("encodes the safety boundaries without decimal-unit drift", () => {
    expect(ARCHIVE_LIMITS).toMatchObject({
      maxSourceBytes: 200_000_000,
      maxEntryCount: 10_000,
      maxExpandedEntryBytes: 100_000_000,
      maxExpandedTotalBytes: 1_000_000_000,
      maxExpansionRatio: 100,
    });
    expect(XML_LIMITS).toMatchObject({ maxBytes: 10_000_000, maxDepth: 64 });
    expect(OPERATION_LIMITS.perFileTimeoutMs).toBe(120_000);
  });
});
