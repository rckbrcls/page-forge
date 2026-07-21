import type { SelectedEpubId, SourceFingerprint } from "./epub-document";
import type { Finding, FindingIdentity, RuleOutcome } from "./finding";

export type HealthState = "healthy" | "repairable" | "needs_review" | "unsupported" | "unsafe";
export type EpubVersion = "2" | "3" | "unknown";

export interface RuleResult {
  readonly ruleId: string;
  readonly outcome: RuleOutcome;
  readonly findingIds: readonly FindingIdentity[];
}

interface HealthReportBase {
  readonly sourceId: SelectedEpubId;
  readonly sourceFingerprint: SourceFingerprint;
  readonly epubVersion: EpubVersion;
  readonly findings: readonly Finding[];
  readonly inspectedAtMs: number;
  readonly durationMs: number;
  readonly ruleResults: readonly RuleResult[];
}

export type HealthReport =
  | (HealthReportBase & { readonly health: "healthy" })
  | (HealthReportBase & { readonly health: "repairable" })
  | (HealthReportBase & { readonly health: "needs_review" })
  | (HealthReportBase & { readonly health: "unsupported" })
  | (HealthReportBase & { readonly health: "unsafe" });
