import type { ProcessingFailure } from "../../domain/models/processing-failure";
import { err, ok, type Result } from "../../domain/models/result";

export type PickerPathProvider = () =>
  | readonly string[]
  | Promise<readonly string[]>
  | Result<readonly string[], ProcessingFailure>
  | Promise<Result<readonly string[], ProcessingFailure>>;

function isResult(
  value: readonly string[] | Result<readonly string[], ProcessingFailure>,
): value is Result<readonly string[], ProcessingFailure> {
  return !Array.isArray(value) && "ok" in value;
}

/** Adapts form state without importing React or Raycast UI components. */
export function createFilePickerSource(provider: PickerPathProvider): {
  readonly pickEpubPaths: () => Promise<Result<readonly string[], ProcessingFailure>>;
} {
  return {
    async pickEpubPaths() {
      try {
        const value = await provider();
        return isResult(value) ? value : ok([...value]);
      } catch {
        return err({
          category: "internal",
          code: "INTERNAL_FAILURE",
          safeMessage: "The selected files could not be opened.",
          retryable: true,
          phase: "selecting",
        });
      }
    },
  };
}

export function filePickerSource(paths: readonly string[]) {
  return createFilePickerSource(() => paths);
}
