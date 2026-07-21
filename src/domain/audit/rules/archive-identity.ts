import { createFinding } from "../finding-catalog";
import type { ArchiveEntryDescriptor } from "../../models/archive";
import type { Finding } from "../../models/finding";

export interface ArchiveIdentityInput {
  readonly valid?: boolean;
  readonly entries?: readonly ArchiveEntryDescriptor[];
  readonly multiDisk?: boolean;
  readonly zip64Invalid?: boolean;
  readonly crcMismatchEntryIndexes?: readonly number[];
  readonly sizeMismatchEntryIndexes?: readonly number[];
}

export function auditArchiveIdentity(input: ArchiveIdentityInput | readonly ArchiveEntryDescriptor[]): Finding[] {
  const normalized: ArchiveIdentityInput = Array.isArray(input)
    ? { entries: input as readonly ArchiveEntryDescriptor[] }
    : (input as ArchiveIdentityInput);
  if (normalized.valid === false) return [createFinding("ZIP_INVALID")];

  const findings: Finding[] = [];
  if (normalized.multiDisk === true) findings.push(createFinding("ZIP_MULTIDISK"));
  if (normalized.zip64Invalid === true) findings.push(createFinding("ZIP64_INVALID"));
  if (normalized.entries?.length === 0) findings.push(createFinding("ZIP_EMPTY"));

  for (const entry of normalized.entries ?? []) {
    if (entry.compressionMethod !== 0 && entry.compressionMethod !== 8) {
      findings.push(
        createFinding("ZIP_METHOD_UNSUPPORTED", {
          location: { kind: "archive_entry", entryIndex: entry.index },
          evidence: { compressionMethod: entry.compressionMethod },
        }),
      );
    }
  }
  for (const entryIndex of normalized.crcMismatchEntryIndexes ?? []) {
    findings.push(
      createFinding("ZIP_CRC_MISMATCH", {
        location: { kind: "archive_entry", entryIndex },
      }),
    );
  }
  for (const entryIndex of normalized.sizeMismatchEntryIndexes ?? []) {
    findings.push(
      createFinding("ZIP_SIZE_MISMATCH", {
        location: { kind: "archive_entry", entryIndex },
      }),
    );
  }
  return findings;
}

export const auditArchiveIdentityRules = auditArchiveIdentity;
