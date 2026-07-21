import { createFinding } from "../../domain/audit/finding-catalog";
import { internalPathCollisionKey, isPathAncestor, withoutDirectoryMarker } from "../../domain/audit/internal-path";
import type { ArchiveEntryDescriptor, InternalPath } from "../../domain/models/archive";
import type { Finding } from "../../domain/models/finding";

export interface ArchivePathSafetyResult {
  readonly findings: readonly Finding[];
}

type ArchivePathSafetyCode =
  | "ARCHIVE_PATH_ABSOLUTE"
  | "ARCHIVE_PATH_TRAVERSAL"
  | "ARCHIVE_PATH_INVALID"
  | "ARCHIVE_ENTRY_DUPLICATE"
  | "ARCHIVE_CASE_COLLISION"
  | "ARCHIVE_FILE_DIRECTORY_CONFLICT"
  | "ARCHIVE_SYMLINK"
  | "ARCHIVE_SPECIAL_FILE";

interface ValidArchivePathEntry {
  readonly path: InternalPath;
}

const UTF8_DECODER = new TextDecoder("utf-8", { fatal: true });

export function inspectArchivePathSafety(entries: readonly ArchiveEntryDescriptor[]): ArchivePathSafetyResult {
  const findings: Finding[] = [];
  const observedPaths = new Map<InternalPath, ValidArchivePathEntry>();
  const collisionBuckets = new Map<string, InternalPath>();
  const seen = new Set<string>();
  const validEntries: ValidArchivePathEntry[] = [];

  const addFinding = (
    code: ArchivePathSafetyCode,
    entryIndex: number,
    evidence: Record<string, string | number | boolean | null> = {},
  ): void => {
    const key = `${code}:${entryIndex}`;
    if (seen.has(key)) return;
    seen.add(key);
    findings.push(
      createFinding(code, {
        location: { kind: "archive_entry", entryIndex },
        evidence,
      }),
    );
  };

  const addPathInvalid = (reason: string, entry: ArchiveEntryDescriptor): void => {
    const code: ArchivePathSafetyCode =
      reason === "absolute"
        ? "ARCHIVE_PATH_ABSOLUTE"
        : reason === "traversal"
          ? "ARCHIVE_PATH_TRAVERSAL"
          : "ARCHIVE_PATH_INVALID";
    addFinding(code, entry.index, { reason, originalName: entry.originalName });
  };

  const checkTypeSafety = (entry: ArchiveEntryDescriptor): void => {
    if (entry.kind === "symlink") {
      addFinding("ARCHIVE_SYMLINK", entry.index, { kind: "symlink" });
    } else if (entry.kind === "special") {
      addFinding("ARCHIVE_SPECIAL_FILE", entry.index, { kind: "special" });
    }
  };

  for (const entry of entries) {
    checkTypeSafety(entry);

    if (typeof entry.path !== "string") {
      addPathInvalid(entry.path.reason, entry);
      continue;
    }

    if (entry.originalNameBytes !== undefined && !isValidUtf8(entry.originalNameBytes)) {
      addPathInvalid("invalid_encoding", entry);
      continue;
    }

    const normalizedPath = entry.path;
    const normalizedPathWithoutMarker = withoutDirectoryMarker(normalizedPath);
    const existingExact = observedPaths.get(normalizedPath);
    if (existingExact !== undefined) {
      addFinding("ARCHIVE_ENTRY_DUPLICATE", entry.index, {
        originalName: entry.originalName,
        existingName: existingExact.path,
      });
      continue;
    }

    const collisionKey = internalPathCollisionKey(normalizedPath);
    const existingCollision = collisionBuckets.get(collisionKey);
    if (existingCollision !== undefined && withoutDirectoryMarker(existingCollision) !== normalizedPathWithoutMarker) {
      addFinding("ARCHIVE_CASE_COLLISION", entry.index, {
        originalName: entry.originalName,
        collidingPath: existingCollision,
      });
    }
    collisionBuckets.set(collisionKey, normalizedPath);

    const current: ValidArchivePathEntry = {
      path: normalizedPath,
    };
    for (const prior of validEntries) {
      if (isFileDirectoryConflict(current.path, prior.path)) {
        const evidencePath =
          prior.path === normalizedPath ? current.path : maybeConflictEvidence(current.path, prior.path);
        addFinding("ARCHIVE_FILE_DIRECTORY_CONFLICT", entry.index, {
          path: current.path,
          siblingPath: prior.path,
          evidencePath,
        });
        break;
      }
    }

    validEntries.push(current);
    observedPaths.set(current.path, current);
  }

  return { findings };
}

export const auditArchivePathSafety = inspectArchivePathSafety;

function isValidUtf8(value: Uint8Array): boolean {
  try {
    UTF8_DECODER.decode(value);
    return true;
  } catch {
    return false;
  }
}

function isFileDirectoryConflict(a: InternalPath, b: InternalPath): boolean {
  if (a === b) return false;
  const aWithoutMarker = withoutDirectoryMarker(a);
  const bWithoutMarker = withoutDirectoryMarker(b);
  if (aWithoutMarker === bWithoutMarker) return true;
  return isPathAncestor(a, b) || isPathAncestor(b, a);
}

function maybeConflictEvidence(path: InternalPath, siblingPath: InternalPath): InternalPath {
  return path < siblingPath ? path : siblingPath;
}
