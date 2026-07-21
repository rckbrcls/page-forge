import type { ArchiveLimits } from "../../application/ports";
import { OPERATION_LIMITS } from "../../domain/audit/limits";
import { createFinding } from "../../domain/audit/finding-catalog";
import type { FindingCode } from "../../domain/audit/finding-codes";
import type { Finding } from "../../domain/models/finding";

export interface ArchiveLimitsEntryMetadata {
  readonly kind: "file" | "directory";
  readonly compressedSize: number;
  readonly expandedSize: number;
}

export interface ArchiveLimitsMetadata {
  readonly sourceBytes: number;
  readonly entryCount: number;
  readonly entries: readonly ArchiveLimitsEntryMetadata[];
  readonly compressedFileBytes: number;
  readonly expandedFileBytes: number;
}

export interface InspectionDeadline {
  readonly signal: AbortSignal;
  readonly dispose: () => void;
}

interface RatioTuple {
  readonly expanded: bigint;
  readonly compressed: bigint;
}

function toSafeBigInt(value: number): bigint | undefined {
  if (!Number.isSafeInteger(value) || value < 0) return undefined;
  return BigInt(value);
}

function exceedsRatio({ expanded, compressed }: RatioTuple, maxRatio: bigint): boolean {
  if (compressed === 0n) return expanded > 0n;
  return expanded > compressed * maxRatio;
}

function addOnce(findings: Finding[], seen: Set<FindingCode>, code: FindingCode): void {
  if (seen.has(code)) return;
  seen.add(code);
  findings.push(createFinding(code));
}

export function inspectArchiveLimits(metadata: ArchiveLimitsMetadata, limits: ArchiveLimits): readonly Finding[] {
  const findings: Finding[] = [];
  const seen = new Set<FindingCode>();

  const maxSourceBytes = toSafeBigInt(limits.maxSourceBytes);
  const sourceBytes = toSafeBigInt(metadata.sourceBytes);
  if (maxSourceBytes !== undefined && (sourceBytes === undefined || sourceBytes > maxSourceBytes)) {
    addOnce(findings, seen, "ARCHIVE_SOURCE_TOO_LARGE");
  }

  const maxEntryCount = toSafeBigInt(limits.maxEntryCount);
  const entryCount = toSafeBigInt(metadata.entryCount);
  if (maxEntryCount !== undefined && (entryCount === undefined || entryCount > maxEntryCount)) {
    addOnce(findings, seen, "ARCHIVE_TOO_MANY_ENTRIES");
  }

  const maxExpandedEntryBytes = toSafeBigInt(limits.maxExpandedEntryBytes);
  const maxExpandedTotalBytes = toSafeBigInt(limits.maxExpandedTotalBytes);
  const maxExpansionRatio = toSafeBigInt(limits.maxExpansionRatio);

  for (const entry of metadata.entries) {
    if (entry.kind !== "file") continue;

    const expandedEntryBytes = toSafeBigInt(entry.expandedSize);
    const compressedEntryBytes = toSafeBigInt(entry.compressedSize);
    if (
      maxExpandedEntryBytes !== undefined &&
      (expandedEntryBytes === undefined || expandedEntryBytes > maxExpandedEntryBytes)
    ) {
      addOnce(findings, seen, "ARCHIVE_ENTRY_TOO_LARGE");
    }

    if (maxExpansionRatio !== undefined && compressedEntryBytes !== undefined && expandedEntryBytes !== undefined) {
      if (exceedsRatio({ expanded: expandedEntryBytes, compressed: compressedEntryBytes }, maxExpansionRatio)) {
        addOnce(findings, seen, "ARCHIVE_COMPRESSION_RATIO");
      }
    } else {
      if (maxExpansionRatio !== undefined) {
        addOnce(findings, seen, "ARCHIVE_COMPRESSION_RATIO");
      }
    }
  }

  const compressedFileBytes = toSafeBigInt(metadata.compressedFileBytes);
  const expandedFileBytes = toSafeBigInt(metadata.expandedFileBytes);
  if (
    maxExpandedTotalBytes !== undefined &&
    (compressedFileBytes === undefined || expandedFileBytes === undefined || expandedFileBytes > maxExpandedTotalBytes)
  ) {
    addOnce(findings, seen, "ARCHIVE_EXPANDED_TOO_LARGE");
  }

  if (maxExpansionRatio !== undefined && compressedFileBytes !== undefined && expandedFileBytes !== undefined) {
    if (exceedsRatio({ expanded: expandedFileBytes, compressed: compressedFileBytes }, maxExpansionRatio)) {
      addOnce(findings, seen, "ARCHIVE_COMPRESSION_RATIO");
    }
  } else {
    if (maxExpansionRatio !== undefined) {
      addOnce(findings, seen, "ARCHIVE_COMPRESSION_RATIO");
    }
  }

  return findings;
}

export interface ArchiveLimitStreamMonitor {
  readonly findings: readonly Finding[];
  readonly isActive: boolean;
  beginEntry(entry: ArchiveLimitsEntryMetadata): void;
  endEntry(): void;
  addCompressedBytes(bytes: number): void;
  addExpandedBytes(bytes: number): void;
  reset(): void;
}

export function createArchiveLimitStreamMonitor(limits: ArchiveLimits): ArchiveLimitStreamMonitor {
  const findings: Finding[] = [];
  const seen = new Set<FindingCode>();

  const maxExpandedEntryBytes = toSafeBigInt(limits.maxExpandedEntryBytes);
  const maxExpandedTotalBytes = toSafeBigInt(limits.maxExpandedTotalBytes);
  const maxExpansionRatio = toSafeBigInt(limits.maxExpansionRatio);

  let active = false;
  let activeIsFile = false;
  let activeCompressedDeclared: bigint | undefined;
  let activeExpanded = 0n;
  let aggregateCompressed = 0n;
  let aggregateExpanded = 0n;

  const addFinding = (code: FindingCode): void => {
    addOnce(findings, seen, code);
  };

  const incrementCompressed = (value: number): void => {
    if (!activeIsFile) {
      return;
    }

    const safe = toSafeBigInt(value);
    if (safe === undefined) {
      addFinding("ARCHIVE_SOURCE_TOO_LARGE");
      return;
    }
    aggregateCompressed += safe;
  };

  const incrementExpanded = (value: number): void => {
    if (!activeIsFile) {
      return;
    }

    const safe = toSafeBigInt(value);
    if (safe === undefined) {
      addFinding("ARCHIVE_ENTRY_TOO_LARGE");
      return;
    }

    aggregateExpanded += safe;
    if (maxExpandedTotalBytes !== undefined && aggregateExpanded > maxExpandedTotalBytes) {
      addFinding("ARCHIVE_EXPANDED_TOO_LARGE");
    }
    if (maxExpandedEntryBytes !== undefined && activeExpanded + safe > maxExpandedEntryBytes) {
      addFinding("ARCHIVE_ENTRY_TOO_LARGE");
      return;
    }
    activeExpanded += safe;
    if (maxExpansionRatio !== undefined) {
      if (activeCompressedDeclared === undefined) {
        addFinding("ARCHIVE_COMPRESSION_RATIO");
      } else if (exceedsRatio({ expanded: activeExpanded, compressed: activeCompressedDeclared }, maxExpansionRatio)) {
        addFinding("ARCHIVE_COMPRESSION_RATIO");
      }
    }
  };

  const checkAggregateRatio = (): void => {
    if (maxExpansionRatio === undefined) {
      return;
    }
    if (exceedsRatio({ expanded: aggregateExpanded, compressed: aggregateCompressed }, maxExpansionRatio)) {
      addFinding("ARCHIVE_COMPRESSION_RATIO");
    }
  };

  return {
    get findings() {
      return findings;
    },
    get isActive() {
      return active;
    },
    beginEntry(entry): void {
      if (active) throw new Error("An archive entry is already active.");
      active = true;
      activeIsFile = entry.kind === "file";
      activeCompressedDeclared = activeIsFile ? toSafeBigInt(entry.compressedSize) : undefined;
      activeExpanded = 0n;
      if (activeIsFile && maxExpansionRatio !== undefined && activeCompressedDeclared === undefined) {
        addFinding("ARCHIVE_COMPRESSION_RATIO");
      }
    },
    endEntry(): void {
      active = false;
      activeIsFile = false;
      activeExpanded = 0n;
      activeCompressedDeclared = undefined;
    },
    addCompressedBytes(bytes: number): void {
      if (!active) {
        throw new Error("No active entry is open.");
      }
      incrementCompressed(bytes);
      checkAggregateRatio();
    },
    addExpandedBytes(bytes: number): void {
      if (!active) {
        throw new Error("No active entry is open.");
      }
      incrementExpanded(bytes);
      checkAggregateRatio();
    },
    reset(): void {
      findings.length = 0;
      seen.clear();
      active = false;
      activeIsFile = false;
      activeExpanded = 0n;
      activeCompressedDeclared = undefined;
      aggregateCompressed = 0n;
      aggregateExpanded = 0n;
    },
  };
}

export function createInspectionDeadline(
  parentSignal: AbortSignal,
  timeoutMs: number = OPERATION_LIMITS.perFileTimeoutMs,
): InspectionDeadline {
  const controller = new AbortController();
  const timer = setTimeout(() => {
    if (controller.signal.aborted) return;
    parentSignal.removeEventListener("abort", onParentAbort);
    controller.abort({ code: "ARCHIVE_TIMEOUT" });
  }, timeoutMs);

  const onParentAbort = (): void => {
    if (controller.signal.aborted) return;
    clearTimeout(timer);
    controller.abort(parentSignal.reason);
  };

  if (parentSignal.aborted) {
    onParentAbort();
  } else {
    parentSignal.addEventListener("abort", onParentAbort, { once: true });
  }

  return {
    signal: controller.signal,
    dispose: () => {
      clearTimeout(timer);
      parentSignal.removeEventListener("abort", onParentAbort);
    },
  };
}
