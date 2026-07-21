import { Action, ActionPanel, Detail, Icon } from "@raycast/api";

import type { DeliveryConfiguration } from "../../domain/models/delivery";
import type { BatchOperation } from "../../domain/models/operation";

export interface DeliveryConfirmationProps {
  readonly operation: BatchOperation;
  readonly configuration?: DeliveryConfiguration;
  readonly onConfirm: () => void;
  readonly onOpenPreferences: () => void;
  readonly onOpenSendToKindle: () => void;
}

function securityModeLabel(configuration: DeliveryConfiguration): string {
  return configuration.securityMode === "implicit_tls" ? "Implicit TLS" : "STARTTLS";
}

export function DeliveryConfirmation(props: DeliveryConfirmationProps) {
  const eligible = props.operation.results.filter(
    (result) => result.status === "prepared" || (result.status === "inspected" && result.report.health === "healthy"),
  );
  const blocked = props.operation.results.filter(
    (result) => !eligible.some((candidate) => candidate.source.id === result.source.id),
  );
  const fixedCount = eligible.reduce(
    (total, result) => total + (result.status === "prepared" ? result.prepared.comparison.resolved.length : 0),
    0,
  );
  const names = eligible.map(({ source }) => `- **${source.displayName}**`).join("\n");
  const blockedDetails = blocked.map(blockedDescription).join("\n");
  const configuration = props.configuration;
  const title = configuration
    ? eligible.length > 0
      ? "Ready to Send"
      : "Book Could Not Be Prepared"
    : "Delivery Setup Required";
  const readySection = names ? `### Ready\n\n${names}\n\n` : "";
  const repairSection =
    fixedCount > 0
      ? `${fixedCount} compatibility ${fixedCount === 1 ? "issue was" : "issues were"} repaired safely.\n\n`
      : "";
  const blockedSection = blockedDetails ? `### Needs Attention\n\n${blockedDetails}\n\n` : "";
  const markdown = configuration
    ? `## ${title}\n\n${readySection}${repairSection}${blockedSection}${eligible.length > 0 ? `${eligible.length === 1 ? "This book is" : "These books are"} ready for your confirmation.` : "No books will be sent. Review the issues above."}`
    : "## Delivery Setup Required\n\nConfigure SMTP delivery before preparing or sending books.";

  return (
    <Detail
      navigationTitle={title}
      markdown={markdown}
      metadata={
        <Detail.Metadata>
          <Detail.Metadata.Label title="Ready Books" text={String(eligible.length)} />
          {blocked.length > 0 ? <Detail.Metadata.Label title="Needs Attention" text={String(blocked.length)} /> : null}
          {configuration ? (
            <>
              <Detail.Metadata.Separator />
              <Detail.Metadata.Label title="Sender" text={configuration.senderAddress} />
              <Detail.Metadata.Label title="Kindle Address" text={configuration.kindleAddress} />
              <Detail.Metadata.Label title="SMTP Security" text={securityModeLabel(configuration)} />
            </>
          ) : (
            <Detail.Metadata.Label title="SMTP" text="Not configured" />
          )}
        </Detail.Metadata>
      }
      actions={
        <ActionPanel>
          {configuration && eligible.length > 0 ? (
            <Action title="Send Books" icon={Icon.Envelope} onAction={props.onConfirm} />
          ) : null}
          <Action title="Open Delivery Preferences" icon={Icon.Gear} onAction={props.onOpenPreferences} />
          {configuration && eligible.length > 0 ? (
            <Action title="Open Send to Kindle" icon={Icon.Globe} onAction={props.onOpenSendToKindle} />
          ) : null}
        </ActionPanel>
      }
    />
  );
}

function blockedDescription(result: BatchOperation["results"][number]): string {
  if (result.status === "failed") return `- **${result.source.displayName}:** ${result.failure.safeMessage}`;
  if (result.status === "inspected") {
    const reasons = result.report.findings
      .filter(({ stateImpact }) => stateImpact !== "healthy")
      .map(({ title }) => title)
      .join(", ");
    return `- **${result.source.displayName}:** ${reasons || "The book requires manual review."}`;
  }
  if (result.status === "cancelled") return `- **${result.source.displayName}:** Processing was cancelled.`;
  return `- **${result.source.displayName}:** The book is not ready for delivery.`;
}
