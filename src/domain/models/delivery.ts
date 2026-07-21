import type { SelectedEpubId } from "./epub-document";

declare const deliverySecretBrand: unique symbol;

export type DeliverySecret = string & { readonly [deliverySecretBrand]: "DeliverySecret" };
export type DeliverySecurityMode = "implicit_tls" | "starttls";

export interface DeliveryConfiguration {
  readonly senderAddress: string;
  readonly smtpHost: string;
  readonly smtpPort: number;
  readonly securityMode: DeliverySecurityMode;
  readonly username: string;
  readonly appPassword: DeliverySecret;
  readonly kindleAddress: string;
}

export type DeliveryFailureCategory =
  "authentication" | "tls" | "dns" | "connection" | "timeout" | "envelope" | "message" | "stream" | "unknown";

interface DeliveryResultBase<S extends string, Retry extends boolean> {
  readonly status: S;
  readonly sourceId: SelectedEpubId;
  readonly displayName: string;
  readonly startedAtMs?: number;
  readonly endedAtMs: number;
  readonly bytesStreamed: number;
  readonly manualRetryAllowed: Retry;
}

export type DeliveryResult =
  | DeliveryResultBase<"not_started", false>
  | DeliveryResultBase<"cancelled", false>
  | (DeliveryResultBase<"submitted", false> & {
      readonly smtpResponseCode: number;
    })
  | (DeliveryResultBase<"failed", boolean> & {
      readonly failureCategory: DeliveryFailureCategory;
      readonly safeMessage: string;
      readonly smtpResponseCode?: number;
    })
  | (DeliveryResultBase<"delivery_unknown", true> & {
      readonly failureCategory: "connection" | "timeout" | "unknown";
      readonly safeMessage: string;
    });
