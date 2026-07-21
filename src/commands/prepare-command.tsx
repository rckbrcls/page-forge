import { Action, ActionPanel, Icon, List } from "@raycast/api";

import type { SelectedEpub, SelectedEpubId } from "../domain/models/epub-document";
import type { HealthReport, HealthState } from "../domain/models/health-report";
import type {
  BatchItemResult,
  BatchOperation,
  OperationProgress,
  ProcessingPhase,
} from "../domain/models/operation";
import type { PreparedEpub, RepairPlan } from "../domain/models/repair";
import { healthBadge, healthReportMarkdown } from "./components/health-report-detail";
import { PreparationActions } from "./components/preparation-actions";
import { RepairPlanDetail } from "./components/repair-plan-detail";
import { RevalidationDetail } from "./components/revalidation-detail";

export interface PrepareCommandViewProps {
  readonly operation: BatchOperation;
  readonly plans?: readonly RepairPlan[];
  readonly onConfirmPlan: (plan: RepairPlan) => void;
  readonly onRevealOutput: (prepared: PreparedEpub) => void;
  readonly onCopyOutputPath: (prepared: PreparedEpub) => void;
  readonly onOpenContainingFolder: (prepared: PreparedEpub) => void;
  readonly onViewFinalReport: (prepared: PreparedEpub) => void;
  readonly onSendToKindle: (prepared: PreparedEpub) => void;
  readonly onRetryFailed: () => void;
  readonly onCancel: () => void;
}

const HEALTH_TITLES: Readonly<Record<HealthState, string>> = {
  healthy: "No preparation is required",
  repairable: "Repairable",
  needs_review: "Needs Review",
  unsupported: "Unsupported",
  unsafe: "Unsafe",
};

function phaseLabel(phase: ProcessingPhase): string {
  return phase.replaceAll("_", " ");
}

function operationIsActive(operation: BatchOperation): boolean {
  return !["completed", "failed", "cancelled"].includes(operation.phase);
}

function resultForSource(
  results: readonly BatchItemResult[],
  sourceId: SelectedEpubId,
): BatchItemResult | undefined {
  return results.find(({ source }) => source.id === sourceId);
}

function planForSource(plans: readonly RepairPlan[], sourceId: SelectedEpubId) {
  return plans.find(({ source }) => source.id === sourceId);
}

function progressLabel(progress: OperationProgress | undefined): string {
  if (!progress) return "Progress is reported by the active phase.";
  const total = progress.total === undefined ? "unknown" : String(progress.total);
  return `${progress.completed} of ${total} ${progress.unit}`;
}

function reportDetail(report: HealthReport) {
  return (
    <List.Item.Detail
      markdown={`# ${HEALTH_TITLES[report.health]}\n\n${healthReportMarkdown(report)}`}
      metadata={
        <List.Item.Detail.Metadata>
          <List.Item.Detail.Metadata.Label title="Health" text={report.health} />
          <List.Item.Detail.Metadata.Label title="EPUB Version" text={report.epubVersion} />
          <List.Item.Detail.Metadata.Label title="Findings" text={String(report.findings.length)} />
          <List.Item.Detail.Metadata.TagList title="Finding Status">
            {report.findings.length === 0 ? (
              <List.Item.Detail.Metadata.TagList.Item text="No findings" />
            ) : (
              report.findings.map((finding) => (
                <List.Item.Detail.Metadata.TagList.Item
                  key={finding.identity}
                  text={`${finding.code} / ${finding.repairability}`}
                />
              ))
            )}
          </List.Item.Detail.Metadata.TagList>
        </List.Item.Detail.Metadata>
      }
    />
  );
}

function itemDetail(result: BatchItemResult | undefined, plan: RepairPlan | undefined) {
  if (plan) return RepairPlanDetail({ plan });
  if (result?.status === "prepared") {
    return RevalidationDetail({
      comparison: result.prepared.comparison,
      outputName: result.prepared.displayName,
    });
  }
  if (result?.status === "inspected") return reportDetail(result.report);
  if (result?.status === "failed") {
    if (result.preparation?.comparison) {
      return RevalidationDetail({
        comparison: result.preparation.comparison,
        failure: result.failure,
      });
    }
    return (
      <List.Item.Detail
        markdown={`# Preparation Failed\n\n**${result.failure.code}:** ${result.failure.safeMessage}`}
        metadata={
          <List.Item.Detail.Metadata>
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
  if (result?.status === "in_progress") {
    return (
      <List.Item.Detail
        markdown={`# Preparation in Progress\n\n**Phase:** ${phaseLabel(result.phase)}\n\n**Progress:** ${progressLabel(result.progress)}`}
      />
    );
  }
  if (result?.status === "cancelled") {
    return <List.Item.Detail markdown={`# Cancelled\n\nStopped during ${phaseLabel(result.phase)}.`} />;
  }
  return <List.Item.Detail markdown="# Pending\n\nWaiting for inspection." />;
}

function itemActions(
  result: BatchItemResult | undefined,
  plan: RepairPlan | undefined,
  props: PrepareCommandViewProps,
) {
  if (result?.status === "prepared") {
    return PreparationActions({ prepared: result.prepared, ...props });
  }

  return (
    <ActionPanel>
      {plan && props.operation.phase === "awaiting_confirmation" ? (
        <Action
          title="Prepare EPUB"
          icon={Icon.Hammer}
          shortcut={{ modifiers: ["cmd"], key: "enter" }}
          onAction={() => props.onConfirmPlan(plan)}
        />
      ) : null}
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

function itemSubtitle(result: BatchItemResult | undefined, plan: RepairPlan | undefined): string {
  if (plan) return `${plan.operations.length} reviewed operations`;
  if (!result) return "pending";
  switch (result.status) {
    case "pending":
      return "pending";
    case "in_progress":
      return `${phaseLabel(result.phase)}: ${progressLabel(result.progress)}`;
    case "inspected":
      return HEALTH_TITLES[result.report.health];
    case "prepared":
      return `Prepared: ${result.prepared.displayName}`;
    case "failed":
      return result.failure.safeMessage;
    case "cancelled":
      return `Cancelled during ${phaseLabel(result.phase)}`;
    case "submitted":
    case "delivery_unknown":
      return "Unexpected delivery result";
  }
}

function itemAccessories(result: BatchItemResult | undefined, plan: RepairPlan | undefined) {
  if (plan) return [{ tag: "plan ready" }, { text: `${plan.operations.length} operations` }];
  if (result?.status === "inspected") {
    return [
      { tag: healthBadge(result.report.health) },
      { text: `${result.report.findings.length} findings` },
    ];
  }
  if (result?.status === "prepared") return [{ tag: "healthy" }, { text: result.prepared.displayName }];
  if (result?.status === "in_progress") return [{ tag: phaseLabel(result.phase) }];
  if (result?.status === "failed") return [{ tag: "failed" }, { text: result.failure.code }];
  return [{ tag: result?.status ?? "pending" }];
}

export function PrepareCommandView(props: PrepareCommandViewProps) {
  const plans = props.plans ?? [];
  return (
    <List
      isLoading={operationIsActive(props.operation)}
      isShowingDetail
      navigationTitle="Prepare EPUB for Kindle"
      searchBarPlaceholder="Search EPUB preparation results"
    >
      {props.operation.items.map((source: SelectedEpub) => {
        const result = resultForSource(props.operation.results, source.id);
        const plan = planForSource(plans, source.id);
        return (
          <List.Item
            key={source.id}
            title={source.displayName}
            subtitle={itemSubtitle(result, plan)}
            icon={Icon.Book}
            accessories={itemAccessories(result, plan)}
            detail={itemDetail(result, plan)}
            actions={itemActions(result, plan, props)}
          />
        );
      })}
    </List>
  );
}

export default PrepareCommandView;
