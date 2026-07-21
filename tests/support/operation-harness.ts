export class FakeClock {
  readonly #initialMs: number;
  #currentMs: number;

  constructor(initial: Date | number = Date.UTC(2026, 0, 1)) {
    this.#initialMs = initial instanceof Date ? initial.getTime() : initial;
    this.#currentMs = this.#initialMs;
  }

  now(): Date {
    return new Date(this.#currentMs);
  }

  nowMs(): number {
    return this.#currentMs;
  }

  advance(milliseconds: number): void {
    if (!Number.isFinite(milliseconds) || milliseconds < 0) {
      throw new RangeError("Fake clock advances must be finite and non-negative");
    }
    this.#currentMs += milliseconds;
  }

  reset(): void {
    this.#currentMs = this.#initialMs;
  }
}

export class ProgressRecorder<Event> {
  readonly events: Event[] = [];

  readonly record = (event: Event): void => {
    this.events.push(event);
  };

  clear(): void {
    this.events.length = 0;
  }

  latest(): Event | undefined {
    return this.events.at(-1);
  }
}

export interface AbortHarness {
  readonly controller: AbortController;
  readonly signal: AbortSignal;
  abort(reason?: unknown): void;
  checkpoint(): void;
}

export function createAbortHarness(): AbortHarness {
  const controller = new AbortController();
  return {
    controller,
    signal: controller.signal,
    abort(reason?: unknown): void {
      controller.abort(reason);
    },
    checkpoint(): void {
      controller.signal.throwIfAborted();
    },
  };
}

export function abortAfterCheckpoints(count: number, reason?: unknown): {
  signal: AbortSignal;
  checkpoint(): void;
} {
  if (!Number.isInteger(count) || count < 1) {
    throw new RangeError("Checkpoint count must be a positive integer");
  }
  const controller = new AbortController();
  let remaining = count;
  return {
    signal: controller.signal,
    checkpoint(): void {
      remaining -= 1;
      if (remaining === 0) controller.abort(reason);
      controller.signal.throwIfAborted();
    },
  };
}

export async function nextEventLoopTurn(): Promise<void> {
  await new Promise<void>((resolve) => setImmediate(resolve));
}
