import { createReadStream } from "node:fs";
import { basename } from "node:path";
import type { Readable } from "node:stream";
import { createTransport } from "nodemailer";

import type { DeliveryConfiguration, DeliveryResult, DeliveryFailureCategory } from "../../domain/models/delivery";
import type { DeliverySource } from "../../application/ports";
import type { ProcessingFailure } from "../../domain/models/processing-failure";
import type { Result } from "../../domain/models/result";
import { ok } from "../../domain/models/result";
import type { ProgressListener } from "../../application/progress";
import { buildSmtpTransportOptions } from "../raycast/delivery-preferences";
import {
  classifySmtpFailure,
  deliveryMayBeUnknown,
  safeSmtpFailureMessage,
  UNCONFIRMED_SUBMISSION_MESSAGE,
} from "./smtp-result";

type SubmitResult = Promise<Result<DeliveryResult, ProcessingFailure>>;

interface StreamableAttachment {
  readonly filename: string;
  readonly contentType: string;
  readonly content: Readable;
}

interface MessageOptions {
  readonly from: string;
  readonly to: string;
  readonly subject: string;
  readonly text: string;
  readonly attachments: readonly StreamableAttachment[];
}

interface SendOutcome {
  readonly responseCode?: number;
}

interface SmtpTransport {
  readonly sendMail: (options: MessageOptions) => Promise<SendOutcome>;
  readonly verify: () => Promise<void | boolean>;
  readonly close: () => void | Promise<void>;
}

type TransportError = Error & {
  readonly code?: string;
  readonly command?: string;
  readonly response?: string;
  readonly responseCode?: number;
};

const transportError = (error: unknown): TransportError => {
  if (error instanceof Error) {
    return error as TransportError;
  }
  return Object.assign(new Error("SMTP transport failed"), { code: "unknown" }) as TransportError;
};

const nowMs = (): number => Date.now();

type DeliverResultByStatus<T extends DeliveryResult["status"]> = Extract<DeliveryResult, { readonly status: T }>;

type DeliveryUnknownCategory = Extract<DeliveryResult, { readonly status: "delivery_unknown" }>["failureCategory"];

function nowRange(startedAtMs: number): {
  readonly startedAtMs: number;
  readonly endedAtMs: number;
} {
  return { startedAtMs, endedAtMs: nowMs() };
}

function cancelledResult(
  source: DeliverySource,
  startedAtMs: number,
  bytesStreamed: number,
): DeliverResultByStatus<"cancelled"> {
  const timestamps = nowRange(startedAtMs);
  return {
    status: "cancelled",
    sourceId: source.source.id,
    displayName: source.source.displayName,
    bytesStreamed,
    manualRetryAllowed: false,
    ...timestamps,
  };
}

function submittedResult(
  source: DeliverySource,
  startedAtMs: number,
  bytesStreamed: number,
  responseCode: number,
): DeliverResultByStatus<"submitted"> {
  const timestamps = nowRange(startedAtMs);
  return {
    status: "submitted",
    sourceId: source.source.id,
    displayName: source.source.displayName,
    bytesStreamed,
    manualRetryAllowed: false,
    smtpResponseCode: responseCode,
    ...timestamps,
  };
}

function failedResult(
  source: DeliverySource,
  startedAtMs: number,
  bytesStreamed: number,
  failureCategory: DeliveryFailureCategory,
  safeMessage: string,
  responseCode?: number,
): DeliverResultByStatus<"failed"> {
  const timestamps = nowRange(startedAtMs);
  return {
    status: "failed",
    sourceId: source.source.id,
    displayName: source.source.displayName,
    bytesStreamed,
    manualRetryAllowed: true,
    failureCategory,
    safeMessage,
    smtpResponseCode: responseCode,
    ...timestamps,
  };
}

function deliveryUnknownResult(
  source: DeliverySource,
  startedAtMs: number,
  bytesStreamed: number,
  failureCategory: DeliveryUnknownCategory,
  safeMessage: string,
): DeliverResultByStatus<"delivery_unknown"> {
  const timestamps = nowRange(startedAtMs);
  return {
    status: "delivery_unknown",
    sourceId: source.source.id,
    displayName: source.source.displayName,
    bytesStreamed,
    manualRetryAllowed: true,
    failureCategory,
    safeMessage,
    ...timestamps,
  };
}

async function closeTransport(transport: SmtpTransport | undefined): Promise<void> {
  if (!transport) return;
  try {
    await transport.close();
  } catch {
    // best-effort transport close
  }
}

export async function submit(
  source: DeliverySource,
  configuration: DeliveryConfiguration,
  signal: AbortSignal,
  onProgress: ProgressListener,
): SubmitResult {
  void onProgress;
  if (signal.aborted) {
    const startedAtMs = nowMs();
    return Promise.resolve(ok(cancelledResult(source, startedAtMs, 0)));
  }

  const bytesStreamed = source.source.sizeBytes;
  const attachment = basename(source.source.sourcePath);
  const nowStarted = nowMs();

  const transportOptions = {
    ...buildSmtpTransportOptions(configuration),
    debug: false,
    logger: false,
    connectionTimeout: 20_000,
    greetingTimeout: 20_000,
    socketTimeout: 120_000,
    disableFileAccess: true,
    disableUrlAccess: true,
  };

  let transport: SmtpTransport | undefined;
  let attachmentStream: Readable | undefined;
  let sendStarted = false;

  signal.addEventListener(
    "abort",
    () => {
      attachmentStream?.destroy();
      void closeTransport(transport);
    },
    { once: true },
  );

  try {
    transport = createTransport(transportOptions) as unknown as SmtpTransport;
    attachmentStream = createReadStream(source.source.sourcePath);
    const mail: MessageOptions = {
      from: configuration.senderAddress,
      to: configuration.kindleAddress,
      subject: "Page Forge",
      text: "Page Forge",
      attachments: [
        {
          filename: attachment,
          contentType: "application/epub+zip",
          content: attachmentStream,
        },
      ],
    };

    await transport.verify();

    if (signal.aborted) {
      return ok(cancelledResult(source, nowStarted, 0));
    }

    sendStarted = true;
    const response = await transport.sendMail(mail);
    return ok(submittedResult(source, nowStarted, bytesStreamed, response.responseCode ?? 0));
  } catch (error) {
    const transportFailure = transportError(error);
    const code = transportFailure.code;
    const command = transportFailure.command;
    const response = transportFailure.response;
    const responseCode = transportFailure.responseCode;

    if (signal.aborted && !sendStarted) {
      return ok(cancelledResult(source, nowStarted, 0));
    }

    if (signal.aborted && deliveryMayBeUnknown({ code, command, response }, sendStarted)) {
      return ok(deliveryUnknownResult(source, nowStarted, bytesStreamed, "connection", UNCONFIRMED_SUBMISSION_MESSAGE));
    }

    const failureCategory = classifySmtpFailure({ code, command, response });

    return ok(
      failedResult(
        source,
        nowStarted,
        bytesStreamed,
        failureCategory,
        safeSmtpFailureMessage(failureCategory),
        responseCode,
      ),
    );
  } finally {
    try {
      attachmentStream?.destroy();
    } catch {
      // ignore stream-close failures
    }
    await closeTransport(transport);
  }
}

export default submit;
