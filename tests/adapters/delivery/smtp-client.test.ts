import { beforeEach, describe, expect, it, vi } from "vitest";

import { basename } from "node:path";

import type { DeliveryConfiguration } from "../../../src/domain/models/delivery";
import type { DeliverySecret } from "../../../src/domain/models/delivery";
import type { DeliverySource } from "../../../src/application/ports";
import type { DeliveryResult } from "../../../src/domain/models/delivery";
import type { ProcessingFailure } from "../../../src/domain/models/processing-failure";
import type { Result } from "../../../src/domain/models/result";
import type {
  SourceFingerprint,
  VerifiedDescriptorId,
  VerifiedReadDescriptor,
  Sha256Digest,
} from "../../../src/domain/models/epub-document";
import { selectedEpub } from "../../fixtures/input/fixture-definitions";
import { withTestFilesystem } from "../../support/test-filesystem";

type ModuleExports = Record<string, unknown>;
type ModulePath = string;
type ModuleLoader = Promise<ModuleExports>;
type SubmitTransport = (
  source: DeliverySource,
  configuration: DeliveryConfiguration,
  signal: AbortSignal,
  onProgress: (event: unknown) => void,
) => Promise<Result<DeliveryResult, ProcessingFailure>>;

const SMTP_CLIENT_MODULE: ModulePath = "../../../src/adapters/delivery/smtp-client" as string;

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

  const defaultExport = module.default;
  if (typeof defaultExport === "function") {
    return defaultExport as SubmitTransport;
  }
  if (defaultExport !== undefined && typeof defaultExport === "object" && defaultExport !== null) {
    const matched = pick(defaultExport as Record<string, unknown>);
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

interface SendMailMessage {
  readonly from?: string;
  readonly to?: string;
  readonly subject?: string;
  readonly text?: string;
  readonly html?: string;
  readonly attachments?: ReadonlyArray<Record<string, unknown>>;
}

const SMTP_HOST = "smtp.example.com";
const SMTP_PASSWORD = "smtp-app-password";

const configuration: DeliveryConfiguration = {
  senderAddress: "sender@example.com",
  smtpHost: SMTP_HOST,
  smtpPort: 465,
  securityMode: "implicit_tls",
  username: "smtp-user",
  appPassword: SMTP_PASSWORD as DeliverySecret,
  kindleAddress: "reader@kindle.com",
};

function hasAsyncIterator(value: unknown): value is AsyncIterable<unknown> {
  return Boolean(value && typeof value === "object" && Symbol.asyncIterator in value);
}

const createTransport = vi.fn();
const sendMail = vi.fn();
const verify = vi.fn();
const close = vi.fn();

vi.mock("nodemailer", () => ({
  createTransport: (...args: unknown[]) => createTransport(...args),
}));

function setTransportMock() {
  sendMail.mockReset();
  createTransport.mockReset();
  createTransport.mockReturnValue({
    sendMail,
    verify,
    close,
  });
  verify.mockReset();
  close.mockReset();
}

function buildDeliverySource(sourcePath: string): DeliverySource {
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
  const reviewedFingerprint: SourceFingerprint = {
    identity: source.identity,
    sizeBytes: source.sizeBytes,
    modifiedAtMs: source.modifiedAtMs,
    sha256: `digest-${source.id}` as Sha256Digest,
  };

  return {
    source,
    descriptor,
    reviewedFingerprint,
  };
}

describe("smtp client contract", () => {
  async function submitDelivery(
    source: DeliverySource,
    signal = new AbortController().signal,
  ): Promise<Result<DeliveryResult, ProcessingFailure>> {
    const submit = await resolveSubmitFunction();
    return (await submit(source, configuration, signal, () => undefined)) as Result<DeliveryResult, ProcessingFailure>;
  }

  beforeEach(() => {
    setTransportMock();
    verify.mockReset();
    verify.mockResolvedValue(true);
  });

  it("sends one streamed EPUB attachment with fixed envelope, minimal body, and stream/file safeguards", async () => {
    await withTestFilesystem(async (filesystem) => {
      const sourcePath = filesystem.path("inputs/Kindle/Example Book.epub");
      await filesystem.write("inputs/Kindle/Example Book.epub", "fake epub bytes");
      const source = buildDeliverySource(sourcePath);
      let message: SendMailMessage | undefined;

      sendMail.mockImplementation(async (mail: SendMailMessage) => {
        message = mail;
        return {
          response: "250 OK",
          responseCode: 250,
        };
      });

      const result = await submitDelivery(source);

      expect(result).toMatchObject({ ok: true });
      if (!result.ok) {
        throw new Error("Expected SMTP submission to succeed in contract test");
      }
      expect(result.value.status).toBe("submitted");

      const transportOptions = createTransport.mock.calls.at(0)?.[0] as {
        readonly disableFileAccess?: boolean;
        readonly disableUrlAccess?: boolean;
      };
      expect(transportOptions?.disableFileAccess).toBe(true);
      expect(transportOptions?.disableUrlAccess).toBe(true);

      expect(message).toBeDefined();
      expect(String(message?.from ?? "")).toContain(configuration.senderAddress);
      expect(String(message?.to ?? "")).toContain(configuration.kindleAddress);
      expect([message?.subject, message?.text, message?.html]).toSatisfy((values: readonly unknown[]) =>
        values.some((value) => value === undefined || value === "" || String(value).includes("Page Forge")),
      );

      const attachments = message?.attachments;
      expect(Array.isArray(attachments)).toBe(true);
      expect(attachments).toHaveLength(1);

      const attachment = attachments?.[0];
      expect(String(attachment?.filename ?? "")).toBe("Example Book.epub");
      expect(attachment?.contentType).toBe("application/epub+zip");
      expect(attachment?.path).toBeUndefined();
      expect(attachment?.href).toBeUndefined();
      expect(hasAsyncIterator(attachment?.content)).toBe(true);

      const messageFields = JSON.stringify([
        message?.from,
        message?.to,
        message?.subject,
        message?.text,
        message?.html,
      ]);
      expect(messageFields).not.toContain(sourcePath);
    });
  });
});
