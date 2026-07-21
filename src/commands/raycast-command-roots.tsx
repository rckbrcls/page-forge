import { getPreferenceValues, openCommandPreferences, showInFinder } from "@raycast/api";
import { useCallback, useEffect, useRef, useState } from "react";

import { inspectEpubs } from "../application/inspect-epubs";
import { prepareEpub } from "../application/prepare-epubs";
import { selectEpubs } from "../application/select-epubs";
import { sendEpubs } from "../application/send-epubs";
import { archiveReader } from "../adapters/archive/archive-reader";
import { archiveWriter } from "../adapters/archive/archive-writer";
import { openOfficialSendToKindle } from "../adapters/delivery/kindle-handoff";
import { submit } from "../adapters/delivery/smtp-client";
import { atomicOutputWriter } from "../adapters/filesystem/atomic-output-writer";
import { localEpubFiles } from "../adapters/filesystem/local-epub-files";
import { createManualHandoffFile } from "../adapters/filesystem/manual-handoff-file";
import { loadDeliveryConfiguration, type RawDeliveryPreferences } from "../adapters/raycast/delivery-preferences";
import { createFilePickerSource } from "../adapters/raycast/file-picker-source";
import { selectedFinderItems } from "../adapters/raycast/selected-finder-items";
import {
  parseContainerProjection,
  parseContentProjection,
  parsePackageProjection,
} from "../adapters/xml/epub-projections";
import { SafeXmlError } from "../adapters/xml/safe-xml-parser";
import { auditEpub } from "../domain/audit/audit-epub";
import { ARCHIVE_LIMITS, XML_LIMITS } from "../domain/audit/limits";
import { compareReports } from "../domain/repair/compare-revalidation";
import { createRepairPlan } from "../domain/repair/create-repair-plan";
import { deriveRepairCandidates } from "../domain/repair/derive-repair-candidates";
import type { DeliveryConfiguration } from "../domain/models/delivery";
import type { SelectedEpub, SelectionRejection, SelectionSnapshot } from "../domain/models/epub-document";
import type { HealthReport } from "../domain/models/health-report";
import type { BatchItemResult, BatchOperation, BatchOperationId, ProgressEvent } from "../domain/models/operation";
import type { ProcessingFailure } from "../domain/models/processing-failure";
import { err, ok, type Result } from "../domain/models/result";
import type { AppliedRepair, RepairPlan } from "../domain/models/repair";
import { EpubPicker } from "./components/epub-picker";
import { SetupRequiredDetail } from "./components/setup-required-detail";
import { SendCommandView } from "./send-command";

const clock = { nowMs: () => Date.now() } as const;
const filesystem = { ...localEpubFiles, ...atomicOutputWriter };

function xmlFailure(error: unknown): ProcessingFailure {
  if (error instanceof SafeXmlError && error.code === "cancelled") {
    return {
      category: "cancelled",
      code: "OPERATION_CANCELLED",
      safeMessage: "The operation was cancelled.",
      retryable: false,
      phase: "preflight",
    };
  }
  return {
    category: "xml",
    code: "XML_PARSER_FAILED",
    safeMessage: "The book file appears to be corrupted and cannot be read.",
    retryable: false,
    phase: "preflight",
  };
}

const xml = {
  async parseContainer(
    source: Parameters<typeof parseContainerProjection>[0],
    path: Parameters<typeof parseContainerProjection>[1],
    limits: typeof XML_LIMITS,
    signal: AbortSignal,
  ) {
    try {
      return ok({
        projection: await parseContainerProjection(source, path, limits, signal),
        findings: [],
      });
    } catch (error) {
      return err(xmlFailure(error));
    }
  },
  async parsePackage(
    source: Parameters<typeof parsePackageProjection>[0],
    path: Parameters<typeof parsePackageProjection>[1],
    limits: typeof XML_LIMITS,
    signal: AbortSignal,
  ) {
    try {
      return ok({ projection: await parsePackageProjection(source, path, limits, signal), findings: [] });
    } catch (error) {
      return err(xmlFailure(error));
    }
  },
  async parseContentReferences(
    source: Parameters<typeof parseContentProjection>[0],
    path: Parameters<typeof parseContentProjection>[1],
    mediaType: string,
    limits: typeof XML_LIMITS,
    signal: AbortSignal,
  ) {
    try {
      return ok({
        projection: await parseContentProjection(source, path, mediaType, limits, signal),
        findings: [],
      });
    } catch (error) {
      return err(xmlFailure(error));
    }
  },
};

const inspection = {
  inspect: (source: SelectedEpub, signal: AbortSignal) =>
    auditEpub(source, { filesystem, archive: archiveReader, xml, clock }, signal),
};

function isPdf(source: SelectedEpub): boolean {
  return source.format === "pdf" || source.displayName.toLocaleLowerCase("en-US").endsWith(".pdf");
}

async function inspectPdf(source: SelectedEpub, signal: AbortSignal): Promise<Result<HealthReport, ProcessingFailure>> {
  const startedAtMs = clock.nowMs();
  const descriptor = await filesystem.openVerifiedSource(source);
  if (!descriptor.ok) return descriptor;
  const header = await filesystem.validatePdfHeader(descriptor.value);
  if (!header.ok) {
    await filesystem.closeVerifiedSource(descriptor.value);
    return header;
  }
  const fingerprint = await filesystem.fingerprint(descriptor.value, signal);
  const closed = await filesystem.verifyAndCloseVerifiedSource(descriptor.value);
  if (!fingerprint.ok) return fingerprint;
  if (!closed.ok) return closed;
  const inspectedAtMs = clock.nowMs();
  return ok({
    sourceId: source.id,
    sourceFingerprint: fingerprint.value,
    epubVersion: "unknown",
    health: "healthy",
    findings: [],
    inspectedAtMs,
    durationMs: inspectedAtMs - startedAtMs,
    ruleResults: [],
  });
}

const reconstruction = {
  async apply(
    plan: RepairPlan,
    temporary: Parameters<typeof archiveWriter.rebuildArchive>[2],
    signal: AbortSignal,
    onProgress: (event: ProgressEvent) => void,
  ): Promise<Result<readonly AppliedRepair[], ProcessingFailure>> {
    const descriptor = await filesystem.openVerifiedSource(plan.source);
    if (!descriptor.ok) return descriptor;
    const preflight = await archiveReader.preflightArchive(descriptor.value, ARCHIVE_LIMITS, signal);
    if (!preflight.ok) return preflight;
    if (preflight.value.outcome.terminal || preflight.value.session === undefined) {
      return err({
        category: "repair",
        code: "REPAIR_WRITE_FAILED",
        safeMessage: "The book file could not be safely repaired and saved.",
        retryable: false,
        phase: "reconstructing",
      } as ProcessingFailure);
    }
    const rebuilt = await archiveWriter.rebuildArchive(
      preflight.value.session,
      plan,
      temporary,
      ARCHIVE_LIMITS,
      signal,
      onProgress,
    );
    const closed = await preflight.value.session.close();
    return rebuilt.ok && !closed.ok ? closed : rebuilt;
  },
};

function idle(intent: BatchOperation["intent"]): BatchOperation {
  return {
    id: `${intent}:idle` as BatchOperationId,
    intent,
    items: [],
    phase: "selecting",
    cancellationRequested: false,
    results: [],
  };
}

function progressOperation(operation: BatchOperation, event: ProgressEvent): BatchOperation {
  return {
    ...operation,
    phase: event.phase,
    activeIndex: event.itemIndex,
    results: operation.results.map((result) =>
      result.source.id === event.sourceId && (result.status === "pending" || result.status === "in_progress")
        ? {
            status: "in_progress",
            source: result.source,
            phase: event.phase,
            ...(event.progress ? { progress: event.progress } : {}),
          }
        : result,
    ),
  };
}

function useIntake(
  intent: BatchOperation["intent"],
  onSnapshot: (snapshot: SelectionSnapshot, signal: AbortSignal) => Promise<void>,
  enabled = true,
) {
  const [selecting, setSelecting] = useState(enabled);
  const [rejections, setRejections] = useState<readonly SelectionRejection[]>([]);
  const controller = useRef<AbortController | undefined>(undefined);
  const onSnapshotRef = useRef(onSnapshot);

  useEffect(() => {
    onSnapshotRef.current = onSnapshot;
  }, [onSnapshot]);

  const select = useCallback(async (paths: readonly string[] = []): Promise<void> => {
    controller.current?.abort();
    const next = new AbortController();
    controller.current = next;
    setSelecting(true);
    const selection = await selectEpubs(
      {
        ...selectedFinderItems,
        ...createFilePickerSource(() => paths),
        snapshotSelection: filesystem.snapshotSelection,
      },
      next.signal,
    );
    if (!selection.ok) {
      setSelecting(false);
      return;
    }
    setRejections(selection.value.rejections);
    if (selection.value.items.length === 0) {
      setSelecting(false);
      return;
    }
    await onSnapshotRef.current(selection.value, next.signal);
    setSelecting(false);
  }, []);

  const beginOperation = (): AbortSignal => {
    controller.current?.abort();
    controller.current = new AbortController();
    return controller.current.signal;
  };

  useEffect(() => {
    if (!enabled) {
      controller.current?.abort();
      setSelecting(false);
      return;
    }
    void select();
    return () => controller.current?.abort();
  }, [enabled, select]);

  return { selecting, rejections, select, beginOperation, cancel: () => controller.current?.abort(), intent };
}

type DeliverySetupState =
  | { readonly status: "ready"; readonly configuration: DeliveryConfiguration }
  | { readonly status: "required"; readonly issue: string };

function readDeliverySetup(): DeliverySetupState {
  const result = loadDeliveryConfiguration(getPreferenceValues<RawDeliveryPreferences>());
  if (!result.ok) return { status: "required", issue: result.failure.safeMessage };
  if (result.value === undefined) {
    return { status: "required", issue: "Add your SMTP server, email credentials, and Kindle address." };
  }
  return { status: "ready", configuration: result.value };
}

export function BookSenderCommand() {
  const [operation, setOperation] = useState(() => idle("send"));
  const [deliverySetup, setDeliverySetup] = useState<DeliverySetupState>(readDeliverySetup);
  const configuration = deliverySetup.status === "ready" ? deliverySetup.configuration : undefined;
  const intake = useIntake(
    "send",
    async (snapshot, signal) => {
      setOperation({
        ...idle("send"),
        items: snapshot.items,
        results: snapshot.items.map((source) => ({ status: "pending", source })),
      });
      const epubItems = snapshot.items.filter((source) => !isPdf(source));
      const epubInspection = await inspectEpubs(
        { ...snapshot, items: epubItems },
        { inspection, clock },
        signal,
        (event) => setOperation((current) => progressOperation(current, event)),
      );
      const inspectedById = new Map(epubInspection.results.map((result) => [result.source.id, result]));
      for (const [index, source] of snapshot.items.entries()) {
        if (!isPdf(source)) continue;
        setOperation((current) => ({ ...current, phase: "preflight", activeIndex: index }));
        const report = await inspectPdf(source, signal);
        inspectedById.set(
          source.id,
          report.ok
            ? { status: "inspected", source, report: report.value }
            : { status: "failed", source, failure: report.failure },
        );
      }
      const inspected: BatchOperation = {
        ...epubInspection,
        intent: "send",
        items: snapshot.items,
        results: snapshot.items.map((source) => inspectedById.get(source.id) ?? { status: "pending" as const, source }),
      };
      const results = [...inspected.results];
      for (const [index, item] of inspected.results.entries()) {
        if (item.status !== "inspected" || item.report.health !== "repairable") continue;
        const prediction = await filesystem.predictOutput(item.source.sourcePath, 1);
        if (!prediction.ok) {
          results[index] = { status: "failed", source: item.source, failure: prediction.failure };
          continue;
        }
        const plan = createRepairPlan(
          item.source,
          item.report,
          deriveRepairCandidates(item.report),
          prediction.value.candidatePath,
        );
        if (!plan.ok) {
          results[index] = { status: "failed", source: item.source, failure: plan.failure };
          continue;
        }
        setOperation((current) => ({
          ...current,
          phase: "reconstructing",
          activeIndex: index,
          results: current.results.map((result) =>
            result.source.id === item.source.id
              ? { status: "in_progress", source: result.source, phase: "reconstructing" }
              : result,
          ),
        }));
        const prepared = await prepareEpub(
          plan.value,
          { filesystem, reconstruction, inspection, comparison: { compare: compareReports }, clock },
          signal,
          (event) => setOperation((current) => progressOperation(current, event)),
        );
        results[index] =
          prepared.status === "prepared"
            ? { status: "prepared", source: item.source, prepared: prepared.prepared }
            : prepared.status === "cancelled"
              ? { status: "cancelled", source: item.source, phase: prepared.phase }
              : { status: "failed", source: item.source, failure: prepared.failure, preparation: prepared };
      }
      setOperation({ ...inspected, intent: "send", phase: "awaiting_delivery_confirmation", results });
    },
    deliverySetup.status === "ready",
  );

  const confirm = async (items: readonly BatchItemResult[]): Promise<void> => {
    if (!configuration) return;
    const candidates = items.filter(
      (item): item is Extract<BatchItemResult, { status: "inspected" | "prepared" }> =>
        item.status === "prepared" || (item.status === "inspected" && item.report.health === "healthy"),
    );
    const signal = intake.beginOperation();
    const preparedById = new Map(
      items
        .filter((item): item is Extract<BatchItemResult, { status: "prepared" }> => item.status === "prepared")
        .map((item) => [item.source.id, item.prepared]),
    );
    setOperation((current) => ({ ...current, phase: "checking_delivery_eligibility", cancellationRequested: false }));
    const completed = await sendEpubs(
      candidates,
      configuration,
      { filesystem, delivery: { submit }, clock },
      signal,
      (event) => setOperation((current) => progressOperation(current, event)),
    );
    for (const result of completed.results) {
      if (result.status !== "submitted") continue;
      const prepared = preparedById.get(result.source.id);
      if (prepared) await filesystem.cleanupPromotedOutput(prepared.outputPath, prepared.outputSnapshot);
    }
    setOperation(completed);
  };

  const refreshDeliverySetup = (): void => setDeliverySetup(readDeliverySetup());

  if (deliverySetup.status === "required") {
    return (
      <SetupRequiredDetail
        issue={deliverySetup.issue}
        onOpenPreferences={() => {
          void openCommandPreferences();
        }}
        onCheckAgain={refreshDeliverySetup}
      />
    );
  }
  if (operation.items.length === 0)
    return <EpubPicker onSubmit={intake.select} isLoading={intake.selecting} rejections={intake.rejections} />;
  return (
    <SendCommandView
      operation={operation}
      deliveryConfiguration={configuration}
      onOpenDeliveryPreferences={() => void openCommandPreferences()}
      onOpenSendToKindle={async () => {
        const prepared = operation.results.find((result) => result.status === "prepared");
        if (prepared?.status === "prepared") {
          const handoff = await createManualHandoffFile(prepared.prepared.outputPath, prepared.source.displayName);
          if (handoff.ok) await showInFinder(handoff.value);
        }
        await openOfficialSendToKindle();
      }}
      onConfirmSend={(items: readonly BatchItemResult[]) => void confirm(items)}
      onSendAgainConfirmed={() => void confirm(operation.results)}
      onRetryFailed={() => void intake.select(operation.items.map(({ sourcePath }) => sourcePath))}
      onCancel={intake.cancel}
    />
  );
}
