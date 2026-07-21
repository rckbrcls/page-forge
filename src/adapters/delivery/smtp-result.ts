import type { DeliveryFailureCategory } from "../../domain/models/delivery";

export interface SmtpFailureFacts {
  readonly code?: string;
  readonly command?: string;
  readonly response?: string;
}

const SAFE_MESSAGES: Readonly<Record<DeliveryFailureCategory, string>> = {
  authentication: "Authentication failed. Check the username and app password.",
  tls: "A secure connection could not be established.",
  dns: "The SMTP host could not be resolved.",
  connection: "The SMTP server could not be reached.",
  timeout: "The SMTP connection timed out before submission.",
  envelope: "The sender or Kindle address was rejected.",
  message: "The SMTP server rejected the message or attachment size.",
  stream: "The EPUB could not be read completely.",
  unknown: "The message could not be submitted.",
};

export const UNCONFIRMED_SUBMISSION_MESSAGE = "Submission could not be confirmed. The message may have been accepted.";

export function classifySmtpFailure({ code, command, response }: SmtpFailureFacts): DeliveryFailureCategory {
  if (code === "ENOTFOUND") return "dns";
  if (code === "EAUTH" || command === "AUTH") return "authentication";
  if (code === "EENVELOPE" || command === "MAIL" || command === "RCPT") return "envelope";
  if (code === "EMESSAGE") return "message";
  if (code?.startsWith("STREAM") || code === "ERR_STREAM_PREMATURE_CLOSE" || command === "STREAM") {
    return "stream";
  }
  if (code === "ESOCKET" || /certificate|tls|ssl|handshake/i.test(response ?? "")) return "tls";
  if (code === "ETIMEDOUT" || code === "ESOCKETTIMEDOUT") return "timeout";
  if (
    code === "ECONNREFUSED" ||
    code === "ECONNRESET" ||
    code === "ECONNABORTED" ||
    code === "EPIPE" ||
    code === "ENETUNREACH" ||
    code === "EHOSTUNREACH" ||
    code === "ENOTCONN"
  ) {
    return "connection";
  }
  return "unknown";
}

export function safeSmtpFailureMessage(category: DeliveryFailureCategory): string {
  return SAFE_MESSAGES[category];
}

export function deliveryMayBeUnknown(facts: SmtpFailureFacts, transmissionStarted: boolean): boolean {
  if (!transmissionStarted) return false;
  return (
    facts.command === "DATA" || facts.code === "ECONNRESET" || facts.code === "ETIMEDOUT" || facts.code === "ESOCKET"
  );
}
