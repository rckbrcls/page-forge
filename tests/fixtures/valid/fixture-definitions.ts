import { buildZip } from "../../support/fixture-builder";
import {
  createMinimalEpub2,
  createMinimalEpub3,
  createMinimalEpubEntries,
} from "../../support/epub-fixture-factory";

import type { FindingCode } from "../../../src/domain/audit/finding-codes";
import type { Severity } from "../../../src/domain/models/finding";
import type { EpubVersion, HealthState } from "../../../src/domain/models/health-report";

export interface AuditFixtureExpectation {
  readonly code: FindingCode;
  readonly severity: Severity;
}

export interface AuditFixtureDefinition {
  readonly name: string;
  readonly bytes: Uint8Array;
  readonly epubVersion: EpubVersion;
  readonly health: HealthState;
  readonly findings: readonly AuditFixtureExpectation[];
}

function fixedLayoutEpub(): Buffer {
  return buildZip(
    createMinimalEpubEntries({
      version: 3,
      transformEntries: (entries) =>
        entries.map((entry) => {
          if (entry.name !== "EPUB/package.opf" || typeof entry.data !== "string") return entry;
          return {
            ...entry,
            data: entry.data.replace(
              "</metadata>",
              '    <meta property="rendition:layout">pre-paginated</meta>\n  </metadata>',
            ),
          };
        }),
    }),
  );
}

export const validAndZipFixtures = {
  epub2: {
    name: "valid-epub-2.epub",
    bytes: createMinimalEpub2(),
    epubVersion: "2",
    health: "healthy",
    findings: [],
  },
  epub3: {
    name: "valid-epub-3.epub",
    bytes: createMinimalEpub3(),
    epubVersion: "3",
    health: "healthy",
    findings: [],
  },
  fixedLayout: {
    name: "fixed-layout.epub",
    bytes: fixedLayoutEpub(),
    epubVersion: "3",
    health: "healthy",
    findings: [{ code: "CONTENT_FIXED_LAYOUT", severity: "info" }],
  },
  invalidZip: {
    name: "invalid-zip.epub",
    bytes: Buffer.from("This is not a ZIP archive.", "utf8"),
    epubVersion: "unknown",
    health: "unsupported",
    findings: [{ code: "ZIP_INVALID", severity: "critical" }],
  },
  emptyZip: {
    name: "empty.epub",
    bytes: buildZip([]),
    epubVersion: "unknown",
    health: "unsupported",
    findings: [{ code: "ZIP_EMPTY", severity: "error" }],
  },
  nonEpubZip: {
    name: "ordinary-zip.epub",
    bytes: buildZip([{ name: "README.txt", data: "Not an EPUB." }]),
    epubVersion: "unknown",
    health: "unsupported",
    findings: [
      { code: "MIMETYPE_MISSING", severity: "error" },
      { code: "CONTAINER_MISSING", severity: "error" },
      { code: "PACKAGE_NOT_FOUND", severity: "error" },
    ],
  },
} as const satisfies Record<string, AuditFixtureDefinition>;
