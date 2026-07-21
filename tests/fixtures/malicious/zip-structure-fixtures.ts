import type { FindingCode } from "../../../src/domain/audit/finding-codes";
import { buildZip, type ZipFixtureEntry, type ZipFixtureOptions } from "../../support/fixture-builder";
import { createMinimalEpubEntries } from "../../support/epub-fixture-factory";

export interface ArchiveStructureSafetyFixture {
  readonly name: string;
  readonly bytes: Uint8Array;
  readonly findingCode:
    | "ZIP_MULTIDISK"
    | "ZIP64_INVALID"
    | "ZIP_METHOD_UNSUPPORTED"
    | "ZIP_CRC_MISMATCH"
    | "ZIP_SIZE_MISMATCH"
    | "ARCHIVE_SYMLINK"
    | "ARCHIVE_SPECIAL_FILE"
    | "ARCHIVE_ENCRYPTED_ENTRY";
}

const UNIX_FILE_TYPE = {
  symlink: 0xa000,
  fifo: 0x1000,
} as const;
const UNIX_PERMISSIONS = 0o644;

function rawEpub(options: Partial<ZipFixtureOptions> = {}): Buffer {
  return buildZip({
    ...options,
    entries: [...createMinimalEpubEntries({ version: 3 }), ...(options.entries ?? [])],
  });
}

function fixture(
  name: string,
  findingCode: ArchiveStructureSafetyFixture["findingCode"],
  options: Partial<ZipFixtureOptions>,
): ArchiveStructureSafetyFixture {
  return { name, bytes: rawEpub(options), findingCode };
}

function orphan(overrides: Partial<ZipFixtureEntry> = {}): ZipFixtureEntry {
  return { name: "EPUB/orphan.bin", data: "x", method: 0, ...overrides };
}

export const archiveStructureSafetyFixtures = [
  fixture("zip-multidisk.epub", "ZIP_MULTIDISK", { diskNumber: 1 }),
  fixture("zip64-invalid.epub", "ZIP64_INVALID", {
    entries: [
      orphan({
        centralCompressedSize: 0xffffffff,
        centralExtra: Uint8Array.from([0x01, 0x00, 0x08, 0x00, 0x01, 0x00, 0x00, 0x00]),
      }),
    ],
  }),
  fixture("zip-method-unsupported.epub", "ZIP_METHOD_UNSUPPORTED", {
    entries: [orphan({ method: 12 })],
  }),
  fixture("zip-crc-mismatch.epub", "ZIP_CRC_MISMATCH", {
    entries: [orphan({ centralCrc32: 0 })],
  }),
  fixture("zip-size-mismatch.epub", "ZIP_SIZE_MISMATCH", {
    entries: [orphan({ centralExpandedSize: 2 })],
  }),
  fixture("archive-symlink.epub", "ARCHIVE_SYMLINK", {
    entries: [
      orphan({
        externalAttributes: ((UNIX_FILE_TYPE.symlink | 0o777) << 16) >>> 0,
      }),
    ],
  }),
  fixture("archive-special-file.epub", "ARCHIVE_SPECIAL_FILE", {
    entries: [
      orphan({
        externalAttributes: ((UNIX_FILE_TYPE.fifo | UNIX_PERMISSIONS) << 16) >>> 0,
      }),
    ],
  }),
  fixture("archive-encrypted-entry.epub", "ARCHIVE_ENCRYPTED_ENTRY", {
    entries: [orphan({ flags: 0x0001 })],
  }),
] as const satisfies readonly ArchiveStructureSafetyFixture[];

export const archiveStructureSafetyFindingCodes = [
  "ZIP_MULTIDISK",
  "ZIP64_INVALID",
  "ZIP_METHOD_UNSUPPORTED",
  "ZIP_CRC_MISMATCH",
  "ZIP_SIZE_MISMATCH",
  "ARCHIVE_SYMLINK",
  "ARCHIVE_SPECIAL_FILE",
  "ARCHIVE_ENCRYPTED_ENTRY",
] as const satisfies readonly FindingCode[];
