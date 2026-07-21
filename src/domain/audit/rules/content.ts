import { createFinding } from "../finding-catalog";
import { internalPathCollisionKey, referenceIdentity } from "../internal-path";
import type { InternalPath } from "../../models/archive";
import type { ContentProjection, PackageProjection } from "../../models/epub-document";
import type { Finding } from "../../models/finding";

export interface ContentAuditInput {
  readonly packageDocument: PackageProjection;
  readonly contentDocuments: readonly ContentProjection[];
  readonly malformedXhtmlPaths: readonly InternalPath[];
  readonly existingPaths: readonly InternalPath[];
  readonly relevantResourceBytes: ReadonlyMap<InternalPath, number>;
}

export function auditContent(input: ContentAuditInput): Finding[] {
  const findings: Finding[] = [];
  const exactPaths = new Set(input.existingPaths);
  const pathsByCollisionKey = new Map<string, InternalPath[]>();
  for (const path of input.existingPaths) {
    const key = internalPathCollisionKey(path);
    pathsByCollisionKey.set(key, [...(pathsByCollisionKey.get(key) ?? []), path]);
  }

  for (const path of input.malformedXhtmlPaths) {
    findings.push(
      createFinding("XHTML_MALFORMED", {
        location: { kind: "internal_path", path },
      }),
    );
  }

  for (const document of input.contentDocuments) {
    for (const reference of document.references) {
      const location = { kind: "internal_path" as const, path: document.path };
      if (isRemoteReference(reference.rawReference)) {
        findings.push(
          createFinding("CONTENT_REMOTE_RESOURCE", {
            location,
            targetIdentifier: reference.rawReference,
          }),
        );
        continue;
      }
      if (reference.targetPath === undefined || exactPaths.has(reference.targetPath)) continue;

      const equivalentPaths = pathsByCollisionKey.get(
        internalPathCollisionKey(reference.targetPath),
      );
      if (equivalentPaths?.length === 1) {
        findings.push(
          createFinding("CONTENT_PATH_CASE_MISMATCH", {
            location,
            targetIdentifier: referenceIdentity(reference.targetPath, reference.fragment),
            evidence: {
              referencedPath: reference.targetPath,
              existingPath: equivalentPaths[0]!,
            },
          }),
        );
        continue;
      }

      findings.push(
        createFinding(missingReferenceCode(reference.kind), {
          location,
          targetIdentifier: referenceIdentity(reference.targetPath, reference.fragment),
          evidence: { reference: reference.rawReference },
        }),
      );
    }
  }

  for (const [path, bytes] of input.relevantResourceBytes) {
    if (bytes === 0) {
      findings.push(
        createFinding("CONTENT_RELEVANT_FILE_EMPTY", {
          location: { kind: "internal_path", path },
        }),
      );
    }
  }

  const manifestById = new Map(input.packageDocument.manifest.map((item) => [item.id, item]));
  const spinePaths = new Set(
    input.packageDocument.spine.flatMap(({ idref, linear }) => {
      if (idref === undefined || linear === false) return [];
      const path = manifestById.get(idref)?.resolvedPath;
      return path === undefined ? [] : [path];
    }),
  );
  for (const document of input.contentDocuments) {
    if (spinePaths.has(document.path) && !document.hasUsefulContent) {
      findings.push(
        createFinding("CONTENT_CHAPTER_EMPTY", {
          location: { kind: "internal_path", path: document.path },
        }),
      );
    }
  }

  if (input.packageDocument.metadata.renditionLayout === "pre-paginated") {
    findings.push(
      createFinding("CONTENT_FIXED_LAYOUT", {
        location: { kind: "internal_path", path: input.packageDocument.path },
      }),
    );
  }

  return findings;
}

function missingReferenceCode(kind: ContentProjection["references"][number]["kind"]):
  | "CONTENT_LINK_BROKEN"
  | "CONTENT_IMAGE_MISSING"
  | "CONTENT_STYLESHEET_MISSING"
  | "CONTENT_FONT_MISSING" {
  switch (kind) {
    case "image":
      return "CONTENT_IMAGE_MISSING";
    case "stylesheet":
      return "CONTENT_STYLESHEET_MISSING";
    case "font":
      return "CONTENT_FONT_MISSING";
    case "link":
    case "other":
      return "CONTENT_LINK_BROKEN";
  }
}

function isRemoteReference(reference: string): boolean {
  return /^https?:\/\//i.test(reference) || reference.startsWith("//");
}
