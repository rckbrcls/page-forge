import { Action, ActionPanel, Icon, List } from "@raycast/api";
import { createElement, type ComponentProps, type ComponentType } from "react";

import type { SelectedEpub, SelectedEpubId } from "../domain/models/epub-document";
import type { Finding } from "../domain/models/finding";
import type { HealthReport } from "../domain/models/health-report";
import type { BatchItemResult, BatchOperation, ProcessingPhase } from "../domain/models/operation";
import { healthBadge, healthReportMarkdown } from "./components/health-report-detail";

export interface InspectCommandViewProps {
  readonly operation: BatchOperation;
  readonly onViewReport: (source: SelectedEpub, report: HealthReport) => void;
  readonly onPrepare: (source: SelectedEpub) => void;
  readonly onReveal: (source: SelectedEpub) => void;
  readonly onCopyPath: (source: SelectedEpub) => void;
  readonly onRetryFailed: () => void;
  readonly onCancel: () => void;
}

type ActionWithSourceIdProps = ComponentProps<typeof Action> & {
  readonly sourceId: SelectedEpubId;
};

const ActionWithSourceId = Action as ComponentType<ActionWithSourceIdProps>;

function phaseLabel(phase: ProcessingPhase): string {
  return phase.replaceAll("_", " ");
}

function operationIsActive(operation: BatchOperation): boolean {
  return !["completed", "failed", "cancelled"].includes(operation.phase);
}

function findingSummary(findings: readonly Finding[]): string {
  if (findings.length === 0) return "No findings";
  const counts = new Map<string, number>();
  for (const finding of findings) {
    const key = `${finding.severity} ${finding.category}`;
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  return [...counts].map(([label, count]) => `${count} ${label}`).join(", ");
}

function resultForSource(
  results: readonly BatchItemResult[],
  sourceId: SelectedEpubId,
): BatchItemResult | undefined {
  return results.find(({ source }) => source.id === sourceId);
}

function reportMetadata(report: HealthReport) {
  return (
    <List.Item.Detail.Metadata>
      <List.Item.Detail.Metadata.Label title="Health" text={report.health} />
      <List.Item.Detail.Metadata.Label title="EPUB Version" text={report.epubVersion} />
      <List.Item.Detail.Metadata.Label title="Findings" text={String(report.findings.length)} />
      <List.Item.Detail.Metadata.Label title="Duration" text={`${report.durationMs} ms`} />
      <List.Item.Detail.Metadata.Separator />
      <List.Item.Detail.Metadata.TagList title="Finding Summary">
        {report.findings.length === 0 ? (
          <List.Item.Detail.Metadata.TagList.Item text="No findings" />
        ) : (
          report.findings.map((finding) => (
            <List.Item.Detail.Metadata.TagList.Item
              key={finding.identity}
              text={`${finding.code} / ${finding.category} / ${finding.repairability}`}
            />
          ))
        )}
      </List.Item.Detail.Metadata.TagList>
    </List.Item.Detail.Metadata>
  );
}

function itemDetail(result: BatchItemResult | undefined) {
  if (result?.status === "inspected") {
    return (
      <List.Item.Detail
        markdown={healthReportMarkdown(result.report)}
        metadata={reportMetadata(result.report)}
      />
    );
  }
  if (result?.status === "failed") {
    return (
      <List.Item.Detail
        markdown={`# Inspection Failed\n\n${result.failure.safeMessage}`}
        metadata={
          <List.Item.Detail.Metadata>
            <List.Item.Detail.Metadata.Label title="Code" text={result.failure.code} />
            <List.Item.Detail.Metadata.Label title="Category" text={result.failure.category} />
            <List.Item.Detail.Metadata.Label title="Phase" text={phaseLabel(result.failure.phase)} />
            <List.Item.Detail.Metadata.Label
              title="Retryable"
              text={result.failure.retryable ? "Yes" : "No"}
            />
          </List.Item.Detail.Metadata>
        }
      />
    );
  }
  const phase =
    result?.status === "in_progress" || result?.status === "cancelled"
      ? result.phase
      : "selecting";
  return (
    <List.Item.Detail
      markdown={`# ${result?.status === "cancelled" ? "Cancelled" : "Pending"}\n\n${phaseLabel(phase)}`}
    />
  );
}

function itemAccessories(result: BatchItemResult | undefined) {
  if (result?.status === "inspected") {
    return [
      { tag: healthBadge(result.report.health) },
      { text: `${result.report.findings.length} findings` },
    ];
  }
  if (result?.status === "failed") return [{ tag: "failed" }, { text: result.failure.code }];
  if (result?.status === "in_progress") return [{ tag: phaseLabel(result.phase) }];
  return [{ tag: result?.status ?? "pending" }];
}

function itemActions(
  source: SelectedEpub,
  result: BatchItemResult | undefined,
  props: InspectCommandViewProps,
) {
  const report = result?.status === "inspected" ? result.report : undefined;
  return (
    <ActionPanel>
      {report ? (
        <Action
          title="View Full Report"
          icon={Icon.Eye}
          shortcut={{ modifiers: ["cmd"], key: "enter" }}
          onAction={() => props.onViewReport(source, report)}
        />
      ) : null}
      {report?.health === "repairable"
        ? createElement(ActionWithSourceId, {
            title: "Prepare EPUB",
            icon: Icon.Hammer,
            shortcut: { modifiers: ["cmd", "shift"], key: "p" },
            sourceId: source.id,
            onAction: () => props.onPrepare(source),
          })
        : null}
      <Action
        title="Reveal in Finder"
        icon={Icon.Finder}
        shortcut={{ modifiers: ["cmd", "shift"], key: "f" }}
        onAction={() => props.onReveal(source)}
      />
      <Action
        title="Copy File Path"
        icon={Icon.Clipboard}
        shortcut={{ modifiers: ["cmd", "shift"], key: "c" }}
        onAction={() => props.onCopyPath(source)}
      />
      {result?.status === "failed" && result.failure.retryable ? (
        <Action
          title="Retry Failed Items"
          icon={Icon.RotateClockwise}
          shortcut={{ modifiers: ["cmd"], key: "r" }}
          onAction={props.onRetryFailed}
        />
      ) : null}
      {operationIsActive(props.operation) && !props.operation.cancellationRequested ? (
        <Action
          title="Cancel Active Operation"
          icon={Icon.XMarkCircle}
          shortcut={{ modifiers: ["cmd"], key: "." }}
          onAction={props.onCancel}
        />
      ) : null}
    </ActionPanel>
  );
}

export function InspectCommandView(props: InspectCommandViewProps) {
  const { operation } = props;
  const isLoading = operationIsActive(operation);

  return (
    <List
      isLoading={isLoading}
      isShowingDetail
      searchBarPlaceholder="Search inspected EPUBs"
      navigationTitle="Inspect EPUB"
    >
      {operation.items.map((source) => {
        const result = resultForSource(operation.results, source.id);
        const subtitle =
          result?.status === "inspected"
            ? findingSummary(result.report.findings)
            : result?.status === "failed"
              ? result.failure.safeMessage
              : result?.status === "in_progress"
                ? phaseLabel(result.phase)
                : result?.status ?? "pending";
        return (
          <List.Item
            key={source.id}
            title={source.displayName}
            subtitle={subtitle}
            icon={Icon.Book}
            accessories={itemAccessories(result)}
            detail={itemDetail(result)}
            actions={itemActions(source, result, props)}
          />
        );
      })}
    </List>
  );
}

export default InspectCommandView;
