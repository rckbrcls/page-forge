import { createFinding } from "../finding-catalog";
import type { ArchiveEntryDescriptor, InternalPath } from "../../models/archive";
import type { ContentProjection, EncryptionProjection, PackageProjection } from "../../models/epub-document";
import type { Finding } from "../../models/finding";

export interface ActiveContentInput {
  readonly packageDocument: PackageProjection;
  readonly contentDocuments: readonly ContentProjection[];
  readonly archiveEntries: readonly ArchiveEntryDescriptor[];
  readonly encryption?: EncryptionProjection;
}

export function auditActiveContent(input: ActiveContentInput): Finding[] {
  const findings: Finding[] = [];

  for (const document of input.contentDocuments) {
    for (const reference of document.references) {
      if (isRemoteResource(reference.rawReference)) {
        findings.push(
          createFinding("CONTENT_REMOTE_RESOURCE", {
            location: { kind: "internal_path", path: document.path },
            targetIdentifier: reference.rawReference,
          }),
        );
      } else if (isLocalFileReference(reference.rawReference)) {
        findings.push(
          createFinding("CONTENT_EXTERNAL_FILE_REFERENCE", {
            location: { kind: "internal_path", path: document.path },
            targetIdentifier: reference.rawReference,
          }),
        );
      }
    }

    if (document.scripted) {
      findings.push(
        createFinding("CONTENT_SCRIPTED", {
          location: { kind: "internal_path", path: document.path },
        }),
      );
    }

    if (document.interactive) {
      findings.push(
        createFinding("CONTENT_INTERACTIVE", {
          location: { kind: "internal_path", path: document.path },
        }),
      );
    }
  }

  for (const item of input.packageDocument.manifest) {
    if (item.resolvedPath === undefined || item.mediaType === undefined) continue;
    if (isExecutableMediaType(item.mediaType) || isExecutablePath(item.resolvedPath)) {
      findings.push(
        createFinding("CONTENT_EXECUTABLE_RESOURCE", {
          location: { kind: "internal_path", path: item.resolvedPath },
        }),
      );
    }
  }

  if (input.encryption !== undefined && input.encryption.path.length > 0) {
    findings.push(
      createFinding("CONTENT_ENCRYPTED", {
        location: { kind: "internal_path", path: input.encryption.path },
      }),
    );
  }

  return findings;
}

function isRemoteResource(reference: string): boolean {
  return /^https?:\/\//i.test(reference) || reference.startsWith("//");
}

function isLocalFileReference(reference: string): boolean {
  return /^file:\/\//i.test(reference) || /^\//.test(reference) || /^[A-Za-z]:[\\/]/.test(reference);
}

function isExecutableMediaType(mediaType: string): boolean {
  const normalized = mediaType.toLowerCase().trim();
  return (
    normalized === "application/x-msdownload" ||
    normalized === "application/x-executable" ||
    normalized === "application/vnd.microsoft.portable-executable" ||
    normalized === "application/x-msdos-program" ||
    normalized === "application/x-shockwave-flash" ||
    normalized === "application/octet-stream"
  );
}

function isExecutablePath(path: InternalPath): boolean {
  const lower = path.toLowerCase();
  const hasExecutableExtension = [
    ".exe",
    ".dll",
    ".com",
    ".msi",
    ".cmd",
    ".bat",
    ".scr",
    ".vbs",
    ".vbe",
    ".ps1",
    ".js",
    ".jar",
  ].some((extension) => lower.endsWith(extension));
  return hasExecutableExtension;
}
