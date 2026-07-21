import { OPERATION_LIMITS } from "../domain/audit/limits";
import type { ProcessingPhase } from "../domain/models/operation";
import type { ProcessingFailure } from "../domain/models/processing-failure";

export type CancellationKind = "user" | "deadline";

export interface CancellationContext {
  readonly signal: AbortSignal;
  readonly kind: () => CancellationKind | undefined;
  readonly dispose: () => void;
}

export type CancellationCheckpoint =
  | { readonly status: "continue" }
  | { readonly status: "deadline"; readonly phase: ProcessingPhase }
  | {
      readonly status: "cancelled";
      readonly phase: ProcessingPhase;
      readonly failure: ProcessingFailure & { readonly category: "cancelled" };
    };

export function createCancellationContext(
  userSignal: AbortSignal,
  timeoutMs: number = OPERATION_LIMITS.perFileTimeoutMs,
): CancellationContext {
  const controller = new AbortController();
  let cancellationKind: CancellationKind | undefined;

  const cancelFromUser = (): void => {
    if (controller.signal.aborted) return;
    cancellationKind = "user";
    controller.abort("user");
  };

  if (userSignal.aborted) cancelFromUser();
  else userSignal.addEventListener("abort", cancelFromUser, { once: true });

  const timeout = setTimeout(() => {
    if (controller.signal.aborted) return;
    cancellationKind = "deadline";
    controller.abort("deadline");
  }, timeoutMs);

  return {
    signal: controller.signal,
    kind: () => cancellationKind,
    dispose: () => {
      clearTimeout(timeout);
      userSignal.removeEventListener("abort", cancelFromUser);
    },
  };
}

export function cancellationCheckpoint(
  signal: AbortSignal,
  phase: ProcessingPhase,
): CancellationCheckpoint {
  if (!signal.aborted) return { status: "continue" };
  if (signal.reason === "deadline") return { status: "deadline", phase };
  return {
    status: "cancelled",
    phase,
    failure: {
      category: "cancelled",
      code: "OPERATION_CANCELLED",
      safeMessage: "The operation was cancelled.",
      retryable: false,
      phase,
    },
  };
}

export async function yieldToEventLoop(): Promise<void> {
  await new Promise<void>((resolve) => setTimeout(resolve, 0));
}

export async function cooperativeCheckpoint(
  signal: AbortSignal,
  phase: ProcessingPhase,
): Promise<CancellationCheckpoint> {
  const beforeYield = cancellationCheckpoint(signal, phase);
  if (beforeYield.status !== "continue") return beforeYield;
  await yieldToEventLoop();
  return cancellationCheckpoint(signal, phase);
}
