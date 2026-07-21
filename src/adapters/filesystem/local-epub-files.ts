import { createHash, randomUUID } from "node:crypto";
import type { Stats } from "node:fs";
import { open, lstat, type FileHandle } from "node:fs/promises";
import { basename } from "node:path";

import type {
  FilesystemIdentity,
  SelectedEpub,
  SelectedEpubId,
  SelectionRejection,
  SelectionSnapshot,
  Sha256Digest,
  SourceFingerprint,
  SourceSnapshot,
  VerifiedDescriptorId,
  VerifiedReadDescriptor,
} from "../../domain/models/epub-document";
import { createFindingIdentity, type Finding } from "../../domain/models/finding";
import type { ProcessingFailure } from "../../domain/models/processing-failure";
import type { ProcessingPhase } from "../../domain/models/operation";
import { err, ok, type Result } from "../../domain/models/result";

interface OpenDescriptor {
  readonly descriptor: VerifiedReadDescriptor;
  readonly handle: FileHandle;
}

const descriptors = new Map<VerifiedDescriptorId, OpenDescriptor>();

function identity(stats: Stats): FilesystemIdentity {
  return { device: String(stats.dev), file: String(stats.ino) };
}

function snapshot(stats: Stats): SourceSnapshot {
  return { identity: identity(stats), sizeBytes: stats.size, modifiedAtMs: stats.mtimeMs };
}

function sameSnapshot(left: SourceSnapshot, right: SourceSnapshot): boolean {
  return (
    left.identity.device === right.identity.device &&
    left.identity.file === right.identity.file &&
    left.sizeBytes === right.sizeBytes &&
    left.modifiedAtMs === right.modifiedAtMs
  );
}

function failure(
  code: "INPUT_NOT_REGULAR_FILE" | "INPUT_UNREADABLE" | "INPUT_CHANGED",
  safeMessage: string,
  phase: ProcessingPhase = "selecting",
): ProcessingFailure {
  return {
    category: "input",
    code,
    safeMessage,
    retryable: code !== "INPUT_NOT_REGULAR_FILE",
    phase,
  };
}

function finding(
  code: "INPUT_NOT_EPUB" | "INPUT_NOT_REGULAR_FILE" | "INPUT_UNREADABLE" | "INPUT_CHANGED",
  description: string,
): Finding {
  const facts = {
    INPUT_NOT_EPUB: ["Unsupported file type", "unsupported"],
    INPUT_NOT_REGULAR_FILE: ["Not a regular file", "unsupported"],
    INPUT_UNREADABLE: ["File is not readable", "unsupported"],
    INPUT_CHANGED: ["File changed after selection", "needs_review"],
  } as const;
  return {
    identity: createFindingIdentity(code),
    code,
    severity: "error",
    category: "input",
    title: facts[code][0],
    description,
    repairability: "none",
    revalidation: "not_compared",
    evidence: {},
    stateImpact: facts[code][1],
  };
}

function rejection(
  selectionIndex: number,
  path: string,
  code: "INPUT_NOT_EPUB" | "INPUT_NOT_REGULAR_FILE" | "INPUT_UNREADABLE" | "INPUT_CHANGED",
  description: string,
): SelectionRejection {
  return { selectionIndex, displayName: basename(path), finding: finding(code, description) };
}

function errno(error: unknown): string | undefined {
  return typeof error === "object" && error !== null && "code" in error
    ? String((error as NodeJS.ErrnoException).code)
    : undefined;
}

export async function snapshotSource(path: string): Promise<Result<SelectedEpub, ProcessingFailure>> {
  let before: Stats;
  try {
    before = await lstat(path);
  } catch {
    return err(failure("INPUT_NOT_REGULAR_FILE", "The selected item is not a regular file."));
  }
  if (!before.isFile()) {
    return err(failure("INPUT_NOT_REGULAR_FILE", "The selected item is not a regular file."));
  }

  let handle: FileHandle | undefined;
  try {
    handle = await open(path, "r");
    const after = await handle.stat();
    if (!after.isFile() || !sameSnapshot(snapshot(before), snapshot(after))) {
      return err(failure("INPUT_CHANGED", "The selected file changed while it was being read."));
    }
    return ok({
      id: randomUUID() as SelectedEpubId,
      sourcePath: path,
      displayName: basename(path),
      ...snapshot(after),
      readable: true,
    });
  } catch (error) {
    if (errno(error) === "ENOENT") {
      return err(failure("INPUT_CHANGED", "The selected file changed while it was being read."));
    }
    return err(failure("INPUT_UNREADABLE", "The selected file cannot be opened for reading."));
  } finally {
    await handle?.close().catch(() => undefined);
  }
}

export async function snapshotSelection(
  paths: readonly string[],
  signal: AbortSignal,
): Promise<Result<SelectionSnapshot, ProcessingFailure>> {
  const items: SelectedEpub[] = [];
  const rejections: SelectionRejection[] = [];
  const identities = new Set<string>();

  for (const [selectionIndex, path] of paths.entries()) {
    if (signal.aborted) {
      return err({
        category: "cancelled",
        code: "OPERATION_CANCELLED",
        safeMessage: "The operation was cancelled.",
        retryable: false,
        phase: "selecting",
      });
    }
    if (!basename(path).toLocaleLowerCase("en-US").endsWith(".epub")) {
      rejections.push(rejection(selectionIndex, path, "INPUT_NOT_EPUB", "Only EPUB files are supported."));
      continue;
    }

    const result = await snapshotSource(path);
    if (!result.ok) {
      const code = result.failure.category === "input" ? result.failure.code : "INPUT_UNREADABLE";
      const inputCode =
        code === "INPUT_CHANGED" || code === "INPUT_UNREADABLE"
          ? code
          : "INPUT_NOT_REGULAR_FILE";
      rejections.push(rejection(selectionIndex, path, inputCode, result.failure.safeMessage));
      continue;
    }

    const key = `${result.value.identity.device}\0${result.value.identity.file}`;
    if (identities.has(key)) continue;
    identities.add(key);
    items.push(result.value);
  }

  return ok({ items, rejections, selectedAtMs: Date.now() });
}

export async function openVerifiedSource(
  selected: SelectedEpub,
): Promise<Result<VerifiedReadDescriptor, ProcessingFailure>> {
  let handle: FileHandle | undefined;
  try {
    handle = await open(selected.sourcePath, "r");
    const current = await handle.stat();
    if (!current.isFile() || !sameSnapshot(selected, snapshot(current))) {
      await handle.close();
      return err(
        failure("INPUT_CHANGED", "The selected file no longer matches its snapshot.", "preflight"),
      );
    }
    const descriptor: VerifiedReadDescriptor = {
      id: randomUUID() as VerifiedDescriptorId,
      sourceId: selected.id,
      snapshot: snapshot(current),
    };
    descriptors.set(descriptor.id, { descriptor, handle });
    return ok(descriptor);
  } catch (error) {
    await handle?.close().catch(() => undefined);
    if (errno(error) === "ENOENT") {
      return err(
        failure("INPUT_CHANGED", "The selected file no longer matches its snapshot.", "preflight"),
      );
    }
    return err(
      failure("INPUT_UNREADABLE", "The selected file cannot be opened for reading.", "preflight"),
    );
  }
}

export function resolveVerifiedFileHandle(descriptor: VerifiedReadDescriptor): FileHandle | undefined {
  const openDescriptor = descriptors.get(descriptor.id);
  return openDescriptor?.descriptor === descriptor ? openDescriptor.handle : undefined;
}

export async function closeVerifiedSource(
  descriptor: VerifiedReadDescriptor,
): Promise<Result<void, ProcessingFailure>> {
  const openDescriptor = descriptors.get(descriptor.id);
  if (!openDescriptor || openDescriptor.descriptor !== descriptor) return ok(undefined);
  descriptors.delete(descriptor.id);
  try {
    await openDescriptor.handle.close();
    return ok(undefined);
  } catch {
    return err({
      category: "archive",
      code: "ARCHIVE_CLOSE_FAILED",
      safeMessage: "The EPUB could not be closed safely.",
      retryable: true,
      phase: "preflight",
    });
  }
}

export async function verifyAndCloseVerifiedSource(
  descriptor: VerifiedReadDescriptor,
): Promise<Result<void, ProcessingFailure>> {
  const openDescriptor = descriptors.get(descriptor.id);
  if (!openDescriptor || openDescriptor.descriptor !== descriptor) {
    return err(
      failure("INPUT_CHANGED", "The verified file descriptor is no longer available.", "preflight"),
    );
  }

  let unchanged = false;
  try {
    const current = await openDescriptor.handle.stat();
    unchanged = current.isFile() && sameSnapshot(descriptor.snapshot, snapshot(current));
  } catch {
    unchanged = false;
  }

  const closeResult = await closeVerifiedSource(descriptor);
  if (!closeResult.ok) return closeResult;
  return unchanged
    ? ok(undefined)
    : err(
        failure("INPUT_CHANGED", "The selected file changed while it was being read.", "preflight"),
      );
}

export async function fingerprint(
  descriptor: VerifiedReadDescriptor,
  signal: AbortSignal,
): Promise<Result<SourceFingerprint, ProcessingFailure>> {
  const handle = resolveVerifiedFileHandle(descriptor);
  if (!handle) {
    return err(
      failure("INPUT_CHANGED", "The verified file descriptor is no longer available.", "preflight"),
    );
  }
  const hash = createHash("sha256");
  const stream = handle.createReadStream({ autoClose: false, start: 0 });
  const abort = () => stream.destroy();
  signal.addEventListener("abort", abort, { once: true });
  try {
    for await (const chunk of stream) {
      if (signal.aborted) {
        return err({
          category: "cancelled",
          code: "OPERATION_CANCELLED",
          safeMessage: "The operation was cancelled.",
          retryable: false,
          phase: "preflight",
        });
      }
      hash.update(chunk);
    }
    const current = snapshot(await handle.stat());
    if (!sameSnapshot(descriptor.snapshot, current)) {
      return err(
        failure("INPUT_CHANGED", "The selected file changed while it was being read.", "preflight"),
      );
    }
    return ok({ ...current, sha256: hash.digest("hex") as Sha256Digest });
  } catch {
    if (signal.aborted) {
      return err({
        category: "cancelled",
        code: "OPERATION_CANCELLED",
        safeMessage: "The operation was cancelled.",
        retryable: false,
        phase: "preflight",
      });
    }
    return err({
      category: "archive",
      code: "ARCHIVE_READ_FAILED",
      safeMessage: "The EPUB could not be read.",
      retryable: true,
      phase: "preflight",
    });
  } finally {
    signal.removeEventListener("abort", abort);
  }
}

export const localEpubFiles = {
  snapshotSource,
  snapshotSelection,
  openVerifiedSource,
  fingerprint,
  closeVerifiedSource,
  verifyAndCloseVerifiedSource,
} as const;
