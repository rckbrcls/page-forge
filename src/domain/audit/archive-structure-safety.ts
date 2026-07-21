import { createFinding } from "./finding-catalog";
import type { Finding } from "../models/finding";

interface EndOfCentralDirectory {
  readonly endOffset: number;
  readonly diskNumber: number;
  readonly centralDirectoryDisk: number;
  readonly centralDirectorySize: number;
  readonly centralDirectoryOffset: number;
  readonly totalEntries: number;
}

interface ParsedEntryHeader {
  readonly centralFlags: number;
  readonly localFlags: number;
  readonly centralCrc32: number;
  readonly localCrc32: number;
  readonly centralCompressedSize: number;
  readonly centralExpandedSize: number;
  readonly localCompressedSize: number;
  readonly localExpandedSize: number;
  readonly centralExtra: Uint8Array;
  readonly localExtra: Uint8Array;
}

export interface ArchiveStructureSafetyResult {
  readonly findings: readonly Finding[];
  readonly multiDisk: boolean;
  readonly zip64Invalid: boolean;
  readonly crcMismatchEntryIndexes: readonly number[];
  readonly sizeMismatchEntryIndexes: readonly number[];
}

type ArchiveStructureFindingCode =
  "ZIP_MULTIDISK" | "ZIP64_INVALID" | "ZIP_CRC_MISMATCH" | "ZIP_SIZE_MISMATCH" | "ARCHIVE_ENCRYPTED_ENTRY";

const END_OF_CENTRAL_DIRECTORY = 0x06054b50;
const CENTRAL_DIRECTORY_HEADER = 0x02014b50;
const LOCAL_FILE_HEADER = 0x04034b50;
const ZIP64_EXTRA_HEADER = 0x0001;

const ZIP32_PLACEHOLDER = 0xffff_ffff;
const SAFE_ZIP64_HIGH = 0x1f_ffff;

export function inspectArchiveStructureSafety(bytes: Uint8Array): ArchiveStructureSafetyResult {
  const findings: Finding[] = [];
  const seen = new Set<string>();
  const crcMismatchEntryIndexes: number[] = [];
  const sizeMismatchEntryIndexes: number[] = [];
  const addFinding = (code: ArchiveStructureFindingCode, entryIndex?: number): void => {
    const key = entryIndex === undefined ? code : `${code}:${entryIndex}`;
    if (seen.has(key)) return;
    seen.add(key);
    findings.push(
      entryIndex === undefined
        ? createFinding(code)
        : createFinding(code, { location: { kind: "archive_entry", entryIndex } }),
    );
  };

  if (bytes.length < 22) {
    return {
      findings: [createFinding("ZIP_INVALID")],
      multiDisk: false,
      zip64Invalid: false,
      crcMismatchEntryIndexes: [],
      sizeMismatchEntryIndexes: [],
    };
  }

  let endOfCentral: EndOfCentralDirectory;
  try {
    endOfCentral = parseEndOfCentralDirectory(bytes);
  } catch {
    return {
      findings: [createFinding("ZIP_INVALID")],
      multiDisk: false,
      zip64Invalid: false,
      crcMismatchEntryIndexes: [],
      sizeMismatchEntryIndexes: [],
    };
  }

  if (endOfCentral.diskNumber !== 0 || endOfCentral.centralDirectoryDisk !== 0) {
    addFinding("ZIP_MULTIDISK");
    return {
      findings,
      multiDisk: true,
      zip64Invalid: false,
      crcMismatchEntryIndexes,
      sizeMismatchEntryIndexes,
    };
  }

  if (
    endOfCentral.centralDirectorySize === ZIP32_PLACEHOLDER ||
    endOfCentral.centralDirectoryOffset === ZIP32_PLACEHOLDER
  ) {
    addFinding("ZIP64_INVALID");
    return {
      findings,
      multiDisk: false,
      zip64Invalid: true,
      crcMismatchEntryIndexes,
      sizeMismatchEntryIndexes,
    };
  }

  let parsed: {
    readonly zip64Invalid: boolean;
    readonly crcMismatchEntryIndexes: readonly number[];
    readonly sizeMismatchEntryIndexes: readonly number[];
    readonly zipEncryptedEntryIndexes: readonly number[];
  };
  try {
    parsed = parseZipEntries(bytes, endOfCentral);
  } catch {
    return {
      findings: [createFinding("ZIP_INVALID")],
      multiDisk: false,
      zip64Invalid: false,
      crcMismatchEntryIndexes: [],
      sizeMismatchEntryIndexes: [],
    };
  }
  if (parsed.zip64Invalid) {
    addFinding("ZIP64_INVALID");
    return {
      findings,
      multiDisk: false,
      zip64Invalid: true,
      crcMismatchEntryIndexes: [],
      sizeMismatchEntryIndexes: [],
    };
  }
  crcMismatchEntryIndexes.push(...parsed.crcMismatchEntryIndexes);
  sizeMismatchEntryIndexes.push(...parsed.sizeMismatchEntryIndexes);
  for (const entryIndex of parsed.crcMismatchEntryIndexes) {
    addFinding("ZIP_CRC_MISMATCH", entryIndex);
  }
  for (const entryIndex of parsed.sizeMismatchEntryIndexes) {
    addFinding("ZIP_SIZE_MISMATCH", entryIndex);
  }

  for (const index of parsed.zipEncryptedEntryIndexes) {
    addFinding("ARCHIVE_ENCRYPTED_ENTRY", index);
  }

  return {
    findings,
    multiDisk: false,
    zip64Invalid: parsed.zip64Invalid,
    crcMismatchEntryIndexes,
    sizeMismatchEntryIndexes,
  };
}

function parseZipEntries(
  bytes: Uint8Array,
  eocd: EndOfCentralDirectory,
): {
  readonly zip64Invalid: boolean;
  readonly crcMismatchEntryIndexes: readonly number[];
  readonly sizeMismatchEntryIndexes: readonly number[];
  readonly zipEncryptedEntryIndexes: readonly number[];
} {
  const crcMismatchEntryIndexes: number[] = [];
  const sizeMismatchEntryIndexes: number[] = [];
  const zipEncryptedEntryIndexes: number[] = [];
  let zip64Invalid = false;

  const dataEnd = eocd.endOffset;
  const cursorLimit = eocd.centralDirectoryOffset + eocd.centralDirectorySize;
  if (cursorLimit > dataEnd || eocd.centralDirectoryOffset > dataEnd) {
    return {
      zip64Invalid: true,
      crcMismatchEntryIndexes,
      sizeMismatchEntryIndexes,
      zipEncryptedEntryIndexes,
    };
  }

  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  let cursor = eocd.centralDirectoryOffset;
  for (let index = 0; index < eocd.totalEntries; index += 1) {
    if (cursor + 46 > cursorLimit) {
      zip64Invalid = true;
      break;
    }

    if (view.getUint32(cursor, true) !== CENTRAL_DIRECTORY_HEADER) {
      return {
        zip64Invalid: true,
        crcMismatchEntryIndexes,
        sizeMismatchEntryIndexes,
        zipEncryptedEntryIndexes,
      };
    }

    const parsed = parseEntryHeaders(bytes, cursor);
    const entryZip64 = inspectZip64(parsed);
    if (entryZip64.zip64Invalid) zip64Invalid = true;

    const centralEncrypted = (parsed.centralFlags & 1) !== 0;
    const localEncrypted = (parsed.localFlags & 1) !== 0;
    if (centralEncrypted || localEncrypted) zipEncryptedEntryIndexes.push(index);

    if (parsed.centralCrc32 !== parsed.localCrc32) crcMismatchEntryIndexes.push(index);
    if (entryZip64.resolvedCentralCompressedSize !== entryZip64.resolvedLocalCompressedSize) {
      sizeMismatchEntryIndexes.push(index);
    }
    if (entryZip64.resolvedCentralExpandedSize !== entryZip64.resolvedLocalExpandedSize) {
      sizeMismatchEntryIndexes.push(index);
    }

    const nameLength = view.getUint16(cursor + 28, true);
    const extraLength = view.getUint16(cursor + 30, true);
    const commentLength = view.getUint16(cursor + 32, true);
    cursor += 46 + nameLength + extraLength + commentLength;
    if (cursor > cursorLimit) {
      zip64Invalid = true;
      break;
    }
  }

  return { zip64Invalid, crcMismatchEntryIndexes, sizeMismatchEntryIndexes, zipEncryptedEntryIndexes };
}

function parseEndOfCentralDirectory(bytes: Uint8Array): EndOfCentralDirectory {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const minimumOffset = Math.max(0, bytes.length - 65_557);

  for (let offset = bytes.length - 22; offset >= minimumOffset; offset -= 1) {
    if (view.getUint32(offset, true) !== END_OF_CENTRAL_DIRECTORY) continue;
    if (offset + 22 > bytes.length) continue;
    const commentLength = view.getUint16(offset + 20, true);
    if (offset + 22 + commentLength !== bytes.length) continue;

    return {
      endOffset: offset,
      diskNumber: view.getUint16(offset + 4, true),
      centralDirectoryDisk: view.getUint16(offset + 6, true),
      centralDirectorySize: view.getUint32(offset + 12, true),
      centralDirectoryOffset: view.getUint32(offset + 16, true),
      totalEntries: view.getUint16(offset + 10, true),
    };
  }

  throw new Error("Missing end of central directory");
}

function parseEntryHeaders(bytes: Uint8Array, centralOffset: number): ParsedEntryHeader {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const totalLength = view.byteLength;
  if (centralOffset + 46 > totalLength) throw new Error("Invalid central directory entry");

  const centralFlags = view.getUint16(centralOffset + 8, true);
  const centralCrc32 = view.getUint32(centralOffset + 16, true);
  const centralCompressedSize = view.getUint32(centralOffset + 20, true);
  const centralExpandedSize = view.getUint32(centralOffset + 24, true);
  const nameLength = view.getUint16(centralOffset + 28, true);
  const extraLength = view.getUint16(centralOffset + 30, true);

  const localHeaderOffset = view.getUint32(centralOffset + 42, true);
  if (localHeaderOffset + 30 > totalLength) {
    throw new Error("Invalid local file header");
  }
  if (view.getUint32(localHeaderOffset, true) !== LOCAL_FILE_HEADER) {
    throw new Error("Invalid local file header");
  }

  const localFlags = view.getUint16(localHeaderOffset + 6, true);
  const localCrc32 = view.getUint32(localHeaderOffset + 14, true);
  const localCompressedSize = view.getUint32(localHeaderOffset + 18, true);
  const localExpandedSize = view.getUint32(localHeaderOffset + 22, true);

  const localNameLength = view.getUint16(localHeaderOffset + 26, true);
  const localExtraLength = view.getUint16(localHeaderOffset + 28, true);

  const centralExtraStart = centralOffset + 46 + nameLength;
  const centralExtraEnd = centralExtraStart + extraLength;
  if (centralExtraEnd > totalLength) throw new Error("Invalid central extra data");
  const centralExtra = bytes.subarray(centralExtraStart, centralExtraEnd);

  const localExtraStart = localHeaderOffset + 30 + localNameLength;
  const localExtraEnd = localExtraStart + localExtraLength;
  if (localExtraEnd > totalLength) throw new Error("Invalid local extra data");
  const localExtra = bytes.subarray(localExtraStart, localExtraEnd);

  return {
    centralFlags,
    localFlags,
    centralCrc32,
    localCrc32,
    centralCompressedSize,
    centralExpandedSize,
    localCompressedSize,
    localExpandedSize,
    centralExtra,
    localExtra,
  };
}

function inspectZip64(entry: ParsedEntryHeader): {
  readonly zip64Invalid: boolean;
  readonly resolvedCentralCompressedSize: number;
  readonly resolvedCentralExpandedSize: number;
  readonly resolvedLocalCompressedSize: number;
  readonly resolvedLocalExpandedSize: number;
} {
  const centralZip64Values = parseZip64Values(entry.centralExtra);
  const localZip64Values = parseZip64Values(entry.localExtra);
  const centralState = { index: 0 };
  const localState = { index: 0 };

  const centralNeedsZip64 =
    entry.centralCompressedSize === ZIP32_PLACEHOLDER || entry.centralExpandedSize === ZIP32_PLACEHOLDER;
  const localNeedsZip64 =
    entry.localCompressedSize === ZIP32_PLACEHOLDER || entry.localExpandedSize === ZIP32_PLACEHOLDER;
  if (centralNeedsZip64 !== localNeedsZip64) {
    return {
      zip64Invalid: true,
      resolvedCentralCompressedSize: entry.centralCompressedSize,
      resolvedCentralExpandedSize: entry.centralExpandedSize,
      resolvedLocalCompressedSize: entry.localCompressedSize,
      resolvedLocalExpandedSize: entry.localExpandedSize,
    };
  }

  const invalid = { value: false };
  const resolvedCentralCompressedSize = resolveZip64Size(
    entry.centralCompressedSize,
    centralZip64Values,
    centralState,
    invalid,
  );
  const resolvedCentralExpandedSize = resolveZip64Size(
    entry.centralExpandedSize,
    centralZip64Values,
    centralState,
    invalid,
  );
  const resolvedLocalCompressedSize = resolveZip64Size(
    entry.localCompressedSize,
    localZip64Values,
    localState,
    invalid,
  );
  const resolvedLocalExpandedSize = resolveZip64Size(entry.localExpandedSize, localZip64Values, localState, invalid);

  return {
    zip64Invalid: invalid.value,
    resolvedCentralCompressedSize: resolvedCentralCompressedSize,
    resolvedCentralExpandedSize: resolvedCentralExpandedSize,
    resolvedLocalCompressedSize: resolvedLocalCompressedSize,
    resolvedLocalExpandedSize: resolvedLocalExpandedSize,
  };
}

function parseZip64Values(extra: Uint8Array): number[] {
  const values: number[] = [];
  const view = new DataView(extra.buffer, extra.byteOffset, extra.byteLength);
  for (let offset = 0; offset + 4 <= extra.byteLength - 4;) {
    const headerId = view.getUint16(offset, true);
    const dataLength = view.getUint16(offset + 2, true);
    const start = offset + 4;
    const end = start + dataLength;
    if (end > extra.byteLength) break;

    if (headerId === ZIP64_EXTRA_HEADER) {
      for (let cursor = start; cursor + 8 <= end; cursor += 8) {
        const value = readZip64Value(view, cursor);
        if (value === undefined) return [];
        values.push(value);
      }
    }

    offset = end;
  }

  return values;
}

function readZip64Value(view: DataView, offset: number): number | undefined {
  const low = view.getUint32(offset, true);
  const high = view.getUint32(offset + 4, true);
  if (high > SAFE_ZIP64_HIGH) return undefined;
  return high * 0x1_0000_0000 + low;
}

function resolveZip64Size(
  rawValue: number,
  values: readonly number[],
  state: { index: number },
  invalid: { value: boolean },
): number {
  if (rawValue !== ZIP32_PLACEHOLDER) return rawValue;
  const value = values[state.index];
  if (value === undefined) {
    invalid.value = true;
    return rawValue;
  }
  state.index += 1;
  return value;
}

export const auditArchiveStructureSafety = inspectArchiveStructureSafety;
