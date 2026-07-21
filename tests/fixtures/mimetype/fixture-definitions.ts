import { buildZip, zipMethods, type ZipFixtureEntry } from "../../support/fixture-builder";
import { createMinimalEpubEntries } from "../../support/epub-fixture-factory";

import type { FindingCode } from "../../../src/domain/audit/finding-codes";
import type { Severity } from "../../../src/domain/models/finding";
import type { HealthState } from "../../../src/domain/models/health-report";

export interface MimetypeFixtureDefinition {
  readonly name: string;
  readonly bytes: Uint8Array;
  readonly finding: { readonly code: FindingCode; readonly severity: Severity };
  readonly health: HealthState;
}

function epubWithEntries(transform: (entries: ZipFixtureEntry[]) => ZipFixtureEntry[]): Buffer {
  return buildZip(transform(createMinimalEpubEntries({ version: 3 })));
}

function replaceMimetype(
  entries: ZipFixtureEntry[],
  replacement: Partial<ZipFixtureEntry>,
): ZipFixtureEntry[] {
  return entries.map((entry) =>
    entry.name === "mimetype" ? { ...entry, ...replacement } : entry,
  );
}

export const mimetypeFixtures = {
  missing: {
    name: "mimetype-missing.epub",
    bytes: epubWithEntries((entries) => entries.filter((entry) => entry.name !== "mimetype")),
    finding: { code: "MIMETYPE_MISSING", severity: "error" },
    health: "repairable",
  },
  notFirst: {
    name: "mimetype-not-first.epub",
    bytes: epubWithEntries((entries) => [entries[1], entries[0], ...entries.slice(2)]),
    finding: { code: "MIMETYPE_NOT_FIRST", severity: "error" },
    health: "repairable",
  },
  compressed: {
    name: "mimetype-compressed.epub",
    bytes: epubWithEntries((entries) =>
      replaceMimetype(entries, { method: zipMethods.deflate }),
    ),
    finding: { code: "MIMETYPE_COMPRESSED", severity: "error" },
    health: "repairable",
  },
  invalidValue: {
    name: "mimetype-value-invalid.epub",
    bytes: epubWithEntries((entries) =>
      replaceMimetype(entries, { data: "application/zip" }),
    ),
    finding: { code: "MIMETYPE_VALUE_INVALID", severity: "error" },
    health: "repairable",
  },
  localExtraField: {
    name: "mimetype-extra-field.epub",
    bytes: epubWithEntries((entries) =>
      replaceMimetype(entries, { localExtra: Uint8Array.from([0xfe, 0xca, 0, 0]) }),
    ),
    finding: { code: "MIMETYPE_EXTRA_FIELD", severity: "warning" },
    health: "repairable",
  },
} as const satisfies Record<string, MimetypeFixtureDefinition>;
