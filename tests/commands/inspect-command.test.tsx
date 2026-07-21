import { isValidElement, type ReactNode } from "react";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { InspectCommandView } from "../../src/commands/inspect-command";
import type { InternalPath } from "../../src/domain/models/archive";
import type { Sha256Digest } from "../../src/domain/models/epub-document";
import { createFindingIdentity, type Finding } from "../../src/domain/models/finding";
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
  const nestedNodes = Object.values(props).flatMap(nestedReactNodes);
  return [{ type: node.type, props }, ...nestedNodes.flatMap((child) => flatten(child))];
}

function nestedReactNodes(value: unknown): ReactNode[] {
  if (isValidElement(value)) return [value];
  if (Array.isArray(value)) return value.flatMap(nestedReactNodes);
  return [];
}

function elementTypeName(type: unknown): string | undefined {
  if (typeof type === "string") return type;
  if (typeof type === "function" && "displayName" in type) {
    return String(type.displayName);
  }
  return undefined;
}

function reportFinding(): Finding {
  return {
    identity: createFindingIdentity("MIMETYPE_MISSING"),
    code: "MIMETYPE_MISSING",
    severity: "error",
    category: "mimetype",
    title: "Mimetype is missing",
    description: "The required root mimetype entry is absent.",
    location: { kind: "internal_path", path: "mimetype" as InternalPath },
    repairability: "automatic",
    recommendedRepair: "write_canonical_mimetype",
    revalidation: "not_compared",
    evidence: {},
    stateImpact: "repairable",
  };
}

const healthySource = selectedEpub("/fixtures/healthy.epub", "healthy.epub", "healthy");
const repairableSource = selectedEpub("/fixtures/repairable.epub", "repairable.epub", "repairable");
const failedSource = selectedEpub("/fixtures/failed.epub", "failed.epub", "failed");

function report(sourceId: typeof healthySource.id, health: HealthReport["health"]): HealthReport {
  const source = sourceId === healthySource.id ? healthySource : repairableSource;
  return {
    sourceId,
    sourceFingerprint: {
      identity: source.identity,
      sizeBytes: source.sizeBytes,
      modifiedAtMs: source.modifiedAtMs,
      sha256: `digest-${source.displayName}` as Sha256Digest,
    },
    epubVersion: "3",
    health,
    findings: health === "repairable" ? [reportFinding()] : [],
    inspectedAtMs: 1_721_476_800_000,
    durationMs: health === "repairable" ? 42 : 21,
    ruleResults: [],
  };
}

const operation: BatchOperation = {
  id: "inspect-operation" as BatchOperationId,
  intent: "inspect",
  items: [healthySource, repairableSource, failedSource],
  phase: "inspecting_content",
  activeIndex: 2,
  cancellationRequested: false,
  results: [
    { status: "inspected", source: healthySource, report: report(healthySource.id, "healthy") },
    {
      status: "inspected",
      source: repairableSource,
      report: report(repairableSource.id, "repairable"),
    },
    {
      status: "failed",
      source: failedSource,
      failure: {
        category: "archive",
        code: "ARCHIVE_READ_FAILED",
        safeMessage: "The EPUB could not be read.",
        retryable: true,
        phase: "preflight",
      },
    },
  ],
};

const handlers = {
  onViewReport: vi.fn(),
  onPrepare: vi.fn(),
  onReveal: vi.fn(),
  onCopyPath: vi.fn(),
  onRetryFailed: vi.fn(),
  onCancel: vi.fn(),
};

describe("InspectCommandView", () => {
  beforeEach(() => vi.clearAllMocks());

  it("renders stable result order and the required report summary fields", () => {
    const tree = flatten(InspectCommandView({ operation, ...handlers }) as ReactNode);
    const items = tree.filter(({ type }) => elementTypeName(type) === "List.Item");

    expect(items.map(({ props }) => props.title)).toEqual(["healthy.epub", "repairable.epub", "failed.epub"]);
    const renderedContract = JSON.stringify(tree.map(({ props }) => props));
    expect(renderedContract).toContain("healthy");
    expect(renderedContract).toContain("repairable");
    expect(renderedContract).toContain("EPUB Version");
    expect(renderedContract).toContain("Findings");
    expect(renderedContract).toContain("Duration");
    expect(renderedContract).toContain("ARCHIVE_READ_FAILED");
    expect(renderedContract).toContain("MIMETYPE_MISSING");
    expect(renderedContract).toContain("mimetype");
    expect(renderedContract).toContain("automatic");
    expect(renderedContract).toContain("write_canonical_mimetype");
  });

  it("offers every required inspection action and Prepare EPUB only for repairable items", () => {
    const tree = flatten(InspectCommandView({ operation, ...handlers }) as ReactNode);
    const actionTitles = tree.filter(({ type }) => elementTypeName(type) === "Action").map(({ props }) => props.title);

    expect(actionTitles).toContain("View Full Report");
    expect(actionTitles).toContain("Prepare EPUB");
    expect(actionTitles).toContain("Reveal in Finder");
    expect(actionTitles).toContain("Copy File Path");
    expect(actionTitles).toContain("Retry Failed Items");
    expect(actionTitles).toContain("Cancel Active Operation");

    const prepareActions = tree.filter(
      ({ type, props }) => elementTypeName(type) === "Action" && props.title === "Prepare EPUB",
    );
    expect(prepareActions).toHaveLength(1);
    expect(prepareActions[0]?.props.sourceId).toBe(repairableSource.id);
  });

  it("keeps command composition dependent on callbacks instead of real Raycast side effects", () => {
    const tree = flatten(InspectCommandView({ operation, ...handlers }) as ReactNode);
    const retry = tree.find(
      ({ type, props }) => elementTypeName(type) === "Action" && props.title === "Retry Failed Items",
    );
    const cancel = tree.find(
      ({ type, props }) => elementTypeName(type) === "Action" && props.title === "Cancel Active Operation",
    );

    expect(retry?.props.onAction).toBe(handlers.onRetryFailed);
    expect(cancel?.props.onAction).toBe(handlers.onCancel);
  });
});
