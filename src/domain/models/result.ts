export type Result<T, F> = { readonly ok: true; readonly value: T } | { readonly ok: false; readonly failure: F };

export const ok = <T>(value: T): Result<T, never> => ({ ok: true, value });

export const err = <F>(failure: F): Result<never, F> => ({ ok: false, failure });

export function isOk<T, F>(result: Result<T, F>): result is { readonly ok: true; readonly value: T } {
  return result.ok;
}

export function isErr<T, F>(result: Result<T, F>): result is { readonly ok: false; readonly failure: F } {
  return !result.ok;
}

export function matchResult<T, F, R>(
  result: Result<T, F>,
  branches: {
    readonly ok: (value: T) => R;
    readonly err: (failure: F) => R;
  },
): R {
  return result.ok ? branches.ok(result.value) : branches.err(result.failure);
}

export function mapResult<T, U, F>(result: Result<T, F>, map: (value: T) => U): Result<U, F> {
  return result.ok ? ok(map(result.value)) : result;
}

export function mapFailure<T, F, G>(result: Result<T, F>, map: (failure: F) => G): Result<T, G> {
  return result.ok ? result : err(map(result.failure));
}

export function flatMapResult<T, U, F, G>(result: Result<T, F>, map: (value: T) => Result<U, G>): Result<U, F | G> {
  return result.ok ? map(result.value) : result;
}

export function assertNever(value: never): never {
  return value;
}
