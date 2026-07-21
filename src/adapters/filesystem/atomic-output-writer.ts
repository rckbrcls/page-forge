import { createHash, randomUUID } from "node:crypto";
import { createReadStream } from "node:fs";
import { link, lstat, open, unlink, type FileHandle } from "node:fs/promises";
import { basename, dirname, extname, join } from "node:path";

import type {
  FinalOutput,
  PredictedOutput,
  TemporaryOutput,
} from "../../application/ports";
import type { Sha256Digest, SourceFingerprint } from "../../domain/models/epub-document";
import type { ProcessingFailure } from "../../domain/models/processing-failure";
import { err, ok, type Result } from "../../domain/models/result";

interface TemporaryIdentity {
  readonly path: string;
  readonly device: bigint;
  readonly file: bigint;
}

const ownedTemporaries = new WeakMap<TemporaryOutput, TemporaryIdentity>();

function errno(error: unknown): string | undefined {
  return typeof error === "object" && error !== null && "code" in error
    ? String((error as NodeJS.ErrnoException).code)
    : undefined;
}

function failure(
  code: "REPAIR_OUTPUT_UNWRITABLE" | "REPAIR_TEMP_CLEANUP_FAILED",
  phase: "planning" | "reconstructing" | "promoting",
): ProcessingFailure {
  return {
    category: "repair",
    code,
    safeMessage:
      code === "REPAIR_TEMP_CLEANUP_FAILED"
        ? "The temporary repaired EPUB could not be removed safely."
        : "The repaired EPUB output location is not writable.",
    retryable: true,
    phase,
  };
}

function outputPath(sourcePath: string, suffix: number): string {
  const extension = extname(sourcePath);
  const stem = sourcePath.slice(0, sourcePath.length - extension.length);
  return `${stem}-kindle-ready${suffix === 1 ? "" : `-${suffix}`}.epub`;
}

export async function predictOutput(
  sourcePath: string,
  suffix: number,
): Promise<Result<PredictedOutput, ProcessingFailure>> {
  if (!Number.isSafeInteger(suffix) || suffix < 1) {
    return err(failure("REPAIR_OUTPUT_UNWRITABLE", "planning"));
  }

  for (let current = suffix; Number.isSafeInteger(current); current += 1) {
    const candidatePath = outputPath(sourcePath, current);
    try {
      await lstat(candidatePath);
    } catch (error) {
      if (errno(error) === "ENOENT") return ok({ sourcePath, candidatePath, suffix: current });
      return err(failure("REPAIR_OUTPUT_UNWRITABLE", "planning"));
    }
  }
  return err(failure("REPAIR_OUTPUT_UNWRITABLE", "planning"));
}

export async function createSameDirectoryTemporary(
  prediction: PredictedOutput,
): Promise<Result<TemporaryOutput, ProcessingFailure>> {
  let handle: FileHandle | undefined;
  const id = randomUUID();
  const path = join(dirname(prediction.sourcePath), `.page-forge-${id}.tmp`);
  try {
    handle = await open(path, "wx", 0o600);
    await handle.close();
    handle = undefined;
    const stats = await lstat(path, { bigint: true });
    const temporary: TemporaryOutput = { id, path, prediction };
    ownedTemporaries.set(temporary, { path, device: stats.dev, file: stats.ino });
    return ok(temporary);
  } catch {
    await handle?.close().catch(() => undefined);
    return err(failure("REPAIR_OUTPUT_UNWRITABLE", "reconstructing"));
  }
}

async function fingerprint(path: string): Promise<SourceFingerprint> {
  const before = await lstat(path);
  const hash = createHash("sha256");
  for await (const chunk of createReadStream(path)) hash.update(chunk);
  const after = await lstat(path);
  if (
    !before.isFile() ||
    before.dev !== after.dev ||
    before.ino !== after.ino ||
    before.size !== after.size ||
    before.mtimeMs !== after.mtimeMs
  ) {
    throw new Error("Output changed while fingerprinting");
  }
  return {
    identity: { device: String(after.dev), file: String(after.ino) },
    sizeBytes: after.size,
    modifiedAtMs: after.mtimeMs,
    sha256: hash.digest("hex") as Sha256Digest,
  };
}

async function removeCreatedLink(path: string, temporaryPath: string): Promise<void> {
  try {
    const [candidate, temporary] = await Promise.all([lstat(path), lstat(temporaryPath)]);
    if (candidate.dev === temporary.dev && candidate.ino === temporary.ino) await unlink(path);
  } catch {
    // Never broaden cleanup after ownership can no longer be proved.
  }
}

export async function promoteNoClobber(
  temporary: TemporaryOutput,
  candidate: PredictedOutput,
): Promise<Result<FinalOutput, ProcessingFailure>> {
  const owned = ownedTemporaries.get(temporary);
  if (!owned || temporary.prediction.sourcePath !== candidate.sourcePath) {
    return err(failure("REPAIR_OUTPUT_UNWRITABLE", "promoting"));
  }

  try {
    const current = await lstat(temporary.path, { bigint: true });
    if (
      owned.path !== temporary.path ||
      !current.isFile() ||
      current.dev !== owned.device ||
      current.ino !== owned.file
    ) {
      return err(failure("REPAIR_OUTPUT_UNWRITABLE", "promoting"));
    }
  } catch {
    return err(failure("REPAIR_OUTPUT_UNWRITABLE", "promoting"));
  }

  for (let suffix = candidate.suffix; Number.isSafeInteger(suffix); suffix += 1) {
    const path = outputPath(candidate.sourcePath, suffix);
    try {
      await link(temporary.path, path);
    } catch (error) {
      if (errno(error) === "EEXIST") continue;
      return err(failure("REPAIR_OUTPUT_UNWRITABLE", "promoting"));
    }

    try {
      return ok({ path, displayName: basename(path), fingerprint: await fingerprint(path) });
    } catch {
      await removeCreatedLink(path, temporary.path);
      return err(failure("REPAIR_OUTPUT_UNWRITABLE", "promoting"));
    }
  }
  return err(failure("REPAIR_OUTPUT_UNWRITABLE", "promoting"));
}

export async function cleanupTemporary(
  temporary: TemporaryOutput,
): Promise<Result<void, ProcessingFailure>> {
  const owned = ownedTemporaries.get(temporary);
  if (!owned) return ok(undefined);
  try {
    const current = await lstat(temporary.path, { bigint: true });
    if (
      owned.path !== temporary.path ||
      !current.isFile() ||
      current.dev !== owned.device ||
      current.ino !== owned.file
    ) {
      return err(failure("REPAIR_TEMP_CLEANUP_FAILED", "reconstructing"));
    }
    await unlink(temporary.path);
    ownedTemporaries.delete(temporary);
    return ok(undefined);
  } catch (error) {
    if (errno(error) === "ENOENT") {
      ownedTemporaries.delete(temporary);
      return ok(undefined);
    }
    return err(failure("REPAIR_TEMP_CLEANUP_FAILED", "reconstructing"));
  }
}

export const atomicOutputWriter = {
  predictOutput,
  createSameDirectoryTemporary,
  promoteNoClobber,
  cleanupTemporary,
} as const;
