import type { ClockPort, FilesystemPort, TemporaryOutput } from "./ports";
import type { SelectedEpub, SourceFingerprint } from "../domain/models/epub-document";
import type { HealthReport } from "../domain/models/health-report";
import type { BatchOperationId, ProcessingPhase, ProgressEvent } from "../domain/models/operation";
import type { ProcessingFailure } from "../domain/models/processing-failure";
import type {
  AppliedRepair,
  PreparationResult,
  RepairPlan,
  RevalidationComparison,
  TemporaryCleanupStatus,
} from "../domain/models/repair";
import type { Result } from "../domain/models/result";

export interface RepairExecutionPort {
  readonly apply: (
    plan: RepairPlan,
    temporary: TemporaryOutput,
    signal: AbortSignal,
    onProgress: PrepareProgressListener,
  ) => Promise<Result<readonly AppliedRepair[], ProcessingFailure>>;
}

export interface PrepareInspectionPort {
  readonly inspect: (
    source: SelectedEpub,
    signal: AbortSignal,
  ) => Promise<Result<HealthReport, ProcessingFailure>>;
}

export interface PrepareComparisonPort {
  readonly compare: (
    before: HealthReport,
    after: HealthReport,
    repairs: readonly AppliedRepair[],
  ) => RevalidationComparison;
}

export interface PrepareEpubPorts {
  readonly filesystem: FilesystemPort;
  readonly reconstruction: RepairExecutionPort;
  readonly inspection: PrepareInspectionPort;
  readonly comparison: PrepareComparisonPort;
  readonly clock: ClockPort;
}

export type PrepareProgressListener = (event: ProgressEvent) => void;

type UnsuccessfulResult = Extract<PreparationResult, { readonly status: "unsuccessful" }>;

function internalFailure(phase: ProcessingPhase): ProcessingFailure {
  return {
    category: "internal",
    code: "INTERNAL_FAILURE",
    safeMessage: "The EPUB could not be prepared.",
    retryable: true,
    phase,
  };
}

function stalePlanFailure(): ProcessingFailure {
  return {
    category: "repair",
    code: "REPAIR_PLAN_STALE",
    safeMessage: "The EPUB no longer matches the confirmed repair plan.",
    retryable: false,
    phase: "reconstructing",
  };
}

function revalidationFailure(comparison: RevalidationComparison): ProcessingFailure {
  const hasCritical = comparison.introduced.some(({ severity }) => severity === "critical");
  return {
    category: "repair",
    code: hasCritical ? "REVALIDATION_NEW_CRITICAL" : "REVALIDATION_NEW_ERROR",
    safeMessage: hasCritical
      ? "Revalidation introduced a critical finding."
      : "The repaired EPUB did not pass revalidation.",
    retryable: false,
    phase: "comparing",
    facts: {
      introducedCount: comparison.introduced.length,
      finalHealth: comparison.finalHealth,
    },
  };
}

function cancelledResult(phase: ProcessingPhase, cleanup: TemporaryCleanupStatus): PreparationResult {
  return { status: "cancelled", phase, cleanup };
}

function sameFingerprint(left: SourceFingerprint, right: SourceFingerprint): boolean {
  return (
    left.identity.device === right.identity.device &&
    left.identity.file === right.identity.file &&
    left.sizeBytes === right.sizeBytes &&
    left.modifiedAtMs === right.modifiedAtMs &&
    left.sha256 === right.sha256
  );
}

function sameSnapshot(left: SelectedEpub, right: SelectedEpub): boolean {
  return (
    left.identity.device === right.identity.device &&
    left.identity.file === right.identity.file &&
    left.sizeBytes === right.sizeBytes &&
    left.modifiedAtMs === right.modifiedAtMs
  );
}

function cancelledFailure(signal: AbortSignal, phase: ProcessingPhase): ProcessingFailure | undefined {
  if (!signal.aborted) return undefined;
  return {
    category: "cancelled",
    code: "OPERATION_CANCELLED",
    safeMessage: "The operation was cancelled.",
    retryable: false,
    phase,
  };
}

async function cleanupTemporary(
  filesystem: FilesystemPort,
  temporary: TemporaryOutput | undefined,
): Promise<TemporaryCleanupStatus> {
  if (temporary === undefined) return { status: "not_required" };
  try {
    const result = await filesystem.cleanupTemporary(temporary);
    return result.ok ? { status: "completed" } : { status: "failed", failure: result.failure };
  } catch {
    return {
      status: "failed",
      failure: {
        category: "repair",
        code: "REPAIR_TEMP_CLEANUP_FAILED",
        safeMessage: "The temporary repaired EPUB could not be removed safely.",
        retryable: true,
        phase: "reconstructing",
      },
    };
  }
}

async function verifySource(
  plan: RepairPlan,
  filesystem: FilesystemPort,
  signal: AbortSignal,
): Promise<Result<SourceFingerprint, ProcessingFailure>> {
  const snapshot = await filesystem.snapshotSource(plan.source.sourcePath);
  if (!snapshot.ok) return snapshot;
  if (!sameSnapshot(snapshot.value, plan.source)) {
    return { ok: false, failure: stalePlanFailure() };
  }

  const descriptor = await filesystem.openVerifiedSource(snapshot.value);
  if (!descriptor.ok) return descriptor;
  const fingerprint = await filesystem.fingerprint(descriptor.value, signal);
  if (!fingerprint.ok) return fingerprint;
  if (!sameFingerprint(fingerprint.value, plan.originalReport.sourceFingerprint)) {
    return { ok: false, failure: stalePlanFailure() };
  }
  return fingerprint;
}

function operationEvidenceIsComplete(
  plan: RepairPlan,
  repairs: readonly AppliedRepair[],
): boolean {
  const successfulIds = new Set(
    repairs
      .filter(({ outcome }) => outcome === "applied" || outcome === "already_satisfied")
      .map(({ operationId }) => operationId),
  );
  return plan.operations.every(({ id }) => successfulIds.has(id));
}

function isHealthyReport(
  report: HealthReport,
): report is HealthReport & { readonly health: "healthy" } {
  return report.health === "healthy";
}

function isSuccessfulComparison(
  value: RevalidationComparison,
): value is RevalidationComparison & { readonly successful: true } {
  return value.successful && value.finalHealth === "healthy";
}

export async function prepareEpub(
  confirmedPlan: RepairPlan,
  ports: PrepareEpubPorts,
  signal: AbortSignal,
  onProgress: PrepareProgressListener,
): Promise<PreparationResult> {
  const operationId = `prepare:${confirmedPlan.source.id}:${ports.clock.nowMs()}` as BatchOperationId;
  let temporary: TemporaryOutput | undefined;
  let repairedReport: HealthReport | undefined;
  let comparison: RevalidationComparison | undefined;
  let phase: ProcessingPhase = "preflight";

  const emit = (nextPhase: ProcessingPhase): void => {
    phase = nextPhase;
    onProgress({
      operationId,
      sourceId: confirmedPlan.source.id,
      itemIndex: 0,
      phase: nextPhase,
      occurredAtMs: ports.clock.nowMs(),
    });
  };

  const unsuccessful = async (failure: ProcessingFailure): Promise<UnsuccessfulResult> => ({
    status: "unsuccessful",
    failure,
    originalReport: confirmedPlan.originalReport,
    ...(repairedReport === undefined ? {} : { repairedReport }),
    ...(comparison === undefined ? {} : { comparison }),
    cleanup: await cleanupTemporary(ports.filesystem, temporary),
  });

  const stopIfCancelled = async (): Promise<PreparationResult | undefined> => {
    const failure = cancelledFailure(signal, phase);
    if (failure === undefined) return undefined;
    return cancelledResult(failure.phase, await cleanupTemporary(ports.filesystem, temporary));
  };

  try {
    emit("preflight");
    const initialCancellation = await stopIfCancelled();
    if (initialCancellation !== undefined) return initialCancellation;

    const initialSource = await verifySource(confirmedPlan, ports.filesystem, signal);
    if (!initialSource.ok) {
      if (initialSource.failure.category === "cancelled") {
        return cancelledResult(initialSource.failure.phase, { status: "not_required" });
      }
      return unsuccessful(initialSource.failure);
    }

    const prediction = await ports.filesystem.predictOutput(confirmedPlan.source.sourcePath, 1);
    if (!prediction.ok) return unsuccessful(prediction.failure);
    const temporaryResult = await ports.filesystem.createSameDirectoryTemporary(prediction.value);
    if (!temporaryResult.ok) return unsuccessful(temporaryResult.failure);
    temporary = temporaryResult.value;

    emit("reconstructing");
    const reconstructionCancellation = await stopIfCancelled();
    if (reconstructionCancellation !== undefined) return reconstructionCancellation;
    const reconstructed = await ports.reconstruction.apply(
      confirmedPlan,
      temporary,
      signal,
      onProgress,
    );
    if (!reconstructed.ok) {
      if (reconstructed.failure.category === "cancelled") {
        return cancelledResult(
          reconstructed.failure.phase,
          await cleanupTemporary(ports.filesystem, temporary),
        );
      }
      return unsuccessful(reconstructed.failure);
    }

    emit("revalidating");
    const revalidationCancellation = await stopIfCancelled();
    if (revalidationCancellation !== undefined) return revalidationCancellation;
    const temporarySnapshot = await ports.filesystem.snapshotSource(temporary.path);
    if (!temporarySnapshot.ok) return unsuccessful(temporarySnapshot.failure);
    const temporaryDescriptor = await ports.filesystem.openVerifiedSource(temporarySnapshot.value);
    if (!temporaryDescriptor.ok) return unsuccessful(temporaryDescriptor.failure);
    const outputFingerprint = await ports.filesystem.fingerprint(temporaryDescriptor.value, signal);
    if (!outputFingerprint.ok) {
      if (outputFingerprint.failure.category === "cancelled") {
        return cancelledResult(
          outputFingerprint.failure.phase,
          await cleanupTemporary(ports.filesystem, temporary),
        );
      }
      return unsuccessful(outputFingerprint.failure);
    }

    const inspected = await ports.inspection.inspect(temporarySnapshot.value, signal);
    if (!inspected.ok) {
      if (inspected.failure.category === "cancelled") {
        return cancelledResult(
          inspected.failure.phase,
          await cleanupTemporary(ports.filesystem, temporary),
        );
      }
      return unsuccessful(inspected.failure);
    }
    repairedReport = inspected.value;
    if (!sameFingerprint(repairedReport.sourceFingerprint, outputFingerprint.value)) {
      return unsuccessful(internalFailure("revalidating"));
    }

    emit("comparing");
    comparison = ports.comparison.compare(
      confirmedPlan.originalReport,
      repairedReport,
      reconstructed.value,
    );
    if (
      !isSuccessfulComparison(comparison) ||
      !isHealthyReport(repairedReport) ||
      !operationEvidenceIsComplete(confirmedPlan, reconstructed.value)
    ) {
      return unsuccessful(revalidationFailure(comparison));
    }

    const finalSourceCheck = await verifySource(confirmedPlan, ports.filesystem, signal);
    if (!finalSourceCheck.ok) {
      if (finalSourceCheck.failure.category === "cancelled") {
        return cancelledResult(
          finalSourceCheck.failure.phase,
          await cleanupTemporary(ports.filesystem, temporary),
        );
      }
      return unsuccessful(finalSourceCheck.failure);
    }

    emit("promoting");
    const promotionCancellation = await stopIfCancelled();
    if (promotionCancellation !== undefined) return promotionCancellation;
    const promoted = await ports.filesystem.promoteNoClobber(temporary, temporary.prediction);
    if (!promoted.ok) return unsuccessful(promoted.failure);

    const cleanup = await cleanupTemporary(ports.filesystem, temporary);
    temporary = undefined;
    if (cleanup.status === "failed") {
      return {
        status: "unsuccessful",
        failure: cleanup.failure,
        originalReport: confirmedPlan.originalReport,
        repairedReport,
        comparison,
        cleanup,
      };
    }

    emit("completed");
    return {
      status: "prepared",
      prepared: {
        outputPath: promoted.value.path,
        displayName: promoted.value.displayName,
        sizeBytes: promoted.value.fingerprint.sizeBytes,
        report: repairedReport,
        comparison,
        sourceFingerprint: finalSourceCheck.value,
        outputSnapshot: promoted.value.fingerprint,
      },
    };
  } catch {
    return unsuccessful(internalFailure(phase));
  }
}
