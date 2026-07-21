import type { FindingCode } from "../../../src/domain/audit/finding-codes";
import { parseInternalPath } from "../../../src/domain/audit/internal-path";
import type { ArchiveEntryDescriptor, InternalPath } from "../../../src/domain/models/archive";
import type {
  ContentProjection,
  EncryptionProjection,
  PackageProjection,
} from "../../../src/domain/models/epub-document";
import type {
  FindingStateImpact,
  Repairability,
  Severity,
} from "../../../src/domain/models/finding";
import {
  createMinimalEpub,
  createPackageDocument,
  createXhtmlDocument,
} from "../../support/epub-fixture-factory";
import type { ZipFixtureEntry } from "../../support/fixture-builder";

export interface ActiveContentAuditInput {
  readonly archiveEntries: readonly ArchiveEntryDescriptor[];
  readonly packageDocument: PackageProjection;
  readonly contentDocuments: readonly ContentProjection[];
  readonly encryption?: EncryptionProjection;
}

export interface ForbiddenEffectCounters {
  payloadReads: number;
  networkAccesses: number;
  decryptions: number;
}

export interface ActiveProtectedContentFixture {
  readonly name: string;
  readonly epub: Buffer;
  readonly input: ActiveContentAuditInput;
  readonly expected: {
    readonly code: FindingCode;
    readonly severity: Severity;
    readonly stateImpact: FindingStateImpact;
    readonly repairability: Repairability;
    readonly location: InternalPath;
  };
  readonly forbiddenEffects: ForbiddenEffectCounters;
}

const packagePath = internalPath("EPUB/package.opf");
const chapterPath = internalPath("EPUB/text/chapter.xhtml");
const executablePath = internalPath("EPUB/bin/payload.exe");
const encryptionPath = internalPath("META-INF/encryption.xml");
const fontPath = internalPath("EPUB/fonts/book.woff");

function internalPath(value: string): InternalPath {
  const parsed = parseInternalPath(value);
  if (!parsed.ok) throw new Error(`Invalid fixture internal path: ${value}`);
  return parsed.value.path;
}

function packageDocument(
  additionalManifest: PackageProjection["manifest"] = [],
): PackageProjection {
  return {
    path: packagePath,
    version: "3",
    metadata: {
      titles: ["Fixture Book"],
      identifiers: [{ id: "book-id", value: "urn:uuid:active-content-fixture" }],
      languages: ["en"],
      uniqueIdentifier: "book-id",
    },
    manifest: [
      {
        id: "chapter",
        href: "text/chapter.xhtml",
        resolvedPath: chapterPath,
        mediaType: "application/xhtml+xml",
        properties: [],
      },
      ...additionalManifest,
    ],
    spine: [{ idref: "chapter", linear: true }],
  };
}

function contentDocument(
  changes: Partial<ContentProjection> = {},
): ContentProjection {
  return {
    path: chapterPath,
    mediaType: "application/xhtml+xml",
    references: [],
    scripted: false,
    interactive: false,
    hasUsefulContent: true,
    ...changes,
  };
}

function archiveEntry(index: number, path: InternalPath): ArchiveEntryDescriptor {
  return {
    index,
    originalName: path,
    path,
    kind: "file",
    compressionMethod: 8,
    compressedSize: 32,
    expandedSize: 64,
    crc32: 0,
    encrypted: false,
    externalAttributes: 0,
    flags: 0x0800,
    localHeaderExtraLength: 0,
  };
}

function withForbiddenAccessor<T extends object>(
  value: T,
  property: string,
  onAccess: () => void,
): T {
  Object.defineProperty(value, property, {
    configurable: false,
    enumerable: false,
    get() {
      onAccess();
      throw new Error(`Forbidden active-content access: ${property}`);
    },
  });
  return value;
}

function replaceEntry(
  entries: ZipFixtureEntry[],
  name: string,
  data: string | Uint8Array,
): ZipFixtureEntry[] {
  return entries.map((entry) => (entry.name === name ? { ...entry, data } : entry));
}

function chapterEpub(chapter: string): Buffer {
  return createMinimalEpub({
    transformEntries: (entries) => replaceEntry(entries, "EPUB/text/chapter.xhtml", chapter),
  });
}

function fixture(
  name: string,
  epub: Buffer,
  input: Omit<ActiveContentAuditInput, "packageDocument"> & {
    readonly packageDocument?: PackageProjection;
  },
  expected: ActiveProtectedContentFixture["expected"],
  forbiddenEffects: ForbiddenEffectCounters,
): ActiveProtectedContentFixture {
  return {
    name,
    epub,
    input: {
      archiveEntries: input.archiveEntries,
      packageDocument: input.packageDocument ?? packageDocument(),
      contentDocuments: input.contentDocuments,
      ...(input.encryption === undefined ? {} : { encryption: input.encryption }),
    },
    expected,
    forbiddenEffects,
  };
}

function counters(): ForbiddenEffectCounters {
  return { payloadReads: 0, networkAccesses: 0, decryptions: 0 };
}

const externalEffects = counters();
const externalReference = withForbiddenAccessor(
  {
    rawReference: "file:///Users/example/secret.txt",
    kind: "image" as const,
  },
  "readExternalFile",
  () => {
    externalEffects.payloadReads += 1;
  },
);

export const externalFileFixture = fixture(
  "external local-file reference",
  chapterEpub(createXhtmlDocument({ imageSrc: "file:///Users/example/secret.txt" })),
  {
    archiveEntries: [],
    contentDocuments: [contentDocument({ references: [externalReference] })],
  },
  {
    code: "CONTENT_EXTERNAL_FILE_REFERENCE",
    severity: "critical",
    stateImpact: "unsafe",
    repairability: "none",
    location: chapterPath,
  },
  externalEffects,
);

const executableEffects = counters();
const executableEntry = withForbiddenAccessor(
  archiveEntry(0, executablePath),
  "execute",
  () => {
    executableEffects.payloadReads += 1;
  },
);

export const executableFixture = fixture(
  "embedded executable resource",
  createMinimalEpub({
    additionalEntries: [{ name: executablePath, data: Buffer.from("MZfixture"), method: 0 }],
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
          "  </manifest>",
          '    <item id="payload" href="bin/payload.exe" media-type="application/x-msdownload"/>\n  </manifest>',
        ),
      ),
  }),
  {
    archiveEntries: [executableEntry],
    packageDocument: packageDocument([
      {
        id: "payload",
        href: "bin/payload.exe",
        resolvedPath: executablePath,
        mediaType: "application/x-msdownload",
        properties: [],
      },
    ]),
    contentDocuments: [contentDocument()],
  },
  {
    code: "CONTENT_EXECUTABLE_RESOURCE",
    severity: "critical",
    stateImpact: "unsafe",
    repairability: "none",
    location: executablePath,
  },
  executableEffects,
);

const scriptedEffects = counters();
const scriptedDocument = withForbiddenAccessor(
  contentDocument({ scripted: true }),
  "executeScript",
  () => {
    scriptedEffects.payloadReads += 1;
  },
);

export const scriptedFixture = fixture(
  "scripted XHTML",
  chapterEpub(
    createXhtmlDocument({ body: '<script type="text/javascript">throw new Error("executed")</script>' }),
  ),
  { archiveEntries: [], contentDocuments: [scriptedDocument] },
  {
    code: "CONTENT_SCRIPTED",
    severity: "warning",
    stateImpact: "needs_review",
    repairability: "none",
    location: chapterPath,
  },
  scriptedEffects,
);

const interactiveEffects = counters();
export const interactiveFixture = fixture(
  "interactive XHTML",
  chapterEpub(createXhtmlDocument({ body: '<form><input type="text"/></form>' })),
  { archiveEntries: [], contentDocuments: [contentDocument({ interactive: true })] },
  {
    code: "CONTENT_INTERACTIVE",
    severity: "warning",
    stateImpact: "needs_review",
    repairability: "none",
    location: chapterPath,
  },
  interactiveEffects,
);

const remoteEffects = counters();
const remoteReference = withForbiddenAccessor(
  {
    rawReference: "https://example.invalid/tracker.png",
    kind: "image" as const,
  },
  "fetch",
  () => {
    remoteEffects.networkAccesses += 1;
  },
);

export const remoteResourceFixture = fixture(
  "remote resource",
  chapterEpub(createXhtmlDocument({ imageSrc: "https://example.invalid/tracker.png" })),
  {
    archiveEntries: [],
    contentDocuments: [contentDocument({ references: [remoteReference] })],
  },
  {
    code: "CONTENT_REMOTE_RESOURCE",
    severity: "warning",
    stateImpact: "needs_review",
    repairability: "none",
    location: chapterPath,
  },
  remoteEffects,
);

const encryptedEffects = counters();
const encryption = withForbiddenAccessor<EncryptionProjection>(
  { path: encryptionPath, affectedPaths: [fontPath] },
  "decrypt",
  () => {
    encryptedEffects.decryptions += 1;
  },
);

export const encryptedContentFixture = fixture(
  "DRM or encrypted content",
  createMinimalEpub({ includeEncryption: true }),
  {
    archiveEntries: [],
    contentDocuments: [contentDocument()],
    encryption,
  },
  {
    code: "CONTENT_ENCRYPTED",
    severity: "critical",
    stateImpact: "unsafe",
    repairability: "none",
    location: encryptionPath,
  },
  encryptedEffects,
);

export const activeProtectedContentFixtures = [
  externalFileFixture,
  executableFixture,
  scriptedFixture,
  interactiveFixture,
  remoteResourceFixture,
  encryptedContentFixture,
] as const satisfies readonly ActiveProtectedContentFixture[];
