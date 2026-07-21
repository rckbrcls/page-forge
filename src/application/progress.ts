import { OPERATION_LIMITS } from "../domain/audit/limits";
import type { ProgressEvent } from "../domain/models/operation";
import { yieldToEventLoop } from "./cancellation";

export type ProgressListener = (event: ProgressEvent) => void;

export interface ProgressReporter {
  readonly emit: (event: ProgressEvent, force?: boolean) => void;
  readonly yieldIfDue: () => Promise<void>;
}

export function createProgressReporter(
  listener: ProgressListener,
  now: () => number = Date.now,
  intervalMs: number = OPERATION_LIMITS.maxUiBlockMs,
): ProgressReporter {
  let lastEmissionAt = Number.NEGATIVE_INFINITY;
  let lastYieldAt = now();
  let lastEventKey: string | undefined;

  return {
    emit: (event, force = false) => {
      const eventKey = `${event.sourceId ?? "batch"}:${event.phase}`;
      const phaseChanged = eventKey !== lastEventKey;
      if (!force && !phaseChanged && event.occurredAtMs - lastEmissionAt < intervalMs) return;
      lastEmissionAt = event.occurredAtMs;
      lastEventKey = eventKey;
      listener(event);
    },
    yieldIfDue: async () => {
      const currentTime = now();
      if (currentTime - lastYieldAt < intervalMs) return;
      await yieldToEventLoop();
      lastYieldAt = now();
    },
  };
}
