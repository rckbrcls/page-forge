import { Action, ActionPanel, Detail, Icon, Keyboard } from "@raycast/api";

import type { SelectedEpub } from "../../domain/models/epub-document";
import type { Finding, FindingLocation, Severity } from "../../domain/models/finding";
import type { HealthReport, HealthState } from "../../domain/models/health-report";

export interface HealthReportDetailProps {
  readonly source: SelectedEpub;
  readonly report: HealthReport;
  readonly onPrepare?: (source: SelectedEpub) => void;
  readonly onReveal: (source: SelectedEpub) => void;
  readonly onCopyPath: (source: SelectedEpub) => void;
}

const SEVERITIES: readonly Severity[] = ["critical", "error", "warning", "info"];

const HEALTH_COLORS: Readonly<Record<HealthState, string>> = {
  healthy: "#30D158",
  repairable: "#FFD60A",
  needs_review: "#FF9F0A",
  unsupported: "#8E8E93",
  unsafe: "#FF453A",
};

export function healthBadge(health: HealthState) {
  return { value: health, color: HEALTH_COLORS[health] };
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
      const coordinates =
        location.line === undefined
          ? ""
          : `:${location.line}${location.column === undefined ? "" : `:${location.column}`}`;
      return `${location.path}${coordinates}`;
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
  const recommendation = finding.recommendedRepair ?? "None";
  return [
    `### ${finding.title}`,
    "",
    finding.description,
    "",
    `- **Code:** \`${finding.code}\``,
    `- **Category:** ${finding.category}`,
    `- **Location:** ${locationLabel(finding.location)}`,
    `- **Repairability:** ${finding.repairability}`,
    `- **Recommendation:** ${recommendation}`,
    `- **Compatibility impact:** ${titleCase(finding.stateImpact)}`,
  ].join("\n");
}

export function healthReportMarkdown(report: HealthReport): string {
  if (report.findings.length === 0) {
    return "# No Findings\n\nNo health findings were reported for this EPUB.";
  }

  const sections: string[] = ["# Findings"];
  for (const severity of SEVERITIES) {
    const severityFindings = report.findings.filter((finding) => finding.severity === severity);
    if (severityFindings.length === 0) continue;
    sections.push(`## ${titleCase(severity)}`);

    const categories = [...new Set(severityFindings.map(({ category }) => category))];
    for (const category of categories) {
      sections.push(
        `### ${titleCase(category)}`,
        ...severityFindings.filter((finding) => finding.category === category).map(findingMarkdown),
      );
    }
  }
  return sections.join("\n\n");
}

export function HealthReportDetail({ source, report, onPrepare, onReveal, onCopyPath }: HealthReportDetailProps) {
  return (
    <Detail
      navigationTitle={source.displayName}
      markdown={healthReportMarkdown(report)}
      metadata={
        <Detail.Metadata>
          <Detail.Metadata.Label title="Health" text={report.health} />
          <Detail.Metadata.Label title="EPUB Version" text={report.epubVersion} />
          <Detail.Metadata.Label title="Findings" text={String(report.findings.length)} />
          <Detail.Metadata.Label title="Duration" text={`${report.durationMs} ms`} />
          <Detail.Metadata.Label title="Inspected" text={new Date(report.inspectedAtMs).toLocaleString("en-US")} />
          <Detail.Metadata.Separator />
          <Detail.Metadata.Label title="File" text={source.displayName} />
          <Detail.Metadata.Label title="Size" text={`${source.sizeBytes} bytes`} />
          <Detail.Metadata.Label title="SHA-256" text={report.sourceFingerprint.sha256} />
        </Detail.Metadata>
      }
      actions={
        <ActionPanel>
          {report.health === "repairable" && onPrepare ? (
            <Action
              title="Prepare EPUB"
              icon={Icon.Hammer}
              shortcut={{ modifiers: ["cmd", "shift"], key: "p" }}
              onAction={() => onPrepare(source)}
            />
          ) : null}
          <Action
            title="Reveal in Finder"
            icon={Icon.Finder}
            shortcut={{ modifiers: ["cmd", "shift"], key: "f" }}
            onAction={() => onReveal(source)}
          />
          <Action
            title="Copy File Path"
            icon={Icon.Clipboard}
            shortcut={Keyboard.Shortcut.Common.Copy}
            onAction={() => onCopyPath(source)}
          />
        </ActionPanel>
      }
    />
  );
}
