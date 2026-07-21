import { FINDING_CATALOG } from "./finding-catalog";
import { FINDING_CODES, type FindingCode } from "./finding-codes";
import type { Finding } from "../models/finding";
import type { RuleResult } from "../models/health-report";

export type AuditRuleStage = "preflight" | "mimetype" | "discovery" | "package" | "content";

export interface AuditRuleDefinition {
  readonly ruleId: `finding:${FindingCode}`;
  readonly findingCode: FindingCode;
  readonly stage: AuditRuleStage;
}

function stageFor(code: FindingCode): AuditRuleStage {
  const index = FINDING_CODES.indexOf(code);
  if (index < FINDING_CODES.indexOf("MIMETYPE_MISSING")) return "preflight";
  if (index < FINDING_CODES.indexOf("CONTAINER_MISSING")) return "mimetype";
  if (index < FINDING_CODES.indexOf("METADATA_TITLE_MISSING")) return "discovery";
  if (index < FINDING_CODES.indexOf("XML_ENCODING_INVALID")) return "package";
  return "content";
}

export const RULE_CATALOG: readonly AuditRuleDefinition[] = FINDING_CODES.map((findingCode) => ({
  ruleId: `finding:${findingCode}`,
  findingCode,
  stage: stageFor(findingCode),
}));

export interface RuleAccountingOptions {
  readonly completedStages: ReadonlySet<AuditRuleStage>;
  readonly terminalReason?: string;
  readonly existing?: readonly RuleResult[];
}

export function accountAuditRules(findings: readonly Finding[], options: RuleAccountingOptions): RuleResult[] {
  const findingsByCode = new Map<FindingCode, Finding[]>();
  for (const finding of findings) {
    findingsByCode.set(finding.code, [...(findingsByCode.get(finding.code) ?? []), finding]);
  }
  const existingByRuleId = new Map(options.existing?.map((result) => [result.ruleId, result]));

  return RULE_CATALOG.map((rule) => {
    const existing = existingByRuleId.get(rule.ruleId);
    if (existing !== undefined) return existing;

    const findingIds = (findingsByCode.get(rule.findingCode) ?? []).map(({ identity }) => identity);
    if (findingIds.length > 0 || options.completedStages.has(rule.stage)) {
      return { ruleId: rule.ruleId, outcome: { status: "completed" }, findingIds };
    }
    if (options.terminalReason !== undefined) {
      return {
        ruleId: rule.ruleId,
        outcome: {
          status: "not_run_after_terminal_finding",
          reason: options.terminalReason,
        },
        findingIds,
      };
    }
    return {
      ruleId: rule.ruleId,
      outcome: {
        status: "not_applicable",
        reason: `${FINDING_CATALOG[rule.findingCode].title} was not applicable.`,
      },
      findingIds,
    };
  });
}

export const ruleCatalog = RULE_CATALOG;
