import { inflateRawSync } from "node:zlib";

import { describe, expect, it } from "vitest";

import type {
  ArchiveLimits,
  ArchiveSession,
  BoundedReadable,
  TemporaryOutput,
} from "../../../src/application/ports";
import { ARCHIVE_LIMITS } from "../../../src/domain/audit/limits";
import { parseInternalPath } from "../../../src/domain/audit/internal-path";
import type {
  ArchiveEntryDescriptor,
  ArchiveProjection,
  InternalPath,
} from "../../../src/domain/models/archive";
import type { Sha256Digest } from "../../../src/domain/models/epub-document";
import type { ProcessingFailure } from "../../../src/domain/models/processing-failure";
import type { RepairOperationId, RepairPlan } from "../../../src/domain/models/repair";
import { ok, type Result } from "../../../src/domain/models/result";
import { rebuildArchive } from "../../../src/adapters/archive/archive-writer";
import { selectedEpub } from "../../fixtures/input/fixture-definitions";
import { crc32, zipMethods } from "../../support/fixture-builder";
import { withTestFilesystem } from "../../support/test-filesystem";

const END_OF_CENTRAL_DIRECTORY = 0x06054b50;
const CENTRAL_DIRECTORY_HEADER = 0x02014b50;
const LOCAL_FILE_HEADER = 0x04034b50;

interface ParsedZipEntry {
  readonly name: string;
  readonly method: number;
  readonly crc32: number;
  readonly localExtraLength: number;
  readonly data: Buffer;
}

function internalPath(value: string): InternalPath {
  const parsed = parseInternalPath(value);
  if (!parsed.ok) throw new Error(`Invalid test path: ${value}`);
  return parsed.value.path;
}

function findEndOfCentralDirectory(archive: Buffer): number {
  for (
    let offset = archive.length - 22;
    offset >= Math.max(0, archive.length - 65_557);
    offset -= 1
  ) {
    if (archive.readUInt32LE(offset) === END_OF_CENTRAL_DIRECTORY) return offset;
  }
  throw new Error("ZIP end-of-central-directory record was not found");
}

function parseZip(archive: Buffer): ParsedZipEntry[] {
  const endOffset = findEndOfCentralDirectory(archive);
  const entryCount = archive.readUInt16LE(endOffset + 10);
  let centralOffset = archive.readUInt32LE(endOffset + 16);
  const entries: ParsedZipEntry[] = [];

  for (let index = 0; index < entryCount; index += 1) {
    expect(archive.readUInt32LE(centralOffset)).toBe(CENTRAL_DIRECTORY_HEADER);
    const method = archive.readUInt16LE(centralOffset + 10);
    const checksum = archive.readUInt32LE(centralOffset + 16);
    const compressedSize = archive.readUInt32LE(centralOffset + 20);
    const nameLength = archive.readUInt16LE(centralOffset + 28);
    const extraLength = archive.readUInt16LE(centralOffset + 30);
    const commentLength = archive.readUInt16LE(centralOffset + 32);
    const localOffset = archive.readUInt32LE(centralOffset + 42);
    const name = archive.subarray(centralOffset + 46, centralOffset + 46 + nameLength).toString("utf8");

    expect(archive.readUInt32LE(localOffset)).toBe(LOCAL_FILE_HEADER);
    const localNameLength = archive.readUInt16LE(localOffset + 26);
    const localExtraLength = archive.readUInt16LE(localOffset + 28);
    const dataOffset = localOffset + 30 + localNameLength + localExtraLength;
    const compressed = archive.subarray(dataOffset, dataOffset + compressedSize);
    const data = method === zipMethods.deflate ? inflateRawSync(compressed) : Buffer.from(compressed);
    entries.push({ name, method, crc32: checksum, localExtraLength, data });
    centralOffset += 46 + nameLength + extraLength + commentLength;
  }

  return entries;
}

function descriptor(
  index: number,
  name: string,
  data: Uint8Array,
  overrides: Partial<ArchiveEntryDescriptor> = {},
): ArchiveEntryDescriptor {
  return {
    index,
    originalName: name,
    originalNameBytes: Buffer.from(name),
    path: internalPath(name),
    kind: "file",
    compressionMethod: zipMethods.deflate,
    compressedSize: Math.max(1, Math.ceil(data.byteLength / 2)),
    expandedSize: data.byteLength,
    crc32: crc32(data),
    encrypted: false,
    externalAttributes: 0,
    flags: 0,
    localHeaderExtraLength: 0,
    ...overrides,
  };
}

class StreamingArchiveSession implements ArchiveSession {
  readonly projection: ArchiveProjection;
  readonly opened: string[] = [];
  maxActive = 0;
  yieldedChunks = 0;
  private active = 0;

  constructor(
    readonly entries: readonly { descriptor: ArchiveEntryDescriptor; data: Buffer }[],
    private readonly chunkSize = 4_096,
  ) {
    this.projection = {
      entries: entries.map((entry) => entry.descriptor),
      entryIndex: new Map(entries.map((entry) => [entry.descriptor.path as InternalPath, entry.descriptor])),
      compressedFileBytes: entries.reduce((total, entry) => total + entry.descriptor.compressedSize, 0),
      expandedFileBytes: entries.reduce((total, entry) => total + entry.descriptor.expandedSize, 0),
    };
  }

  async openEntry(
    entry: ArchiveEntryDescriptor,
    _signal: AbortSignal,
  ): Promise<Result<BoundedReadable, ProcessingFailure>> {
    if (this.active !== 0) throw new Error("Writer opened more than one source entry at once");
    const source = this.entries.find((candidate) => candidate.descriptor.index === entry.index);
    if (!source) throw new Error(`Missing source entry ${entry.originalName}`);
    this.active += 1;
    this.maxActive = Math.max(this.maxActive, this.active);
    this.opened.push(entry.originalName);
    let closed = false;
    const close = async () => {
      if (!closed) {
        closed = true;
        this.active -= 1;
      }
      return ok(undefined);
    };
    const readable: BoundedReadable = {
      [Symbol.asyncIterator]: async function* (this: StreamingArchiveSession) {
        try {
          for (let offset = 0; offset < source.data.length; offset += this.chunkSize) {
            this.yieldedChunks += 1;
            yield source.data.subarray(offset, offset + this.chunkSize);
          }
        } finally {
          await close();
        }
      }.bind(this),
      close,
    };
    return ok(readable);
  }

  async close() {
    return ok(undefined);
  }
}

function repairPlan(sourcePath: string): RepairPlan {
  const source = selectedEpub(sourcePath, "book.epub", "archive-writer");
  const mimetypeOperationId = "repair-mimetype" as RepairOperationId;
  const rebuildOperationId = "repair-archive" as RepairOperationId;
  return {
    source,
    originalReport: {
      sourceId: source.id,
      sourceFingerprint: {
        identity: source.identity,
        sizeBytes: source.sizeBytes,
        modifiedAtMs: source.modifiedAtMs,
        sha256: "fixture-sha256" as Sha256Digest,
      },
      epubVersion: "3",
      health: "repairable",
      findings: [],
      inspectedAtMs: 1,
      durationMs: 1,
      ruleResults: [],
    },
    operations: [
      {
        id: mimetypeOperationId,
        kind: "write_canonical_mimetype",
        findingIds: [],
        readPaths: [],
        changedPaths: [internalPath("mimetype")],
        explanation: "Write the canonical EPUB mimetype entry.",
        value: "application/epub+zip",
      },
      {
        id: rebuildOperationId,
        kind: "rebuild_epub_archive",
        findingIds: [],
        readPaths: [],
        changedPaths: [internalPath("mimetype")],
        explanation: "Rebuild the archive in canonical order.",
        entryOperations: [mimetypeOperationId],
      },
    ],
    unresolvedFindings: [],
    predictedOutputPath: sourcePath.replace(/\.epub$/u, "-kindle-ready.epub"),
    createdAtMs: 1,
  };
}

function temporary(path: string, sourcePath: string): TemporaryOutput {
  return {
    id: "temporary-archive-writer",
    path,
    prediction: { sourcePath, candidatePath: path.replace(/\.tmp$/u, ".epub"), suffix: 1 },
  };
}

async function reconstruct(
  session: ArchiveSession,
  outputPath: string,
  sourcePath: string,
  limits: ArchiveLimits = ARCHIVE_LIMITS,
) {
  return rebuildArchive(
    session,
    repairPlan(sourcePath),
    temporary(outputPath, sourcePath),
    limits,
    new AbortController().signal,
    () => undefined,
  );
}

describe("archive writer", () => {
  it("streams a canonical first STORE mimetype without extras and keeps remaining relative order", async () => {
    await withTestFilesystem(async (filesystem) => {
      const chapter = Buffer.from("chapter".repeat(40_000));
      const image = Buffer.from(Array.from({ length: 48_000 }, (_, index) => index % 251));
      const packageDocument = Buffer.from("<package version=\"3.0\"/>");
      const entries = [
        { descriptor: descriptor(0, "EPUB/chapter.xhtml", chapter), data: chapter },
        {
          descriptor: descriptor(1, "mimetype", Buffer.from("text/plain"), {
            compressionMethod: zipMethods.deflate,
            localHeaderExtraLength: 12,
          }),
          data: Buffer.from("text/plain"),
        },
        { descriptor: descriptor(2, "EPUB/images/cover.bin", image), data: image },
        { descriptor: descriptor(3, "EPUB/package.opf", packageDocument), data: packageDocument },
      ];
      const session = new StreamingArchiveSession(entries);
      const outputPath = filesystem.path(".page-forge-rebuild.tmp");

      const result = await reconstruct(session, outputPath, filesystem.path("book.epub"));

      expect(result.ok).toBe(true);
      const output = parseZip(await filesystem.read(".page-forge-rebuild.tmp"));
      expect(output.map((entry) => entry.name)).toEqual([
        "mimetype",
        "EPUB/chapter.xhtml",
        "EPUB/images/cover.bin",
        "EPUB/package.opf",
      ]);
      expect(output[0]).toMatchObject({
        method: zipMethods.store,
        localExtraLength: 0,
        crc32: crc32("application/epub+zip"),
      });
      expect(output[0]?.data.toString("ascii")).toBe("application/epub+zip");
      expect(session.opened).toEqual([
        "EPUB/chapter.xhtml",
        "EPUB/images/cover.bin",
        "EPUB/package.opf",
      ]);
      expect(session.maxActive).toBe(1);
      expect(session.yieldedChunks).toBeGreaterThan(50);
    });
  });

  it("preserves every unplanned resource byte and writes matching output CRC values", async () => {
    await withTestFilesystem(async (filesystem) => {
      const resources = new Map<string, Buffer>([
        ["META-INF/container.xml", Buffer.from([0, 1, 2, 3, 254, 255])],
        [
          "EPUB/fonts/book.woff",
          Buffer.from(Array.from({ length: 65_537 }, (_, index) => index % 256)),
        ],
        ["EPUB/styles/book.css", Buffer.from("body { color: #123456; }\n")],
      ]);
      const session = new StreamingArchiveSession(
        [...resources].map(([name, data], index) => ({
          descriptor: descriptor(index, name, data),
          data,
        })),
        1_024,
      );

      const result = await reconstruct(
        session,
        filesystem.path(".page-forge-preservation.tmp"),
        filesystem.path("book.epub"),
      );

      expect(result.ok).toBe(true);
      const output = parseZip(await filesystem.read(".page-forge-preservation.tmp"));
      for (const [name, expectedBytes] of resources) {
        const entry = output.find((candidate) => candidate.name === name);
        expect(entry?.data).toEqual(expectedBytes);
        expect(entry?.crc32).toBe(crc32(expectedBytes));
      }
    });
  });

  it("rejects a source stream whose actual CRC does not match its descriptor", async () => {
    await withTestFilesystem(async (filesystem) => {
      const data = Buffer.from("preserve this resource exactly");
      const session = new StreamingArchiveSession([
        {
          descriptor: descriptor(0, "EPUB/resource.bin", data, { crc32: (crc32(data) + 1) >>> 0 }),
          data,
        },
      ]);

      const result = await reconstruct(
        session,
        filesystem.path(".page-forge-bad-crc.tmp"),
        filesystem.path("book.epub"),
      );

      expect(result).toMatchObject({ ok: false });
      if (!result.ok) expect(result.failure.code).toBe("REPAIR_WRITE_FAILED");
    });
  });

  it("stops reconstruction when actual entry or output bytes exceed configured limits", async () => {
    await withTestFilesystem(async (filesystem) => {
      const data = Buffer.alloc(32_000, 0x61);
      const entryLimited = new StreamingArchiveSession([
        { descriptor: descriptor(0, "EPUB/large.bin", data), data },
      ]);
      const outputLimited = new StreamingArchiveSession([
        { descriptor: descriptor(0, "EPUB/large.bin", data), data },
      ]);

      const entryResult = await reconstruct(
        entryLimited,
        filesystem.path(".page-forge-entry-limit.tmp"),
        filesystem.path("book.epub"),
        { ...ARCHIVE_LIMITS, maxExpandedEntryBytes: data.length - 1 },
      );
      const outputResult = await reconstruct(
        outputLimited,
        filesystem.path(".page-forge-output-limit.tmp"),
        filesystem.path("book.epub"),
        { ...ARCHIVE_LIMITS, maxOutputBytes: 64 },
      );

      expect(entryResult).toMatchObject({ ok: false });
      expect(outputResult).toMatchObject({ ok: false });
      if (!entryResult.ok) expect(entryResult.failure.code).toBe("REPAIR_WRITE_FAILED");
      if (!outputResult.ok) expect(outputResult.failure.code).toBe("REPAIR_WRITE_FAILED");
    });
  });
});
