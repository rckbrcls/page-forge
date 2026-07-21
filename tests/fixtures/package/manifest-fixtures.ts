import { parseInternalPath } from "../../../src/domain/audit/internal-path";
import type { ArchiveEntryDescriptor, InternalPath } from "../../../src/domain/models/archive";
import type {
  ManifestItemProjection,
  PackageProjection,
} from "../../../src/domain/models/epub-document";

export type ManifestFindingCode =
  | "METADATA_TITLE_MISSING"
  | "METADATA_IDENTIFIER_MISSING"
  | "METADATA_LANGUAGE_MISSING"
  | "PACKAGE_UNIQUE_IDENTIFIER_INVALID"
  | "MANIFEST_MISSING"
  | "MANIFEST_ID_DUPLICATE"
  | "MANIFEST_HREF_DUPLICATE"
  | "MANIFEST_RESOURCE_MISSING"
  | "MANIFEST_MEDIA_TYPE_MISMATCH"
  | "MANIFEST_MEDIA_TYPE_UNKNOWN";

export interface PackageRuleFixture {
  readonly name: string;
  readonly expectedCode: ManifestFindingCode;
  readonly packageDocument: PackageProjection;
  readonly entryIndex: ReadonlyMap<InternalPath, ArchiveEntryDescriptor>;
}

function internalPath(value: string): InternalPath {
  const result = parseInternalPath(value);
  if (!result.ok) throw new Error(`Invalid fixture path: ${value}`);
  return result.value.path;
}

function manifestItem(
  id: string,
  href: string,
  mediaType: string | undefined,
  properties: readonly string[] = [],
): ManifestItemProjection {
  return { id, href, resolvedPath: internalPath(`EPUB/${href}`), mediaType, properties };
}

function archiveEntry(index: number, path: string): ArchiveEntryDescriptor {
  return {
    index,
    originalName: path,
    path: internalPath(path),
    kind: "file",
    compressionMethod: 8,
    compressedSize: 1,
    expandedSize: 1,
    crc32: 0,
    encrypted: false,
    externalAttributes: 0,
    flags: 0x0800,
    localHeaderExtraLength: 0,
  };
}

function entryIndex(paths: readonly string[]): ReadonlyMap<InternalPath, ArchiveEntryDescriptor> {
  return new Map(paths.map((path, index) => [internalPath(path), archiveEntry(index, path)]));
}

const chapter = manifestItem("chapter", "text/chapter.xhtml", "application/xhtml+xml");
const navigation = manifestItem(
  "nav",
  "nav.xhtml",
  "application/xhtml+xml",
  ["nav"],
);
const cover = manifestItem("cover", "images/cover.png", "image/png", ["cover-image"]);

const basePackage: PackageProjection = {
  path: internalPath("EPUB/package.opf"),
  version: "3",
  metadata: {
    titles: ["Fixture Book"],
    identifiers: [{ id: "book-id", value: "urn:uuid:fixture" }],
    languages: ["en"],
    uniqueIdentifier: "book-id",
  },
  manifest: [chapter, navigation, cover],
  spine: [{ idref: "chapter", linear: true }],
};

const basePaths = [
  "EPUB/package.opf",
  "EPUB/text/chapter.xhtml",
  "EPUB/nav.xhtml",
  "EPUB/images/cover.png",
] as const;

function fixture(
  name: string,
  expectedCode: ManifestFindingCode,
  packageChanges: Partial<PackageProjection>,
  paths: readonly string[] = basePaths,
): PackageRuleFixture {
  return {
    name,
    expectedCode,
    packageDocument: { ...basePackage, ...packageChanges },
    entryIndex: entryIndex(paths),
  };
}

export const manifestRuleFixtures: readonly PackageRuleFixture[] = [
  fixture("missing title", "METADATA_TITLE_MISSING", {
    metadata: { ...basePackage.metadata, titles: ["   "] },
  }),
  fixture("missing identifier", "METADATA_IDENTIFIER_MISSING", {
    metadata: { ...basePackage.metadata, identifiers: [] },
  }),
  fixture("missing language", "METADATA_LANGUAGE_MISSING", {
    metadata: { ...basePackage.metadata, languages: [] },
  }),
  fixture("absent unique-identifier attribute", "PACKAGE_UNIQUE_IDENTIFIER_INVALID", {
    metadata: { ...basePackage.metadata, uniqueIdentifier: undefined },
  }),
  fixture("unresolved unique-identifier", "PACKAGE_UNIQUE_IDENTIFIER_INVALID", {
    metadata: { ...basePackage.metadata, uniqueIdentifier: "missing-id" },
  }),
  fixture("duplicated unique-identifier target", "PACKAGE_UNIQUE_IDENTIFIER_INVALID", {
    metadata: {
      ...basePackage.metadata,
      identifiers: [
        { id: "book-id", value: "urn:uuid:first" },
        { id: "book-id", value: "urn:uuid:second" },
      ],
    },
  }),
  fixture("missing manifest", "MANIFEST_MISSING", { manifest: [] }),
  fixture("duplicate manifest ID", "MANIFEST_ID_DUPLICATE", {
    manifest: [chapter, { ...cover, id: "chapter" }, navigation],
  }),
  fixture("duplicate manifest href", "MANIFEST_HREF_DUPLICATE", {
    manifest: [chapter, { ...chapter, id: "chapter-copy" }, navigation, cover],
  }),
  fixture("missing manifest resource", "MANIFEST_RESOURCE_MISSING", {
    manifest: [
      {
        ...chapter,
        href: "text/missing.xhtml",
        resolvedPath: internalPath("EPUB/text/missing.xhtml"),
      },
      navigation,
      cover,
    ],
  }),
  fixture("known extension with mismatched media type", "MANIFEST_MEDIA_TYPE_MISMATCH", {
    manifest: [{ ...chapter, mediaType: "text/plain" }, navigation, cover],
  }),
  fixture(
    "resource with unknown media type",
    "MANIFEST_MEDIA_TYPE_UNKNOWN",
    {
      manifest: [
        chapter,
        navigation,
        cover,
        manifestItem("unknown", "resources/data.fixture", undefined),
      ],
    },
    [...basePaths, "EPUB/resources/data.fixture"],
  ),
];
