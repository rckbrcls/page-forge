import type { InternalPath } from "../models/archive";
import type { HealthReport } from "../models/health-report";
import type { RepairCandidateFacts } from "./create-repair-plan";

export function deriveRepairCandidates(report: HealthReport): RepairCandidateFacts {
  const containerRepairs = report.findings.flatMap((finding) => {
    const packagePath = pathEvidence(finding.evidence.packagePath);
    if (finding.recommendedRepair !== "rebuild_container_for_single_opf" || packagePath === undefined) return [];
    return [{ findingId: finding.identity, packagePath }];
  });

  const mediaTypeCorrections = report.findings.flatMap((finding) => {
    const mediaType = stringEvidence(finding.evidence.inferredMediaType ?? finding.evidence.expectedMediaType);
    if (
      finding.recommendedRepair !== "correct_manifest_media_type" ||
      finding.location?.kind !== "manifest_item" ||
      mediaType === undefined
    ) {
      return [];
    }
    return [
      {
        findingId: finding.identity,
        packagePath: finding.location.path,
        manifestId: finding.location.manifestId,
        mediaType,
      },
    ];
  });

  const referenceCorrections = report.findings.flatMap((finding) => {
    const ownerPath = xmlOrInternalPath(finding.location);
    const originalReference = stringEvidence(finding.evidence.reference);
    const replacementReference = stringEvidence(finding.evidence.replacementReference);
    const targetPath = pathEvidence(finding.evidence.targetPath);
    if (
      finding.recommendedRepair !== "correct_unique_reference" ||
      ownerPath === undefined ||
      originalReference === undefined ||
      replacementReference === undefined ||
      targetPath === undefined
    ) {
      return [];
    }
    return [{ findingId: finding.identity, ownerPath, originalReference, replacementReference, targetPath }];
  });

  const equivalentPathCorrections = report.findings.flatMap((finding) => {
    const sourcePath = pathEvidence(finding.evidence.existingPath);
    const targetPath = pathEvidence(finding.evidence.referencedPath);
    if (
      finding.recommendedRepair !== "normalize_equivalent_internal_path" ||
      sourcePath === undefined ||
      targetPath === undefined ||
      sourcePath === targetPath
    ) {
      return [];
    }
    return [{ findingId: finding.identity, sourcePath, targetPath }];
  });

  const xmlEncodingCorrections = report.findings.flatMap((finding) => {
    const path = xmlOrInternalPath(finding.location);
    if (finding.recommendedRepair !== "normalize_xml_encoding" || path === undefined) return [];
    return [{ findingId: finding.identity, path }];
  });

  return {
    ...(containerRepairs.length === 0 ? {} : { containerRepairs }),
    ...(mediaTypeCorrections.length === 0 ? {} : { mediaTypeCorrections }),
    ...(referenceCorrections.length === 0 ? {} : { referenceCorrections }),
    ...(equivalentPathCorrections.length === 0 ? {} : { equivalentPathCorrections }),
    ...(xmlEncodingCorrections.length === 0 ? {} : { xmlEncodingCorrections }),
  };
}

function stringEvidence(value: unknown): string | undefined {
  return typeof value === "string" && value.length > 0 ? value : undefined;
}

function pathEvidence(value: unknown): InternalPath | undefined {
  return stringEvidence(value) as InternalPath | undefined;
}

function xmlOrInternalPath(location: HealthReport["findings"][number]["location"]): InternalPath | undefined {
  return location?.kind === "internal_path" || location?.kind === "xml" ? location.path : undefined;
}
