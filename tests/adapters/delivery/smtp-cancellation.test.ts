import { beforeEach, describe, expect, it, vi } from "vitest";

import { basename } from "node:path";

import type { DeliveryConfiguration, DeliveryResult, DeliverySecret } from "../../../src/domain/models/delivery";
import type { ProcessingFailure } from "../../../src/domain/models/processing-failure";
import type { Result } from "../../../src/domain/models/result";
import type {
  SourceFingerprint,
  VerifiedReadDescriptor,
  VerifiedDescriptorId,
  SelectedEpub,
  SourceFingerprint as SourceFingerprintAlias,
} from "../../../src/domain/models/epub-document";
import { selectedEpub } from "../../fixtures/input/fixture-definitions";
import { nextEventLoopTurn } from "../../support/operation-harness";
import { withTestFilesystem } from "../../support/test-filesystem";

type ModuleExports = Record<string, unknown>;
type ModulePath = string;
type ModuleLoader = Promise<ModuleExports>;

type SubmitTransport = (
  source: {
    readonly source: SelectedEpub;
    readonly descriptor: VerifiedReadDescriptor;
    readonly reviewedFingerprint: SourceFingerprint;
  },
  configuration: DeliveryConfiguration,
  signal: AbortSignal,
  onProgress: (event: unknown) => void,
) => Promise<Result<DeliveryResult, ProcessingFailure>>;

const SMTP_PASSWORD = "smtp-app-password";
const configuration: DeliveryConfiguration = {
  senderAddress: "sender@example.com",
  smtpHost: "smtp.example.com",
  smtpPort: 465,
  securityMode: "implicit_tls",
  username: "smtp-user",
  appPassword: SMTP_PASSWORD as DeliverySecret,
  kindleAddress: "reader@kindle.com",
};

const SMTP_CLIENT_MODULE: ModulePath = "../../../src/adapters/delivery/smtp-client" as string;

const createTransport = vi.fn();
const sendMail = vi.fn();
const verify = vi.fn();
const close = vi.fn();

vi.mock("nodemailer", () => ({
  createTransport: (...args: unknown[]) => createTransport(...args),
}));

let smtpClientModule: ModuleLoader | undefined;

async function loadSmtpModule(): Promise<ModuleExports> {
  if (!smtpClientModule) {
    smtpClientModule = import(SMTP_CLIENT_MODULE as ModulePath).then((module) => module as ModuleExports);
  }
  return smtpClientModule;
}

async function resolveSubmitFunction(): Promise<SubmitTransport> {
  const module = await loadSmtpModule();
  const names = [
    "submit",
    "submitSmtp",
    "submitViaSmtp",
    "send",
    "sendEpub",
    "sendViaSmtp",
    "deliver",
    "deliverSource",
    "submitDelivery",
    "submitDeliverySource",
  ];

  const pick = (candidate: Record<string, unknown>): SubmitTransport | undefined => {
    for (const name of names) {
      const entry = candidate[name];
      if (typeof entry === "function") {
        return entry as SubmitTransport;
      }
    }
    return undefined;
  };

  const fromDefault = module.default;
  if (typeof fromDefault === "function") {
    return fromDefault as SubmitTransport;
  }
  if (fromDefault !== undefined && typeof fromDefault === "object" && fromDefault !== null) {
    const matched = pick(fromDefault as Record<string, unknown>);
    if (matched) return matched;
  }

  const direct = pick(module);
  if (direct) return direct;

  for (const value of Object.values(module)) {
    if (value !== null && typeof value === "object") {
      const matched = pick(value as Record<string, unknown>);
      if (matched) return matched;
    }
  }

  throw new Error("Could not resolve SMTP submit function in adapter module");
}

function setTransportMock(): void {
  sendMail.mockReset();
  createTransport.mockReset();
  verify.mockReset();
  close.mockReset();
  createTransport.mockReturnValue({ sendMail, verify, close });
  verify.mockResolvedValue(true);
}

function createSourceFingerprint(source: SelectedEpub): SourceFingerprint {
  return {
    identity: source.identity,
    sizeBytes: source.sizeBytes,
    modifiedAtMs: source.modifiedAtMs,
    sha256: `digest-${source.id}` as SourceFingerprintAlias["sha256"],
  };
}

function buildDeliverySource(sourcePath: string): {
  readonly source: SelectedEpub;
  readonly descriptor: VerifiedReadDescriptor;
  readonly reviewedFingerprint: SourceFingerprint;
} {
  const source = selectedEpub(sourcePath, basename(sourcePath), `delivery-${basename(sourcePath)}`);
  const descriptor: VerifiedReadDescriptor = {
    id: `verified:${source.id}` as VerifiedDescriptorId,
    sourceId: source.id,
    snapshot: {
      identity: source.identity,
      sizeBytes: source.sizeBytes,
      modifiedAtMs: source.modifiedAtMs,
    },
  };
  return {
    source,
    descriptor,
    reviewedFingerprint: createSourceFingerprint(source),
  };
}

async function submitDelivery(
  sourcePath: string,
  signal: AbortSignal,
): Promise<Result<DeliveryResult, ProcessingFailure>> {
  const source = buildDeliverySource(sourcePath);
  const submit = await resolveSubmitFunction();
  return (await submit(source, configuration, signal, () => undefined)) as Result<DeliveryResult, ProcessingFailure>;
}

function expectNoRetry(result: Result<DeliveryResult, ProcessingFailure>): void {
  expect(sendMail).toHaveBeenCalledTimes(1);
  if (!result.ok) {
    throw new Error("Expected adapter submission to return DeliveryResult");
  }
  if (
    result.value.status !== "failed" &&
    result.value.status !== "delivery_unknown" &&
    result.value.status !== "cancelled"
  ) {
    throw new Error("Expected failed, delivery_unknown, or cancelled status");
  }
}

describe("smtp cancellation", () => {
  beforeEach(() => {
    setTransportMock();
  });

  it("returns cancelled before connect and does not start SMTP transport", async () => {
    await withTestFilesystem(async (filesystem) => {
      const sourcePath = filesystem.path("books/cancel-before-connect.epub");
      await filesystem.write("books/cancel-before-connect.epub", "payload");

      sendMail.mockImplementation(async () => {
        throw new Error("sendMail should not run when aborted before connect");
      });

      const controller = new AbortController();
      controller.abort("user cancelled");

      const result = await submitDelivery(sourcePath, controller.signal);

      expect(createTransport).not.toHaveBeenCalled();
      expect(sendMail).not.toHaveBeenCalled();
      expect(result).toMatchObject({ ok: true, value: { status: "cancelled" } });
    });
  });

  it("returns delivery_unknown when cancellation interrupts transmission before definitive acceptance", async () => {
    await withTestFilesystem(async (filesystem) => {
      const sourcePath = filesystem.path("books/cancel-mid-flight.epub");
      await filesystem.write("books/cancel-mid-flight.epub", "payload");

      const controller = new AbortController();

      sendMail.mockImplementation(async () => {
        await nextEventLoopTurn();
        if (controller.signal.aborted) {
          const error = Object.assign(new Error("stream interrupted by cancellation"), {
            code: "ECONNRESET",
            command: "DATA",
          });
          throw error;
        }
        await nextEventLoopTurn();
        return {
          response: "250 OK",
          responseCode: 250,
        };
      });

      const submission = submitDelivery(sourcePath, controller.signal);
      await nextEventLoopTurn();
      controller.abort("user cancelled");

      const result = await submission;

      if (!result.ok) {
        throw new Error("Expected DeliveryResult, not Result error");
      }
      if (result.value.status !== "delivery_unknown") {
        throw new Error("Expected delivery_unknown from canceled in-flight transmission");
      }

      expect(result.value.manualRetryAllowed).toBe(true);
      expect(result.value.failureCategory).toBe("connection");
      expect(result.value.safeMessage).toBe("Submission could not be confirmed. The message may have been accepted.");
      expect(result.value.bytesStreamed).toBeGreaterThanOrEqual(0);
      expect(close).toHaveBeenCalled();
    });
  });

  it("keeps submitted status when DATA has already completed before cancellation", async () => {
    await withTestFilesystem(async (filesystem) => {
      const sourcePath = filesystem.path("books/cancel-after-data.epub");
      await filesystem.write("books/cancel-after-data.epub", "payload");

      const controller = new AbortController();
      let closeOnAbortDone = false;

      sendMail.mockImplementation(async () => {
        await nextEventLoopTurn();
        closeOnAbortDone = true;
        return {
          response: "250 OK",
          responseCode: 250,
        };
      });

      const submission = submitDelivery(sourcePath, controller.signal);
      await nextEventLoopTurn();
      controller.abort("user cancelled after data");

      const result = await submission;
      if (!result.ok) {
        throw new Error("Expected DeliveryResult, not Result error");
      }
      if (result.value.status !== "submitted") {
        throw new Error("Expected submitted status after DATA completion");
      }

      expect(closeOnAbortDone).toBe(true);
      expect(result.value.smtpResponseCode).toBe(250);
      expect(result.value.manualRetryAllowed).toBe(false);
    });
  });

  it("does not automatically retry after cancellation or transport exceptions", async () => {
    await withTestFilesystem(async (filesystem) => {
      const sourcePath = filesystem.path("books/no-retry-on-cancel.epub");
      await filesystem.write("books/no-retry-on-cancel.epub", "payload");

      const controller = new AbortController();
      sendMail.mockImplementation(async () => {
        await nextEventLoopTurn();
        const error = Object.assign(new Error("network interrupted"), {
          code: "ECONNRESET",
        });
        throw error;
      });

      const result = await submitDelivery(sourcePath, controller.signal);
      expect(result).toMatchObject({ ok: true });
      expectNoRetry(result);
      if (!result.ok) {
        throw new Error("Expected DeliveryResult, not Result error");
      }
      expect(result.value.manualRetryAllowed).toBe(true);
      expect(controller.signal.aborted).toBe(false);
    });
  });
});
