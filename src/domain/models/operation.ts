import type { DeliveryResult } from "./delivery";
import type { SelectedEpub, SelectedEpubId } from "./epub-document";
import type { HealthReport } from "./health-report";
import type { PreparationResult, PreparedEpub } from "./repair";
import type { ProcessingFailure } from "./processing-failure";

declare const batchOperationIdBrand: unique symbol;

export type BatchOperationId = string & { readonly [batchOperationIdBrand]: "BatchOperationId" };
export type OperationIntent = "inspect" | "prepare" | "send";
export type ProcessingPhase =
  | "selecting"
  | "preflight"
  | "inspecting_container"
  | "inspecting_package"
  | "inspecting_content"
  | "planning"
  | "awaiting_confirmation"
  | "reconstructing"
  | "revalidating"
  | "comparing"
  | "promoting"
  | "checking_delivery_eligibility"
  | "awaiting_delivery_confirmation"
  | "connecting"
  | "transmitting"
  | "completed"
  | "failed"
  | "cancelled";

export type ProgressUnit = "files" | "entries" | "bytes";

export interface OperationProgress {
  readonly completed: number;
  readonly total?: number;
  readonly unit: ProgressUnit;
}

export interface ProgressEvent {
  readonly operationId: BatchOperationId;
  readonly sourceId?: SelectedEpubId;
  readonly itemIndex?: number;
  readonly phase: ProcessingPhase;
  readonly progress?: OperationProgress;
  readonly occurredAtMs: number;
}

export type BatchItemResult =
  | { readonly status: "pending"; readonly source: SelectedEpub }
  | {
      readonly status: "in_progress";
      readonly source: SelectedEpub;
      readonly phase: ProcessingPhase;
      readonly progress?: OperationProgress;
    }
  | { readonly status: "inspected"; readonly source: SelectedEpub; readonly report: HealthReport }
  | { readonly status: "prepared"; readonly source: SelectedEpub; readonly prepared: PreparedEpub }
  | {
      readonly status: "submitted";
      readonly source: SelectedEpub;
      readonly delivery: DeliveryResult & { readonly status: "submitted" };
    }
  | {
      readonly status: "failed";
      readonly source: SelectedEpub;
      readonly failure: ProcessingFailure;
      readonly preparation?: Extract<PreparationResult, { readonly status: "unsuccessful" }>;
      readonly delivery?: Extract<DeliveryResult, { readonly status: "failed" }>;
    }
  | {
      readonly status: "cancelled";
      readonly source: SelectedEpub;
      readonly phase: ProcessingPhase;
    }
  | {
      readonly status: "delivery_unknown";
      readonly source: SelectedEpub;
      readonly delivery: DeliveryResult & { readonly status: "delivery_unknown" };
    };

export interface BatchOperation {
  readonly id: BatchOperationId;
  readonly intent: OperationIntent;
  readonly items: readonly SelectedEpub[];
  readonly phase: ProcessingPhase;
  readonly activeIndex?: number;
  readonly cancellationRequested: boolean;
  readonly results: readonly BatchItemResult[];
}
