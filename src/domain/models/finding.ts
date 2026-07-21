import type { FindingCode } from "../audit/finding-codes";
import type { InternalPath } from "./archive";
import type { RepairKind } from "./repair";

declare const findingIdentityBrand: unique symbol;

export type Severity = "info" | "warning" | "error" | "critical";
export type FindingCategory =
  "input" | "archive" | "mimetype" | "container" | "package" | "content" | "compatibility" | "delivery";
export type Repairability = "none" | "automatic";
export type RevalidationStatus = "not_compared" | "resolved" | "remaining" | "introduced";
export type FindingStateImpact = "healthy" | "repairable" | "needs_review" | "unsupported" | "unsafe";

export type FindingLocation =
  | { readonly kind: "internal_path"; readonly path: InternalPath }
  | {
      readonly kind: "xml";
      readonly path: InternalPath;
      readonly line?: number;
      readonly column?: number;
    }
  | { readonly kind: "manifest_item"; readonly path: InternalPath; readonly manifestId: string }
  | { readonly kind: "spine_item"; readonly path: InternalPath; readonly idref: string }
  | { readonly kind: "archive_entry"; readonly entryIndex: number };

export type FindingEvidenceValue = string | number | boolean | null;
export type FindingEvidence = Readonly<Record<string, FindingEvidenceValue>>;
export type FindingIdentity = string & { readonly [findingIdentityBrand]: "FindingIdentity" };

export interface AppliedRepairReference {
  readonly operationId: string;
}

export interface Finding {
  readonly identity: FindingIdentity;
  readonly code: FindingCode;
  readonly severity: Severity;
  readonly category: FindingCategory;
  readonly title: string;
  readonly description: string;
  readonly location?: FindingLocation;
  readonly targetIdentifier?: string;
  readonly repairability: Repairability;
  readonly recommendedRepair?: RepairKind;
  readonly appliedRepair?: AppliedRepairReference;
  readonly revalidation: RevalidationStatus;
  readonly evidence: FindingEvidence;
  readonly stateImpact: FindingStateImpact;
}

export function createFindingIdentity(
  code: FindingCode,
  location?: FindingLocation,
  targetIdentifier?: string,
): FindingIdentity {
  const normalizedLocation = location === undefined ? null : normalizeLocation(location);
  return JSON.stringify([code, normalizedLocation, targetIdentifier?.normalize("NFC") ?? null]) as FindingIdentity;
}

function normalizeLocation(location: FindingLocation): readonly (string | number | null)[] {
  switch (location.kind) {
    case "internal_path":
      return [location.kind, normalizePath(location.path)];
    case "xml":
      return [location.kind, normalizePath(location.path), location.line ?? null, location.column ?? null];
    case "manifest_item":
      return [location.kind, normalizePath(location.path), location.manifestId.normalize("NFC")];
    case "spine_item":
      return [location.kind, normalizePath(location.path), location.idref.normalize("NFC")];
    case "archive_entry":
      return [location.kind, location.entryIndex];
  }
}

function normalizePath(path: InternalPath): string {
  const withoutDirectoryMarker = path.endsWith("/") ? path.slice(0, -1) : path;
  return withoutDirectoryMarker.normalize("NFC");
}

export type RuleOutcome =
  | { readonly status: "completed" }
  | { readonly status: "not_applicable"; readonly reason: string }
  | { readonly status: "not_run_after_terminal_finding"; readonly reason: string };
