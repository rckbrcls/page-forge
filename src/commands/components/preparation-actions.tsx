import { Action, ActionPanel, Icon } from "@raycast/api";

import type { PreparedEpub } from "../../domain/models/repair";

export interface PreparationActionsProps {
  readonly prepared: PreparedEpub;
  readonly onRevealOutput: (prepared: PreparedEpub) => void;
  readonly onCopyOutputPath: (prepared: PreparedEpub) => void;
  readonly onOpenContainingFolder: (prepared: PreparedEpub) => void;
  readonly onViewFinalReport: (prepared: PreparedEpub) => void;
  readonly onSendToKindle: (prepared: PreparedEpub) => void;
}

export function PreparationActions({
  prepared,
  onRevealOutput,
  onCopyOutputPath,
  onOpenContainingFolder,
  onViewFinalReport,
  onSendToKindle,
}: PreparationActionsProps) {
  return (
    <ActionPanel>
      <Action title="Reveal Output in Finder" icon={Icon.Finder} onAction={() => onRevealOutput(prepared)} />
      <Action title="Copy Output Path" icon={Icon.Clipboard} onAction={() => onCopyOutputPath(prepared)} />
      <Action title="Open Containing Folder" icon={Icon.Folder} onAction={() => onOpenContainingFolder(prepared)} />
      <Action title="View Final Report" icon={Icon.Eye} onAction={() => onViewFinalReport(prepared)} />
      <Action title="Send EPUB to Kindle" icon={Icon.Envelope} onAction={() => onSendToKindle(prepared)} />
    </ActionPanel>
  );
}
