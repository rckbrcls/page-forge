import { createFinding } from "../finding-catalog";
import type { ArchiveEntryDescriptor, InternalPath } from "../../models/archive";
import type { ManifestItemProjection, PackageProjection } from "../../models/epub-document";
import type { Finding } from "../../models/finding";

const MEDIA_TYPES_BY_EXTENSION: Readonly<Record<string, string>> = {
  ".css": "text/css",
  ".gif": "image/gif",
  ".html": "application/xhtml+xml",
  ".jpeg": "image/jpeg",
  ".jpg": "image/jpeg",
  ".ncx": "application/x-dtbncx+xml",
  ".otf": "font/otf",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".ttf": "font/ttf",
  ".woff": "font/woff",
  ".woff2": "font/woff2",
  ".xhtml": "application/xhtml+xml",
};

export function auditPackageRules(
  packageDocument: PackageProjection,
  entryIndex: ReadonlyMap<InternalPath, ArchiveEntryDescriptor>,
): Finding[] {
  const findings: Finding[] = [];
  const packageLocation = { kind: "internal_path" as const, path: packageDocument.path };
  const metadata = packageDocument.metadata;

  if (!metadata.titles.some(isNonEmpty)) {
    findings.push(createFinding("METADATA_TITLE_MISSING", { location: packageLocation }));
  }
  if (!metadata.identifiers.some(({ value }) => isNonEmpty(value))) {
    findings.push(createFinding("METADATA_IDENTIFIER_MISSING", { location: packageLocation }));
  }
  if (!metadata.languages.some(isNonEmpty)) {
    findings.push(createFinding("METADATA_LANGUAGE_MISSING", { location: packageLocation }));
  }

  const uniqueIdentifier = metadata.uniqueIdentifier?.trim();
  const uniqueIdentifierMatches = metadata.identifiers.filter(
    ({ id, value }) => id === uniqueIdentifier && isNonEmpty(value),
  );
  if (uniqueIdentifier === undefined || uniqueIdentifier.length === 0 || uniqueIdentifierMatches.length !== 1) {
    findings.push(
      createFinding("PACKAGE_UNIQUE_IDENTIFIER_INVALID", {
        location: packageLocation,
        targetIdentifier: uniqueIdentifier,
      }),
    );
  }

  if (packageDocument.manifest.length === 0) {
    findings.push(createFinding("MANIFEST_MISSING", { location: packageLocation }));
  } else {
    auditManifest(packageDocument, entryIndex, findings);
    auditNavigationAndCover(packageDocument, findings);
  }
  auditSpine(packageDocument, findings);

  return findings;
}

function auditManifest(
  packageDocument: PackageProjection,
  entryIndex: ReadonlyMap<InternalPath, ArchiveEntryDescriptor>,
  findings: Finding[],
): void {
  const idCounts = countBy(packageDocument.manifest, ({ id }) => id.normalize("NFC"));
  const hrefCounts = countBy(packageDocument.manifest, manifestTargetKey);

  const duplicateId = firstDuplicate(idCounts);
  if (duplicateId !== undefined) {
    findings.push(
      createFinding("MANIFEST_ID_DUPLICATE", {
        location: { kind: "manifest_item", path: packageDocument.path, manifestId: duplicateId },
        targetIdentifier: duplicateId,
      }),
    );
  }
  const duplicateHref = firstDuplicate(hrefCounts);
  if (duplicateHref !== undefined) {
    findings.push(
      createFinding("MANIFEST_HREF_DUPLICATE", {
        location: { kind: "internal_path", path: packageDocument.path },
        targetIdentifier: duplicateHref,
      }),
    );
  }

  const missing = packageDocument.manifest.find(
    ({ resolvedPath }) => resolvedPath === undefined || !entryIndex.has(resolvedPath),
  );
  if (missing !== undefined) {
    findings.push(manifestFinding("MANIFEST_RESOURCE_MISSING", packageDocument, missing));
  }

  const mismatch = packageDocument.manifest.find((item) => {
    const expected = expectedMediaType(item.href);
    return expected !== undefined && item.mediaType !== undefined && item.mediaType !== expected;
  });
  if (mismatch !== undefined) {
    const expected = expectedMediaType(mismatch.href);
    findings.push(
      manifestFinding("MANIFEST_MEDIA_TYPE_MISMATCH", packageDocument, mismatch, {
        declaredMediaType: mismatch.mediaType ?? null,
        expectedMediaType: expected ?? null,
      }),
    );
  }

  const unknown = packageDocument.manifest.find(
    (item) => item.mediaType === undefined && expectedMediaType(item.href) === undefined,
  );
  if (unknown !== undefined) {
    findings.push(manifestFinding("MANIFEST_MEDIA_TYPE_UNKNOWN", packageDocument, unknown));
  }
}

function auditSpine(packageDocument: PackageProjection, findings: Finding[]): void {
  if (packageDocument.spine.length === 0) {
    findings.push(
      createFinding("SPINE_MISSING", {
        location: { kind: "internal_path", path: packageDocument.path },
      }),
    );
    return;
  }

  const missingId = packageDocument.spine.find(({ idref }) => !isNonEmpty(idref ?? ""));
  if (missingId !== undefined) {
    findings.push(
      createFinding("SPINE_ITEMREF_MISSING_ID", {
        location: { kind: "internal_path", path: packageDocument.path },
      }),
    );
  }

  const manifestIds = new Set(packageDocument.manifest.map(({ id }) => id));
  const absentItem = packageDocument.spine.find(
    ({ idref }) => isNonEmpty(idref ?? "") && !manifestIds.has(idref!),
  );
  if (absentItem?.idref !== undefined) {
    findings.push(
      createFinding("SPINE_ITEM_NOT_IN_MANIFEST", {
        location: {
          kind: "spine_item",
          path: packageDocument.path,
          idref: absentItem.idref,
        },
        targetIdentifier: absentItem.idref,
      }),
    );
  }

  const hasLinearReadingOrder = packageDocument.spine.some(
    ({ idref, linear }) =>
      isNonEmpty(idref ?? "") && linear !== false && manifestIds.has(idref!),
  );
  if (!hasLinearReadingOrder && missingId === undefined && absentItem === undefined) {
    findings.push(
      createFinding("SPINE_READING_ORDER_INVALID", {
        location: { kind: "internal_path", path: packageDocument.path },
      }),
    );
  }
}

function auditNavigationAndCover(packageDocument: PackageProjection, findings: Finding[]): void {
  const navigation =
    packageDocument.version === "2"
      ? packageDocument.manifest.filter(
          ({ id, mediaType }) =>
            id === packageDocument.spineToc && mediaType === "application/x-dtbncx+xml",
        )
      : packageDocument.manifest.filter(({ properties }) => properties.includes("nav"));
  if (navigation.length === 0) {
    findings.push(createFinding("NAVIGATION_MISSING", { location: { kind: "internal_path", path: packageDocument.path } }));
  } else if (navigation.length > 1) {
    findings.push(createFinding("NAVIGATION_AMBIGUOUS", { location: { kind: "internal_path", path: packageDocument.path } }));
  }

  const covers = packageDocument.manifest.filter(isCoverCandidate);
  if (covers.length === 0) {
    findings.push(createFinding("COVER_MISSING", { location: { kind: "internal_path", path: packageDocument.path } }));
  } else if (covers.length > 1) {
    findings.push(createFinding("COVER_AMBIGUOUS", { location: { kind: "internal_path", path: packageDocument.path } }));
  }
}

function manifestFinding(
  code: "MANIFEST_RESOURCE_MISSING" | "MANIFEST_MEDIA_TYPE_MISMATCH" | "MANIFEST_MEDIA_TYPE_UNKNOWN",
  packageDocument: PackageProjection,
  item: ManifestItemProjection,
  evidence: Readonly<Record<string, string | number | boolean | null>> = {},
): Finding {
  return createFinding(code, {
    location: { kind: "manifest_item", path: packageDocument.path, manifestId: item.id },
    targetIdentifier: item.id,
    evidence,
  });
}

function isNonEmpty(value: string): boolean {
  return value.trim().length > 0;
}

function manifestTargetKey(item: ManifestItemProjection): string {
  return (item.resolvedPath ?? item.href).normalize("NFC");
}

function countBy<T>(items: readonly T[], keyFor: (item: T) => string): Map<string, number> {
  const counts = new Map<string, number>();
  for (const item of items) {
    const key = keyFor(item);
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  return counts;
}

function firstDuplicate(counts: ReadonlyMap<string, number>): string | undefined {
  return [...counts].find(([, count]) => count > 1)?.[0];
}

function expectedMediaType(href: string): string | undefined {
  const path = href.split(/[?#]/, 1)[0]?.toLowerCase() ?? "";
  const dot = path.lastIndexOf(".");
  return dot < 0 ? undefined : MEDIA_TYPES_BY_EXTENSION[path.slice(dot)];
}

function isCoverCandidate(item: ManifestItemProjection): boolean {
  if (item.properties.includes("cover-image")) return true;
  const id = item.id.toLowerCase();
  const basename = item.href.split("/").at(-1)?.toLowerCase() ?? "";
  return id === "cover" || id === "cover-image" || /^cover(?:[._-]|$)/.test(basename);
}
