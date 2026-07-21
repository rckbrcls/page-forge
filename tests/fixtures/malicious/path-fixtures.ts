import type { FindingCode } from "../../../src/domain/audit/finding-codes";
import { buildZip, type FixtureBytes, type ZipFixtureEntry } from "../../support/fixture-builder";
import { createMinimalEpubEntries } from "../../support/epub-fixture-factory";

export interface ArchivePathSafetyFixture {
  readonly name: string;
  readonly bytes: Uint8Array;
  readonly findingCode:
    | "ARCHIVE_PATH_ABSOLUTE"
    | "ARCHIVE_PATH_TRAVERSAL"
    | "ARCHIVE_PATH_INVALID"
    | "ARCHIVE_ENTRY_DUPLICATE"
    | "ARCHIVE_CASE_COLLISION"
    | "ARCHIVE_FILE_DIRECTORY_CONFLICT";
}

function epubWithEntries(entries: readonly ZipFixtureEntry[]): Buffer {
  return buildZip([...createMinimalEpubEntries({ version: 3 }), ...entries]);
}

function namedEntry(name: FixtureBytes): ZipFixtureEntry {
  return { name, data: "hostile fixture", method: 0 };
}

function fixture(
  name: string,
  findingCode: ArchivePathSafetyFixture["findingCode"],
  entries: readonly ZipFixtureEntry[],
): ArchivePathSafetyFixture {
  return { name, bytes: epubWithEntries(entries), findingCode };
}

export const archivePathSafetyFixtures = [
  fixture("archive-path-posix-absolute.epub", "ARCHIVE_PATH_ABSOLUTE", [
    namedEntry("/outside.xhtml"),
  ]),
  fixture("archive-path-drive-absolute.epub", "ARCHIVE_PATH_ABSOLUTE", [
    namedEntry("C:/outside.xhtml"),
  ]),
  fixture("archive-path-unc-absolute.epub", "ARCHIVE_PATH_ABSOLUTE", [
    namedEntry("\\\\server\\share\\outside.xhtml"),
  ]),
  fixture("archive-path-traversal.epub", "ARCHIVE_PATH_TRAVERSAL", [
    namedEntry("../outside.xhtml"),
  ]),
  fixture("archive-path-noncanonical.epub", "ARCHIVE_PATH_TRAVERSAL", [
    namedEntry("EPUB/text/../chapter.xhtml"),
  ]),
  fixture("archive-path-nul.epub", "ARCHIVE_PATH_INVALID", [
    namedEntry("EPUB/text/chapter\0.xhtml"),
  ]),
  fixture("archive-path-backslash.epub", "ARCHIVE_PATH_INVALID", [
    namedEntry("EPUB\\text\\chapter.xhtml"),
  ]),
  fixture("archive-path-invalid-encoding.epub", "ARCHIVE_PATH_INVALID", [
    namedEntry(Uint8Array.from([0x45, 0x50, 0x55, 0x42, 0x2f, 0xc3, 0x28])),
  ]),
  fixture("archive-entry-exact-duplicate.epub", "ARCHIVE_ENTRY_DUPLICATE", [
    namedEntry("EPUB/duplicate.bin"),
    namedEntry("EPUB/duplicate.bin"),
  ]),
  fixture("archive-entry-unicode-folded-collision.epub", "ARCHIVE_CASE_COLLISION", [
    namedEntry("EPUB/Straße.xhtml"),
    namedEntry("EPUB/STRASSE.xhtml"),
  ]),
  fixture("archive-file-directory-conflict.epub", "ARCHIVE_FILE_DIRECTORY_CONFLICT", [
    namedEntry("EPUB/conflict"),
    namedEntry("EPUB/conflict/child.xhtml"),
  ]),
] as const satisfies readonly ArchivePathSafetyFixture[];

export const explicitDirectoryAncestryFixture = epubWithEntries([
  { name: "EPUB/", data: "", method: 0 },
  namedEntry("EPUB/child.xhtml"),
]);

export const archivePathSafetyFindingCodes = [
  "ARCHIVE_PATH_ABSOLUTE",
  "ARCHIVE_PATH_TRAVERSAL",
  "ARCHIVE_PATH_INVALID",
  "ARCHIVE_ENTRY_DUPLICATE",
  "ARCHIVE_CASE_COLLISION",
  "ARCHIVE_FILE_DIRECTORY_CONFLICT",
] as const satisfies readonly FindingCode[];
