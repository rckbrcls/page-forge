import type { ProcessingPhase } from "./operation";

export type SafeFailureFact = string | number | boolean | null;
export type SafeFailureFacts = Readonly<Record<string, SafeFailureFact>>;

interface ProcessingFailureBase<C extends string, Code extends string> {
  readonly category: C;
  readonly code: Code;
  readonly safeMessage: string;
  readonly retryable: boolean;
  readonly phase: ProcessingPhase;
  readonly facts?: SafeFailureFacts;
}

export type InputFailureCode =
  | "INPUT_NOT_EPUB"
  | "INPUT_NOT_REGULAR_FILE"
  | "INPUT_UNREADABLE"
  | "INPUT_CHANGED";

export type ArchiveFailureCode =
  | "ARCHIVE_OPEN_FAILED"
  | "ARCHIVE_READ_FAILED"
  | "ARCHIVE_STREAM_FAILED"
  | "ARCHIVE_CLOSE_FAILED";

export type XmlFailureCode = "XML_STREAM_FAILED" | "XML_PARSER_FAILED";

export type RepairFailureCode =
  | "REPAIR_PLAN_STALE"
  | "REPAIR_OUTPUT_UNWRITABLE"
  | "REPAIR_WRITE_FAILED"
  | "REPAIR_TIMEOUT"
  | "REPAIR_TEMP_CLEANUP_FAILED"
  | "REVALIDATION_TIMEOUT"
  | "REVALIDATION_NEW_ERROR"
  | "REVALIDATION_NEW_CRITICAL";

export type DeliveryConfigurationFailureCode =
  | "DELIVERY_CONFIG_MISSING"
  | "DELIVERY_CONFIG_INVALID";

export type DeliveryTransportFailureCode =
  | "DELIVERY_DNS_FAILED"
  | "DELIVERY_CONNECTION_FAILED"
  | "DELIVERY_TLS_FAILED"
  | "DELIVERY_AUTH_FAILED"
  | "DELIVERY_ENVELOPE_REJECTED"
  | "DELIVERY_MESSAGE_REJECTED"
  | "DELIVERY_STREAM_FAILED"
  | "DELIVERY_TIMEOUT";

export type ProcessingFailure =
  | ProcessingFailureBase<"input", InputFailureCode>
  | ProcessingFailureBase<"archive", ArchiveFailureCode>
  | ProcessingFailureBase<"xml", XmlFailureCode>
  | ProcessingFailureBase<"repair", RepairFailureCode>
  | ProcessingFailureBase<"delivery_config", DeliveryConfigurationFailureCode>
  | ProcessingFailureBase<"delivery_transport", DeliveryTransportFailureCode>
  | ProcessingFailureBase<"cancelled", "OPERATION_CANCELLED">
  | ProcessingFailureBase<"internal", "INTERNAL_FAILURE">;
