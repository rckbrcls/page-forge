import type { ClockPort, FilesystemPort, DeliveryPort } from "./ports";
import type { DeliveryConfiguration, DeliveryFailureCategory } from "../domain/models/delivery";
import type { ProcessingFailure } from "../domain/models/processing-failure";
import type { SourceFingerprint, VerifiedReadDescriptor, SelectedEpub } from "../domain/models/epub-document";
import type { DeliveryResult } from "../domain/models/delivery";
import type {
  BatchItemResult,
  BatchOperation,
  BatchOperationId,
  ProcessingPhase,
  ProgressEvent,
} from "../domain/models/operation";
import type { Result } from "../domain/models/result";

type SendCandidate = Extract<BatchItemResult, { readonly status: "inspected" | "prepared" }>;

export interface SendPorts {
  readonly filesystem: Pick<FilesystemPort, "snapshotSource" | "openVerifiedSource" | "fingerprint">;
  readonly delivery: DeliveryPort;
  readonly clock: ClockPort;
}

export type SendProgressListener = (event: ProgressEvent) => void;

type DeliveryFailureCode =
  | "DELIVERY_AUTH_FAILED"
  | "DELIVERY_DNS_FAILED"
  | "DELIVERY_CONNECTION_FAILED"
  | "DELIVERY_TLS_FAILED"
  | "DELIVERY_STREAM_FAILED"
  | "DELIVERY_TIMEOUT"
  | "DELIVERY_MESSAGE_REJECTED";

function internalFailure(phase: ProcessingPhase): ProcessingFailure {
  return {
    category: "internal",
    code: "INTERNAL_FAILURE",
    safeMessage: "The book could not be sent.",
    retryable: true,
    phase,
  };
}

function blockedDeliveryFailure(message: string, phase: ProcessingPhase): ProcessingFailure {
  return {
    category: "delivery_transport",
    code: "DELIVERY_MESSAGE_REJECTED",
    safeMessage: message,
    retryable: false,
    phase,
  };
}

function changedFailure(phase: ProcessingPhase): ProcessingFailure {
  return {
    category: "input",
    code: "INPUT_CHANGED",
    safeMessage: "The book file changed unexpectedly before it could be sent.",
    retryable: false,
    phase,
  };
}

function cancelledFailure(phase: ProcessingPhase): ProcessingFailure {
  return {
    category: "cancelled",
    code: "OPERATION_CANCELLED",
    safeMessage: "The operation was cancelled.",
    retryable: false,
    phase,
  };
}

function sameFingerprint(left: SourceFingerprint, right: SourceFingerprint): boolean {
  return (
    left.identity.device === right.identity.device &&
    left.identity.file === right.identity.file &&
    left.sizeBytes === right.sizeBytes &&
    left.modifiedAtMs === right.modifiedAtMs &&
    left.sha256 === right.sha256
  );
}

function deliverySource(candidate: SendCandidate): {
  readonly path: string;
  readonly reviewedFingerprint: SourceFingerprint;
} {
  if (candidate.status === "prepared") {
    return {
      path: candidate.prepared.outputPath,
      reviewedFingerprint: candidate.prepared.outputSnapshot,
    };
  }
  return {
    path: candidate.source.sourcePath,
    reviewedFingerprint: candidate.report.sourceFingerprint,
  };
}

function mapDeliveryFailure(category: DeliveryFailureCategory): DeliveryFailureCode {
  switch (category) {
    case "authentication":
      return "DELIVERY_AUTH_FAILED";
    case "dns":
      return "DELIVERY_DNS_FAILED";
    case "connection":
      return "DELIVERY_CONNECTION_FAILED";
    case "tls":
      return "DELIVERY_TLS_FAILED";
    case "stream":
      return "DELIVERY_STREAM_FAILED";
    case "timeout":
      return "DELIVERY_TIMEOUT";
    default:
      return "DELIVERY_MESSAGE_REJECTED";
  }
}

function emitProgress(
  listener: SendProgressListener,
  operationId: BatchOperationId,
  phase: ProcessingPhase,
  clock: ClockPort,
  sourceId?: SendCandidate["source"]["id"],
  itemIndex?: number,
  progress?: ProgressEvent["progress"],
): void {
  listener({
    operationId,
    sourceId,
    itemIndex,
    phase,
    progress,
    occurredAtMs: clock.nowMs(),
  });
}

export async function sendEpubs(
  confirmedSet: readonly SendCandidate[],
  configuration: DeliveryConfiguration,
  ports: SendPorts,
  signal: AbortSignal,
  onProgress: SendProgressListener,
): Promise<BatchOperation> {
  const operationId = `send:${ports.clock.nowMs()}` as BatchOperationId;
  const items = confirmedSet.map((entry) => entry.source);
  const results: BatchItemResult[] = confirmedSet.map((entry) => ({ status: "pending", source: entry.source }));

  let cancellationRequested = false;

  interface PendingTransmission {
    readonly index: number;
    readonly source: SendCandidate["source"];
    readonly reviewedFingerprint: SourceFingerprint;
    readonly descriptor: VerifiedReadDescriptor;
  }

  const readyToSend: PendingTransmission[] = [];

  const failItem = (index: number, failure: ProcessingFailure): void => {
    const source = confirmedSet[index].source;
    results[index] = {
      status: "failed",
      source,
      failure,
    };
  };

  for (const [index, candidate] of confirmedSet.entries()) {
    emitProgress(onProgress, operationId, "checking_delivery_eligibility", ports.clock, candidate.source.id, index, {
      completed: index,
      total: confirmedSet.length,
      unit: "files",
    });

    if (signal.aborted) {
      cancellationRequested = true;
      failItem(index, cancelledFailure("checking_delivery_eligibility"));
      results[index] = {
        status: "cancelled",
        source: candidate.source,
        phase: "checking_delivery_eligibility",
      };
      continue;
    }

    if (candidate.status === "inspected") {
      if (candidate.report.health !== "healthy" && candidate.report.health !== "repairable") {
        failItem(
          index,
          blockedDeliveryFailure(
            `The EPUB was blocked as ${candidate.report.health}.`,
            "checking_delivery_eligibility",
          ),
        );
        continue;
      }

      if (candidate.report.health === "repairable") {
        failItem(
          index,
          blockedDeliveryFailure(
            "This EPUB is repairable. Prepare it before sending to Kindle.",
            "checking_delivery_eligibility",
          ),
        );
        continue;
      }
    }

    if (candidate.status === "prepared") {
      if (candidate.prepared.outputPath.length === 0) {
        failItem(
          index,
          blockedDeliveryFailure("This EPUB has no prepared output file.", "checking_delivery_eligibility"),
        );
        continue;
      }
    }

    const expected = deliverySource(candidate);

    let snapshotResult: Result<SelectedEpub, ProcessingFailure>;
    try {
      snapshotResult = await ports.filesystem.snapshotSource(expected.path);
    } catch {
      snapshotResult = {
        ok: false,
        failure: internalFailure("checking_delivery_eligibility"),
      };
    }

    if (!snapshotResult.ok) {
      failItem(index, snapshotResult.failure);
      continue;
    }

    let descriptorResult: Result<VerifiedReadDescriptor, ProcessingFailure>;
    try {
      descriptorResult = await ports.filesystem.openVerifiedSource(snapshotResult.value);
    } catch {
      descriptorResult = {
        ok: false,
        failure: internalFailure("checking_delivery_eligibility"),
      };
    }

    if (!descriptorResult.ok) {
      failItem(index, descriptorResult.failure);
      continue;
    }

    let digestResult: Result<SourceFingerprint, ProcessingFailure>;
    try {
      digestResult = await ports.filesystem.fingerprint(descriptorResult.value, signal);
    } catch {
      digestResult = {
        ok: false,
        failure: internalFailure("checking_delivery_eligibility"),
      };
    }

    if (!digestResult.ok) {
      failItem(index, digestResult.failure);
      continue;
    }

    if (!sameFingerprint(digestResult.value, expected.reviewedFingerprint)) {
      failItem(index, changedFailure("checking_delivery_eligibility"));
      continue;
    }

    readyToSend.push({
      index,
      source: candidate.source,
      reviewedFingerprint: expected.reviewedFingerprint,
      descriptor: descriptorResult.value,
    });
  }

  if (readyToSend.length > 0) {
    emitProgress(onProgress, operationId, "awaiting_delivery_confirmation", ports.clock, undefined, 0);
  }

  for (const [sendIndex, pending] of readyToSend.entries()) {
    emitProgress(onProgress, operationId, "connecting", ports.clock, pending.source.id, pending.index, {
      completed: sendIndex + 1,
      total: readyToSend.length,
      unit: "files",
    });

    if (signal.aborted) {
      cancellationRequested = true;
      results[pending.index] = {
        status: "cancelled",
        source: pending.source,
        phase: "connecting",
      };
      break;
    }

    let submission: Result<DeliveryResult, ProcessingFailure>;

    const submitEventSink = (event: ProgressEvent): void => {
      onProgress({
        ...event,
        operationId,
      });
    };

    try {
      submission = await ports.delivery.submit(
        {
          source: pending.source,
          descriptor: pending.descriptor,
          reviewedFingerprint: pending.reviewedFingerprint,
        },
        configuration,
        signal,
        submitEventSink,
      );
    } catch {
      submission = {
        ok: false,
        failure: internalFailure("connecting"),
      };
    }

    emitProgress(onProgress, operationId, "transmitting", ports.clock, pending.source.id, pending.index);

    if (signal.aborted) {
      cancellationRequested = true;
      results[pending.index] = {
        status: "cancelled",
        source: pending.source,
        phase: "transmitting",
      };
      continue;
    }

    if (!submission.ok) {
      results[pending.index] = {
        status: "failed",
        source: pending.source,
        failure: submission.failure,
      };
      continue;
    }

    if (submission.value.status === "submitted") {
      results[pending.index] = {
        status: "submitted",
        source: pending.source,
        delivery: submission.value,
      };
      continue;
    }

    if (submission.value.status === "failed") {
      results[pending.index] = {
        status: "failed",
        source: pending.source,
        failure: {
          category: "delivery_transport",
          code: mapDeliveryFailure(submission.value.failureCategory),
          safeMessage: submission.value.safeMessage,
          retryable: submission.value.manualRetryAllowed,
          phase: "transmitting",
        },
      };
      continue;
    }

    if (submission.value.status === "delivery_unknown") {
      results[pending.index] = {
        status: "delivery_unknown",
        source: pending.source,
        delivery: submission.value,
      };
      continue;
    }

    if (submission.value.status === "cancelled") {
      results[pending.index] = {
        status: "cancelled",
        source: pending.source,
        phase: "transmitting",
      };
      continue;
    }

    results[pending.index] = {
      status: "failed",
      source: pending.source,
      failure: internalFailure("transmitting"),
    };
  }

  for (const [index, result] of results.entries()) {
    if (result.status === "pending") {
      results[index] = {
        status: "cancelled",
        source: result.source,
        phase: "completed",
      };
    }
  }

  const phase = cancellationRequested ? "cancelled" : "completed";

  return {
    id: operationId,
    intent: "send",
    items,
    phase,
    cancellationRequested,
    results,
  };
}
