import { ARCHIVE_LIMITS, OPERATION_LIMITS } from "../../../src/domain/audit/limits";

export interface ArchiveLimitEntryMetadata {
  readonly kind: "file" | "directory";
  readonly compressedSize: number;
  readonly expandedSize: number;
}

export interface ArchiveLimitMetadata {
  readonly sourceBytes: number;
  readonly entryCount: number;
  readonly entries: readonly ArchiveLimitEntryMetadata[];
  readonly compressedFileBytes: number;
  readonly expandedFileBytes: number;
}

export type ArchiveLimitFindingCode =
  | "ARCHIVE_SOURCE_TOO_LARGE"
  | "ARCHIVE_TOO_MANY_ENTRIES"
  | "ARCHIVE_ENTRY_TOO_LARGE"
  | "ARCHIVE_EXPANDED_TOO_LARGE"
  | "ARCHIVE_COMPRESSION_RATIO";

export interface ArchiveLimitFixture {
  readonly name: string;
  readonly metadata: ArchiveLimitMetadata;
  readonly expectedCodes: readonly ArchiveLimitFindingCode[];
}

const baseMetadata: ArchiveLimitMetadata = {
  sourceBytes: 1,
  entryCount: 1,
  entries: [{ kind: "file", compressedSize: 1, expandedSize: 1 }],
  compressedFileBytes: 1,
  expandedFileBytes: 1,
};

function fixture(
  name: string,
  metadata: Partial<ArchiveLimitMetadata>,
  ...expectedCodes: readonly ArchiveLimitFindingCode[]
): ArchiveLimitFixture {
  return { name, metadata: { ...baseMetadata, ...metadata }, expectedCodes };
}

function entryRatioFixture(
  name: string,
  compressedSize: number,
  expandedSize: number,
  expectedCodes: readonly ArchiveLimitFindingCode[] = [],
): ArchiveLimitFixture {
  return fixture(
    name,
    {
      entries: [{ kind: "file", compressedSize, expandedSize }],
      compressedFileBytes: compressedSize,
      expandedFileBytes: expandedSize,
    },
    ...expectedCodes,
  );
}

function aggregateRatioFixture(
  name: string,
  compressedFileBytes: number,
  expandedFileBytes: number,
  expectedCodes: readonly ArchiveLimitFindingCode[] = [],
): ArchiveLimitFixture {
  return fixture(
    name,
    {
      entries: [{ kind: "file", compressedSize: 1, expandedSize: 1 }],
      compressedFileBytes,
      expandedFileBytes,
    },
    ...expectedCodes,
  );
}

export const archiveLimitFixtures = [
  fixture("source bytes immediately below the limit", {
    sourceBytes: ARCHIVE_LIMITS.maxSourceBytes - 1,
  }),
  fixture("source bytes at the limit", { sourceBytes: ARCHIVE_LIMITS.maxSourceBytes }),
  fixture(
    "source bytes immediately above the limit",
    { sourceBytes: ARCHIVE_LIMITS.maxSourceBytes + 1 },
    "ARCHIVE_SOURCE_TOO_LARGE",
  ),
  fixture("entry count immediately below the limit", {
    entryCount: ARCHIVE_LIMITS.maxEntryCount - 1,
  }),
  fixture("entry count at the limit", { entryCount: ARCHIVE_LIMITS.maxEntryCount }),
  fixture(
    "entry count immediately above the limit",
    { entryCount: ARCHIVE_LIMITS.maxEntryCount + 1 },
    "ARCHIVE_TOO_MANY_ENTRIES",
  ),
  fixture("expanded entry bytes immediately below the limit", {
    entries: [
      {
        kind: "file",
        compressedSize: ARCHIVE_LIMITS.maxExpandedEntryBytes,
        expandedSize: ARCHIVE_LIMITS.maxExpandedEntryBytes - 1,
      },
    ],
    compressedFileBytes: ARCHIVE_LIMITS.maxExpandedEntryBytes,
    expandedFileBytes: ARCHIVE_LIMITS.maxExpandedEntryBytes - 1,
  }),
  fixture("expanded entry bytes at the limit", {
    entries: [
      {
        kind: "file",
        compressedSize: ARCHIVE_LIMITS.maxExpandedEntryBytes,
        expandedSize: ARCHIVE_LIMITS.maxExpandedEntryBytes,
      },
    ],
    compressedFileBytes: ARCHIVE_LIMITS.maxExpandedEntryBytes,
    expandedFileBytes: ARCHIVE_LIMITS.maxExpandedEntryBytes,
  }),
  fixture(
    "expanded entry bytes immediately above the limit",
    {
      entries: [
        {
          kind: "file",
          compressedSize: ARCHIVE_LIMITS.maxExpandedEntryBytes + 1,
          expandedSize: ARCHIVE_LIMITS.maxExpandedEntryBytes + 1,
        },
      ],
      compressedFileBytes: ARCHIVE_LIMITS.maxExpandedEntryBytes + 1,
      expandedFileBytes: ARCHIVE_LIMITS.maxExpandedEntryBytes + 1,
    },
    "ARCHIVE_ENTRY_TOO_LARGE",
  ),
  fixture("expanded total immediately below the limit", {
    compressedFileBytes: ARCHIVE_LIMITS.maxExpandedTotalBytes,
    expandedFileBytes: ARCHIVE_LIMITS.maxExpandedTotalBytes - 1,
  }),
  fixture("expanded total at the limit", {
    compressedFileBytes: ARCHIVE_LIMITS.maxExpandedTotalBytes,
    expandedFileBytes: ARCHIVE_LIMITS.maxExpandedTotalBytes,
  }),
  fixture(
    "expanded total immediately above the limit",
    {
      compressedFileBytes: ARCHIVE_LIMITS.maxExpandedTotalBytes + 1,
      expandedFileBytes: ARCHIVE_LIMITS.maxExpandedTotalBytes + 1,
    },
    "ARCHIVE_EXPANDED_TOO_LARGE",
  ),
  entryRatioFixture("empty entry with a zero denominator", 0, 0),
  entryRatioFixture("non-empty entry with a zero denominator", 0, 1, [
    "ARCHIVE_COMPRESSION_RATIO",
  ]),
  entryRatioFixture(
    "per-entry ratio immediately below the limit",
    10,
    ARCHIVE_LIMITS.maxExpansionRatio * 10 - 1,
  ),
  entryRatioFixture(
    "per-entry ratio at the limit",
    10,
    ARCHIVE_LIMITS.maxExpansionRatio * 10,
  ),
  entryRatioFixture(
    "per-entry ratio immediately above the limit",
    10,
    ARCHIVE_LIMITS.maxExpansionRatio * 10 + 1,
    ["ARCHIVE_COMPRESSION_RATIO"],
  ),
  aggregateRatioFixture("empty aggregate with a zero denominator", 0, 0),
  aggregateRatioFixture("non-empty aggregate with a zero denominator", 0, 1, [
    "ARCHIVE_COMPRESSION_RATIO",
  ]),
  aggregateRatioFixture(
    "aggregate ratio immediately below the limit",
    10,
    ARCHIVE_LIMITS.maxExpansionRatio * 10 - 1,
  ),
  aggregateRatioFixture(
    "aggregate ratio at the limit",
    10,
    ARCHIVE_LIMITS.maxExpansionRatio * 10,
  ),
  aggregateRatioFixture(
    "aggregate ratio immediately above the limit",
    10,
    ARCHIVE_LIMITS.maxExpansionRatio * 10 + 1,
    ["ARCHIVE_COMPRESSION_RATIO"],
  ),
] as const satisfies readonly ArchiveLimitFixture[];

export const inspectionTimeoutFixture = {
  timeoutMs: OPERATION_LIMITS.perFileTimeoutMs,
  beforeMs: OPERATION_LIMITS.perFileTimeoutMs - 1,
  atMs: OPERATION_LIMITS.perFileTimeoutMs,
  aboveMs: OPERATION_LIMITS.perFileTimeoutMs + 1,
  findingCode: "ARCHIVE_TIMEOUT",
} as const;
