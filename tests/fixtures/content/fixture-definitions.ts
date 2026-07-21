import type { FindingCode } from "../../../src/domain/audit/finding-codes";
import { parseInternalPath } from "../../../src/domain/audit/internal-path";
import type { InternalPath } from "../../../src/domain/models/archive";
import type {
  ContentProjection,
  PackageProjection,
} from "../../../src/domain/models/epub-document";
import type {
  FindingStateImpact,
  Repairability,
  Severity,
} from "../../../src/domain/models/finding";
import type { RepairKind } from "../../../src/domain/models/repair";
import {
  createMinimalEpub,
  createPackageDocument,
  createStylesheet,
  createXhtmlDocument,
} from "../../support/epub-fixture-factory";
import type { ZipFixtureEntry } from "../../support/fixture-builder";

export interface ContentAuditInput {
  readonly packageDocument: PackageProjection;
  readonly contentDocuments: readonly ContentProjection[];
  readonly malformedXhtmlPaths: readonly InternalPath[];
  readonly existingPaths: readonly InternalPath[];
  readonly relevantResourceBytes: ReadonlyMap<InternalPath, number>;
}

export interface ContentFindingExpectation {
  readonly code: FindingCode;
  readonly severity: Severity;
  readonly stateImpact: FindingStateImpact;
  readonly repairability: Repairability;
  readonly recommendedRepair?: RepairKind;
  readonly location: InternalPath;
}

export interface ContentRuleFixture {
  readonly name: string;
  readonly epub: Buffer;
  readonly input: ContentAuditInput;
  readonly expected: ContentFindingExpectation;
}

const packagePath = internalPath("EPUB/package.opf");
const chapterPath = internalPath("EPUB/text/chapter.xhtml");
const stylesheetPath = internalPath("EPUB/styles/book.css");
const imagePath = internalPath("EPUB/images/cover.png");
const fontPath = internalPath("EPUB/fonts/book.woff");

function internalPath(value: string): InternalPath {
  const parsed = parseInternalPath(value);
  if (!parsed.ok) throw new Error(`Invalid fixture internal path: ${value}`);
  return parsed.value.path;
}

function packageDocument(options: {
  readonly renditionLayout?: string;
  readonly includeStylesheet?: boolean;
} = {}): PackageProjection {
  const manifest: PackageProjection["manifest"] = [
    {
      id: "chapter",
      href: "text/chapter.xhtml",
      resolvedPath: chapterPath,
      mediaType: "application/xhtml+xml",
      properties: [],
    },
    ...(options.includeStylesheet
      ? [
          {
            id: "css",
            href: "styles/book.css",
            resolvedPath: stylesheetPath,
            mediaType: "text/css",
            properties: [],
          },
        ]
      : []),
  ];

  return {
    path: packagePath,
    version: "3",
    metadata: {
      titles: ["Fixture Book"],
      identifiers: [{ id: "book-id", value: "urn:uuid:page-forge-fixture" }],
      languages: ["en"],
      uniqueIdentifier: "book-id",
      renditionLayout: options.renditionLayout,
    },
    manifest,
    spine: [{ idref: "chapter", linear: true }],
  };
}

function contentDocument(options: {
  readonly path?: InternalPath;
  readonly mediaType?: string;
  readonly references?: ContentProjection["references"];
  readonly hasUsefulContent?: boolean;
} = {}): ContentProjection {
  return {
    path: options.path ?? chapterPath,
    mediaType: options.mediaType ?? "application/xhtml+xml",
    references: options.references ?? [],
    scripted: false,
    interactive: false,
    hasUsefulContent: options.hasUsefulContent ?? true,
  };
}

function replaceEntry(
  entries: ZipFixtureEntry[],
  name: string,
  data: string | Uint8Array,
): ZipFixtureEntry[] {
  return entries.map((entry) => (entry.name === name ? { ...entry, data } : entry));
}

function epubWithChapter(chapter: string): Buffer {
  return createMinimalEpub({
    transformEntries: (entries) => replaceEntry(entries, "EPUB/text/chapter.xhtml", chapter),
  });
}

function fixtureInput(options: Partial<ContentAuditInput> = {}): ContentAuditInput {
  return {
    packageDocument: packageDocument(),
    contentDocuments: [contentDocument()],
    malformedXhtmlPaths: [],
    existingPaths: [packagePath, chapterPath, stylesheetPath, imagePath, fontPath],
    relevantResourceBytes: new Map(),
    ...options,
  };
}

export const malformedXhtmlFixture: ContentRuleFixture = {
  name: "malformed XHTML",
  epub: epubWithChapter(
    '<?xml version="1.0" encoding="UTF-8"?><html xmlns="http://www.w3.org/1999/xhtml"><body><p>Unclosed</body></html>',
  ),
  input: fixtureInput({ contentDocuments: [], malformedXhtmlPaths: [chapterPath] }),
  expected: {
    code: "XHTML_MALFORMED",
    severity: "error",
    stateImpact: "needs_review",
    repairability: "none",
    location: chapterPath,
  },
};

export const brokenLinkFixture: ContentRuleFixture = {
  name: "broken internal link",
  epub: epubWithChapter(
    createXhtmlDocument({ body: '<p><a href="missing.xhtml">Missing chapter</a></p>' }),
  ),
  input: fixtureInput({
    contentDocuments: [
      contentDocument({
        references: [
          {
            rawReference: "missing.xhtml",
            targetPath: internalPath("EPUB/text/missing.xhtml"),
            kind: "link",
          },
        ],
      }),
    ],
  }),
  expected: {
    code: "CONTENT_LINK_BROKEN",
    severity: "warning",
    stateImpact: "needs_review",
    repairability: "none",
    location: chapterPath,
  },
};

export const missingImageFixture: ContentRuleFixture = {
  name: "missing image",
  epub: epubWithChapter(createXhtmlDocument({ imageSrc: "../images/missing.png" })),
  input: fixtureInput({
    contentDocuments: [
      contentDocument({
        references: [
          {
            rawReference: "../images/missing.png",
            targetPath: internalPath("EPUB/images/missing.png"),
            kind: "image",
          },
        ],
      }),
    ],
  }),
  expected: {
    code: "CONTENT_IMAGE_MISSING",
    severity: "error",
    stateImpact: "needs_review",
    repairability: "none",
    location: chapterPath,
  },
};

export const missingStylesheetFixture: ContentRuleFixture = {
  name: "missing stylesheet",
  epub: epubWithChapter(createXhtmlDocument({ stylesheetHref: "../styles/missing.css" })),
  input: fixtureInput({
    contentDocuments: [
      contentDocument({
        references: [
          {
            rawReference: "../styles/missing.css",
            targetPath: internalPath("EPUB/styles/missing.css"),
            kind: "stylesheet",
          },
        ],
      }),
    ],
  }),
  expected: {
    code: "CONTENT_STYLESHEET_MISSING",
    severity: "warning",
    stateImpact: "needs_review",
    repairability: "none",
    location: chapterPath,
  },
};

export const missingFontFixture: ContentRuleFixture = {
  name: "missing font",
  epub: createMinimalEpub({
    transformEntries: (entries) =>
      replaceEntry(
        entries,
        "EPUB/styles/book.css",
        createStylesheet({ fontHref: "../fonts/missing.woff" }),
      ),
  }),
  input: fixtureInput({
    contentDocuments: [
      contentDocument(),
      contentDocument({
        path: stylesheetPath,
        mediaType: "text/css",
        references: [
          {
            rawReference: "../fonts/missing.woff",
            targetPath: internalPath("EPUB/fonts/missing.woff"),
            kind: "font",
          },
        ],
      }),
    ],
  }),
  expected: {
    code: "CONTENT_FONT_MISSING",
    severity: "warning",
    stateImpact: "needs_review",
    repairability: "none",
    location: stylesheetPath,
  },
};

export const pathCaseMismatchFixture: ContentRuleFixture = {
  name: "unique path case mismatch",
  epub: epubWithChapter(createXhtmlDocument({ imageSrc: "../Images/Cover.PNG" })),
  input: fixtureInput({
    contentDocuments: [
      contentDocument({
        references: [
          {
            rawReference: "../Images/Cover.PNG",
            targetPath: internalPath("EPUB/Images/Cover.PNG"),
            kind: "image",
          },
        ],
      }),
    ],
  }),
  expected: {
    code: "CONTENT_PATH_CASE_MISMATCH",
    severity: "warning",
    stateImpact: "repairable",
    repairability: "automatic",
    recommendedRepair: "normalize_equivalent_internal_path",
    location: chapterPath,
  },
};

export const remoteResourceFixture: ContentRuleFixture = {
  name: "remote resource",
  epub: epubWithChapter(createXhtmlDocument({ imageSrc: "https://example.invalid/cover.png" })),
  input: fixtureInput({
    contentDocuments: [
      contentDocument({
        references: [
          {
            rawReference: "https://example.invalid/cover.png",
            kind: "image",
          },
        ],
      }),
    ],
  }),
  expected: {
    code: "CONTENT_REMOTE_RESOURCE",
    severity: "warning",
    stateImpact: "needs_review",
    repairability: "none",
    location: chapterPath,
  },
};

export const relevantEmptyFileFixture: ContentRuleFixture = {
  name: "relevant empty stylesheet",
  epub: createMinimalEpub({
    transformEntries: (entries) => replaceEntry(entries, "EPUB/styles/book.css", ""),
  }),
  input: fixtureInput({
    packageDocument: packageDocument({ includeStylesheet: true }),
    relevantResourceBytes: new Map([[stylesheetPath, 0]]),
  }),
  expected: {
    code: "CONTENT_RELEVANT_FILE_EMPTY",
    severity: "warning",
    stateImpact: "needs_review",
    repairability: "none",
    location: stylesheetPath,
  },
};

export const emptyChapterFixture: ContentRuleFixture = {
  name: "empty spine chapter",
  epub: epubWithChapter(
    '<?xml version="1.0" encoding="UTF-8"?><html xmlns="http://www.w3.org/1999/xhtml"><head><title>Empty</title></head><body> </body></html>',
  ),
  input: fixtureInput({ contentDocuments: [contentDocument({ hasUsefulContent: false })] }),
  expected: {
    code: "CONTENT_CHAPTER_EMPTY",
    severity: "warning",
    stateImpact: "needs_review",
    repairability: "none",
    location: chapterPath,
  },
};

export const fixedLayoutFixture: ContentRuleFixture = {
  name: "fixed-layout publication",
  epub: createMinimalEpub({
    transformEntries: (entries) =>
      replaceEntry(
        entries,
        "EPUB/package.opf",
        createPackageDocument({
          version: 3,
          includeStylesheet: true,
          includeImage: true,
          includeFont: true,
        }).replace(
          '<meta property="dcterms:modified">2026-01-01T00:00:00Z</meta>',
          '<meta property="dcterms:modified">2026-01-01T00:00:00Z</meta>\n    <meta property="rendition:layout">pre-paginated</meta>',
        ),
      ),
  }),
  input: fixtureInput({ packageDocument: packageDocument({ renditionLayout: "pre-paginated" }) }),
  expected: {
    code: "CONTENT_FIXED_LAYOUT",
    severity: "info",
    stateImpact: "healthy",
    repairability: "none",
    location: packagePath,
  },
};

export const contentRuleFixtures = [
  malformedXhtmlFixture,
  brokenLinkFixture,
  missingImageFixture,
  missingStylesheetFixture,
  missingFontFixture,
  pathCaseMismatchFixture,
  remoteResourceFixture,
  relevantEmptyFileFixture,
  emptyChapterFixture,
  fixedLayoutFixture,
] as const satisfies readonly ContentRuleFixture[];
