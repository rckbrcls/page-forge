import type { Finding, FindingLocation } from "../models/finding";
import type { HealthState } from "../models/health-report";

const HEALTH_PRECEDENCE: Readonly<Record<HealthState, number>> = {
  healthy: 0,
  repairable: 1,
  needs_review: 2,
  unsupported: 3,
  unsafe: 4,
};

const CATEGORY_ORDER = [
  "input",
  "archive",
  "mimetype",
  "container",
  "package",
  "content",
  "compatibility",
  "delivery",
] as const;

export function deriveHealth(findings: readonly Finding[]): HealthState {
  let health: HealthState = "healthy";
  for (const finding of findings) {
    if (HEALTH_PRECEDENCE[finding.stateImpact] > HEALTH_PRECEDENCE[health]) {
      health = finding.stateImpact;
    }
  }
  return health;
}

export function compareFindings(left: Finding, right: Finding): number {
  const categoryDifference =
    CATEGORY_ORDER.indexOf(left.category) - CATEGORY_ORDER.indexOf(right.category);
  if (categoryDifference !== 0) return categoryDifference;

  const locationDifference = locationKey(left.location).localeCompare(locationKey(right.location));
  if (locationDifference !== 0) return locationDifference;

  const codeDifference = left.code.localeCompare(right.code);
  if (codeDifference !== 0) return codeDifference;
  return (left.targetIdentifier ?? "").localeCompare(right.targetIdentifier ?? "");
}

export function sortFindings(findings: readonly Finding[]): Finding[] {
  return [...findings].sort(compareFindings);
}

export const orderFindings = sortFindings;

function locationKey(location: FindingLocation | undefined): string {
  if (location === undefined) return "";
  switch (location.kind) {
    case "internal_path":
      return `internal_path:${location.path.normalize("NFC")}`;
    case "xml":
      return `xml:${location.path.normalize("NFC")}:${location.line ?? ""}:${location.column ?? ""}`;
    case "manifest_item":
      return `manifest_item:${location.path.normalize("NFC")}:${location.manifestId.normalize("NFC")}`;
    case "spine_item":
      return `spine_item:${location.path.normalize("NFC")}:${location.idref.normalize("NFC")}`;
    case "archive_entry":
      return `archive_entry:${String(location.entryIndex).padStart(12, "0")}`;
  }
}
