import { parseInternalPath } from "../../../src/domain/audit/internal-path";
import type { ArchiveEntryDescriptor, InternalPath } from "../../../src/domain/models/archive";
import type {
  ManifestItemProjection,
  PackageProjection,
} from "../../../src/domain/models/epub-document";

export type ReadingOrderFindingCode =
  | "SPINE_MISSING"
  | "SPINE_ITEMREF_MISSING_ID"
  | "SPINE_ITEM_NOT_IN_MANIFEST"
  | "SPINE_READING_ORDER_INVALID"
  | "NAVIGATION_MISSING"
  | "NAVIGATION_AMBIGUOUS"
  | "COVER_MISSING"
  | "COVER_AMBIGUOUS";

export interface ReadingOrderRuleFixture {
  readonly name: string;
  readonly expectedCode: ReadingOrderFindingCode;
  readonly packageDocument: PackageProjection;
  readonly entryIndex: ReadonlyMap<InternalPath, ArchiveEntryDescriptor>;
}

function internalPath(value: string): InternalPath {
  const result = parseInternalPath(value);
  if (!result.ok) throw new Error(`Invalid fixture path: ${value}`);
  return result.value.path;
}

function item(
  id: string,
  href: string,
  mediaType: string,
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

const chapter = item("chapter", "text/chapter.xhtml", "application/xhtml+xml");
const nav = item("nav", "nav.xhtml", "application/xhtml+xml", ["nav"]);
const cover = item("cover", "images/cover.png", "image/png", ["cover-image"]);

const basePackage: PackageProjection = {
  path: internalPath("EPUB/package.opf"),
  version: "3",
  metadata: {
    titles: ["Fixture Book"],
    identifiers: [{ id: "book-id", value: "urn:uuid:fixture" }],
    languages: ["en"],
    uniqueIdentifier: "book-id",
  },
  manifest: [chapter, nav, cover],
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
  expectedCode: ReadingOrderFindingCode,
  packageChanges: Partial<PackageProjection>,
  paths: readonly string[] = basePaths,
): ReadingOrderRuleFixture {
  return {
    name,
    expectedCode,
    packageDocument: { ...basePackage, ...packageChanges },
    entryIndex: entryIndex(paths),
  };
}

export const readingOrderRuleFixtures: readonly ReadingOrderRuleFixture[] = [
  fixture("missing spine", "SPINE_MISSING", { spine: [] }),
  fixture("spine itemref without idref", "SPINE_ITEMREF_MISSING_ID", { spine: [{}] }),
  fixture("spine item absent from manifest", "SPINE_ITEM_NOT_IN_MANIFEST", {
    spine: [{ idref: "missing-chapter", linear: true }],
  }),
  fixture("spine without a linear reading order", "SPINE_READING_ORDER_INVALID", {
    spine: [{ idref: "chapter", linear: false }],
  }),
  fixture("EPUB 3 without a navigation document", "NAVIGATION_MISSING", {
    manifest: [chapter, cover],
  }),
  fixture("EPUB 2 without an NCX reference", "NAVIGATION_MISSING", {
    version: "2",
    manifest: [chapter, cover],
    spineToc: undefined,
  }),
  fixture(
    "multiple EPUB 3 navigation documents",
    "NAVIGATION_AMBIGUOUS",
    {
      manifest: [
        chapter,
        nav,
        item("nav-secondary", "nav-secondary.xhtml", "application/xhtml+xml", ["nav"]),
        cover,
      ],
    },
    [...basePaths, "EPUB/nav-secondary.xhtml"],
  ),
  fixture("missing cover", "COVER_MISSING", { manifest: [chapter, nav] }),
  fixture(
    "multiple cover candidates",
    "COVER_AMBIGUOUS",
    {
      manifest: [
        chapter,
        nav,
        cover,
        item("cover-secondary", "images/cover-secondary.jpg", "image/jpeg", ["cover-image"]),
      ],
    },
    [...basePaths, "EPUB/images/cover-secondary.jpg"],
  ),
];
