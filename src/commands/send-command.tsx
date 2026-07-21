import { Action, ActionPanel, Detail, Icon } from "@raycast/api";

import type { DeliveryConfiguration } from "../domain/models/delivery";
import type { BatchItemResult, BatchOperation } from "../domain/models/operation";
import { DeliveryConfirmation } from "./components/delivery-confirmation";
import { DeliveryResultDetail } from "./components/delivery-result";

export interface SendCommandViewProps {
  readonly operation: BatchOperation;
  readonly deliveryConfiguration?: DeliveryConfiguration;
  readonly onPrepare?: () => void;
  readonly onOpenDeliveryPreferences?: () => void;
  readonly onOpenPreferences?: () => void;
  readonly onOpenSendToKindle?: () => void;
  readonly onManualHandoff?: () => void;
  readonly onConfirmSend?: (items: readonly BatchItemResult[]) => void;
  readonly onSend?: (items: readonly BatchItemResult[]) => void;
  readonly onConfirmSendSelection?: (items: readonly BatchItemResult[]) => void;
  readonly onSendAgainConfirmed?: () => void;
  readonly onSendAgain?: () => void;
  readonly onRetryFailed?: () => void;
  readonly onCancel?: () => void;
  readonly onCancelPendingDeliveries?: () => void;
}

const noop = (): void => undefined;

function eligibleItems(operation: BatchOperation): readonly BatchItemResult[] {
  return operation.results.filter(
    (result) => result.status === "prepared" || (result.status === "inspected" && result.report.health === "healthy"),
  );
}

function phaseLabel(operation: BatchOperation): string {
  const active = operation.activeIndex === undefined ? undefined : operation.results[operation.activeIndex];
  if (active?.status !== "in_progress") return operation.phase.replaceAll("_", " ");
  if (!active.progress) return active.phase.replaceAll("_", " ");
  const total = active.progress.total === undefined ? "unknown" : String(active.progress.total);
  return `${active.phase.replaceAll("_", " ")}: ${active.progress.completed} of ${total} ${active.progress.unit}`;
}

export function SendCommandView(props: SendCommandViewProps) {
  const openPreferences = props.onOpenDeliveryPreferences ?? props.onOpenPreferences ?? noop;
  const openHandoff = props.onOpenSendToKindle ?? props.onManualHandoff ?? noop;
  const confirm = props.onConfirmSend ?? props.onSend ?? props.onConfirmSendSelection;
  const sendAgain = props.onSendAgainConfirmed ?? props.onSendAgain ?? noop;

  if (props.operation.phase === "awaiting_delivery_confirmation") {
    return DeliveryConfirmation({
      operation: props.operation,
      configuration: props.deliveryConfiguration,
      onConfirm: () => confirm?.(eligibleItems(props.operation)),
      onOpenPreferences: openPreferences,
      onOpenSendToKindle: openHandoff,
    });
  }

  if (["completed", "failed", "cancelled"].includes(props.operation.phase)) {
    return DeliveryResultDetail({
      operation: props.operation,
      onSendAgain: sendAgain,
      onRetryFailed: props.onRetryFailed ?? noop,
      onOpenSendToKindle: openHandoff,
    });
  }

  return (
    <Detail
      isLoading
      markdown={`# Sending EPUBs\n\n${phaseLabel(props.operation)}`}
      actions={
        <ActionPanel>
          {!props.operation.cancellationRequested ? (
            <Action
              title="Cancel Pending Deliveries"
              icon={Icon.XMarkCircle}
              onAction={props.onCancelPendingDeliveries ?? props.onCancel ?? noop}
            />
          ) : null}
        </ActionPanel>
      }
    />
  );
}

export default SendCommandView;
