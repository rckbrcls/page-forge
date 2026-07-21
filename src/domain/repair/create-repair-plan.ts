import type { InternalPath } from "../models/archive";
import type { SelectedEpub } from "../models/epub-document";
import type { Finding, FindingIdentity } from "../models/finding";
import type { HealthReport } from "../models/health-report";
import type { ProcessingFailure } from "../models/processing-failure";
import type { RepairKind, RepairOperation, RepairOperationId, RepairPlan, UnresolvedFinding } from "../models/repair";
import { err, ok, type Result } from "../models/result";
import { evaluateRepairPermission } from "./permitted-repairs";

const MIMETYPE_PATH = "mimetype" as InternalPath;
const CONTAINER_PATH = "META-INF/container.xml" as InternalPath;
interface CandidateBase {
  readonly findingId: FindingIdentity;
}

export interface ContainerRepairCandidate extends CandidateBase {
  readonly packagePath: InternalPath;
}

export interface MediaTypeCorrectionCandidate extends CandidateBase {
  readonly packagePath: InternalPath;
  readonly manifestId: string;
  readonly mediaType: string;
}

export interface ReferenceCorrectionCandidate extends CandidateBase {
  readonly ownerPath: InternalPath;
  readonly originalReference: string;
  readonly replacementReference: string;
  readonly targetPath: InternalPath;
}

export interface EquivalentPathCandidate extends CandidateBase {
  readonly sourcePath: InternalPath;
  readonly targetPath: InternalPath;
}

export interface XmlEncodingCandidate extends CandidateBase {
  readonly path: InternalPath;
}

export interface RepairCandidateFacts {
  readonly containerRepairs?: readonly ContainerRepairCandidate[];
  readonly mediaTypeCorrections?: readonly MediaTypeCorrectionCandidate[];
  readonly referenceCorrections?: readonly ReferenceCorrectionCandidate[];
  readonly equivalentPathCorrections?: readonly EquivalentPathCandidate[];
  readonly xmlEncodingCorrections?: readonly XmlEncodingCandidate[];
}

export function createRepairPlan(
  source: SelectedEpub,
  report: HealthReport & { readonly health: "repairable" },
  candidates: RepairCandidateFacts,
  predictedOutputPath: string,
): Result<RepairPlan, ProcessingFailure> {
  if (!matchesSnapshot(source, report)) return err(stalePlanFailure());

  const operations: RepairOperation[] = [];
  const unresolvedFindings: UnresolvedFinding[] = [];
  const handled = new Set<FindingIdentity>();

  const mimetypeFindings = report.findings.filter(
    (finding) => finding.repairability === "automatic" && finding.recommendedRepair === "write_canonical_mimetype",
  );
  if (mimetypeFindings.length > 0) {
    const findingIds = mimetypeFindings.map(({ identity }) => identity);
    operations.push({
      id: operationId("write_canonical_mimetype", findingIds, MIMETYPE_PATH),
      kind: "write_canonical_mimetype",
      findingIds,
      readPaths: [],
      changedPaths: [MIMETYPE_PATH],
      explanation: "Write the exact canonical EPUB mimetype entry.",
      value: "application/epub+zip",
    });
    findingIds.forEach((id) => handled.add(id));
  }

  for (const finding of report.findings) {
    if (handled.has(finding.identity)) continue;
    const operation = operationForFinding(finding, candidates);
    if (typeof operation === "string") {
      unresolvedFindings.push({ finding, reason: operation });
      continue;
    }
    operations.push(operation);
    handled.add(finding.identity);
  }

  if (operations.length === 0) {
    return err({
      category: "internal",
      code: "INTERNAL_FAILURE",
      safeMessage: "The repairable report contains no deterministic permitted repair.",
      retryable: false,
      phase: "planning",
    });
  }

  const entryOperations = operations.map(({ id }) => id);
  const changedPaths = uniquePaths(operations.flatMap(({ changedPaths }) => changedPaths));
  const findingIds = uniqueFindingIds(operations.flatMap(({ findingIds }) => findingIds));
  operations.push({
    id: operationId("rebuild_epub_archive", findingIds, ...changedPaths),
    kind: "rebuild_epub_archive",
    findingIds,
    readPaths: changedPaths,
    changedPaths,
    explanation: "Rebuild the EPUB archive using only the reviewed entry repairs.",
    entryOperations,
  });

  return ok({
    source,
    originalReport: report,
    operations: operations as [RepairOperation, ...RepairOperation[]],
    unresolvedFindings,
    predictedOutputPath,
    createdAtMs: Date.now(),
  });
}

function operationForFinding(finding: Finding, candidates: RepairCandidateFacts): RepairOperation | string {
  const kind = finding.recommendedRepair;
  if (kind === undefined) return deterministicReason();
  const repairPermission = evaluateRepairPermission(finding);
  if (repairPermission !== undefined) {
    return repairPermission;
  }
  if (finding.repairability !== "automatic") {
    return "This finding is not eligible for an automatic repair.";
  }

  switch (kind) {
    case "rebuild_container_for_single_opf": {
      if (candidateCount(candidates.containerRepairs, finding.identity) > 1) {
        return deterministicReason();
      }
      const supplied = uniqueCandidate(candidates.containerRepairs, finding.identity);
      const evidencePath = stringEvidence(finding, "packagePath") as InternalPath | undefined;
      if (supplied !== undefined && evidencePath !== undefined && supplied.packagePath !== evidencePath) {
        return deterministicReason();
      }
      const packagePath = supplied?.packagePath ?? evidencePath;
      if (packagePath === undefined) return deterministicReason();
      return {
        id: operationId(kind, [finding.identity], packagePath),
        kind,
        findingIds: [finding.identity],
        readPaths: [],
        changedPaths: [CONTAINER_PATH],
        explanation: `Rebuild the container document for the sole package at ${packagePath}.`,
        packagePath,
      };
    }
    case "correct_manifest_media_type": {
      const candidate = uniqueCandidate(candidates.mediaTypeCorrections, finding.identity);
      const expectedMediaType =
        stringEvidence(finding, "inferredMediaType") ?? stringEvidence(finding, "expectedMediaType");
      if (
        candidate === undefined ||
        finding.location?.kind !== "manifest_item" ||
        candidate.packagePath !== finding.location.path ||
        candidate.manifestId !== finding.location.manifestId ||
        (expectedMediaType !== undefined && candidate.mediaType !== expectedMediaType)
      ) {
        return deterministicReason();
      }
      return {
        id: operationId(kind, [finding.identity], candidate.packagePath, candidate.manifestId, candidate.mediaType),
        kind,
        findingIds: [finding.identity],
        readPaths: [candidate.packagePath],
        changedPaths: [candidate.packagePath],
        explanation: `Correct media-type for manifest item ${candidate.manifestId}.`,
        packagePath: candidate.packagePath,
        manifestId: candidate.manifestId,
        mediaType: candidate.mediaType,
      };
    }
    case "correct_unique_reference": {
      const candidate = uniqueCandidate(candidates.referenceCorrections, finding.identity);
      const ownerPath =
        finding.location?.kind === "internal_path" || finding.location?.kind === "xml"
          ? finding.location.path
          : undefined;
      const originalReference = stringEvidence(finding, "reference");
      if (
        candidate === undefined ||
        ownerPath === undefined ||
        candidate.ownerPath !== ownerPath ||
        (originalReference !== undefined && candidate.originalReference !== originalReference) ||
        (finding.targetIdentifier !== undefined && !finding.targetIdentifier.startsWith(`${candidate.targetPath}#`))
      ) {
        return deterministicReason();
      }
      return {
        id: operationId(
          kind,
          [finding.identity],
          candidate.ownerPath,
          candidate.originalReference,
          candidate.replacementReference,
        ),
        kind,
        findingIds: [finding.identity],
        readPaths: [candidate.ownerPath],
        changedPaths: [candidate.ownerPath],
        explanation: `Correct one unique internal reference in ${candidate.ownerPath}.`,
        ownerPath: candidate.ownerPath,
        originalReference: candidate.originalReference,
        replacementReference: candidate.replacementReference,
        targetPath: candidate.targetPath,
      };
    }
    case "normalize_equivalent_internal_path": {
      if (candidateCount(candidates.equivalentPathCorrections, finding.identity) > 1) {
        return deterministicReason();
      }
      const supplied = uniqueCandidate(candidates.equivalentPathCorrections, finding.identity);
      const evidenceSourcePath = stringEvidence(finding, "existingPath") as InternalPath | undefined;
      const evidenceTargetPath = stringEvidence(finding, "referencedPath") as InternalPath | undefined;
      if (
        supplied !== undefined &&
        ((evidenceSourcePath !== undefined && supplied.sourcePath !== evidenceSourcePath) ||
          (evidenceTargetPath !== undefined && supplied.targetPath !== evidenceTargetPath))
      ) {
        return deterministicReason();
      }
      const sourcePath = supplied?.sourcePath ?? evidenceSourcePath;
      const targetPath = supplied?.targetPath ?? evidenceTargetPath;
      if (sourcePath === undefined || targetPath === undefined || sourcePath === targetPath) {
        return deterministicReason();
      }
      return {
        id: operationId(kind, [finding.identity], sourcePath, targetPath),
        kind,
        findingIds: [finding.identity],
        readPaths: [sourcePath],
        changedPaths: [sourcePath, targetPath],
        explanation: `Rename ${sourcePath} to the uniquely equivalent path ${targetPath}.`,
        sourcePath,
        targetPath,
      };
    }
    case "normalize_xml_encoding": {
      if (candidateCount(candidates.xmlEncodingCorrections, finding.identity) > 1) {
        return deterministicReason();
      }
      const supplied = uniqueCandidate(candidates.xmlEncodingCorrections, finding.identity);
      const locationPath =
        finding.location?.kind === "internal_path" || finding.location?.kind === "xml"
          ? finding.location.path
          : undefined;
      const path = supplied?.path ?? locationPath;
      if (path === undefined || (supplied !== undefined && supplied.path !== locationPath)) {
        return deterministicReason();
      }
      return {
        id: operationId(kind, [finding.identity], path),
        kind,
        findingIds: [finding.identity],
        readPaths: [path],
        changedPaths: [path],
        explanation: `Normalize the XML byte encoding of ${path} to UTF-8.`,
        path,
        outputEncoding: "utf-8",
      };
    }
    case "write_canonical_mimetype":
      return "The canonical mimetype repair could not be grouped deterministically.";
    case "rebuild_epub_archive":
      return deterministicReason();
  }
}

function uniqueCandidate<T extends CandidateBase>(
  values: readonly T[] | undefined,
  findingId: FindingIdentity,
): T | undefined {
  const matches = values?.filter((value) => value.findingId === findingId) ?? [];
  return matches.length === 1 ? matches[0] : undefined;
}

function candidateCount<T extends CandidateBase>(values: readonly T[] | undefined, findingId: FindingIdentity): number {
  return values?.filter((value) => value.findingId === findingId).length ?? 0;
}

function stringEvidence(finding: Finding, key: string): string | undefined {
  const value = finding.evidence[key];
  return typeof value === "string" && value.length > 0 ? value : undefined;
}

function matchesSnapshot(source: SelectedEpub, report: HealthReport): boolean {
  const fingerprint = report.sourceFingerprint;
  return (
    report.sourceId === source.id &&
    fingerprint.identity.device === source.identity.device &&
    fingerprint.identity.file === source.identity.file &&
    fingerprint.sizeBytes === source.sizeBytes &&
    fingerprint.modifiedAtMs === source.modifiedAtMs
  );
}

function stalePlanFailure(): ProcessingFailure {
  return {
    category: "repair",
    code: "REPAIR_PLAN_STALE",
    safeMessage: "The EPUB no longer matches the inspected source snapshot.",
    retryable: false,
    phase: "planning",
  };
}

function deterministicReason(): string {
  return "No unique deterministic target was proven; the finding remains unresolved for review.";
}

function operationId(
  kind: RepairKind,
  findingIds: readonly FindingIdentity[],
  ...targets: readonly string[]
): RepairOperationId {
  return JSON.stringify([kind, findingIds, targets]) as RepairOperationId;
}

function uniquePaths(paths: readonly InternalPath[]): InternalPath[] {
  return [...new Set(paths)];
}

function uniqueFindingIds(ids: readonly FindingIdentity[]): FindingIdentity[] {
  return [...new Set(ids)];
}
