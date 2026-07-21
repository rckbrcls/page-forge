import { isValidElement, type ReactNode } from "react";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { PrepareCommandView } from "../../src/commands/prepare-command";
import type { InternalPath } from "../../src/domain/models/archive";
import type { Sha256Digest } from "../../src/domain/models/epub-document";
import { createFindingIdentity, type Finding } from "../../src/domain/models/finding";
import type { HealthReport, HealthState } from "../../src/domain/models/health-report";
import type { BatchOperation, BatchOperationId } from "../../src/domain/models/operation";
import type {
  PreparedEpub,
  RepairOperationId,
  RepairPlan,
} from "../../src/domain/models/repair";
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
  return [{ type: node.type, props }, ...nestedNodes.flatMap(flatten)];
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

function actions(tree: readonly FlatElement[]) {
  return tree.filter(({ type }) => elementTypeName(type) === "Action");
}

function finding(
  code: "MIMETYPE_MISSING" | "METADATA_TITLE_MISSING",
  repairability: Finding["repairability"],
  stateImpact: Finding["stateImpact"],
): Finding {
  const path = "mimetype" as InternalPath;
  return {
    identity: createFindingIdentity(code, { kind: "internal_path", path }),
    code,
    severity: code === "MIMETYPE_MISSING" ? "error" : "warning",
    category: code === "MIMETYPE_MISSING" ? "mimetype" : "package",
    title: code === "MIMETYPE_MISSING" ? "Mimetype is missing" : "Title is missing",
    description: "Deterministic prepare command fixture finding.",
    location: { kind: "internal_path", path },
    repairability,
    recommendedRepair: repairability === "automatic" ? "write_canonical_mimetype" : undefined,
    revalidation: "not_compared",
    evidence: {},
    stateImpact,
  };
}

const repairableSource = selectedEpub(
  "/fixtures/repairable.epub",
  "repairable.epub",
  "prepare-repairable",
);
const healthySource = selectedEpub("/fixtures/healthy.epub", "healthy.epub", "prepare-healthy");
const reviewSource = selectedEpub("/fixtures/review.epub", "review.epub", "prepare-review");
const unsupportedSource = selectedEpub(
  "/fixtures/unsupported.epub",
  "unsupported.epub",
  "prepare-unsupported",
);
const unsafeSource = selectedEpub("/fixtures/unsafe.epub", "unsafe.epub", "prepare-unsafe");

function report(
  source: typeof repairableSource,
  health: HealthState,
  findings: readonly Finding[] = [],
): HealthReport {
  return {
    sourceId: source.id,
    sourceFingerprint: {
      identity: source.identity,
      sizeBytes: source.sizeBytes,
      modifiedAtMs: source.modifiedAtMs,
      sha256: `sha256-${source.displayName}` as Sha256Digest,
    },
    epubVersion: "3",
    health,
    findings,
    inspectedAtMs: 1_721_476_800_000,
    durationMs: 30,
    ruleResults: [],
  } as HealthReport;
}

const repairableFinding = finding("MIMETYPE_MISSING", "automatic", "repairable");
const unresolvedFinding = finding("METADATA_TITLE_MISSING", "none", "needs_review");
const repairableReport = report(repairableSource, "repairable", [
  repairableFinding,
  unresolvedFinding,
]) as HealthReport & { readonly health: "repairable" };
const operationId = "prepare-operation" as BatchOperationId;
const operationIdForRepair = "write-mimetype" as RepairOperationId;

const plan: RepairPlan = {
  source: repairableSource,
  originalReport: repairableReport,
  operations: [
    {
      id: operationIdForRepair,
      kind: "write_canonical_mimetype",
      findingIds: [repairableFinding.identity],
      readPaths: [],
      changedPaths: ["mimetype" as InternalPath],
      explanation: "Write the required exact root mimetype entry.",
      value: "application/epub+zip",
    },
  ],
  unresolvedFindings: [{ finding: unresolvedFinding, reason: "Editorial metadata is not changed." }],
  predictedOutputPath: "/fixtures/repairable-kindle-ready.epub",
  createdAtMs: 1_721_476_800_010,
};

const prepared: PreparedEpub = {
  outputPath: "/fixtures/repairable-kindle-ready.epub",
  displayName: "repairable-kindle-ready.epub",
  sizeBytes: 4_128,
  report: report(repairableSource, "healthy") as HealthReport & { readonly health: "healthy" },
  comparison: {
    before: repairableReport,
    after: report(repairableSource, "healthy"),
    repairs: [],
    resolved: [repairableFinding.identity],
    remaining: [],
    introduced: [],
    successful: true,
    finalHealth: "healthy",
  },
  sourceFingerprint: repairableReport.sourceFingerprint,
  outputSnapshot: {
    identity: { device: "fixture-device", file: "prepared-output" },
    sizeBytes: 4_128,
    modifiedAtMs: 1_721_476_800_100,
    sha256: "sha256-prepared-output" as Sha256Digest,
  },
};

const handlers = {
  onConfirmPlan: vi.fn(),
  onRevealOutput: vi.fn(),
  onCopyOutputPath: vi.fn(),
  onOpenContainingFolder: vi.fn(),
  onViewFinalReport: vi.fn(),
  onSendToKindle: vi.fn(),
  onRetryFailed: vi.fn(),
  onCancel: vi.fn(),
};

function view(operation: BatchOperation, plans: readonly RepairPlan[] = []) {
  return flatten(PrepareCommandView({ operation, plans, ...handlers }) as ReactNode);
}

describe("PrepareCommandView", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.unstubAllGlobals();
  });

  it("shows the complete plan before exposing an explicit confirmation and performs no write on render", () => {
    const operation: BatchOperation = {
      id: operationId,
      intent: "prepare",
      items: [repairableSource],
      phase: "awaiting_confirmation",
      activeIndex: 0,
      cancellationRequested: false,
      results: [{ status: "inspected", source: repairableSource, report: repairableReport }],
    };

    const tree = view(operation, [plan]);
    const renderedContract = JSON.stringify(tree.map(({ props }) => props));
    const confirm = actions(tree).find(({ props }) => props.title === "Prepare EPUB");

    expect(renderedContract).toContain("write_canonical_mimetype");
    expect(renderedContract).toContain("MIMETYPE_MISSING");
    expect(renderedContract).toContain("METADATA_TITLE_MISSING");
    expect(renderedContract).toContain("Editorial metadata is not changed.");
    expect(renderedContract).toContain("repairable-kindle-ready.epub");
    expect(confirm).toBeDefined();
    expect(handlers.onConfirmPlan).not.toHaveBeenCalled();

    (confirm?.props.onAction as () => void)();
    expect(handlers.onConfirmPlan).toHaveBeenCalledOnce();
    expect(handlers.onConfirmPlan).toHaveBeenCalledWith(plan);
  });

  it.each([
    [healthySource, "healthy", "No preparation is required"],
    [reviewSource, "needs_review", "Needs Review"],
    [unsupportedSource, "unsupported", "Unsupported"],
    [unsafeSource, "unsafe", "Unsafe"],
  ] as const)("renders %s as %s without a repair action", (source, health, expectedText) => {
    const stateReport = report(source, health, [
      finding("METADATA_TITLE_MISSING", "none", health),
    ]);
    const operation: BatchOperation = {
      id: operationId,
      intent: "prepare",
      items: [source],
      phase: "completed",
      cancellationRequested: false,
      results: [{ status: "inspected", source, report: stateReport }],
    };
    const tree = view(operation);

    expect(JSON.stringify(tree.map(({ props }) => props))).toContain(expectedText);
    expect(actions(tree).map(({ props }) => props.title)).not.toContain("Prepare EPUB");
  });

  it("renders real entry progress and wires cancellation while preparation is active", () => {
    const operation: BatchOperation = {
      id: operationId,
      intent: "prepare",
      items: [repairableSource],
      phase: "reconstructing",
      activeIndex: 0,
      cancellationRequested: false,
      results: [
        {
          status: "in_progress",
          source: repairableSource,
          phase: "reconstructing",
          progress: { completed: 7, total: 12, unit: "entries" },
        },
      ],
    };
    const tree = view(operation);
    const renderedContract = JSON.stringify(tree.map(({ props }) => props));
    const cancel = actions(tree).find(({ props }) => props.title === "Cancel Active Operation");

    expect(renderedContract).toContain("reconstructing");
    expect(renderedContract).toContain("7");
    expect(renderedContract).toContain("12");
    expect(renderedContract).toContain("entries");
    expect(cancel?.props.onAction).toBe(handlers.onCancel);
  });

  it("offers exactly the five successful-result actions and delegates without network access", () => {
    const fetchSpy = vi.fn();
    vi.stubGlobal("fetch", fetchSpy);
    const operation: BatchOperation = {
      id: operationId,
      intent: "prepare",
      items: [repairableSource],
      phase: "completed",
      cancellationRequested: false,
      results: [{ status: "prepared", source: repairableSource, prepared }],
    };
    const tree = view(operation);
    const resultActions = actions(tree);

    expect(resultActions.map(({ props }) => props.title)).toEqual([
      "Reveal Output in Finder",
      "Copy Output Path",
      "Open Containing Folder",
      "View Final Report",
      "Send EPUB to Kindle",
    ]);

    for (const action of resultActions) (action.props.onAction as () => void)();

    expect(handlers.onRevealOutput).toHaveBeenCalledWith(prepared);
    expect(handlers.onCopyOutputPath).toHaveBeenCalledWith(prepared);
    expect(handlers.onOpenContainingFolder).toHaveBeenCalledWith(prepared);
    expect(handlers.onViewFinalReport).toHaveBeenCalledWith(prepared);
    expect(handlers.onSendToKindle).toHaveBeenCalledWith(prepared);
    expect(fetchSpy).not.toHaveBeenCalled();
  });
});
