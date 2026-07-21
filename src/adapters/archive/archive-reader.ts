import crc32 from "buffer-crc32";
import type { FileHandle } from "node:fs/promises";
import { Readable } from "node:stream";
import { fromRandomAccessReaderPromise, RandomAccessReader, type Entry, type ZipFile } from "yauzl";

import type { ArchiveLimits, ArchivePreflightResult, ArchiveSession, BoundedReadable } from "../../application/ports";
import { inspectArchivePathSafety } from "./archive-path-safety";
import { parseInternalPath } from "../../domain/audit/internal-path";
import type {
  ArchiveEntryDescriptor,
  ArchiveEntryKind,
  ArchiveProjection,
  InternalPath,
} from "../../domain/models/archive";
import type { VerifiedReadDescriptor } from "../../domain/models/epub-document";
import { createFindingIdentity, type Finding } from "../../domain/models/finding";
import type { ProcessingFailure } from "../../domain/models/processing-failure";
import { err, ok, type Result } from "../../domain/models/result";
import {
  closeVerifiedSource,
  resolveVerifiedFileHandle,
  verifyAndCloseVerifiedSource,
} from "../filesystem/local-epub-files";

function archiveFailure(
  code: "ARCHIVE_OPEN_FAILED" | "ARCHIVE_READ_FAILED" | "ARCHIVE_STREAM_FAILED",
  safeMessage: string,
): ProcessingFailure {
  return { category: "archive", code, safeMessage, retryable: true, phase: "preflight" };
}

class FileHandleRandomAccessReader extends RandomAccessReader {
  constructor(private readonly handle: FileHandle) {
    super();
  }

  _readStreamForRange(start: number, end: number): Readable {
    const handle = this.handle;
    return Readable.from(
      (async function* () {
        for (let position = start; position < end;) {
          const buffer = Buffer.allocUnsafe(Math.min(64 * 1024, end - position));
          const { bytesRead } = await handle.read(buffer, 0, buffer.length, position);
          if (bytesRead === 0) return;
          position += bytesRead;
          yield buffer.subarray(0, bytesRead);
        }
      })(),
    );
  }

  close(callback: (error: Error | null) => void): void {
    callback(null);
  }
}

function zipFinding(code: "ZIP_INVALID" | "ZIP_EMPTY"): Finding {
  const invalid = code === "ZIP_INVALID";
  return {
    identity: createFindingIdentity(code),
    code,
    severity: invalid ? "critical" : "error",
    category: "archive",
    title: invalid ? "Invalid ZIP archive" : "Empty ZIP archive",
    description: invalid
      ? "The selected EPUB is not a complete readable ZIP archive."
      : "The selected EPUB archive contains no entries.",
    repairability: "none",
    revalidation: "not_compared",
    evidence: {},
    stateImpact: "unsupported",
  };
}

function terminalOutcome(finding: Finding): ArchivePreflightResult {
  return {
    outcome: {
      terminal: true,
      findings: [finding],
      ruleResults: [
        {
          ruleId: `finding:${finding.code}`,
          outcome: { status: "completed" },
          findingIds: [finding.identity],
        },
      ],
    },
  };
}

function terminalOutcomes(findings: readonly Finding[]): ArchivePreflightResult {
  return {
    outcome: {
      terminal: true,
      findings,
      ruleResults: findings.map((finding) => ({
        ruleId: `finding:${finding.code}`,
        outcome: { status: "completed" },
        findingIds: [finding.identity],
      })),
    },
  };
}

function entryKind(entry: Entry): ArchiveEntryKind {
  if (entry.fileName.endsWith("/")) return "directory";
  const host = entry.versionMadeBy >>> 8;
  if (host !== 3) return "file";
  const mode = entry.externalFileAttributes >>> 16;
  const type = mode & 0xf000;
  if (type === 0xa000) return "symlink";
  if (type !== 0 && type !== 0x8000) return "special";
  return "file";
}

async function describeEntry(entry: Entry, index: number, zip: ZipFile): Promise<ArchiveEntryDescriptor> {
  const parsed = parseInternalPath(entry.fileName);
  const localHeader = await zip.readLocalFileHeaderPromise(entry);
  return {
    index,
    originalName: entry.fileName,
    originalNameBytes: new Uint8Array(entry.fileNameRaw),
    path: parsed.ok ? parsed.value.path : { originalName: entry.fileName, reason: parsed.failure },
    kind: entryKind(entry),
    compressionMethod: entry.compressionMethod,
    compressedSize: entry.compressedSize,
    expandedSize: entry.uncompressedSize,
    crc32: entry.crc32 >>> 0,
    encrypted: entry.isEncrypted(),
    externalAttributes: entry.externalFileAttributes,
    flags: entry.generalPurposeBitFlag,
    localHeaderExtraLength: localHeader.extraFieldLength,
  };
}

class EntryReadable implements BoundedReadable {
  private released = false;
  private terminalFailure: ProcessingFailure | undefined;

  constructor(
    private readonly stream: Readable,
    private readonly entry: ArchiveEntryDescriptor,
    private readonly maxBytes: number,
    private readonly signal: AbortSignal,
    private readonly release: () => void,
  ) {}

  async *[Symbol.asyncIterator](): AsyncIterator<Uint8Array> {
    let bytes = 0;
    let checksum = 0;
    const abort = () => this.stream.destroy();
    this.signal.addEventListener("abort", abort, { once: true });
    try {
      for await (const value of this.stream) {
        if (this.signal.aborted) {
          this.terminalFailure = {
            category: "cancelled",
            code: "OPERATION_CANCELLED",
            safeMessage: "The operation was cancelled.",
            retryable: false,
            phase: "preflight",
          };
          break;
        }
        const chunk = Buffer.isBuffer(value) ? value : Buffer.from(value as Uint8Array);
        bytes += chunk.length;
        if (bytes > this.entry.expandedSize || bytes > this.maxBytes) {
          this.terminalFailure = archiveFailure(
            "ARCHIVE_STREAM_FAILED",
            "The archive entry has an invalid expanded size.",
          );
          break;
        }
        checksum = crc32.unsigned(chunk, checksum);
        yield chunk;
      }
      if (!this.terminalFailure && (bytes !== this.entry.expandedSize || checksum !== this.entry.crc32)) {
        this.terminalFailure = archiveFailure("ARCHIVE_STREAM_FAILED", "The archive entry failed its integrity check.");
      }
    } catch {
      this.terminalFailure = this.signal.aborted
        ? {
            category: "cancelled",
            code: "OPERATION_CANCELLED",
            safeMessage: "The operation was cancelled.",
            retryable: false,
            phase: "preflight",
          }
        : archiveFailure("ARCHIVE_STREAM_FAILED", "The archive entry could not be read.");
    } finally {
      this.signal.removeEventListener("abort", abort);
      this.releaseStream();
    }
  }

  async close(): Promise<Result<void, ProcessingFailure>> {
    this.releaseStream();
    return this.terminalFailure ? err(this.terminalFailure) : ok(undefined);
  }

  private releaseStream(): void {
    if (this.released) return;
    this.released = true;
    this.stream.destroy();
    this.release();
  }
}

class YauzlArchiveSession implements ArchiveSession {
  private active = false;
  private activeReadable: BoundedReadable | undefined;
  private closed = false;

  constructor(
    readonly projection: ArchiveProjection,
    private readonly zip: ZipFile,
    private readonly descriptor: VerifiedReadDescriptor,
    private readonly sourceEntries: ReadonlyMap<number, Entry>,
    private readonly limits: ArchiveLimits,
  ) {}

  async openEntry(
    entry: ArchiveEntryDescriptor,
    signal: AbortSignal,
  ): Promise<Result<BoundedReadable, ProcessingFailure>> {
    if (this.closed || this.active || signal.aborted) {
      if (signal.aborted) {
        return err({
          category: "cancelled",
          code: "OPERATION_CANCELLED",
          safeMessage: "The operation was cancelled.",
          retryable: false,
          phase: "preflight",
        });
      }
      return err(archiveFailure("ARCHIVE_STREAM_FAILED", "The archive entry cannot be opened."));
    }
    const source = this.sourceEntries.get(entry.index);
    if (!source) return err(archiveFailure("ARCHIVE_STREAM_FAILED", "The archive entry is unavailable."));
    try {
      const stream = await this.zip.openReadStreamPromise(source);
      this.active = true;
      const readable = new EntryReadable(stream, entry, this.limits.maxExpandedEntryBytes, signal, () => {
        this.active = false;
        this.activeReadable = undefined;
      });
      this.activeReadable = readable;
      return ok(readable);
    } catch {
      return err(archiveFailure("ARCHIVE_STREAM_FAILED", "The archive entry could not be read."));
    }
  }

  async close(): Promise<Result<void, ProcessingFailure>> {
    if (this.closed) return ok(undefined);
    this.closed = true;
    const streamClose = await this.activeReadable?.close();
    const descriptorClose = await verifyAndCloseVerifiedSource(this.descriptor);
    try {
      this.zip.close();
    } catch {
      // Closing yauzl releases its reader; the descriptor remains ours.
    }
    if (streamClose && !streamClose.ok) return streamClose;
    return descriptorClose;
  }
}

export async function preflightArchive(
  descriptor: VerifiedReadDescriptor,
  limits: ArchiveLimits,
  signal: AbortSignal,
): Promise<Result<ArchivePreflightResult, ProcessingFailure>> {
  const handle = resolveVerifiedFileHandle(descriptor);
  if (!handle) return err(archiveFailure("ARCHIVE_OPEN_FAILED", "The EPUB could not be opened."));
  if (signal.aborted) {
    await closeVerifiedSource(descriptor);
    return err({
      category: "cancelled",
      code: "OPERATION_CANCELLED",
      safeMessage: "The operation was cancelled.",
      retryable: false,
      phase: "preflight",
    });
  }

  let zip: ZipFile;
  try {
    zip = await fromRandomAccessReaderPromise(new FileHandleRandomAccessReader(handle), descriptor.snapshot.sizeBytes, {
      autoClose: false,
      lazyEntries: true,
      decodeStrings: true,
      strictFileNames: false,
      validateEntrySizes: true,
    });
  } catch {
    const closeResult = await verifyAndCloseVerifiedSource(descriptor);
    if (!closeResult.ok) return closeResult;
    return ok(terminalOutcome(zipFinding("ZIP_INVALID")));
  }

  if (zip.entryCount === 0) {
    zip.close();
    const closeResult = await verifyAndCloseVerifiedSource(descriptor);
    if (!closeResult.ok) return closeResult;
    return ok(terminalOutcome(zipFinding("ZIP_EMPTY")));
  }

  const entries: ArchiveEntryDescriptor[] = [];
  const sourceEntries = new Map<number, Entry>();
  try {
    for await (const sourceEntry of zip.eachEntry()) {
      if (signal.aborted) {
        zip.close();
        await closeVerifiedSource(descriptor);
        return err({
          category: "cancelled",
          code: "OPERATION_CANCELLED",
          safeMessage: "The operation was cancelled.",
          retryable: false,
          phase: "preflight",
        });
      }
      const index = entries.length;
      entries.push(await describeEntry(sourceEntry, index, zip));
      sourceEntries.set(index, sourceEntry);
    }
  } catch {
    zip.close();
    const closeResult = await verifyAndCloseVerifiedSource(descriptor);
    if (!closeResult.ok) return closeResult;
    return ok(terminalOutcome(zipFinding("ZIP_INVALID")));
  }

  const entryIndex = new Map<InternalPath, ArchiveEntryDescriptor>();
  let compressedFileBytes = 0;
  let expandedFileBytes = 0;

  const pathSafety = inspectArchivePathSafety(entries);
  if (pathSafety.findings.length > 0) {
    zip.close();
    const closeResult = await verifyAndCloseVerifiedSource(descriptor);
    if (!closeResult.ok) return closeResult;
    return ok(terminalOutcomes(pathSafety.findings));
  }

  for (const entry of entries) {
    if (entry.kind === "file") {
      compressedFileBytes += entry.compressedSize;
      expandedFileBytes += entry.expandedSize;
    }
    if (typeof entry.path === "string") entryIndex.set(entry.path, entry);
  }
  const projection: ArchiveProjection = {
    entries,
    entryIndex,
    compressedFileBytes,
    expandedFileBytes,
  };
  return ok({
    outcome: { terminal: false, projection, findings: [], ruleResults: [] },
    session: new YauzlArchiveSession(projection, zip, descriptor, sourceEntries, limits),
  });
}

export const archiveReader = { preflightArchive } as const;
