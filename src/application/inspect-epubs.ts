import type { ClockPort } from "./ports";
import type { SelectedEpub, SelectionSnapshot } from "../domain/models/epub-document";
import type { HealthReport } from "../domain/models/health-report";
import type {
  BatchItemResult,
  BatchOperation,
  BatchOperationId,
  ProgressEvent,
} from "../domain/models/operation";
import type { ProcessingFailure } from "../domain/models/processing-failure";
import type { Result } from "../domain/models/result";

export interface InspectEpubPort {
  readonly inspect: (
    source: SelectedEpub,
    signal: AbortSignal,
  ) => Promise<Result<HealthReport, ProcessingFailure>>;
}

export interface InspectEpubsPorts {
  readonly inspection: InspectEpubPort;
  readonly clock: ClockPort;
}

export type InspectProgressListener = (event: ProgressEvent) => void;

function internalFailure(): ProcessingFailure {
  return {
    category: "internal",
    code: "INTERNAL_FAILURE",
    safeMessage: "The EPUB could not be inspected.",
    retryable: true,
    phase: "preflight",
  };
}

export async function inspectEpubs(
  snapshot: SelectionSnapshot,
  ports: InspectEpubsPorts,
  signal: AbortSignal,
  onProgress: InspectProgressListener,
): Promise<BatchOperation> {
  const operationId = `inspect:${snapshot.selectedAtMs}:${ports.clock.nowMs()}` as BatchOperationId;
  const results: BatchItemResult[] = snapshot.items.map((source) => ({ status: "pending", source }));
  let cancelled = signal.aborted;

  for (const [itemIndex, source] of snapshot.items.entries()) {
    if (signal.aborted) {
      cancelled = true;
      break;
    }

    onProgress({
      operationId,
      sourceId: source.id,
      itemIndex,
      phase: "preflight",
      progress: { completed: itemIndex, total: snapshot.items.length, unit: "files" },
      occurredAtMs: ports.clock.nowMs(),
    });

    let inspected: Result<HealthReport, ProcessingFailure>;
    try {
      inspected = await ports.inspection.inspect(source, signal);
    } catch {
      inspected = { ok: false, failure: internalFailure() };
    }

    if (inspected.ok) {
      results[itemIndex] = { status: "inspected", source, report: inspected.value };
    } else if (inspected.failure.category === "cancelled") {
      results[itemIndex] = { status: "cancelled", source, phase: inspected.failure.phase };
      cancelled = true;
    } else {
      results[itemIndex] = { status: "failed", source, failure: inspected.failure };
    }

    onProgress({
      operationId,
      sourceId: source.id,
      itemIndex,
      phase: cancelled ? "cancelled" : "completed",
      progress: { completed: itemIndex + 1, total: snapshot.items.length, unit: "files" },
      occurredAtMs: ports.clock.nowMs(),
    });
    if (cancelled || signal.aborted) {
      cancelled = true;
      break;
    }
  }

  if (cancelled) {
    for (const [index, result] of results.entries()) {
      if (result.status === "pending") {
        results[index] = { status: "cancelled", source: result.source, phase: "preflight" };
      }
    }
  }

  return {
    id: operationId,
    intent: "inspect",
    items: snapshot.items,
    phase: cancelled ? "cancelled" : "completed",
    cancellationRequested: cancelled,
    results,
  };
}
