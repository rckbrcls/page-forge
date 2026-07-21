import { deflateRawSync } from "node:zlib";

export type FixtureBytes = string | Uint8Array;

export interface ZipFixtureEntry {
  name: FixtureBytes;
  data?: FixtureBytes;
  compressedData?: FixtureBytes;
  method?: number;
  localMethod?: number;
  centralMethod?: number;
  flags?: number;
  localFlags?: number;
  centralFlags?: number;
  crc32?: number;
  localCrc32?: number;
  centralCrc32?: number;
  compressedSize?: number;
  localCompressedSize?: number;
  centralCompressedSize?: number;
  expandedSize?: number;
  localExpandedSize?: number;
  centralExpandedSize?: number;
  localExtra?: FixtureBytes;
  centralExtra?: FixtureBytes;
  comment?: FixtureBytes;
  externalAttributes?: number;
  internalAttributes?: number;
  versionMadeBy?: number;
  versionNeeded?: number;
  localHeaderOffset?: number;
}

export interface ZipFixtureOptions {
  entries: readonly ZipFixtureEntry[];
  comment?: FixtureBytes;
  diskNumber?: number;
  centralDirectoryDisk?: number;
  entriesOnDisk?: number;
  totalEntries?: number;
  centralDirectorySize?: number;
  centralDirectoryOffset?: number;
  prefix?: FixtureBytes;
  suffix?: FixtureBytes;
}

const LOCAL_FILE_HEADER = 0x04034b50;
const CENTRAL_DIRECTORY_HEADER = 0x02014b50;
const END_OF_CENTRAL_DIRECTORY = 0x06054b50;
const UTF8_FLAG = 0x0800;
const STORE = 0;
const DEFLATE = 8;
const DOS_DATE_1980_01_01 = 0x0021;

function bytes(value: FixtureBytes | undefined): Buffer {
  if (value === undefined) return Buffer.alloc(0);
  return typeof value === "string" ? Buffer.from(value, "utf8") : Buffer.from(value);
}

function uint16(value: number, field: string): number {
  if (!Number.isInteger(value) || value < 0 || value > 0xffff) {
    throw new RangeError(`${field} must fit in an unsigned 16-bit integer`);
  }
  return value;
}

function uint32(value: number, field: string): number {
  if (!Number.isInteger(value) || value < 0 || value > 0xffffffff) {
    throw new RangeError(`${field} must fit in an unsigned 32-bit integer`);
  }
  return value;
}

function localHeader(options: {
  versionNeeded: number;
  flags: number;
  method: number;
  crc32: number;
  compressedSize: number;
  expandedSize: number;
  name: Buffer;
  extra: Buffer;
}): Buffer {
  const header = Buffer.alloc(30);
  header.writeUInt32LE(LOCAL_FILE_HEADER, 0);
  header.writeUInt16LE(uint16(options.versionNeeded, "versionNeeded"), 4);
  header.writeUInt16LE(uint16(options.flags, "localFlags"), 6);
  header.writeUInt16LE(uint16(options.method, "localMethod"), 8);
  header.writeUInt16LE(0, 10);
  header.writeUInt16LE(DOS_DATE_1980_01_01, 12);
  header.writeUInt32LE(uint32(options.crc32, "localCrc32"), 14);
  header.writeUInt32LE(uint32(options.compressedSize, "localCompressedSize"), 18);
  header.writeUInt32LE(uint32(options.expandedSize, "localExpandedSize"), 22);
  header.writeUInt16LE(uint16(options.name.length, "entry name length"), 26);
  header.writeUInt16LE(uint16(options.extra.length, "local extra length"), 28);
  return Buffer.concat([header, options.name, options.extra]);
}

function centralHeader(options: {
  versionMadeBy: number;
  versionNeeded: number;
  flags: number;
  method: number;
  crc32: number;
  compressedSize: number;
  expandedSize: number;
  name: Buffer;
  extra: Buffer;
  comment: Buffer;
  internalAttributes: number;
  externalAttributes: number;
  localHeaderOffset: number;
}): Buffer {
  const header = Buffer.alloc(46);
  header.writeUInt32LE(CENTRAL_DIRECTORY_HEADER, 0);
  header.writeUInt16LE(uint16(options.versionMadeBy, "versionMadeBy"), 4);
  header.writeUInt16LE(uint16(options.versionNeeded, "versionNeeded"), 6);
  header.writeUInt16LE(uint16(options.flags, "centralFlags"), 8);
  header.writeUInt16LE(uint16(options.method, "centralMethod"), 10);
  header.writeUInt16LE(0, 12);
  header.writeUInt16LE(DOS_DATE_1980_01_01, 14);
  header.writeUInt32LE(uint32(options.crc32, "centralCrc32"), 16);
  header.writeUInt32LE(uint32(options.compressedSize, "centralCompressedSize"), 20);
  header.writeUInt32LE(uint32(options.expandedSize, "centralExpandedSize"), 24);
  header.writeUInt16LE(uint16(options.name.length, "entry name length"), 28);
  header.writeUInt16LE(uint16(options.extra.length, "central extra length"), 30);
  header.writeUInt16LE(uint16(options.comment.length, "entry comment length"), 32);
  header.writeUInt16LE(0, 34);
  header.writeUInt16LE(uint16(options.internalAttributes, "internalAttributes"), 36);
  header.writeUInt32LE(uint32(options.externalAttributes, "externalAttributes"), 38);
  header.writeUInt32LE(uint32(options.localHeaderOffset, "localHeaderOffset"), 42);
  return Buffer.concat([header, options.name, options.extra, options.comment]);
}

function encodedData(method: number, data: Buffer, override: FixtureBytes | undefined): Buffer {
  if (override !== undefined) return bytes(override);
  if (method === DEFLATE) return deflateRawSync(data, { level: 9 });
  return data;
}

interface MaterializedEntry {
  localRecord: Buffer;
  centralRecord(offset: number): Buffer;
}

function materializeEntry(entry: ZipFixtureEntry): MaterializedEntry {
  const name = bytes(entry.name);
  const data = bytes(entry.data);
  const method = entry.method ?? STORE;
  const localMethod = entry.localMethod ?? method;
  const centralMethod = entry.centralMethod ?? method;
  const flags = entry.flags ?? UTF8_FLAG;
  const localFlags = entry.localFlags ?? flags;
  const centralFlags = entry.centralFlags ?? flags;
  const compressed = encodedData(method, data, entry.compressedData);
  const actualCrc32 = crc32(data);
  const declaredCrc32 = entry.crc32 ?? actualCrc32;
  const declaredCompressedSize = entry.compressedSize ?? compressed.length;
  const declaredExpandedSize = entry.expandedSize ?? data.length;
  const localExtra = bytes(entry.localExtra);
  const centralExtra = bytes(entry.centralExtra);
  const comment = bytes(entry.comment);
  const versionNeeded = entry.versionNeeded ?? 20;

  const localRecord = Buffer.concat([
    localHeader({
      versionNeeded,
      flags: localFlags,
      method: localMethod,
      crc32: entry.localCrc32 ?? declaredCrc32,
      compressedSize: entry.localCompressedSize ?? declaredCompressedSize,
      expandedSize: entry.localExpandedSize ?? declaredExpandedSize,
      name,
      extra: localExtra,
    }),
    compressed,
  ]);

  return {
    localRecord,
    centralRecord(offset: number): Buffer {
      return centralHeader({
        versionMadeBy: entry.versionMadeBy ?? 0x0314,
        versionNeeded,
        flags: centralFlags,
        method: centralMethod,
        crc32: entry.centralCrc32 ?? declaredCrc32,
        compressedSize: entry.centralCompressedSize ?? declaredCompressedSize,
        expandedSize: entry.centralExpandedSize ?? declaredExpandedSize,
        name,
        extra: centralExtra,
        comment,
        internalAttributes: entry.internalAttributes ?? 0,
        externalAttributes: entry.externalAttributes ?? 0,
        localHeaderOffset: entry.localHeaderOffset ?? offset,
      });
    },
  };
}

export function buildZip(options: ZipFixtureOptions | readonly ZipFixtureEntry[]): Buffer {
  const fixture: ZipFixtureOptions = Array.isArray(options)
    ? { entries: options }
    : (options as ZipFixtureOptions);
  const prefix = bytes(fixture.prefix);
  const materialized = fixture.entries.map(materializeEntry);
  const localRecords: Buffer[] = [];
  const centralRecords: Buffer[] = [];
  let offset = prefix.length;

  for (const entry of materialized) {
    localRecords.push(entry.localRecord);
    centralRecords.push(entry.centralRecord(offset));
    offset += entry.localRecord.length;
  }

  const centralDirectory = Buffer.concat(centralRecords);
  const comment = bytes(fixture.comment);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(END_OF_CENTRAL_DIRECTORY, 0);
  end.writeUInt16LE(uint16(fixture.diskNumber ?? 0, "diskNumber"), 4);
  end.writeUInt16LE(uint16(fixture.centralDirectoryDisk ?? 0, "centralDirectoryDisk"), 6);
  end.writeUInt16LE(uint16(fixture.entriesOnDisk ?? fixture.entries.length, "entriesOnDisk"), 8);
  end.writeUInt16LE(uint16(fixture.totalEntries ?? fixture.entries.length, "totalEntries"), 10);
  end.writeUInt32LE(
    uint32(fixture.centralDirectorySize ?? centralDirectory.length, "centralDirectorySize"),
    12,
  );
  end.writeUInt32LE(uint32(fixture.centralDirectoryOffset ?? offset, "centralDirectoryOffset"), 16);
  end.writeUInt16LE(uint16(comment.length, "archive comment length"), 20);

  return Buffer.concat([
    prefix,
    ...localRecords,
    centralDirectory,
    end,
    comment,
    bytes(fixture.suffix),
  ]);
}

export function crc32(input: FixtureBytes): number {
  const inputBytes = bytes(input);
  let crc = 0xffffffff;
  for (const value of inputBytes) {
    crc ^= value;
    for (let bit = 0; bit < 8; bit += 1) {
      crc = (crc >>> 1) ^ (crc & 1 ? 0xedb88320 : 0);
    }
  }
  return (crc ^ 0xffffffff) >>> 0;
}

export const zipMethods = { store: STORE, deflate: DEFLATE } as const;
