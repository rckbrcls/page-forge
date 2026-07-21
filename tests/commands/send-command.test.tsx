import { isValidElement, type ReactNode } from "react";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { SendCommandView, type SendCommandViewProps } from "../../src/commands/send-command";
import type { DeliveryConfiguration } from "../../src/domain/models/delivery";
import type { HealthReport, HealthState } from "../../src/domain/models/health-report";
import type { BatchOperation, BatchOperationId } from "../../src/domain/models/operation";
import type { Sha256Digest } from "../../src/domain/models/epub-document";
import type { ProcessingFailure } from "../../src/domain/models/processing-failure";
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

function actionByTitle(tree: readonly FlatElement[], title: string) {
  return actions(tree).find((entry) => String(entry.props.title) === title);
}

function actionByTitleContains(tree: readonly FlatElement[], title: string) {
  return actions(tree).find((entry) => String(entry.props.title).includes(title));
}

function reportFor(source: ReturnType<typeof selectedEpub>, health: HealthState): HealthReport {
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
    findings: [],
    inspectedAtMs: 1_721_476_800_000,
    durationMs: 11,
    ruleResults: [],
  };
}

const healthySource = selectedEpub("/fixtures/healthy.epub", "healthy.epub", "send-healthy");
const repairableSource = selectedEpub("/fixtures/repairable.epub", "repairable.epub", "send-repairable");

const confirmedConfiguration: DeliveryConfiguration = {
  senderAddress: "sender@example.com",
  smtpHost: "smtp.example.com",
  smtpPort: 465,
  securityMode: "implicit_tls",
  username: "smtp-user",
  appPassword: "smtp-secret" as DeliveryConfiguration["appPassword"],
  kindleAddress: "reader@kindle.com",
};

const handlers = {
  onPrepare: vi.fn(),
  onReveal: vi.fn(),
  onCopyPath: vi.fn(),
  onOpenContainingFolder: vi.fn(),
  onViewHealthReport: vi.fn(),
  onViewReport: vi.fn(),
  onOpenDeliveryPreferences: vi.fn(),
  onOpenPreferences: vi.fn(),
  onOpenSendToKindle: vi.fn(),
  onManualHandoff: vi.fn(),
  onConfirmSend: vi.fn(),
  onSend: vi.fn(),
  onConfirmSendSelection: vi.fn(),
  onSendAgainConfirmed: vi.fn(),
  onSendAgain: vi.fn(),
  onRetryFailed: vi.fn(),
  onCancel: vi.fn(),
  onCancelPendingDeliveries: vi.fn(),
};

function view(operation: BatchOperation, override: Partial<SendCommandViewProps> = {}) {
  return flatten(
    SendCommandView({
      operation,
      ...handlers,
      ...override,
    }) as ReactNode,
  );
}

describe("SendCommandView", () => {
  beforeEach(() => vi.clearAllMocks());

  it("supports optional settings by showing preference action and manual handoff with no SMTP block", () => {
    const operation: BatchOperation = {
      id: "send-operation-no-config" as BatchOperationId,
      intent: "send",
      items: [healthySource, repairableSource],
      phase: "awaiting_delivery_confirmation",
      activeIndex: 0,
      cancellationRequested: false,
      results: [
        { status: "inspected", source: healthySource, report: reportFor(healthySource, "healthy") },
        { status: "inspected", source: repairableSource, report: reportFor(repairableSource, "repairable") },
      ],
    };

    const tree = view(operation);
    const titles = actions(tree).map(({ props }) => String(props.title));

    expect(titles).toContain("Open Delivery Preferences");
    expect(titles).toContain("Open Send to Kindle");

    const prefAction = actionByTitle(tree, "Open Delivery Preferences");
    const handoffAction = actionByTitleContains(tree, "Send to Kindle");

    expect(prefAction).toBeDefined();
    expect(handoffAction).toBeDefined();

    expect(typeof prefAction?.props.onAction).toBe("function");
    expect(typeof handoffAction?.props.onAction).toBe("function");
  });

  it("renders confirmation detail with configured settings and confirms the eligible set", () => {
    const operation: BatchOperation = {
      id: "send-operation-confirm" as BatchOperationId,
      intent: "send",
      items: [healthySource, repairableSource],
      phase: "awaiting_delivery_confirmation",
      activeIndex: 0,
      cancellationRequested: false,
      results: [
        { status: "inspected", source: healthySource, report: reportFor(healthySource, "healthy") },
        { status: "inspected", source: repairableSource, report: reportFor(repairableSource, "repairable") },
      ],
    };

    const tree = view(operation, { deliveryConfiguration: confirmedConfiguration });
    const renderedContract = JSON.stringify(tree.map(({ props }) => props));
    const sendAction = actionByTitle(tree, "Send EPUBs");

    expect(renderedContract).toContain("healthy.epub");
    expect(renderedContract).toContain("repairable.epub");
    expect(renderedContract).toContain("sender@example.com");
    expect(renderedContract).toContain("reader@kindle.com");
    expect(renderedContract).toContain("Implicit TLS");
    expect(renderedContract).toContain("2");
    expect(sendAction).toBeDefined();

    expect(typeof sendAction?.props.onAction).toBe("function");
  });

  it("shows real progress while transmitting and exposes pending-delivery cancellation", () => {
    const operation: BatchOperation = {
      id: "send-operation-progress" as BatchOperationId,
      intent: "send",
      items: [healthySource],
      phase: "transmitting",
      activeIndex: 0,
      cancellationRequested: false,
      results: [
        {
          status: "in_progress",
          source: healthySource,
          phase: "transmitting",
          progress: { completed: 7, total: 12, unit: "entries" },
        },
      ],
    };

    const tree = view(operation, { deliveryConfiguration: confirmedConfiguration });
    const renderedContract = JSON.stringify(tree.map(({ props }) => props));

    expect(renderedContract).toContain("7");
    expect(renderedContract).toContain("12");
    expect(renderedContract).toContain("entries");
    expect(actions(tree).map(({ props }) => String(props.title))).toContain("Cancel Pending Deliveries");

    const cancel = actionByTitle(tree, "Cancel Pending Deliveries");
    expect(typeof cancel?.props.onAction).toBe("function");
  });

  it("shows sanitized send outcomes and does not expose raw sensitive delivery facts", () => {
    const deliveryFailure: ProcessingFailure = {
      category: "delivery_transport",
      code: "DELIVERY_DNS_FAILED",
      safeMessage: "The SMTP host could not be resolved.",
      retryable: true,
      phase: "connecting",
      facts: {
        smtpHost: "smtp.internal.example",
        username: "smtp-secret-user",
        appPassword: "super-secret-password",
        sourcePath: "/tmp/this/should/not/appear.epub",
      },
    };

    const operation: BatchOperation = {
      id: "send-operation-failed" as BatchOperationId,
      intent: "send",
      items: [healthySource],
      phase: "completed",
      cancellationRequested: false,
      results: [
        {
          status: "failed",
          source: healthySource,
          failure: deliveryFailure,
        },
      ],
    };

    const tree = view(operation, { deliveryConfiguration: confirmedConfiguration });
    const renderedContract = JSON.stringify(tree.map(({ props }) => props));

    expect(renderedContract).toContain("The SMTP host could not be resolved.");
    expect(renderedContract).not.toContain("smtp.internal.example");
    expect(renderedContract).not.toContain("smtp-secret-user");
    expect(renderedContract).not.toContain("super-secret-password");
    expect(renderedContract).not.toContain("/tmp/this/should/not/appear.epub");
  });

  it("shows Send Again warning for delivery_unknown and keeps retry explicit", () => {
    const tree = view(
      {
        id: "send-operation-unknown" as BatchOperationId,
        intent: "send",
        items: [healthySource],
        phase: "completed",
        cancellationRequested: false,
        results: [
          {
            status: "delivery_unknown",
            source: healthySource,
            delivery: {
              status: "delivery_unknown",
              sourceId: healthySource.id,
              displayName: healthySource.displayName,
              startedAtMs: 1_721_476_800_123,
              endedAtMs: 1_721_476_800_456,
              bytesStreamed: 1_024,
              manualRetryAllowed: true,
              failureCategory: "connection",
              safeMessage: "Submission could not be confirmed. The message may have been accepted.",
            },
          },
        ],
      },
      { deliveryConfiguration: confirmedConfiguration },
    );

    const renderedContract = JSON.stringify(tree.map(({ props }) => props));
    const titles = actions(tree).map(({ props }) => String(props.title));

    expect(titles).toContain("Send Again");
    expect(renderedContract.toLowerCase()).toContain("duplicate");

    const sendAgainAction = actionByTitle(tree, "Send Again");
    expect(typeof sendAgainAction?.props.onAction).toBe("function");
  });
});
