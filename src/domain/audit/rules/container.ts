import { createFinding } from "../finding-catalog";
import type { ArchiveEntryDescriptor, InternalPath } from "../../models/archive";
import type { ContainerProjection, PackageProjection } from "../../models/epub-document";
import type { Finding } from "../../models/finding";

const CONTAINER_PATH = "META-INF/container.xml" as InternalPath;

export interface ContainerAuditInput {
  readonly container?: ContainerProjection;
  readonly packages: readonly PackageProjection[];
  readonly entryIndex?: ReadonlyMap<InternalPath, ArchiveEntryDescriptor>;
  readonly containerXmlInvalid?: boolean;
  readonly packageXmlInvalid?: boolean;
  readonly packageXmlInvalidPath?: InternalPath;
}

export function auditContainer(input: ContainerAuditInput): Finding[] {
  const findings: Finding[] = [];
  const uniquePackage = input.packages.length === 1 ? input.packages[0] : undefined;
  const conditionalRepair =
    uniquePackage === undefined
      ? {}
      : {
          repairability: "automatic" as const,
          stateImpact: "repairable" as const,
          recommendedRepair: "rebuild_container_for_single_opf" as const,
          evidence: { packagePath: uniquePackage.path },
        };
  const containerLocation = { kind: "internal_path" as const, path: CONTAINER_PATH };

  if (input.containerXmlInvalid === true) {
    findings.push(
      createFinding("CONTAINER_XML_INVALID", {
        location: containerLocation,
        ...conditionalRepair,
      }),
    );
  } else if (input.container === undefined) {
    findings.push(
      createFinding("CONTAINER_MISSING", {
        location: containerLocation,
        ...conditionalRepair,
      }),
    );
  } else if (input.container.rootfiles.length === 0) {
    findings.push(
      createFinding("CONTAINER_ROOTFILE_MISSING", {
        location: containerLocation,
        ...conditionalRepair,
      }),
    );
  } else if (input.container.rootfiles.length > 1) {
    findings.push(
      createFinding("CONTAINER_ROOTFILE_MULTIPLE", {
        location: containerLocation,
        evidence: { rootfileCount: input.container.rootfiles.length },
      }),
    );
  } else {
    const rootfile = input.container.rootfiles[0];
    const referencedPackage = rootfile?.resolvedPath;
    const referencedExists =
      referencedPackage !== undefined &&
      (input.packages.some((packageDocument) => packageDocument.path === referencedPackage) ||
        input.entryIndex?.has(referencedPackage) === true ||
        (input.packageXmlInvalid === true &&
          (input.packageXmlInvalidPath === undefined || input.packageXmlInvalidPath === referencedPackage)));
    if (!referencedExists) {
      findings.push(
        createFinding("CONTAINER_PACKAGE_MISSING", {
          location: containerLocation,
          targetIdentifier: rootfile?.fullPath,
          ...conditionalRepair,
        }),
      );
    }
  }

  if (input.packageXmlInvalid === true) {
    findings.push(
      createFinding("PACKAGE_XML_INVALID", {
        location:
          input.packageXmlInvalidPath === undefined
            ? undefined
            : { kind: "internal_path", path: input.packageXmlInvalidPath },
      }),
    );
    return findings;
  }

  if (input.packages.length === 0) {
    findings.push(createFinding("PACKAGE_NOT_FOUND"));
  } else if (input.packages.length > 1) {
    findings.push(
      createFinding("PACKAGE_AMBIGUOUS", {
        evidence: { packageCount: input.packages.length },
      }),
    );
  } else if (uniquePackage?.version === "unknown") {
    findings.push(
      createFinding("PACKAGE_VERSION_UNSUPPORTED", {
        location: { kind: "internal_path", path: uniquePackage.path },
      }),
    );
  }

  return findings;
}

export const auditContainerRules = auditContainer;
