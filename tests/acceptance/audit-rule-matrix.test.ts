import { describe, expect, it } from "vitest";

import { FINDING_CODES, type FindingCode } from "../../src/domain/audit/finding-codes";
import { containerPackageFixtures } from "../fixtures/container/fixture-definitions";
import { contentRuleFixtures } from "../fixtures/content/fixture-definitions";
import { inputFixtureDefinitions } from "../fixtures/input/fixture-definitions";
import { mimetypeFixtures } from "../fixtures/mimetype/fixture-definitions";
import { manifestRuleFixtures } from "../fixtures/package/manifest-fixtures";
import { readingOrderRuleFixtures } from "../fixtures/package/reading-order-fixtures";
import { validAndZipFixtures } from "../fixtures/valid/fixture-definitions";

interface FixtureRegistration {
  readonly code: FindingCode;
  readonly fixture: string;
}

const fixtureRegistry = [
  ["INPUT_NOT_EPUB", inputFixtureDefinitions[0].name],
  ["INPUT_NOT_REGULAR_FILE", inputFixtureDefinitions[0].name],
  ["INPUT_UNREADABLE", inputFixtureDefinitions[0].name],
  ["INPUT_CHANGED", inputFixtureDefinitions[3].name],
  ["ZIP_INVALID", validAndZipFixtures.invalidZip.name],
  ["ZIP_EMPTY", validAndZipFixtures.emptyZip.name],
  ["ZIP_MULTIDISK", "zip-multidisk.epub"],
  ["ZIP64_INVALID", "zip64-invalid.epub"],
  ["ZIP_METHOD_UNSUPPORTED", "zip-method-unsupported.epub"],
  ["ZIP_CRC_MISMATCH", "zip-crc-mismatch.epub"],
  ["ZIP_SIZE_MISMATCH", "zip-size-mismatch.epub"],
  ["ARCHIVE_SOURCE_TOO_LARGE", "archive-source-above-limit.epub"],
  ["ARCHIVE_TOO_MANY_ENTRIES", "archive-entry-count-above-limit.epub"],
  ["ARCHIVE_ENTRY_TOO_LARGE", "archive-entry-bytes-above-limit.epub"],
  ["ARCHIVE_EXPANDED_TOO_LARGE", "archive-expanded-total-above-limit.epub"],
  ["ARCHIVE_COMPRESSION_RATIO", "archive-ratio-above-limit.epub"],
  ["ARCHIVE_TIMEOUT", "archive-inspection-timeout.epub"],
  ["ARCHIVE_PATH_ABSOLUTE", "archive-path-absolute.epub"],
  ["ARCHIVE_PATH_TRAVERSAL", "archive-path-traversal.epub"],
  ["ARCHIVE_PATH_INVALID", "archive-path-invalid-encoding.epub"],
  ["ARCHIVE_ENTRY_DUPLICATE", "archive-entry-exact-duplicate.epub"],
  ["ARCHIVE_CASE_COLLISION", "archive-path-unicode-folded-collision.epub"],
  ["ARCHIVE_FILE_DIRECTORY_CONFLICT", "archive-file-directory-conflict.epub"],
  ["ARCHIVE_SYMLINK", "archive-symlink.epub"],
  ["ARCHIVE_SPECIAL_FILE", "archive-special-file.epub"],
  ["ARCHIVE_ENCRYPTED_ENTRY", "archive-encrypted-entry.epub"],
  ["MIMETYPE_MISSING", mimetypeFixtures.missing.name],
  ["MIMETYPE_NOT_FIRST", mimetypeFixtures.notFirst.name],
  ["MIMETYPE_COMPRESSED", mimetypeFixtures.compressed.name],
  ["MIMETYPE_VALUE_INVALID", mimetypeFixtures.invalidValue.name],
  ["MIMETYPE_EXTRA_FIELD", mimetypeFixtures.localExtraField.name],
  ["CONTAINER_MISSING", containerPackageFixtures.missingContainer.name],
  ["CONTAINER_XML_INVALID", containerPackageFixtures.malformedContainer.name],
  ["CONTAINER_ROOTFILE_MISSING", containerPackageFixtures.rootfileMissing.name],
  ["CONTAINER_ROOTFILE_MULTIPLE", containerPackageFixtures.rootfileMultiple.name],
  ["CONTAINER_PACKAGE_MISSING", containerPackageFixtures.referencedPackageMissing.name],
  ["PACKAGE_NOT_FOUND", containerPackageFixtures.noPackage.name],
  ["PACKAGE_AMBIGUOUS", containerPackageFixtures.ambiguousPackage.name],
  ["PACKAGE_XML_INVALID", containerPackageFixtures.invalidPackageXml.name],
  ["PACKAGE_VERSION_UNSUPPORTED", containerPackageFixtures.unsupportedPackageVersion.name],
  ...manifestRuleFixtures
    .filter(({ expectedCode }, index, fixtures) =>
      fixtures.findIndex((fixture) => fixture.expectedCode === expectedCode) === index,
    )
    .map(({ expectedCode, name }) => [expectedCode, name] as const),
  ...readingOrderRuleFixtures
    .filter(({ expectedCode }, index, fixtures) =>
      fixtures.findIndex((fixture) => fixture.expectedCode === expectedCode) === index,
    )
    .map(({ expectedCode, name }) => [expectedCode, name] as const),
  ["XML_ENCODING_INVALID", "xml-invalid-encoding.epub"],
  ["XML_VERSION_UNSUPPORTED", "xml-version-1.1.epub"],
  ["XML_DOCTYPE_FORBIDDEN", "xml-doctype.epub"],
  ["XML_ENTITY_FORBIDDEN", "xml-entity.epub"],
  ["XML_TOO_LARGE", "xml-above-10mb.epub"],
  ["XML_TOO_DEEP", "xml-depth-above-64.epub"],
  ...contentRuleFixtures
    .filter(({ expected }) =>
      [
        "XHTML_MALFORMED",
        "CONTENT_LINK_BROKEN",
        "CONTENT_IMAGE_MISSING",
        "CONTENT_STYLESHEET_MISSING",
        "CONTENT_FONT_MISSING",
        "CONTENT_PATH_CASE_MISMATCH",
        "CONTENT_REMOTE_RESOURCE",
      ].includes(expected.code),
    )
    .map(({ expected, name }) => [expected.code, name] as const),
  ["CONTENT_EXTERNAL_FILE_REFERENCE", "content-external-file-reference.epub"],
  [
    "CONTENT_RELEVANT_FILE_EMPTY",
    contentRuleFixtures.find(({ expected }) => expected.code === "CONTENT_RELEVANT_FILE_EMPTY")!.name,
  ],
  [
    "CONTENT_CHAPTER_EMPTY",
    contentRuleFixtures.find(({ expected }) => expected.code === "CONTENT_CHAPTER_EMPTY")!.name,
  ],
  ["CONTENT_SCRIPTED", "content-scripted.epub"],
  ["CONTENT_EXECUTABLE_RESOURCE", "content-executable-resource.epub"],
  ["CONTENT_FIXED_LAYOUT", validAndZipFixtures.fixedLayout.name],
  ["CONTENT_INTERACTIVE", "content-interactive.epub"],
  ["CONTENT_ENCRYPTED", "content-encrypted.epub"],
] as const satisfies readonly (readonly [FindingCode, string])[];

const auditRuleFixtureRegistry: readonly FixtureRegistration[] = fixtureRegistry.map(
  ([code, fixture]) => ({ code, fixture }),
);

describe("v1 audit rule fixture matrix", () => {
  it("maps every finding code to exactly one focused fixture", () => {
    const registeredCodes = auditRuleFixtureRegistry.map(({ code }) => code);

    expect(registeredCodes).toEqual(FINDING_CODES);
    expect(new Set(registeredCodes).size).toBe(FINDING_CODES.length);
    expect(auditRuleFixtureRegistry.every(({ fixture }) => fixture.trim().length > 0)).toBe(true);
  });
});
