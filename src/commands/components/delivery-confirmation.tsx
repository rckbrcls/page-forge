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
  const names = props.operation.items.map(({ displayName }) => `- ${displayName}`).join("\n");
  const configuration = props.configuration;
  const markdown = configuration
    ? `# Confirm Kindle Submission\n\n${names}\n\nSubmit ${props.operation.items.length} EPUB files through the configured SMTP server.`
    : `# Delivery Settings Required\n\n${names}\n\nConfigure SMTP delivery or use the official Send to Kindle page.`;

  return (
    <Detail
      markdown={markdown}
      metadata={
        <Detail.Metadata>
          <Detail.Metadata.Label title="Items" text={String(props.operation.items.length)} />
          {configuration ? (
            <>
              <Detail.Metadata.Label title="Sender" text={configuration.senderAddress} />
              <Detail.Metadata.Label title="Kindle Address" text={configuration.kindleAddress} />
              <Detail.Metadata.Label title="Security" text={securityModeLabel(configuration)} />
            </>
          ) : (
            <Detail.Metadata.Label title="SMTP" text="Not configured" />
          )}
        </Detail.Metadata>
      }
      actions={
        <ActionPanel>
          {configuration ? <Action title="Send EPUBs" icon={Icon.Envelope} onAction={props.onConfirm} /> : null}
          <Action title="Open Delivery Preferences" icon={Icon.Gear} onAction={props.onOpenPreferences} />
          <Action title="Open Send to Kindle" icon={Icon.Globe} onAction={props.onOpenSendToKindle} />
        </ActionPanel>
      }
    />
  );
}
