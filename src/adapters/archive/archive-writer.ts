import crc32 from "buffer-crc32";
import { createWriteStream } from "node:fs";
import { Readable, Transform, type TransformCallback } from "node:stream";
import { pipeline } from "node:stream/promises";
import { ZipFile } from "yazl";

import type { ArchiveLimits, ArchiveSession, TemporaryOutput } from "../../application/ports";
import type { ProgressListener } from "../../application/progress";
import type { ArchiveEntryDescriptor } from "../../domain/models/archive";
import type { ProcessingFailure } from "../../domain/models/processing-failure";
import type { AppliedRepair, RepairPlan } from "../../domain/models/repair";
import { err, ok, type Result } from "../../domain/models/result";

const CANONICAL_MIMETYPE = Buffer.from("application/epub+zip", "ascii");

class ReconstructionError extends Error {}

function cancelledFailure(): ProcessingFailure {
  return {
    category: "cancelled",
    code: "OPERATION_CANCELLED",
    safeMessage: "The operation was cancelled.",
    retryable: false,
    phase: "reconstructing",
  };
}

function writeFailure(): ProcessingFailure {
  return {
    category: "repair",
    code: "REPAIR_WRITE_FAILED",
    safeMessage: "The repaired book file could not be saved.",
    retryable: true,
    phase: "reconstructing",
  };
}

function isCanonicalMimetype(entry: ArchiveEntryDescriptor): boolean {
  return entry.originalName === "mimetype" || entry.path === "mimetype";
}

function checkedEntryStream(
  source: ArchiveSession,
  entry: ArchiveEntryDescriptor,
  limits: ArchiveLimits,
  signal: AbortSignal,
  addExpandedBytes: (bytes: number) => void,
): Readable {
  return Readable.from(
    (async function* () {
      if (signal.aborted) throw new ReconstructionError("cancelled");
      const opened = await source.openEntry(entry, signal);
      if (!opened.ok) throw new ReconstructionError(opened.failure.safeMessage);

      const readable = opened.value;
      let entryBytes = 0;
      let checksum = 0;
      let closeFailure: ReconstructionError | undefined;
      try {
        for await (const value of readable) {
          if (signal.aborted) throw new ReconstructionError("cancelled");
          const chunk = Buffer.isBuffer(value) ? value : Buffer.from(value);
          entryBytes += chunk.byteLength;
          if (entryBytes > entry.expandedSize || entryBytes > limits.maxExpandedEntryBytes) {
            throw new ReconstructionError("entry size limit exceeded");
          }
          addExpandedBytes(chunk.byteLength);
          checksum = crc32.unsigned(chunk, checksum);
          yield chunk;
        }
        if (entryBytes !== entry.expandedSize || checksum !== entry.crc32) {
          throw new ReconstructionError("entry integrity check failed");
        }
      } finally {
        const closed = await readable.close();
        if (!closed.ok) closeFailure = new ReconstructionError(closed.failure.safeMessage);
      }
      if (closeFailure !== undefined) throw closeFailure;
    })(),
  );
}

class OutputLimit extends Transform {
  private bytes = 0;

  constructor(private readonly maxBytes: number) {
    super();
  }

  override _transform(chunk: Buffer, _encoding: BufferEncoding, callback: TransformCallback): void {
    this.bytes += chunk.byteLength;
    if (this.bytes > this.maxBytes) {
      callback(new ReconstructionError("output size limit exceeded"));
      return;
    }
    callback(null, chunk);
  }
}

export async function rebuildArchive(
  source: ArchiveSession,
  plan: RepairPlan,
  temporary: TemporaryOutput,
  limits: ArchiveLimits,
  signal: AbortSignal,
  onProgress: ProgressListener,
): Promise<Result<readonly AppliedRepair[], ProcessingFailure>> {
  void onProgress;
  if (signal.aborted) return err(cancelledFailure());

  const zip = new ZipFile();
  let expandedBytes = CANONICAL_MIMETYPE.byteLength;
  const addExpandedBytes = (bytes: number) => {
    expandedBytes += bytes;
    if (expandedBytes > limits.maxExpandedTotalBytes) {
      throw new ReconstructionError("expanded size limit exceeded");
    }
  };

  try {
    if (CANONICAL_MIMETYPE.byteLength > limits.maxExpandedEntryBytes || expandedBytes > limits.maxExpandedTotalBytes) {
      throw new ReconstructionError("mimetype size limit exceeded");
    }
    zip.addBuffer(CANONICAL_MIMETYPE, "mimetype", { compress: false });
    for (const entry of source.projection.entries) {
      if (isCanonicalMimetype(entry)) continue;
      if (entry.kind === "directory") {
        zip.addEmptyDirectory(entry.originalName);
        continue;
      }
      if (entry.kind !== "file") throw new ReconstructionError("unsupported archive entry");
      if (entry.expandedSize > limits.maxExpandedEntryBytes) {
        throw new ReconstructionError("entry size limit exceeded");
      }
      const entryStream = checkedEntryStream(source, entry, limits, signal, addExpandedBytes);
      entryStream.once("error", (error) => {
        // yazl exposes a Node readable at runtime but types it as a web stream.
        (zip.outputStream as unknown as Readable).destroy(error);
      });
      zip.addReadStream(entryStream, entry.originalName, {
        compress: entry.compressionMethod !== 0,
        size: entry.expandedSize,
      });
    }
    zip.end();

    await pipeline(
      zip.outputStream,
      new OutputLimit(limits.maxOutputBytes),
      createWriteStream(temporary.path, { flags: "w", mode: 0o600 }),
      { signal },
    );

    const preservedEntryCount = source.projection.entries.filter((entry) => !isCanonicalMimetype(entry)).length;
    return ok(
      plan.operations.map((operation) => ({
        operationId: operation.id,
        outcome: "applied" as const,
        resolvedFindingIds: operation.findingIds,
        changedEntries: operation.changedPaths,
        preservedEntryCount,
      })),
    );
  } catch {
    return err(signal.aborted ? cancelledFailure() : writeFailure());
  }
}

export const archiveWriter = { rebuildArchive } as const;
