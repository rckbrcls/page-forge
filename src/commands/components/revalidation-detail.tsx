import { List } from "@raycast/api";

import type { ProcessingFailure } from "../../domain/models/processing-failure";
import type { RevalidationComparison } from "../../domain/models/repair";

export interface RevalidationDetailProps {
  readonly comparison: RevalidationComparison;
  readonly outputName?: string;
  readonly failure?: ProcessingFailure;
}

function identities(values: readonly string[]): string {
  return values.length === 0 ? "None" : values.map((value) => `- \`${value}\``).join("\n");
}

export function revalidationMarkdown({
  comparison,
  outputName,
  failure,
}: RevalidationDetailProps): string {
  const heading = comparison.successful ? "Revalidation Passed" : "Revalidation Failed";
  const introduced =
    comparison.introduced.length === 0
      ? "None"
      : comparison.introduced
          .map((finding) => `- \`${finding.code}\`: ${finding.title}`)
          .join("\n");

  return [
    `# ${heading}`,
    "",
    outputName
      ? `Output: \`${outputName}\``
      : "The reconstructed copy was compared with the original report.",
    ...(failure ? ["", `**${failure.code}:** ${failure.safeMessage}`] : []),
    "",
    `- **Final health:** ${comparison.finalHealth}`,
    `- **Applied repairs:** ${comparison.repairs.length}`,
    "",
    "## Resolved Findings",
    "",
    identities(comparison.resolved),
    "",
    "## Remaining Findings",
    "",
    identities(comparison.remaining),
    "",
    "## Introduced Findings",
    "",
    introduced,
  ].join("\n");
}

export function RevalidationDetail(props: RevalidationDetailProps) {
  const { comparison, outputName, failure } = props;
  return (
    <List.Item.Detail
      markdown={revalidationMarkdown(props)}
      metadata={
        <List.Item.Detail.Metadata>
          <List.Item.Detail.Metadata.Label
            title="Revalidation"
            text={comparison.successful ? "Passed" : "Failed"}
          />
          <List.Item.Detail.Metadata.Label title="Final Health" text={comparison.finalHealth} />
          <List.Item.Detail.Metadata.Label
            title="Resolved"
            text={String(comparison.resolved.length)}
          />
          <List.Item.Detail.Metadata.Label
            title="Remaining"
            text={String(comparison.remaining.length)}
          />
          <List.Item.Detail.Metadata.Label
            title="Introduced"
            text={String(comparison.introduced.length)}
          />
          {outputName ? (
            <List.Item.Detail.Metadata.Label title="Output" text={outputName} />
          ) : null}
          {failure ? <List.Item.Detail.Metadata.Label title="Failure" text={failure.code} /> : null}
        </List.Item.Detail.Metadata>
      }
    />
  );
}
