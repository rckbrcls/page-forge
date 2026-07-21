import { List } from "@raycast/api";

import type { Finding, FindingLocation } from "../../domain/models/finding";
import type { HealthReport } from "../../domain/models/health-report";

export type SafetyResultReport = Extract<HealthReport, { readonly health: "unsafe" | "needs_review" }>;

export interface SafetyResultDetailProps {
  readonly report: SafetyResultReport;
}

function titleCase(value: string): string {
  return value.replaceAll("_", " ").replace(/\b\w/g, (character) => character.toUpperCase());
}

function locationLabel(location: FindingLocation | undefined): string {
  if (location === undefined) return "Not specified";

  switch (location.kind) {
    case "internal_path":
      return location.path;
    case "xml": {
      const line = location.line === undefined ? "" : `:${location.line}`;
      const column = location.column === undefined ? "" : `:${location.column}`;
      return `${location.path}${line}${column}`;
    }
    case "manifest_item":
      return `${location.path} (manifest item ${location.manifestId})`;
    case "spine_item":
      return `${location.path} (spine item ${location.idref})`;
    case "archive_entry":
      return `Archive entry ${location.entryIndex}`;
  }
}

function findingMarkdown(finding: Finding): string {
  return [
    `## ${finding.title}`,
    "",
    finding.description,
    "",
    `- **Code:** \`${finding.code}\``,
    `- **Severity:** ${titleCase(finding.severity)}`,
    `- **Category:** ${titleCase(finding.category)}`,
    `- **Location:** ${locationLabel(finding.location)}`,
    `- **Repairability:** ${titleCase(finding.repairability)}`,
  ].join("\n");
}

export function safetyResultMarkdown(report: SafetyResultReport): string {
  const unsafe = report.health === "unsafe";
  const state = unsafe ? "Unsafe" : "Needs Review";
  const explanation = unsafe
    ? "Book Sender stopped automatic processing because this EPUB contains a safety risk. The original file was not modified."
    : "Book Sender found an issue that cannot be resolved safely without your review. The original file was not modified.";
  const nextStep = unsafe
    ? "Review the findings below and obtain a safe, trusted copy of the EPUB before trying again."
    : "Review the findings below and correct the source EPUB manually before inspecting it again.";

  return [
    `# ${state}`,
    "",
    explanation,
    "",
    `**Next step:** ${nextStep}`,
    "",
    "# Findings",
    "",
    ...report.findings.flatMap((finding) => [findingMarkdown(finding), ""]),
  ].join("\n");
}

export function SafetyResultDetail({ report }: SafetyResultDetailProps) {
  const state = report.health === "unsafe" ? "Unsafe" : "Needs Review";

  return (
    <List.Item.Detail
      markdown={safetyResultMarkdown(report)}
      metadata={
        <List.Item.Detail.Metadata>
          <List.Item.Detail.Metadata.Label title="Health" text={state} />
          <List.Item.Detail.Metadata.Label title="EPUB Version" text={report.epubVersion} />
          <List.Item.Detail.Metadata.Label title="Findings" text={String(report.findings.length)} />
          <List.Item.Detail.Metadata.Label title="Automatic Repair" text="Not Available" />
          <List.Item.Detail.Metadata.Separator />
          <List.Item.Detail.Metadata.TagList title="Finding Codes">
            {report.findings.map((finding) => (
              <List.Item.Detail.Metadata.TagList.Item key={finding.identity} text={finding.code} />
            ))}
          </List.Item.Detail.Metadata.TagList>
        </List.Item.Detail.Metadata>
      }
    />
  );
}
