import crc32 from "buffer-crc32";
import { inflateRawSync } from "node:zlib";

import { createFinding } from "../../domain/audit/finding-catalog";
import type { Finding } from "../../domain/models/finding";

const END_OF_CENTRAL_DIRECTORY = 0x06054b50;
const CENTRAL_DIRECTORY_HEADER = 0x02014b50;
const LOCAL_FILE_HEADER = 0x04034b50;
const ZIP64_EXTRA_HEADER = 0x0001;

const ZIP32_PLACEHOLDER = 0xffff_ffff;
const ZIP16_PLACEHOLDER = 0xffff;

const SAFE_ZIP64_HIGH = 0x1fffff;

type IntegrityFindingCode =
  | "ZIP_MULTIDISK"
  | "ZIP64_INVALID"
  | "ZIP_METHOD_UNSUPPORTED"
  | "ZIP_CRC_MISMATCH"
  | "ZIP_SIZE_MISMATCH"
  | "ARCHIVE_SYMLINK"
  | "ARCHIVE_SPECIAL_FILE"
  | "ARCHIVE_ENCRYPTED_ENTRY";

export interface ArchiveIntegrityFinding extends Finding {}

export interface ArchiveIntegrityOptions {
  readonly bytes: Uint8Array;
}

interface EndOfCentralDirectory {
  readonly endOffset: number;
  readonly diskNumber: number;
  readonly centralDirectoryDisk: number;
  readonly entriesOnDisk: number;
  readonly totalEntries: number;
  readonly centralDirectorySize: number;
  readonly centralDirectoryOffset: number;
}

interface ParsedZipHeader {
  readonly method: number;
  readonly flags: number;
  readonly crc32: number;
  readonly rawCompressedSize: number;
  readonly rawExpandedSize: number;
  readonly compressedSize: number;
  readonly expandedSize: number;
  readonly extra: Uint8Array;
  readonly localHeaderOffset: number;
  readonly externalAttributes: number;
}

interface ResolvedZipHeader {
  readonly method: number;
  readonly flags: number;
  readonly crc32: number;
  readonly rawCompressedSize: number;
  readonly rawExpandedSize: number;
  readonly compressedSize: number | undefined;
  readonly expandedSize: number | undefined;
  readonly extra: Uint8Array;
  readonly localHeaderOffset: number;
  readonly externalAttributes: number;
}

interface ResolvedEntry {
  readonly index: number;
  readonly originalName: string;
  readonly central: ParsedZipHeader;
  readonly local: ParsedZipHeader;
}

export interface ArchiveIntegrityResult {
  readonly findings: readonly ArchiveIntegrityFinding[];
}

function addFinding(
  findings: Finding[],
  seen: Set<string>,
  code: IntegrityFindingCode,
  entryIndex: number,
  evidence: Record<string, string | number | boolean> = {},
): void {
  const key = `${code}:${entryIndex}`;
  if (seen.has(key)) return;
  seen.add(key);
  findings.push(createFinding(code, { location: { kind: "archive_entry", entryIndex }, evidence }));
}

function addGlobalFinding(findings: Finding[], seen: Set<string>, code: IntegrityFindingCode): void {
  const key = code;
  if (seen.has(key)) return;
  seen.add(key);
  findings.push(createFinding(code));
}

function findEndOfCentralDirectory(bytes: Uint8Array): EndOfCentralDirectory {
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
      entriesOnDisk: view.getUint16(offset + 8, true),
      totalEntries: view.getUint16(offset + 10, true),
      centralDirectorySize: view.getUint32(offset + 12, true),
      centralDirectoryOffset: view.getUint32(offset + 16, true),
    };
  }

  throw new Error("Missing end of central directory");
}

function readUint64(view: DataView, offset: number): number | undefined {
  const low = view.getUint32(offset, true);
  const high = view.getUint32(offset + 4, true);
  if (high > SAFE_ZIP64_HIGH) return undefined;
  return high * 0x1_0000_0000 + low;
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
        const value = readUint64(view, cursor);
        if (value === undefined) return [];
        values.push(value);
      }
    }

    offset = end;
  }

  return values;
}

interface ZipSizeState {
  index: number;
}

function resolveZip64Size(
  rawValue: number,
  values: readonly number[],
  state: ZipSizeState,
  invalid: { value: boolean },
): number | undefined {
  if (rawValue !== ZIP32_PLACEHOLDER) return rawValue;
  const value = values[state.index];
  if (value === undefined) {
    invalid.value = true;
    return undefined;
  }
  state.index += 1;
  return value;
}

function parseEntryHeaders(bytes: Uint8Array, centralOffset: number, index: number): ResolvedEntry {
  const end = bytes.length;
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);

  if (centralOffset + 46 > end) throw new Error("Invalid central directory");
  if (view.getUint32(centralOffset, true) !== CENTRAL_DIRECTORY_HEADER) {
    throw new Error("Invalid central directory header");
  }

  const centralMethod = view.getUint16(centralOffset + 10, true);
  const centralFlags = view.getUint16(centralOffset + 8, true);
  const centralCrc32 = view.getUint32(centralOffset + 16, true);
  const centralRawCompressed = view.getUint32(centralOffset + 20, true);
  const centralRawExpanded = view.getUint32(centralOffset + 24, true);
  const nameLength = view.getUint16(centralOffset + 28, true);
  const extraLength = view.getUint16(centralOffset + 30, true);
  const localHeaderOffset = view.getUint32(centralOffset + 42, true);
  const externalAttributes = view.getUint32(centralOffset + 38, true);

  const nameStart = centralOffset + 46;
  const nameEnd = nameStart + nameLength;
  if (nameEnd > end) throw new Error("Invalid central entry name");
  const nameBytes = bytes.subarray(nameStart, nameEnd);
  const originalName = new TextDecoder().decode(nameBytes);

  const centralExtraStart = nameEnd;
  const centralExtraEnd = centralExtraStart + extraLength;
  if (centralExtraEnd > end) throw new Error("Invalid central entry extra");
  const centralExtra = bytes.subarray(centralExtraStart, centralExtraEnd);

  if (localHeaderOffset + 30 > end) throw new Error("Invalid local entry offset");
  if (view.getUint32(localHeaderOffset, true) !== LOCAL_FILE_HEADER) {
    throw new Error("Invalid local file header");
  }

  const localMethod = view.getUint16(localHeaderOffset + 8, true);
  const localFlags = view.getUint16(localHeaderOffset + 6, true);
  const localCrc32 = view.getUint32(localHeaderOffset + 14, true);
  const localRawCompressed = view.getUint32(localHeaderOffset + 18, true);
  const localRawExpanded = view.getUint32(localHeaderOffset + 22, true);
  const localNameLength = view.getUint16(localHeaderOffset + 26, true);
  const localExtraLength = view.getUint16(localHeaderOffset + 28, true);

  const localExtraStart = localHeaderOffset + 30 + localNameLength;
  const localExtraEnd = localExtraStart + localExtraLength;
  if (localExtraEnd > end) throw new Error("Invalid local entry extra");
  const localExtra = bytes.subarray(localExtraStart, localExtraEnd);

  return {
    index,
    originalName,
    central: {
      method: centralMethod,
      flags: centralFlags,
      crc32: centralCrc32,
      rawCompressedSize: centralRawCompressed,
      rawExpandedSize: centralRawExpanded,
      compressedSize: centralRawCompressed,
      expandedSize: centralRawExpanded,
      extra: centralExtra,
      localHeaderOffset,
      externalAttributes,
    },
    local: {
      method: localMethod,
      flags: localFlags,
      crc32: localCrc32,
      rawCompressedSize: localRawCompressed,
      rawExpandedSize: localRawExpanded,
      compressedSize: localRawCompressed,
      expandedSize: localRawExpanded,
      extra: localExtra,
      localHeaderOffset,
      externalAttributes,
    },
  };
}

function resolveEntry(
  entry: ResolvedEntry,
  invalid: { value: boolean },
): { readonly central: ResolvedZipHeader; readonly local: ResolvedZipHeader } {
  const centralZip64 = parseZip64Values(entry.central.extra);
  const localZip64 = parseZip64Values(entry.local.extra);

  const centralState: ZipSizeState = { index: 0 };
  const localState: ZipSizeState = { index: 0 };

  const centralRequiresZip64 =
    entry.central.rawCompressedSize === ZIP32_PLACEHOLDER || entry.central.rawExpandedSize === ZIP32_PLACEHOLDER;
  const localRequiresZip64 =
    entry.local.rawCompressedSize === ZIP32_PLACEHOLDER || entry.local.rawExpandedSize === ZIP32_PLACEHOLDER;
  if (centralRequiresZip64 !== localRequiresZip64) invalid.value = true;

  const centralCompressed = resolveZip64Size(entry.central.rawCompressedSize, centralZip64, centralState, invalid);
  const centralExpanded = resolveZip64Size(entry.central.rawExpandedSize, centralZip64, centralState, invalid);
  const localCompressed = resolveZip64Size(entry.local.rawCompressedSize, localZip64, localState, invalid);
  const localExpanded = resolveZip64Size(entry.local.rawExpandedSize, localZip64, localState, invalid);

  return {
    central: {
      ...entry.central,
      compressedSize: centralCompressed,
      expandedSize: centralExpanded,
    },
    local: {
      ...entry.local,
      compressedSize: localCompressed,
      expandedSize: localExpanded,
    },
  };
}

function classifyFileType(externalAttributes: number): "directory" | "symlink" | "special" | "file" {
  const mode = (externalAttributes >>> 16) & 0xf000;
  if (mode === 0xa000) return "symlink";
  if (mode !== 0 && mode !== 0x8000) return "special";
  return "file";
}

function isSupportedMethod(method: number): boolean {
  return method === 0 || method === 8;
}

export function inspectArchiveIntegrity(options: ArchiveIntegrityOptions | Uint8Array): ArchiveIntegrityResult {
  const bytes = options instanceof Uint8Array ? options : options.bytes;
  const findings: Finding[] = [];
  const seen = new Set<string>();

  try {
    const eocd = findEndOfCentralDirectory(bytes);

    if (eocd.diskNumber !== 0 || eocd.centralDirectoryDisk !== 0) {
      addGlobalFinding(findings, seen, "ZIP_MULTIDISK");
      return { findings };
    }

    if (
      eocd.entriesOnDisk === ZIP16_PLACEHOLDER ||
      eocd.totalEntries === ZIP16_PLACEHOLDER ||
      eocd.centralDirectorySize === ZIP32_PLACEHOLDER ||
      eocd.centralDirectoryOffset === ZIP32_PLACEHOLDER
    ) {
      addGlobalFinding(findings, seen, "ZIP64_INVALID");
      return { findings };
    }

    const centralStart = eocd.centralDirectoryOffset;
    const centralEnd = centralStart + eocd.centralDirectorySize;
    const endOfCentral = eocd.endOffset;

    if (centralStart > endOfCentral || centralEnd > endOfCentral) {
      return { findings: [createFinding("ZIP_INVALID")] };
    }

    let cursor = centralStart;
    for (let index = 0; index < eocd.totalEntries; index += 1) {
      if (cursor + 46 > centralEnd) return { findings: [createFinding("ZIP_INVALID")] };

      const entryView = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
      if (entryView.getUint32(cursor, true) !== CENTRAL_DIRECTORY_HEADER) {
        return { findings: [createFinding("ZIP_INVALID")] };
      }

      const nameLength = entryView.getUint16(cursor + 28, true);
      const extraLength = entryView.getUint16(cursor + 30, true);
      const commentLength = entryView.getUint16(cursor + 32, true);
      const skip = 46 + nameLength + extraLength + commentLength;
      if (cursor + skip > centralEnd) {
        return { findings: [createFinding("ZIP_INVALID")] };
      }

      const parsed = parseEntryHeaders(bytes, cursor, index);
      const invalid = { value: false };
      const resolved = resolveEntry(parsed, invalid);

      if (invalid.value) {
        addGlobalFinding(findings, seen, "ZIP64_INVALID");
        return { findings };
      }

      const kind = classifyFileType(parsed.central.externalAttributes);
      if (kind === "symlink") {
        addFinding(findings, seen, "ARCHIVE_SYMLINK", index);
      } else if (kind === "special") {
        addFinding(findings, seen, "ARCHIVE_SPECIAL_FILE", index);
      }

      if ((resolved.central.flags & 1) !== 0 || (resolved.local.flags & 1) !== 0) {
        addFinding(findings, seen, "ARCHIVE_ENCRYPTED_ENTRY", index);
      }

      if (
        parsed.central.method !== parsed.local.method ||
        !isSupportedMethod(parsed.central.method) ||
        !isSupportedMethod(parsed.local.method)
      ) {
        addFinding(findings, seen, "ZIP_METHOD_UNSUPPORTED", index, {
          localMethod: parsed.local.method,
          centralMethod: parsed.central.method,
        });
      }

      if (resolved.central.crc32 !== resolved.local.crc32) {
        addFinding(findings, seen, "ZIP_CRC_MISMATCH", index, {
          centralCrc32: resolved.central.crc32,
          localCrc32: resolved.local.crc32,
        });
      }

      if (
        resolved.central.compressedSize === undefined ||
        resolved.central.expandedSize === undefined ||
        resolved.local.compressedSize === undefined ||
        resolved.local.expandedSize === undefined
      ) {
        addGlobalFinding(findings, seen, "ZIP64_INVALID");
        return { findings };
      }

      if (
        resolved.central.compressedSize !== resolved.local.compressedSize ||
        resolved.central.expandedSize !== resolved.local.expandedSize
      ) {
        addFinding(findings, seen, "ZIP_SIZE_MISMATCH", index, {
          centralCompressedSize: resolved.central.compressedSize,
          localCompressedSize: resolved.local.compressedSize,
          centralExpandedSize: resolved.central.expandedSize,
          localExpandedSize: resolved.local.expandedSize,
        });
      }

      if (!isSupportedMethod(parsed.central.method) || !isSupportedMethod(parsed.local.method)) {
        cursor += skip;
        continue;
      }

      if (parsed.originalName.endsWith("/")) {
        cursor += skip;
        continue;
      }

      const localHeaderOffset = resolved.central.localHeaderOffset;
      if (localHeaderOffset + 30 > bytes.length) {
        addFinding(findings, seen, "ZIP_SIZE_MISMATCH", index, { reason: "invalid_local_header_offset" });
        cursor += skip;
        continue;
      }

      const localNameLength = entryView.getUint16(localHeaderOffset + 26, true);
      const localExtraLength = entryView.getUint16(localHeaderOffset + 28, true);
      const dataOffset = localHeaderOffset + 30 + localNameLength + localExtraLength;
      if (dataOffset + resolved.local.compressedSize > bytes.length) {
        addFinding(findings, seen, "ZIP_SIZE_MISMATCH", index, {
          reason: "compressed_data_truncated",
          declaredCompressedSize: resolved.local.compressedSize,
        });
        cursor += skip;
        continue;
      }

      const compressedData = Buffer.from(bytes.subarray(dataOffset, dataOffset + resolved.local.compressedSize));
      let expandedData: Buffer;
      if (resolved.local.method === 8) {
        try {
          expandedData = inflateRawSync(compressedData);
        } catch {
          addFinding(findings, seen, "ZIP_SIZE_MISMATCH", index, {
            reason: "deflate_failed",
            declaredMethod: resolved.local.method,
          });
          cursor += skip;
          continue;
        }
      } else {
        expandedData = compressedData;
      }

      const checksum = crc32.unsigned(expandedData);

      if (expandedData.byteLength !== resolved.central.expandedSize) {
        addFinding(findings, seen, "ZIP_SIZE_MISMATCH", index, {
          centralExpandedSize: resolved.central.expandedSize,
          expandedSize: expandedData.byteLength,
        });
      }

      if (checksum >>> 0 !== resolved.central.crc32 >>> 0) {
        addFinding(findings, seen, "ZIP_CRC_MISMATCH", index, {
          declaredCrc32: resolved.central.crc32 >>> 0,
          actualCrc32: checksum >>> 0,
        });
      }

      cursor += skip;
    }

    return { findings };
  } catch {
    return { findings: [createFinding("ZIP_INVALID")] };
  }
}

export function auditArchiveIntegrity(input: ArchiveIntegrityOptions | Uint8Array): ArchiveIntegrityResult {
  return inspectArchiveIntegrity(input);
}
