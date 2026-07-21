import { describe, expect, it, vi } from "vitest";

import { sendEpubs } from "../../src/application/send-epubs";
import type { ClockPort, FilesystemPort, DeliveryPort } from "../../src/application/ports";
import type { DeliveryConfiguration, DeliveryResult, DeliverySecret } from "../../src/domain/models/delivery";
import type { ProcessingFailure } from "../../src/domain/models/processing-failure";
import type { BatchItemResult, ProcessingPhase, ProgressEvent } from "../../src/domain/models/operation";
import type {
  SelectedEpub,
  SelectedEpubId,
  SourceFingerprint,
  VerifiedReadDescriptor,
  VerifiedDescriptorId,
  Sha256Digest,
} from "../../src/domain/models/epub-document";
import type { HealthReport } from "../../src/domain/models/health-report";
import type { PreparedEpub } from "../../src/domain/models/repair";
import { ok } from "../../src/domain/models/result";
import type { Result } from "../../src/domain/models/result";
import { selectedEpub } from "../fixtures/input/fixture-definitions";
import { ProgressRecorder } from "../support/operation-harness";

const configuration: DeliveryConfiguration = {
  senderAddress: "sender@example.com",
  smtpHost: "smtp.example.com",
  smtpPort: 465,
  securityMode: "implicit_tls",
  username: "smtp-user",
  appPassword: "super-secret" as DeliverySecret,
  kindleAddress: "reader@kindle.com",
};

type SendCandidate = Extract<BatchItemResult, { readonly status: "inspected" | "prepared" }>;

type SendPorts = {
  readonly filesystem: Pick<FilesystemPort, "snapshotSource" | "openVerifiedSource" | "fingerprint">;
  readonly delivery: DeliveryPort;
  readonly clock: ClockPort;
};

type SendOperationResult = {
  readonly intent: "send";
  readonly items: readonly SelectedEpub[];
  readonly phase: ProcessingPhase;
  readonly results: readonly BatchItemResult[];
  readonly cancellationRequested: boolean;
};

interface SourceState {
  readonly source: SelectedEpub;
  readonly fingerprint: SourceFingerprint;
}

interface Submission {
  readonly sourceId: SelectedEpub["id"];
  readonly sourcePath: string;
}

class FakeFilesystemPort {
  readonly calls: string[] = [];
  readonly snapshotSource: ReturnType<typeof vi.fn>;
  readonly openVerifiedSource: ReturnType<typeof vi.fn>;
  readonly fingerprint: ReturnType<typeof vi.fn>;

  private readonly byPath: Map<string, SourceState> = new Map();
  private readonly byId: Map<SelectedEpub["id"], SourceState> = new Map();

  constructor(states: readonly SourceState[]) {
    for (const state of states) {
      this.byPath.set(state.source.sourcePath, state);
      this.byId.set(state.source.id, state);
    }
    this.snapshotSource = vi.fn(async (path: string) => {
      this.calls.push(`snapshot:${path}`);
      const state = this.byPath.get(path);
      if (!state) {
        return {
          ok: false,
          failure: {
            category: "internal",
            code: "INTERNAL_FAILURE",
            safeMessage: "No fixture available for source path.",
            retryable: false,
            phase: "checking_delivery_eligibility",
          },
        } as Result<never, ProcessingFailure>;
      }
      return ok(state.source);
    });

    this.openVerifiedSource = vi.fn(async (snapshot: SelectedEpub) => {
      this.calls.push(`open:${snapshot.sourcePath}`);
      return ok({
        id: `verified:${snapshot.id}` as VerifiedDescriptorId,
        sourceId: snapshot.id,
        snapshot,
      } satisfies VerifiedReadDescriptor);
    });

    this.fingerprint = vi.fn(async (descriptor: VerifiedReadDescriptor) => {
      this.calls.push(`fingerprint:${descriptor.sourceId}`);
      const state = this.byId.get(descriptor.sourceId);
      if (!state) {
        return {
          ok: false,
          failure: {
            category: "internal",
            code: "INTERNAL_FAILURE",
            safeMessage: "No fixture available for source descriptor.",
            retryable: false,
            phase: "checking_delivery_eligibility",
          },
        } as Result<never, ProcessingFailure>;
      }
      return ok(state.fingerprint);
    });
  }
}

class FakeDeliveryPort {
  readonly calls: Submission[] = [];
  readonly submit: ReturnType<typeof vi.fn>;
  readonly maxActive: { value: number } = { value: 0 };
  private active = 0;
  readonly response: (index: number, source: SelectedEpub) => DeliveryResult;

  constructor(
    response: (index: number, source: SelectedEpub) => DeliveryResult,
    private readonly latencyMs = 0,
  ) {
    this.response = response;
    this.submit = vi.fn(async (_submission: { readonly source: SelectedEpub }) => {
      const index = this.calls.length;
      this.active += 1;
      this.maxActive.value = Math.max(this.maxActive.value, this.active);
      await new Promise<void>((resolve) => setTimeout(resolve, this.latencyMs));
      this.calls.push({
        sourceId: _submission.source.id,
        sourcePath: _submission.source.sourcePath,
      });
      this.active -= 1;
      return ok(this.response(index, _submission.source));
    });
  }
}

const clock: ClockPort = { nowMs: () => 1_721_476_800_000 };

function report<THealth extends HealthReport["health"]>(
  source: SelectedEpub,
  health: THealth,
  fingerprint: SourceFingerprint,
): HealthReport & { readonly health: THealth } {
  return {
    sourceId: source.id,
    sourceFingerprint: fingerprint,
    epubVersion: "3",
    health,
    findings: [],
    inspectedAtMs: 1_721_476_800_000,
    durationMs: 15,
    ruleResults: [],
  } as HealthReport & { readonly health: THealth };
}

function deliveryResult(source: SelectedEpub, status: "submitted" | "failed", safeMessage?: string): DeliveryResult {
  if (status === "submitted") {
    return {
      status,
      sourceId: source.id,
      displayName: source.displayName,
      startedAtMs: 1_721_476_800_010,
      endedAtMs: 1_721_476_800_010,
      bytesStreamed: 4_096,
      manualRetryAllowed: false,
      smtpResponseCode: 250,
    } as const;
  }
  return {
    status,
    sourceId: source.id,
    displayName: source.displayName,
    startedAtMs: 1_721_476_800_010,
    endedAtMs: 1_721_476_800_010,
    bytesStreamed: 0,
    manualRetryAllowed: true,
    failureCategory: "message",
    safeMessage: safeMessage ?? "Submission failed.",
  } as const;
}

function fingerprintFor(source: SelectedEpub, digest: string): SourceFingerprint {
  return {
    identity: source.identity,
    sizeBytes: source.sizeBytes,
    modifiedAtMs: source.modifiedAtMs,
    sha256: digest as Sha256Digest,
  };
}

const healthySource = selectedEpub("/books/healthy.epub", "healthy.epub", "healthy-source");
const preparedSource = selectedEpub("/books/prepared.epub", "prepared.epub", "prepared-source");
const preparedOutputSource = selectedEpub(
  "/books/prepared-kindle-ready.epub",
  "prepared-kindle-ready.epub",
  "prepared-output",
  { sizeBytes: 8_192 },
);
const repairableSource = selectedEpub("/books/repairable.epub", "repairable.epub", "repairable-source");
const needsReviewSource = selectedEpub("/books/needs-review.epub", "needs-review.epub", "needs-review-source");
const unsupportedSource = selectedEpub("/books/unsupported.epub", "unsupported.epub", "unsupported-source");
const unsafeSource = selectedEpub("/books/unsafe.epub", "unsafe.epub", "unsafe-source");

const healthyFingerprint = fingerprintFor(healthySource, "sha256-healthy-reviewed");
const preparedSourceFingerprint = fingerprintFor(preparedSource, "sha256-prepared-reviewed");
const preparedOutputFingerprint = fingerprintFor(preparedOutputSource, "sha256-prepared-output");

const healthyReport = report(healthySource, "healthy", healthyFingerprint);
const preparedReport = report(preparedSource, "healthy", preparedOutputFingerprint);
const repairableReport = report(
  repairableSource,
  "repairable",
  fingerprintFor(repairableSource, "sha256-repairable-reviewed"),
);
const needsReviewReport = report(
  needsReviewSource,
  "needs_review",
  fingerprintFor(needsReviewSource, "sha256-needs-review-reviewed"),
);
const unsupportedReport = report(
  unsupportedSource,
  "unsupported",
  fingerprintFor(unsupportedSource, "sha256-unsupported-reviewed"),
);
const unsafeReport = report(unsafeSource, "unsafe", fingerprintFor(unsafeSource, "sha256-unsafe-reviewed"));

const preparedOutput: PreparedEpub = {
  outputPath: preparedOutputSource.sourcePath,
  displayName: preparedOutputSource.displayName,
  sizeBytes: preparedOutputSource.sizeBytes,
  report: preparedReport,
  comparison: {
    before: preparedReport,
    after: preparedReport,
    repairs: [],
    resolved: [],
    remaining: [],
    introduced: [],
    successful: true,
    finalHealth: "healthy",
  },
  sourceFingerprint: preparedSourceFingerprint,
  outputSnapshot: preparedOutputFingerprint,
};

function toCandidateSet(items: readonly SendCandidate[]): readonly SendCandidate[] {
  return items;
}

describe("sendEpubs", () => {
  it("allows healthy/prepared items, rejects repairable for prepare-first, and blocks needs review/unsupported/unsafe", async () => {
    const filesystem = new FakeFilesystemPort([
      { source: healthySource, fingerprint: healthyFingerprint },
      { source: preparedOutputSource, fingerprint: preparedOutputFingerprint },
      { source: repairableSource, fingerprint: fingerprintFor(repairableSource, "sha256-repairable-live") },
      { source: needsReviewSource, fingerprint: fingerprintFor(needsReviewSource, "sha256-needs-review-live") },
      { source: unsupportedSource, fingerprint: fingerprintFor(unsupportedSource, "sha256-unsupported-live") },
      { source: unsafeSource, fingerprint: fingerprintFor(unsafeSource, "sha256-unsafe-live") },
    ]);
    const delivery = new FakeDeliveryPort((index, source) => deliveryResult(source, "submitted"));
    const progress = new ProgressRecorder<ProgressEvent>();

    const result = (await sendEpubs(
      toCandidateSet([
        { status: "inspected", source: healthySource, report: healthyReport },
        { status: "prepared", source: preparedSource, prepared: preparedOutput },
        { status: "inspected", source: repairableSource, report: repairableReport },
        { status: "inspected", source: needsReviewSource, report: needsReviewReport },
        { status: "inspected", source: unsupportedSource, report: unsupportedReport },
        { status: "inspected", source: unsafeSource, report: unsafeReport },
      ]),
      configuration,
      {
        filesystem,
        delivery,
        clock,
      } as SendPorts,
      new AbortController().signal,
      progress.record,
    )) as SendOperationResult;

    expect(result.intent).toBe("send");
    expect(result.phase).toBe("completed");
    expect(delivery.calls).toHaveLength(2);

    const bySource = new Map(result.results.map((entry) => [entry.source.id, entry]));
    const healthyResult = bySource.get(healthySource.id);
    const preparedResult = bySource.get(preparedSource.id);
    const repairableResult = bySource.get(repairableSource.id);
    const needsReviewResult = bySource.get(needsReviewSource.id);
    const unsupportedResult = bySource.get(unsupportedSource.id);
    const unsafeResult = bySource.get(unsafeSource.id);

    expect(healthyResult).toMatchObject({ status: "submitted", delivery: { status: "submitted" } });
    expect(preparedResult).toMatchObject({ status: "submitted", delivery: { status: "submitted" } });

    if (repairableResult?.status === "failed") {
      expect(repairableResult.failure.safeMessage.toLowerCase()).toContain("prepare");
    } else {
      expect(repairableResult?.status).toBe("failed");
    }
    expect(repairableResult?.status).toBe("failed");
    expect(needsReviewResult?.status).toBe("failed");
    expect(unsupportedResult?.status).toBe("failed");
    expect(unsafeResult?.status).toBe("failed");
    expect(progress.events.map((event) => event.phase)).toEqual(
      expect.arrayContaining([
        "checking_delivery_eligibility",
        "awaiting_delivery_confirmation",
        "connecting",
        "transmitting",
      ]),
    );
  });

  it("requires explicit confirmation before transport starts", async () => {
    const filesystem = new FakeFilesystemPort([{ source: healthySource, fingerprint: healthyFingerprint }]);
    const delivery = new FakeDeliveryPort((_, source) => deliveryResult(source, "submitted"));
    const progress = new ProgressRecorder<ProgressEvent>();
    const signal = new AbortController().signal;

    await sendEpubs(
      toCandidateSet([{ status: "inspected", source: healthySource, report: healthyReport }]),
      configuration,
      {
        filesystem,
        delivery,
        clock,
      } as SendPorts,
      signal,
      progress.record,
    );

    const phases = progress.events.map((event) => event.phase);
    expect(phases).toContain("awaiting_delivery_confirmation");
    expect(phases.findIndex((phase) => phase === "awaiting_delivery_confirmation")).toBeGreaterThan(
      phases.findIndex((phase) => phase === "checking_delivery_eligibility"),
    );
    expect(phases.findIndex((phase) => phase === "awaiting_delivery_confirmation")).toBeLessThan(
      phases.findIndex((phase) => phase === "connecting"),
    );
  });

  it("sends explicit candidates sequentially with one transport in flight", async () => {
    const secondHealthySource = selectedEpub("/books/second.epub", "second.epub", "second-source");
    const thirdHealthySource = selectedEpub("/books/third.epub", "third.epub", "third-source");
    const sources = [healthySource, secondHealthySource, thirdHealthySource].map((source, index) => ({
      source,
      fingerprint: fingerprintFor(source, `sha256-seq-${index + 1}`),
      report: report(source, "healthy", fingerprintFor(source, `sha256-seq-${index + 1}`)),
    }));

    const filesystem = new FakeFilesystemPort(sources);
    const delivery = new FakeDeliveryPort((_, source) => deliveryResult(source, "submitted"), 5);
    const progress = new ProgressRecorder<ProgressEvent>();

    await sendEpubs(
      toCandidateSet(sources.map(({ source, report }) => ({ status: "inspected", source, report }))),
      configuration,
      {
        filesystem,
        delivery,
        clock,
      } as SendPorts,
      new AbortController().signal,
      progress.record,
    );

    expect(delivery.calls.map(({ sourceId }) => sourceId)).toEqual(sources.map(({ source }) => source.id));
    expect(delivery.maxActive.value).toBe(1);
    const connectingOrder = progress.events
      .filter((event) => event.phase === "connecting")
      .map((event) => event.sourceId)
      .filter((sourceId): sourceId is SelectedEpubId => sourceId !== undefined);
    expect(connectingOrder).toEqual(sources.map(({ source }) => source.id));
    expect(progress.events.filter((event) => event.phase === "transmitting").length).toBe(sources.length);
  });

  it("fails delivery when a reviewed digest no longer matches the checked source", async () => {
    const changedFingerprint = fingerprintFor(healthySource, "sha256-changed-after-inspection");
    const filesystem = new FakeFilesystemPort([{ source: healthySource, fingerprint: changedFingerprint }]);
    const delivery = new FakeDeliveryPort((_, source) => deliveryResult(source, "submitted"));

    const result = (await sendEpubs(
      toCandidateSet([{ status: "inspected", source: healthySource, report: healthyReport }]),
      configuration,
      {
        filesystem,
        delivery,
        clock,
      } as SendPorts,
      new AbortController().signal,
      vi.fn(),
    )) as SendOperationResult;

    expect(delivery.calls).toHaveLength(0);
    expect(result.results).toHaveLength(1);
    expect(result.results[0]).toMatchObject({ status: "failed" });
    if (result.results[0].status === "failed") {
      expect(result.results[0].failure.retryable).toBeTypeOf("boolean");
    }
  });

  it("does not auto-retry failed transport and maps one result per failed item", async () => {
    const secondSource = selectedEpub("/books/second.epub", "second.epub", "second-live-source");
    const filesystem = new FakeFilesystemPort([
      { source: healthySource, fingerprint: healthyFingerprint },
      { source: secondSource, fingerprint: fingerprintFor(secondSource, "sha256-second-live") },
    ]);
    const delivery = new FakeDeliveryPort((index, source) =>
      deliveryResult(source, "failed", "Authentication failed."),
    );
    const candidates = toCandidateSet([
      { status: "inspected", source: healthySource, report: healthyReport },
      {
        status: "inspected",
        source: secondSource,
        report: report(secondSource, "healthy", fingerprintFor(secondSource, "sha256-second-live")),
      },
    ]);

    const result = (await sendEpubs(
      candidates,
      configuration,
      {
        filesystem,
        delivery,
        clock,
      } as SendPorts,
      new AbortController().signal,
      vi.fn(),
    )) as SendOperationResult;

    const bySource = new Map(result.results.map((entry) => [entry.source.id, entry]));
    const healthyResult = bySource.get(healthySource.id);
    const secondResult = bySource.get(secondSource.id);

    expect(delivery.calls).toHaveLength(2);
    expect(healthyResult?.status).toBe("failed");
    expect(secondResult?.status).toBe("failed");
  });

  it("submits only confirmed eligible items and ignores unconfirmed candidates", async () => {
    const ignoredSource = selectedEpub("/books/ignore.epub", "ignore.epub", "ignore-source");
    const filesystem = new FakeFilesystemPort([
      { source: healthySource, fingerprint: healthyFingerprint },
      { source: ignoredSource, fingerprint: fingerprintFor(ignoredSource, "sha256-ignore-reviewed") },
    ]);
    const delivery = new FakeDeliveryPort((_, source) => deliveryResult(source, "submitted"));

    await sendEpubs(
      toCandidateSet([{ status: "inspected", source: healthySource, report: healthyReport }]),
      configuration,
      {
        filesystem,
        delivery,
        clock,
      } as SendPorts,
      new AbortController().signal,
      vi.fn(),
    );

    expect(delivery.calls).toHaveLength(1);
    expect(delivery.calls[0].sourceId).toBe(healthySource.id);
    expect(delivery.calls[0].sourcePath).toBe(healthySource.sourcePath);
  });
});
