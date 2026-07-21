import { beforeEach, describe, expect, it, vi } from "vitest";

import { basename } from "node:path";

import type {
  DeliveryConfiguration,
  DeliveryFailureCategory,
  DeliveryResult,
  DeliverySecret,
} from "../../../src/domain/models/delivery";
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
import { withTestFilesystem } from "../../support/test-filesystem";

type ModuleExports = Record<string, unknown>;
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

type ModulePath = string;
type ModuleLoader = Promise<ModuleExports>;

type TransportError = Error & {
  readonly code?: string;
  readonly command?: string;
  readonly response?: string;
  readonly responseCode?: number;
};

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
  close.mockReset();
  verify.mockReset();
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

function smtpErrorFixture(overrides: Partial<TransportError>): TransportError {
  return Object.assign(new Error("SMTP transport rejected the request"), {
    code: "EUNSUPPORTED",
    response: "smtp.example.com 550 SMTP command failed",
    ...overrides,
  }) as TransportError;
}

async function submitDelivery(
  sourcePath: string,
  signal: AbortSignal,
): Promise<Result<DeliveryResult, ProcessingFailure>> {
  const source = buildDeliverySource(sourcePath);
  const submit = await resolveSubmitFunction();
  return (await submit(source, configuration, signal, () => undefined)) as Result<DeliveryResult, ProcessingFailure>;
}

function assertNoSensitiveLeaks(message: string, sourcePath: string): void {
  const leakedValues = [
    configuration.smtpHost,
    configuration.senderAddress,
    configuration.username,
    configuration.kindleAddress,
    SMTP_PASSWORD,
    sourcePath,
    basename(sourcePath),
  ];
  for (const value of leakedValues) {
    expect(message).not.toContain(value);
  }
}

function expectDeliveryFailure(
  outcome: DeliveryResult,
  category: DeliveryFailureCategory,
  safeMessage: string,
): asserts outcome is Extract<DeliveryResult, { readonly status: "failed" }> {
  expect(outcome.status).toBe("failed");
  expect(outcome).toMatchObject({
    status: "failed",
    failureCategory: category,
    safeMessage,
  });
}

describe("smtp error mapping", () => {
  beforeEach(() => {
    setTransportMock();
  });

  it("maps DNS failures to failure-safe dns outcomes", async () => {
    await withTestFilesystem(async (filesystem) => {
      const sourcePath = filesystem.path("books/dns.epub");
      await filesystem.write("books/dns.epub", "payload");

      sendMail.mockRejectedValue(
        smtpErrorFixture({
          code: "ENOTFOUND",
          message: `getaddrinfo ENOTFOUND ${configuration.smtpHost}`,
        }),
      );

      const result = await submitDelivery(sourcePath, new AbortController().signal);
      expect(result).toMatchObject({ ok: true });
      if (!result.ok) {
        return;
      }

      expectDeliveryFailure(result.value, "dns", "The SMTP host could not be resolved.");
      assertNoSensitiveLeaks(result.value.safeMessage, sourcePath);
    });
  });

  it("maps connection failures to failure-safe connection outcomes", async () => {
    await withTestFilesystem(async (filesystem) => {
      const sourcePath = filesystem.path("books/conn.epub");
      await filesystem.write("books/conn.epub", "payload");

      sendMail.mockRejectedValue(
        smtpErrorFixture({
          code: "ECONNREFUSED",
          message: `connect ECONNREFUSED ${configuration.smtpHost}:465`,
        }),
      );

      const result = await submitDelivery(sourcePath, new AbortController().signal);
      expect(result).toMatchObject({ ok: true });
      if (!result.ok) {
        return;
      }

      expectDeliveryFailure(result.value, "connection", "The SMTP server could not be reached.");
      assertNoSensitiveLeaks(result.value.safeMessage, sourcePath);
    });
  });

  it("maps TLS failures to failure-safe tls outcomes", async () => {
    await withTestFilesystem(async (filesystem) => {
      const sourcePath = filesystem.path("books/tls.epub");
      await filesystem.write("books/tls.epub", "payload");

      sendMail.mockRejectedValue(
        smtpErrorFixture({
          code: "ESOCKET",
          command: "CONN",
          message: "socket hang up while TLS negotiation",
          response: `error from ${configuration.smtpHost}: certificate verify failed`,
        }),
      );

      const result = await submitDelivery(sourcePath, new AbortController().signal);
      expect(result).toMatchObject({ ok: true });
      if (!result.ok) {
        return;
      }

      expectDeliveryFailure(result.value, "tls", "A secure connection could not be established.");
      assertNoSensitiveLeaks(result.value.safeMessage, sourcePath);
    });
  });

  it("maps authentication failures to failure-safe authentication outcomes", async () => {
    await withTestFilesystem(async (filesystem) => {
      const sourcePath = filesystem.path("books/auth.epub");
      await filesystem.write("books/auth.epub", "payload");

      sendMail.mockRejectedValue(
        smtpErrorFixture({
          code: "EAUTH",
          command: "AUTH",
          responseCode: 535,
          response: `535 5.7.8 Authentication failed for ${configuration.username}`,
        }),
      );

      const result = await submitDelivery(sourcePath, new AbortController().signal);
      expect(result).toMatchObject({ ok: true });
      if (!result.ok) {
        return;
      }

      expectDeliveryFailure(
        result.value,
        "authentication",
        "Authentication failed. Check the username and app password.",
      );
      assertNoSensitiveLeaks(result.value.safeMessage, sourcePath);
    });
  });

  it("maps sender/recipient envelope rejections to safe envelope outcomes", async () => {
    await withTestFilesystem(async (filesystem) => {
      const sourcePath = filesystem.path("books/envelope.epub");
      await filesystem.write("books/envelope.epub", "payload");

      sendMail.mockRejectedValue(
        smtpErrorFixture({
          code: "EENVELOPE",
          command: "MAIL",
          responseCode: 550,
          response: `550 ${configuration.kindleAddress} is not accepted`,
        }),
      );

      const result = await submitDelivery(sourcePath, new AbortController().signal);
      expect(result).toMatchObject({ ok: true });
      if (!result.ok) {
        return;
      }

      expectDeliveryFailure(result.value, "envelope", "The sender or Kindle address was rejected.");
      assertNoSensitiveLeaks(result.value.safeMessage, sourcePath);
    });
  });

  it("maps 5xx message/size rejection to safe message outcomes", async () => {
    await withTestFilesystem(async (filesystem) => {
      const sourcePath = filesystem.path("books/message.epub");
      await filesystem.write("books/message.epub", "payload");

      sendMail.mockRejectedValue(
        smtpErrorFixture({
          code: "EMESSAGE",
          command: "DATA",
          responseCode: 552,
          response: "552 Message size exceeds fixed limit",
        }),
      );

      const result = await submitDelivery(sourcePath, new AbortController().signal);
      expect(result).toMatchObject({ ok: true });
      if (!result.ok) {
        return;
      }

      expectDeliveryFailure(result.value, "message", "The SMTP server rejected the message or attachment size.");
      assertNoSensitiveLeaks(result.value.safeMessage, sourcePath);
    });
  });

  it("maps streaming interruption to safe stream outcomes", async () => {
    await withTestFilesystem(async (filesystem) => {
      const sourcePath = filesystem.path("books/stream.epub");
      await filesystem.write("books/stream.epub", "payload");

      sendMail.mockRejectedValue(
        smtpErrorFixture({
          code: "STREAM_READ_FAILURE",
          command: "DATA",
          response: `${sourcePath} read stream interrupted`,
        }),
      );

      const result = await submitDelivery(sourcePath, new AbortController().signal);
      expect(result).toMatchObject({ ok: true });
      if (!result.ok) {
        return;
      }

      expectDeliveryFailure(result.value, "stream", "The EPUB could not be read completely.");
      assertNoSensitiveLeaks(result.value.safeMessage, sourcePath);
    });
  });

  it("maps unknown transport errors to safe unknown outcomes with full redaction", async () => {
    await withTestFilesystem(async (filesystem) => {
      const sourcePath = filesystem.path("books/unknown.epub");
      await filesystem.write("books/unknown.epub", "payload");

      sendMail.mockRejectedValue(
        Object.assign(
          new Error(`Unexpected response from ${configuration.senderAddress}: ${configuration.smtpHost}/send`),
          {
            response: "502 Unsupported operation 550",
            code: "ERANDOM",
          },
        ),
      );

      const result = await submitDelivery(sourcePath, new AbortController().signal);
      expect(result).toMatchObject({ ok: true });
      if (!result.ok) {
        return;
      }

      expectDeliveryFailure(result.value, "unknown", "The message could not be submitted.");
      assertNoSensitiveLeaks(result.value.safeMessage, sourcePath);
    });
  });
});
