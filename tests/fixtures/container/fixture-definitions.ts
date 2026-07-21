import { buildZip, type ZipFixtureEntry } from "../../support/fixture-builder";
import {
  createContainerXml,
  createMinimalEpubEntries,
  createPackageDocument,
} from "../../support/epub-fixture-factory";

import type { FindingCode } from "../../../src/domain/audit/finding-codes";
import type { Severity } from "../../../src/domain/models/finding";
import type { EpubVersion, HealthState } from "../../../src/domain/models/health-report";

interface ExpectedFinding {
  readonly code: FindingCode;
  readonly severity: Severity;
  readonly repairability: "none" | "automatic";
  readonly stateImpact: HealthState;
}

export interface ContainerFixtureDefinition {
  readonly name: string;
  readonly bytes: Uint8Array;
  readonly epubVersion: EpubVersion;
  readonly health: HealthState;
  readonly findings: readonly ExpectedFinding[];
}

const containerPath = "META-INF/container.xml";
const packagePath = "EPUB/package.opf";

function containerXml(rootfiles: readonly string[]): string {
  const declarations = rootfiles
    .map(
      (path) =>
        `    <rootfile full-path="${path}" media-type="application/oebps-package+xml"/>`,
    )
    .join("\n");
  return `<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
${declarations}
  </rootfiles>
</container>`;
}

function fixture(transform: (entries: ZipFixtureEntry[]) => ZipFixtureEntry[]): Buffer {
  return buildZip(transform(createMinimalEpubEntries({ version: 3 })));
}

function replaceEntry(
  entries: ZipFixtureEntry[],
  name: string,
  replacement: Partial<ZipFixtureEntry>,
): ZipFixtureEntry[] {
  return entries.map((entry) => (entry.name === name ? { ...entry, ...replacement } : entry));
}

const repairable = (code: FindingCode): ExpectedFinding => ({
  code,
  severity: "error",
  repairability: "automatic",
  stateImpact: "repairable",
});

export const containerPackageFixtures = {
  missingContainer: {
    name: "container-missing-single-opf.epub",
    bytes: fixture((entries) => entries.filter((entry) => entry.name !== containerPath)),
    epubVersion: "3",
    health: "repairable",
    findings: [repairable("CONTAINER_MISSING")],
  },
  malformedContainer: {
    name: "container-malformed-single-opf.epub",
    bytes: fixture((entries) =>
      replaceEntry(entries, containerPath, { data: "<container><rootfiles>" }),
    ),
    epubVersion: "3",
    health: "repairable",
    findings: [repairable("CONTAINER_XML_INVALID")],
  },
  rootfileMissing: {
    name: "container-rootfile-missing-single-opf.epub",
    bytes: fixture((entries) => replaceEntry(entries, containerPath, { data: containerXml([]) })),
    epubVersion: "3",
    health: "repairable",
    findings: [repairable("CONTAINER_ROOTFILE_MISSING")],
  },
  rootfileMultiple: {
    name: "container-rootfile-multiple.epub",
    bytes: fixture((entries) =>
      replaceEntry(entries, containerPath, {
        data: containerXml([packagePath, packagePath]),
      }),
    ),
    epubVersion: "3",
    health: "needs_review",
    findings: [
      {
        code: "CONTAINER_ROOTFILE_MULTIPLE",
        severity: "warning",
        repairability: "none",
        stateImpact: "needs_review",
      },
    ],
  },
  referencedPackageMissing: {
    name: "container-references-missing-package.epub",
    bytes: fixture((entries) =>
      replaceEntry(entries, containerPath, { data: createContainerXml("EPUB/missing.opf") }),
    ),
    epubVersion: "3",
    health: "repairable",
    findings: [repairable("CONTAINER_PACKAGE_MISSING")],
  },
  noPackage: {
    name: "package-not-found.epub",
    bytes: fixture((entries) => entries.filter((entry) => entry.name !== packagePath)),
    epubVersion: "unknown",
    health: "unsupported",
    findings: [
      {
        code: "CONTAINER_PACKAGE_MISSING",
        severity: "error",
        repairability: "none",
        stateImpact: "needs_review",
      },
      {
        code: "PACKAGE_NOT_FOUND",
        severity: "error",
        repairability: "none",
        stateImpact: "unsupported",
      },
    ],
  },
  ambiguousPackage: {
    name: "package-ambiguous.epub",
    bytes: fixture((entries) => [
      ...entries.filter((entry) => entry.name !== containerPath),
      {
        name: "OPS/second.opf",
        data: createPackageDocument({ version: 3 }),
        method: 8,
      },
    ]),
    epubVersion: "unknown",
    health: "needs_review",
    findings: [
      {
        code: "CONTAINER_MISSING",
        severity: "error",
        repairability: "none",
        stateImpact: "needs_review",
      },
      {
        code: "PACKAGE_AMBIGUOUS",
        severity: "error",
        repairability: "none",
        stateImpact: "needs_review",
      },
    ],
  },
  invalidPackageXml: {
    name: "package-xml-invalid.epub",
    bytes: fixture((entries) =>
      replaceEntry(entries, packagePath, { data: "<package><metadata>" }),
    ),
    epubVersion: "unknown",
    health: "needs_review",
    findings: [
      {
        code: "PACKAGE_XML_INVALID",
        severity: "error",
        repairability: "none",
        stateImpact: "needs_review",
      },
    ],
  },
  unsupportedPackageVersion: {
    name: "package-version-unsupported.epub",
    bytes: fixture((entries) =>
      replaceEntry(entries, packagePath, {
        data: createPackageDocument({ version: 3 }).replace('version="3.0"', 'version="4.0"'),
      }),
    ),
    epubVersion: "unknown",
    health: "unsupported",
    findings: [
      {
        code: "PACKAGE_VERSION_UNSUPPORTED",
        severity: "error",
        repairability: "none",
        stateImpact: "unsupported",
      },
    ],
  },
} as const satisfies Record<string, ContainerFixtureDefinition>;
