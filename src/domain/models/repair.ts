import type { InternalPath } from "./archive";
import type {
  SelectedEpub,
  Sha256Digest,
  SourceFingerprint,
  SourceSnapshot,
} from "./epub-document";
import type { Finding, FindingIdentity } from "./finding";
import type { HealthReport, HealthState } from "./health-report";
import type { ProcessingFailure } from "./processing-failure";

declare const repairOperationIdBrand: unique symbol;

export type RepairOperationId = string & {
  readonly [repairOperationIdBrand]: "RepairOperationId";
};
export type RepairKind =
  | "write_canonical_mimetype"
  | "rebuild_container_for_single_opf"
  | "correct_manifest_media_type"
  | "correct_unique_reference"
  | "normalize_equivalent_internal_path"
  | "normalize_xml_encoding"
  | "rebuild_epub_archive";

interface RepairOperationBase<K extends RepairKind> {
  readonly id: RepairOperationId;
  readonly kind: K;
  readonly findingIds: readonly FindingIdentity[];
  readonly readPaths: readonly InternalPath[];
  readonly changedPaths: readonly InternalPath[];
  readonly explanation: string;
}

export type RepairOperation =
  | (RepairOperationBase<"write_canonical_mimetype"> & {
      readonly value: "application/epub+zip";
    })
  | (RepairOperationBase<"rebuild_container_for_single_opf"> & {
      readonly packagePath: InternalPath;
    })
  | (RepairOperationBase<"correct_manifest_media_type"> & {
      readonly packagePath: InternalPath;
      readonly manifestId: string;
      readonly mediaType: string;
    })
  | (RepairOperationBase<"correct_unique_reference"> & {
      readonly ownerPath: InternalPath;
      readonly originalReference: string;
      readonly replacementReference: string;
      readonly targetPath: InternalPath;
    })
  | (RepairOperationBase<"normalize_equivalent_internal_path"> & {
      readonly sourcePath: InternalPath;
      readonly targetPath: InternalPath;
    })
  | (RepairOperationBase<"normalize_xml_encoding"> & {
      readonly path: InternalPath;
      readonly outputEncoding: "utf-8";
    })
  | (RepairOperationBase<"rebuild_epub_archive"> & {
      readonly entryOperations: readonly RepairOperationId[];
    });

export interface UnresolvedFinding {
  readonly finding: Finding;
  readonly reason: string;
}

export interface RepairPlan {
  readonly source: SelectedEpub;
  readonly originalReport: HealthReport & { readonly health: "repairable" };
  readonly operations: readonly [RepairOperation, ...RepairOperation[]];
  readonly unresolvedFindings: readonly UnresolvedFinding[];
  readonly predictedOutputPath: string;
  readonly createdAtMs: number;
}

interface AppliedRepairBase {
  readonly operationId: RepairOperationId;
  readonly resolvedFindingIds: readonly FindingIdentity[];
  readonly changedEntries: readonly InternalPath[];
  readonly preservedEntryCount: number;
}

export type AppliedRepair =
  | (AppliedRepairBase & { readonly outcome: "applied" })
  | (AppliedRepairBase & { readonly outcome: "already_satisfied" })
  | (AppliedRepairBase & { readonly outcome: "failed"; readonly failure: ProcessingFailure });

export interface RevalidationComparison {
  readonly before: HealthReport;
  readonly after: HealthReport;
  readonly repairs: readonly AppliedRepair[];
  readonly resolved: readonly FindingIdentity[];
  readonly remaining: readonly FindingIdentity[];
  readonly introduced: readonly Finding[];
  readonly successful: boolean;
  readonly finalHealth: HealthState;
}

export interface PreparedOutputSnapshot extends SourceSnapshot {
  readonly sha256: Sha256Digest;
}

export interface PreparedEpub {
  readonly outputPath: string;
  readonly displayName: string;
  readonly sizeBytes: number;
  readonly report: HealthReport & { readonly health: "healthy" };
  readonly comparison: RevalidationComparison & { readonly successful: true };
  readonly sourceFingerprint: SourceFingerprint;
  readonly outputSnapshot: PreparedOutputSnapshot;
}

export type TemporaryCleanupStatus =
  | { readonly status: "not_required" }
  | { readonly status: "completed" }
  | { readonly status: "failed"; readonly failure: ProcessingFailure };

export type PreparationResult =
  | { readonly status: "prepared"; readonly prepared: PreparedEpub }
  | {
      readonly status: "unsuccessful";
      readonly failure: ProcessingFailure;
      readonly originalReport: HealthReport;
      readonly repairedReport?: HealthReport;
      readonly comparison?: RevalidationComparison;
      readonly cleanup: TemporaryCleanupStatus;
    }
  | {
      readonly status: "cancelled";
      readonly phase: import("./operation").ProcessingPhase;
      readonly cleanup: TemporaryCleanupStatus;
    };
