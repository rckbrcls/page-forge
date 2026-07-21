import { Action, ActionPanel, Detail, Icon } from "@raycast/api";

import type { BatchOperation } from "../../domain/models/operation";

export interface DeliveryResultProps {
  readonly operation: BatchOperation;
  readonly onSendAgain: () => void;
  readonly onRetryFailed: () => void;
  readonly onOpenSendToKindle: () => void;
}

export function DeliveryResultDetail(props: DeliveryResultProps) {
  const lines = props.operation.results.map((result) => {
    if (result.status === "submitted") {
      return `- **${result.source.displayName}:** Submitted to the SMTP server.`;
    }
    if (result.status === "delivery_unknown") {
      return `- **${result.source.displayName}:** ${result.delivery.safeMessage}`;
    }
    if (result.status === "failed") {
      return `- **${result.source.displayName}:** ${result.failure.safeMessage}`;
    }
    if (result.status === "cancelled") return `- **${result.source.displayName}:** Cancelled.`;
    return `- **${result.source.displayName}:** ${result.status.replaceAll("_", " ")}.`;
  });
  const hasUnknown = props.operation.results.some(({ status }) => status === "delivery_unknown");
  const hasRetryableFailure = props.operation.results.some(
    (result) => result.status === "failed" && result.failure.retryable,
  );

  return (
    <Detail
      markdown={`# Kindle Submission Results\n\n${lines.join("\n")}\n\n${
        hasUnknown
          ? "Sending again may create a duplicate delivery. Confirm a new Send Again action explicitly."
          : "SMTP submission does not guarantee Amazon ingestion or Kindle delivery."
      }`}
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
