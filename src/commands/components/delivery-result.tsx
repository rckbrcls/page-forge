import { Action, ActionPanel, Detail, Icon } from "@raycast/api";

import type { BatchOperation } from "../../domain/models/operation";

export interface DeliveryResultProps {
  readonly operation: BatchOperation;
  readonly onSendAgain: () => void;
  readonly onRetryFailed: () => void;
  readonly onOpenSendToKindle: () => void;
}

export function DeliveryResultDetail(props: DeliveryResultProps) {
  const submitted = props.operation.results.filter((result) => result.status === "submitted");
  const uncertain = props.operation.results.filter((result) => result.status === "delivery_unknown");
  const needsAttention = props.operation.results.filter(
    (result) => result.status !== "submitted" && result.status !== "delivery_unknown",
  );
  const submittedSection = submitted.length
    ? `### Submitted\n\n${submitted.map((result) => `- **${result.source.displayName}**: Accepted by the SMTP server.`).join("\n")}\n\n`
    : "";
  const uncertainSection = uncertain.length
    ? `### Delivery Uncertain\n\n${uncertain.map((result) => `- **${result.source.displayName}**: ${result.delivery.safeMessage}`).join("\n")}\n\n`
    : "";
  const attentionSection = needsAttention.length
    ? `### Needs Attention\n\n${needsAttention.map(resultDescription).join("\n")}\n\n`
    : "";
  const hasUnknown = props.operation.results.some(({ status }) => status === "delivery_unknown");
  const hasRetryableFailure = props.operation.results.some(
    (result) => result.status === "failed" && result.failure.retryable,
  );
  const title = needsAttention.length === 0 && !hasUnknown ? "Submission Complete" : "Kindle Delivery Results";

  return (
    <Detail
      navigationTitle={title}
      markdown={`## ${title}\n\n${submittedSection}${uncertainSection}${attentionSection}${
        hasUnknown
          ? "Sending again may create a duplicate. Review the uncertain items before trying again."
          : "SMTP submission does not guarantee Amazon ingestion or Kindle delivery."
      }`}
      metadata={
        <Detail.Metadata>
          <Detail.Metadata.Label title="Submitted" text={String(submitted.length)} />
          {uncertain.length > 0 ? <Detail.Metadata.Label title="Uncertain" text={String(uncertain.length)} /> : null}
          {needsAttention.length > 0 ? (
            <Detail.Metadata.Label title="Needs Attention" text={String(needsAttention.length)} />
          ) : null}
        </Detail.Metadata>
      }
      actions={
        <ActionPanel>
          {hasUnknown ? <Action title="Send Again" icon={Icon.Repeat} onAction={props.onSendAgain} /> : null}
          {hasRetryableFailure ? (
            <Action title="Retry Failed Items" icon={Icon.RotateClockwise} onAction={props.onRetryFailed} />
          ) : null}
          <Action title="Open Send to Kindle" icon={Icon.Globe} onAction={props.onOpenSendToKindle} />
        </ActionPanel>
      }
    />
  );
}

function resultDescription(result: BatchOperation["results"][number]): string {
  if (result.status === "failed") return `- **${result.source.displayName}**: ${result.failure.safeMessage}`;
  if (result.status === "cancelled") return `- **${result.source.displayName}**: Delivery was cancelled.`;
  return `- **${result.source.displayName}**: The book did not reach a final delivery result.`;
}
