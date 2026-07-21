import type { SelectionPort } from "./ports";
import type { SelectedEpub, SelectionRejection, SelectionSnapshot } from "../domain/models/epub-document";
import { createFindingIdentity, type Finding } from "../domain/models/finding";
import type { ProcessingFailure } from "../domain/models/processing-failure";
import { err, ok, type Result } from "../domain/models/result";

function inputFinding(code: "INPUT_NOT_EPUB" | "INPUT_UNREADABLE", description: string): Finding {
  const title = code === "INPUT_NOT_EPUB" ? "Unsupported file type" : "File is not readable";
  return {
    identity: createFindingIdentity(code),
    code,
    severity: "error",
    category: "input",
    title,
    description,
    repairability: "none",
    revalidation: "not_compared",
    evidence: {},
    stateImpact: "unsupported",
  };
}

function normalizeSnapshot(snapshot: SelectionSnapshot): SelectionSnapshot {
  const identities = new Set<string>();
  const items: SelectedEpub[] = [];
  const rejections: SelectionRejection[] = [...snapshot.rejections];

  for (const [selectionIndex, item] of snapshot.items.entries()) {
    if (!/\.(?:epub|pdf)$/iu.test(item.displayName)) {
      rejections.push({
        selectionIndex,
        displayName: item.displayName,
        finding: inputFinding("INPUT_NOT_EPUB", "Only EPUB and PDF files are supported."),
      });
      continue;
    }
    if (!item.readable) {
      rejections.push({
        selectionIndex,
        displayName: item.displayName,
        finding: inputFinding("INPUT_UNREADABLE", "The file cannot be opened for reading."),
      });
      continue;
    }

    const identity = `${item.identity.device}\0${item.identity.file}`;
    if (identities.has(identity)) continue;
    identities.add(identity);
    items.push(item);
  }

  rejections.sort((left, right) => left.selectionIndex - right.selectionIndex);
  return { ...snapshot, items, rejections };
}

function cancelled(signal: AbortSignal): Result<never, ProcessingFailure> | undefined {
  if (!signal.aborted) return undefined;
  return err({
    category: "cancelled",
    code: "OPERATION_CANCELLED",
    safeMessage: "The operation was cancelled.",
    retryable: false,
    phase: "selecting",
  });
}

export async function selectEpubs(
  source: SelectionPort,
  signal: AbortSignal,
): Promise<Result<SelectionSnapshot, ProcessingFailure>> {
  const cancellation = cancelled(signal);
  if (cancellation) return cancellation;

  const finderPaths = await source.selectedFinderPaths();
  if (!finderPaths.ok) return finderPaths;

  const finderSnapshot = await source.snapshotSelection(finderPaths.value, signal);
  if (!finderSnapshot.ok) return finderSnapshot;
  const normalizedFinder = normalizeSnapshot(finderSnapshot.value);
  if (normalizedFinder.items.length > 0) return ok(normalizedFinder);

  const afterFinder = cancelled(signal);
  if (afterFinder) return afterFinder;

  const pickerPaths = await source.pickEpubPaths();
  if (!pickerPaths.ok) return pickerPaths;
  const pickerSnapshot = await source.snapshotSelection(pickerPaths.value, signal);
  return pickerSnapshot.ok ? ok(normalizeSnapshot(pickerSnapshot.value)) : pickerSnapshot;
}
