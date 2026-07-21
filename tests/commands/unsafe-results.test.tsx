import { isValidElement, type ReactNode } from "react";
import { describe, expect, it, vi } from "vitest";

import { InspectCommandView } from "../../src/commands/inspect-command";
import { accountAuditRules } from "../../src/domain/audit/rule-catalog";
import { createFinding } from "../../src/domain/audit/finding-catalog";
import type { Sha256Digest } from "../../src/domain/models/epub-document";
import type { Finding } from "../../src/domain/models/finding";
import type { HealthReport } from "../../src/domain/models/health-report";
import type { BatchOperation, BatchOperationId } from "../../src/domain/models/operation";
import { selectedEpub } from "../fixtures/input/fixture-definitions";

vi.mock("@raycast/api", () => ({
  Action: mockComponent("Action"),
  ActionPanel: mockComponent("ActionPanel"),
  Detail: Object.assign(mockComponent("Detail"), {
    Metadata: metadataComponent("Detail.Metadata"),
  }),
  Icon: new Proxy({}, { get: (_target, property) => String(property) }),
  List: Object.assign(mockComponent("List"), {
    Item: Object.assign(mockComponent("List.Item"), {
      Detail: Object.assign(mockComponent("List.Item.Detail"), {
        Metadata: metadataComponent("List.Item.Detail.Metadata"),
      }),
    }),
  }),
}));

function mockComponent(name: string) {
  const component = ({ children }: { children?: ReactNode }) => children;
  component.displayName = name;
  return component;
}

function metadataComponent(name: string) {
  return Object.assign(mockComponent(name), {
    Label: mockComponent(`${name}.Label`),
    Link: mockComponent(`${name}.Link`),
    Separator: mockComponent(`${name}.Separator`),
    TagList: Object.assign(mockComponent(`${name}.TagList`), {
      Item: mockComponent(`${name}.TagList.Item`),
    }),
  });
}

interface FlatElement {
  readonly type: unknown;
  readonly props: Record<string, unknown>;
}

function flatten(node: ReactNode): FlatElement[] {
  if (!isValidElement(node)) return [];
  const props = node.props as Record<string, unknown> & { children?: ReactNode };
  const nested = Object.values(props).flatMap(nestedReactNodes);
  return [{ type: node.type, props }, ...nested.flatMap(flatten)];
}

function nestedReactNodes(value: unknown): ReactNode[] {
  if (isValidElement(value)) return [value];
  if (Array.isArray(value)) return value.flatMap(nestedReactNodes);
  return [];
}

function elementTypeName(type: unknown): string | undefined {
  if (typeof type === "string") return type;
  if (typeof type === "function" && "displayName" in type) return String(type.displayName);
  return undefined;
}

const handlers = {
  onViewReport: vi.fn(),
  onPrepare: vi.fn(),
  onReveal: vi.fn(),
  onCopyPath: vi.fn(),
  onRetryFailed: vi.fn(),
  onCancel: vi.fn(),
};

function report(
  source: ReturnType<typeof selectedEpub>,
  health: "unsafe" | "needs_review",
  finding: Finding,
): HealthReport {
  return {
    sourceId: source.id,
    sourceFingerprint: {
      identity: source.identity,
      sizeBytes: source.sizeBytes,
      modifiedAtMs: source.modifiedAtMs,
      sha256: `sha256-${source.displayName}` as Sha256Digest,
    },
    epubVersion: "unknown",
    health,
    findings: [finding],
    inspectedAtMs: 1_721_476_800_000,
    durationMs: 12,
    ruleResults: accountAuditRules([finding], {
      completedStages: new Set(),
      terminalReason: "Inspection stopped safely after this finding.",
    }),
  } as HealthReport;
}

describe("unsafe and ambiguous inspection results", () => {
  it.each([
    {
      health: "unsafe" as const,
      source: selectedEpub("/fixtures/traversal.epub", "traversal.epub", "command-unsafe"),
      finding: createFinding("ARCHIVE_PATH_TRAVERSAL", {
        location: { kind: "archive_entry", entryIndex: 2 },
        evidence: { originalName: "../../outside.xhtml" },
      }),
      stateLabel: "Unsafe",
    },
    {
      health: "needs_review" as const,
      source: selectedEpub("/fixtures/ambiguous.epub", "ambiguous.epub", "command-review"),
      finding: createFinding("PACKAGE_AMBIGUOUS"),
      stateLabel: "Needs Review",
    },
  ])("keeps a $health report actionable without repair or output actions", (fixture) => {
    const stateReport = report(fixture.source, fixture.health, fixture.finding);
    const operation: BatchOperation = {
      id: `inspect-${fixture.health}` as BatchOperationId,
      intent: "inspect",
      items: [fixture.source],
      phase: "completed",
      cancellationRequested: false,
      results: [{ status: "inspected", source: fixture.source, report: stateReport }],
    };

    const tree = flatten(InspectCommandView({ operation, ...handlers }) as ReactNode);
    const renderedContract = JSON.stringify(tree.map(({ props }) => props));
    const actionTitles = tree
      .filter(({ type }) => elementTypeName(type) === "Action")
      .map(({ props }) => props.title);

    expect(renderedContract).toContain(fixture.stateLabel);
    expect(renderedContract).toContain(fixture.finding.code);
    expect(renderedContract).toContain(fixture.finding.title);
    expect(renderedContract).toContain(fixture.finding.description);
    expect(renderedContract).toContain("Repairability");
    expect(renderedContract).toContain("None");
    expect(actionTitles).toEqual(["View Full Report", "Reveal in Finder", "Copy File Path"]);
    expect(actionTitles).not.toContain("Prepare EPUB");
    expect(actionTitles.some((title) => String(title).includes("Output"))).toBe(false);
    expect(renderedContract).not.toContain("kindle-ready.epub");
    expect(handlers.onPrepare).not.toHaveBeenCalled();
  });
});
