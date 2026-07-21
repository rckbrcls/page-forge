import { List } from "@raycast/api";
import { basename } from "node:path";

import type { RepairOperation, RepairPlan } from "../../domain/models/repair";

function operationMarkdown(operation: RepairOperation, index: number): string {
  const findings = operation.findingIds.map((identity) => `\`${identity}\``).join(", ");
  const changedPaths = operation.changedPaths.map((entry) => `\`${entry}\``).join(", ");
  const readPaths = operation.readPaths.map((entry) => `\`${entry}\``).join(", ");

  return [
    `## ${index + 1}. ${operation.kind}`,
    "",
    operation.explanation,
    "",
    `- **Addressed findings:** ${findings || "None"}`,
    `- **Reads:** ${readPaths || "None"}`,
    `- **Changes:** ${changedPaths || "None"}`,
  ].join("\n");
}

export function repairPlanMarkdown(plan: RepairPlan): string {
  const sections = [
    "# Review Repair Plan",
    "",
    "The original EPUB will not be modified. Review every operation before preparing a copy.",
    "",
    ...plan.operations.flatMap((operation, index) => [operationMarkdown(operation, index), ""]),
    "# Unresolved Findings",
    "",
  ];

  if (plan.unresolvedFindings.length === 0) {
    sections.push("None. All reported findings are addressed by this plan.");
  } else {
    for (const { finding, reason } of plan.unresolvedFindings) {
      sections.push(
        `## ${finding.code}`,
        "",
        finding.title,
        "",
        `- **Finding identity:** \`${finding.identity}\``,
        `- **Reason:** ${reason}`,
        "",
      );
    }
  }

  sections.push(
    "# Predicted Output",
    "",
    `\`${basename(plan.predictedOutputPath)}\``,
    "",
    "The actual output may use the next available numeric suffix if this path is taken before promotion.",
  );
  return sections.join("\n");
}

export interface RepairPlanDetailProps {
  readonly plan: RepairPlan;
}

export function RepairPlanDetail({ plan }: RepairPlanDetailProps) {
  return (
    <List.Item.Detail
      markdown={repairPlanMarkdown(plan)}
      metadata={
        <List.Item.Detail.Metadata>
          <List.Item.Detail.Metadata.Label title="Source" text={plan.source.displayName} />
          <List.Item.Detail.Metadata.Label title="Operations" text={String(plan.operations.length)} />
          <List.Item.Detail.Metadata.Label title="Unresolved Findings" text={String(plan.unresolvedFindings.length)} />
          <List.Item.Detail.Metadata.Separator />
          <List.Item.Detail.Metadata.Label title="Predicted Output" text={basename(plan.predictedOutputPath)} />
        </List.Item.Detail.Metadata>
      }
    />
  );
}
