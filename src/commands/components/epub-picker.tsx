import { Action, ActionPanel, Form, Icon } from "@raycast/api";
import { useState } from "react";

import type { SelectionRejection } from "../../domain/models/epub-document";

export interface EpubPickerProps {
  readonly onSubmit: (paths: readonly string[]) => void | Promise<void>;
  readonly isLoading?: boolean;
  readonly rejections?: readonly SelectionRejection[];
}

export function EpubPicker({ onSubmit, isLoading = false, rejections = [] }: EpubPickerProps) {
  const [paths, setPaths] = useState<string[]>([]);
  const rejectionSummary = rejections
    .map(({ displayName, finding }) => `${displayName}: ${finding.description}`)
    .join("\n");

  return (
    <Form
      isLoading={isLoading}
      navigationTitle="Select Books"
      actions={
        <ActionPanel>
          <Action.SubmitForm
            title="Continue"
            icon={Icon.ArrowRight}
            onSubmit={(values) => onSubmit(values.paths as string[])}
          />
        </ActionPanel>
      }
    >
      <Form.FilePicker
        id="paths"
        title="EPUB or PDF Files"
        value={paths}
        allowMultipleSelection
        canChooseDirectories={false}
        canChooseFiles
        onChange={setPaths}
      />
      <Form.Description title="Selection" text="Choose one or more EPUB or PDF books. Originals are never modified." />
      {rejectionSummary ? <Form.Description title="Skipped Items" text={rejectionSummary} /> : null}
    </Form>
  );
}
