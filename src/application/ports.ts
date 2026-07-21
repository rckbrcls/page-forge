import type {
  ArchiveEntryDescriptor,
  ArchiveProjection,
  PreflightOutcome,
} from "../domain/models/archive";
import type { DeliveryConfiguration, DeliveryResult } from "../domain/models/delivery";
import type {
  ContainerProjection,
  ContentProjection,
  PackageProjection,
  ParseOutcome,
  SelectedEpub,
  SelectionSnapshot,
  SourceFingerprint,
  VerifiedReadDescriptor,
} from "../domain/models/epub-document";
import type { AppliedRepair, RepairPlan } from "../domain/models/repair";
import type { ProcessingFailure } from "../domain/models/processing-failure";
import type { Result } from "../domain/models/result";
import type { ProgressListener } from "./progress";

export interface BoundedReadable extends AsyncIterable<Uint8Array> {
  readonly close: () => Promise<Result<void, ProcessingFailure>>;
}

export interface ArchiveSession {
  readonly projection: ArchiveProjection;
  readonly openEntry: (
    entry: ArchiveEntryDescriptor,
    signal: AbortSignal,
  ) => Promise<Result<BoundedReadable, ProcessingFailure>>;
  readonly close: () => Promise<Result<void, ProcessingFailure>>;
}

export interface ArchivePreflightResult {
  readonly outcome: PreflightOutcome<ArchiveProjection>;
  readonly session?: ArchiveSession;
}

export interface ArchiveLimits {
  readonly maxSourceBytes: number;
  readonly maxEntryCount: number;
  readonly maxExpandedEntryBytes: number;
  readonly maxExpandedTotalBytes: number;
  readonly maxExpansionRatio: number;
  readonly maxOutputBytes: number;
}

export interface XmlLimits {
  readonly maxBytes: number;
  readonly maxDepth: number;
}

export interface ArchivePort {
  readonly preflightArchive: (
    descriptor: VerifiedReadDescriptor,
    limits: ArchiveLimits,
    signal: AbortSignal,
  ) => Promise<Result<ArchivePreflightResult, ProcessingFailure>>;
  readonly rebuildArchive: (
    source: ArchiveSession,
    plan: RepairPlan,
    temporary: TemporaryOutput,
    limits: ArchiveLimits,
    signal: AbortSignal,
    onProgress: ProgressListener,
  ) => Promise<Result<readonly AppliedRepair[], ProcessingFailure>>;
}

export interface XmlPort {
  readonly parseContainer: (
    xml: BoundedReadable,
    limits: XmlLimits,
    signal: AbortSignal,
  ) => Promise<Result<ParseOutcome<ContainerProjection>, ProcessingFailure>>;
  readonly parsePackage: (
    xml: BoundedReadable,
    limits: XmlLimits,
    signal: AbortSignal,
  ) => Promise<Result<ParseOutcome<PackageProjection>, ProcessingFailure>>;
  readonly parseContentReferences: (
    xml: BoundedReadable,
    mediaType: string,
    limits: XmlLimits,
    signal: AbortSignal,
  ) => Promise<Result<ParseOutcome<ContentProjection>, ProcessingFailure>>;
}

export interface PredictedOutput {
  readonly sourcePath: string;
  readonly candidatePath: string;
  readonly suffix: number;
}

export interface TemporaryOutput {
  readonly id: string;
  readonly path: string;
  readonly prediction: PredictedOutput;
}

export interface FinalOutput {
  readonly path: string;
  readonly displayName: string;
  readonly fingerprint: SourceFingerprint;
}

export interface FilesystemPort {
  readonly snapshotSource: (path: string) => Promise<Result<SelectedEpub, ProcessingFailure>>;
  readonly openVerifiedSource: (
    snapshot: SelectedEpub,
  ) => Promise<Result<VerifiedReadDescriptor, ProcessingFailure>>;
  readonly fingerprint: (
    descriptor: VerifiedReadDescriptor,
    signal: AbortSignal,
  ) => Promise<Result<SourceFingerprint, ProcessingFailure>>;
  readonly predictOutput: (
    sourcePath: string,
    suffix: number,
  ) => Promise<Result<PredictedOutput, ProcessingFailure>>;
  readonly createSameDirectoryTemporary: (
    prediction: PredictedOutput,
  ) => Promise<Result<TemporaryOutput, ProcessingFailure>>;
  readonly promoteNoClobber: (
    temporary: TemporaryOutput,
    candidate: PredictedOutput,
  ) => Promise<Result<FinalOutput, ProcessingFailure>>;
  readonly cleanupTemporary: (
    temporary: TemporaryOutput,
  ) => Promise<Result<void, ProcessingFailure>>;
}

export interface SelectionPort {
  readonly selectedFinderPaths: () => Promise<
    Result<readonly string[], ProcessingFailure>
  >;
  readonly pickEpubPaths: () => Promise<Result<readonly string[], ProcessingFailure>>;
  readonly snapshotSelection: (
    paths: readonly string[],
    signal: AbortSignal,
  ) => Promise<Result<SelectionSnapshot, ProcessingFailure>>;
}

export interface DeliverySource {
  readonly source: SelectedEpub;
  readonly descriptor: VerifiedReadDescriptor;
  readonly reviewedFingerprint: SourceFingerprint;
}

export interface DeliveryPort {
  readonly submit: (
    source: DeliverySource,
    configuration: DeliveryConfiguration,
    signal: AbortSignal,
    onProgress: ProgressListener,
  ) => Promise<Result<DeliveryResult, ProcessingFailure>>;
}

export interface ClockPort {
  readonly nowMs: () => number;
}
