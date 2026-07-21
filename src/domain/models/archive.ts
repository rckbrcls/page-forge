import type { Finding } from "./finding";
import type { RuleResult } from "./health-report";

declare const internalPathBrand: unique symbol;

export type InternalPath = string & { readonly [internalPathBrand]: "InternalPath" };

export type ArchiveEntryKind = "file" | "directory" | "symlink" | "special";

export interface InvalidInternalPathEvidence {
  readonly originalName: string;
  readonly reason:
    "absolute" | "traversal" | "empty" | "nul" | "backslash" | "invalid_unicode" | "invalid_directory_marker";
}

export interface ArchiveEntryDescriptor {
  readonly index: number;
  readonly originalName: string;
  readonly originalNameBytes?: Uint8Array;
  readonly path: InternalPath | InvalidInternalPathEvidence;
  readonly kind: ArchiveEntryKind;
  readonly compressionMethod: number;
  readonly compressedSize: number;
  readonly expandedSize: number;
  readonly crc32: number;
  readonly encrypted: boolean;
  readonly externalAttributes: number;
  readonly flags: number;
  readonly localHeaderExtraLength: number;
}

export interface ArchiveProjection {
  readonly entries: readonly ArchiveEntryDescriptor[];
  readonly entryIndex: ReadonlyMap<InternalPath, ArchiveEntryDescriptor>;
  readonly compressedFileBytes: number;
  readonly expandedFileBytes: number;
}

export interface PreflightOutcome<TProjection> {
  readonly terminal: boolean;
  readonly projection?: TProjection;
  readonly findings: readonly Finding[];
  readonly ruleResults: readonly RuleResult[];
}
