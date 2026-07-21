import { Action, ActionPanel, Detail, Icon } from "@raycast/api";

export interface SetupRequiredDetailProps {
  readonly issue: string;
  readonly onOpenPreferences: () => void;
  readonly onCheckAgain: () => void;
}

export function SetupRequiredDetail(props: SetupRequiredDetailProps) {
  const markdown = `## Set Up Kindle Delivery

Configure email delivery before selecting a book. This keeps delivery problems separate from book checks.

### Check Your Settings

${props.issue}

Your books have not been selected or checked yet.`;

  return (
    <Detail
      navigationTitle="Delivery Setup"
      markdown={markdown}
      metadata={
        <Detail.Metadata>
          <Detail.Metadata.Label title="Status" text="Setup required" />
          <Detail.Metadata.Label title="Delivery" text="SMTP email" />
        </Detail.Metadata>
      }
      actions={
        <ActionPanel>
          <Action title="Open Delivery Preferences" icon={Icon.Gear} onAction={props.onOpenPreferences} />
          <Action title="Check Setup Again" icon={Icon.RotateClockwise} onAction={props.onCheckAgain} />
        </ActionPanel>
      }
    />
  );
}
