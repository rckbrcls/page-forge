import { parseInternalPath } from "../../../src/domain/audit/internal-path";
import type { InternalPath } from "../../../src/domain/models/archive";
import {
  createContainerXml,
  createMinimalEpubEntries,
} from "../../support/epub-fixture-factory";
import { buildZip, zipMethods, type ZipFixtureEntry } from "../../support/fixture-builder";

export interface MimetypeRepairFixture {
  readonly name: string;
  readonly epub: Uint8Array;
  readonly expected: Uint8Array;
}

export interface ContainerRepairFixture {
  readonly name: string;
  readonly epub: Uint8Array;
  readonly source: Uint8Array | undefined;
  readonly packagePath: InternalPath;
  readonly expected: Uint8Array;
}

const mimetypePath = "mimetype";
const containerPath = "META-INF/container.xml";
const packagePath = internalPath("EPUB/O'Brien & Notes.opf");

export const canonicalMimetype = Buffer.from("application/epub+zip", "ascii");
export const canonicalContainer = Buffer.from(createContainerXml(packagePath), "utf8");

function internalPath(value: string): InternalPath {
  const parsed = parseInternalPath(value);
  if (!parsed.ok || parsed.value.isDirectory) throw new Error(`Invalid fixture path: ${value}`);
  return parsed.value.path;
}

function minimalEntries(): ZipFixtureEntry[] {
  return createMinimalEpubEntries({ version: 3, packagePath });
}

function replaceEntry(
  entries: ZipFixtureEntry[],
  name: string,
  replacement: Partial<ZipFixtureEntry>,
): ZipFixtureEntry[] {
  return entries.map((entry) => (entry.name === name ? { ...entry, ...replacement } : entry));
}

function entryBytes(entries: readonly ZipFixtureEntry[], name: string): Uint8Array | undefined {
  const data = entries.find((entry) => entry.name === name)?.data;
  if (data === undefined) return undefined;
  return typeof data === "string" ? Buffer.from(data, "utf8") : Buffer.from(data);
}

function mimetypeFixture(
  name: string,
  transform: (entries: ZipFixtureEntry[]) => ZipFixtureEntry[],
): MimetypeRepairFixture {
  return { name, epub: buildZip(transform(minimalEntries())), expected: canonicalMimetype };
}

function containerFixture(
  name: string,
  transform: (entries: ZipFixtureEntry[]) => ZipFixtureEntry[],
): ContainerRepairFixture {
  const entries = transform(minimalEntries());
  return {
    name,
    epub: buildZip(entries),
    source: entryBytes(entries, containerPath),
    packagePath,
    expected: canonicalContainer,
  };
}

export const mimetypeRepairFixtures = [
  mimetypeFixture("missing mimetype", (entries) =>
    entries.filter((entry) => entry.name !== mimetypePath),
  ),
  mimetypeFixture("misordered mimetype", (entries) => [entries[1], entries[0], ...entries.slice(2)]),
  mimetypeFixture("compressed mimetype", (entries) =>
    replaceEntry(entries, mimetypePath, { method: zipMethods.deflate }),
  ),
  mimetypeFixture("incorrect mimetype value", (entries) =>
    replaceEntry(entries, mimetypePath, { data: "application/zip" }),
  ),
  mimetypeFixture("mimetype with a local extra field", (entries) =>
    replaceEntry(entries, mimetypePath, {
      localExtra: Uint8Array.from([0xfe, 0xca, 0, 0]),
    }),
  ),
] as const satisfies readonly MimetypeRepairFixture[];

export const containerRepairFixtures = [
  containerFixture("missing container", (entries) =>
    entries.filter((entry) => entry.name !== containerPath),
  ),
  containerFixture("malformed container", (entries) =>
    replaceEntry(entries, containerPath, { data: "<container><rootfiles>" }),
  ),
  containerFixture("container without a rootfile", (entries) =>
    replaceEntry(entries, containerPath, {
      data: '<?xml version="1.0"?><container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles/></container>',
    }),
  ),
  containerFixture("container referencing a missing package", (entries) =>
    replaceEntry(entries, containerPath, { data: createContainerXml("EPUB/missing.opf") }),
  ),
] as const satisfies readonly ContainerRepairFixture[];
