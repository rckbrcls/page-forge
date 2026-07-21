import { describe, expect, it } from "vitest";

import type { DeliveryConfiguration } from "../../../src/domain/models/delivery";
import { SMTP_DEFAULT_PORTS, SMTP_PORT_RANGE } from "../../../src/domain/audit/limits";
import type { ProcessingFailure } from "../../../src/domain/models/processing-failure";
import type { Result } from "../../../src/domain/models/result";

type ModuleExports = Record<string, unknown>;
type RawDeliveryPreferences = Readonly<Record<string, string | undefined>>;
type ConfigurationResolver = (
  preferences: RawDeliveryPreferences,
) =>
  | Result<DeliveryConfiguration | undefined, ProcessingFailure>
  | Promise<Result<DeliveryConfiguration | undefined, ProcessingFailure>>;
type TransportOptionsResolver = (
  configuration: DeliveryConfiguration,
) => Record<string, unknown> | Promise<Record<string, unknown>>;

let deliveryModule: Promise<ModuleExports> | undefined;

async function loadDeliveryPreferencesModule(): Promise<ModuleExports> {
  if (!deliveryModule) {
    deliveryModule = import("../../../src/adapters/raycast/delivery-preferences").then(
      (module) => module as ModuleExports,
    );
  }
  return deliveryModule;
}

function resolveFunction<T>(source: ModuleExports, names: readonly string[], label: string): T {
  for (const name of names) {
    const candidate = source[name];
    if (typeof candidate === "function") return candidate as T;
  }
  throw new Error(`Expected ${label} in exports from src/adapters/raycast/delivery-preferences`);
}

async function resolveConfigurationResult(
  result:
    | Result<DeliveryConfiguration | undefined, ProcessingFailure>
    | Promise<Result<DeliveryConfiguration | undefined, ProcessingFailure>>,
): Promise<Result<DeliveryConfiguration | undefined, ProcessingFailure>> {
  return Promise.resolve(result);
}

function validPreferences(overrides: RawDeliveryPreferences = {}): RawDeliveryPreferences {
  return {
    senderAddress: "reader@example.com",
    smtpHost: "smtp.example.com",
    smtpPort: "",
    securityMode: "implicit_tls",
    username: "reader@example.com",
    appPassword: "secret-password",
    kindleAddress: "reader@kindle.com",
    ...overrides,
  };
}

function expectDeliveryConfigFailure(
  result: Result<DeliveryConfiguration | undefined, ProcessingFailure>,
  expectedCode = "DELIVERY_CONFIG_INVALID",
) {
  expect(result).toMatchObject({
    ok: false,
    failure: {
      category: "delivery_config",
      code: expectedCode,
    },
  });
}

async function resolveDeliveryFns() {
  const module = await loadDeliveryPreferencesModule();
  const resolveDeliveryConfiguration = resolveFunction<ConfigurationResolver>(
    module,
    [
      "loadDeliveryConfiguration",
      "resolveDeliveryConfiguration",
      "parseDeliveryConfiguration",
      "validateDeliveryConfiguration",
      "validateDeliveryPreferences",
      "resolveDeliveryPreferences",
    ],
    "a delivery configuration resolver",
  );
  const buildTransportOptions = resolveFunction<TransportOptionsResolver>(
    module,
    [
      "buildSmtpTransportOptions",
      "buildTransportOptions",
      "createTransportOptions",
      "createSmtpTransportOptions",
      "deliveryTransportOptions",
      "toSmtpTransportOptions",
      "toTransportOptions",
    ],
    "a transport options builder",
  );

  return { resolveDeliveryConfiguration, buildTransportOptions };
}

function extractTransportTls(options: Record<string, unknown>): { minVersion?: string; rejectUnauthorized?: boolean } {
  const value = options.tls;
  if (value === undefined || value === null || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  return value as { minVersion?: string; rejectUnauthorized?: boolean };
}

describe("delivery preferences", () => {
  it("loads empty values as optional configuration", async () => {
    const { resolveDeliveryConfiguration } = await resolveDeliveryFns();
    const result = await resolveConfigurationResult(resolveDeliveryConfiguration({}));

    expect(result).toMatchObject({ ok: true, value: undefined });
  });

  it("accepts exact `@kindle.com` addresses and rejects non-kindle destinations", async () => {
    const { resolveDeliveryConfiguration } = await resolveDeliveryFns();
    const resultOk = await resolveConfigurationResult(
      resolveDeliveryConfiguration(validPreferences({ kindleAddress: "reader@KINDLE.COM" })),
    );
    const resultInvalid = await resolveConfigurationResult(
      resolveDeliveryConfiguration(validPreferences({ kindleAddress: "reader@not-kindles.com" })),
    );

    expect(resultOk).toMatchObject({ ok: true, value: { kindleAddress: "reader@KINDLE.COM" } });
    expectDeliveryConfigFailure(resultInvalid);
  });

  it("rejects CR and LF in sender, host, username, and Kindle addresses", async () => {
    const { resolveDeliveryConfiguration } = await resolveDeliveryFns();
    const senderResult = await resolveConfigurationResult(
      resolveDeliveryConfiguration(validPreferences({ senderAddress: "a\r@example.com" })),
    );
    const hostResult = await resolveConfigurationResult(
      resolveDeliveryConfiguration(validPreferences({ smtpHost: "smtp\n.example.com" })),
    );
    const usernameResult = await resolveConfigurationResult(
      resolveDeliveryConfiguration(validPreferences({ username: "u\nser" })),
    );
    const kindleResult = await resolveConfigurationResult(
      resolveDeliveryConfiguration(validPreferences({ kindleAddress: "kindle\r@kindle.com" })),
    );

    expectDeliveryConfigFailure(senderResult);
    expectDeliveryConfigFailure(hostResult);
    expectDeliveryConfigFailure(usernameResult);
    expectDeliveryConfigFailure(kindleResult);
  });

  it("validates SMTP port bounds 1..65535", async () => {
    const { resolveDeliveryConfiguration } = await resolveDeliveryFns();
    const tooLow = await resolveConfigurationResult(resolveDeliveryConfiguration(validPreferences({ smtpPort: "0" })));
    const tooHigh = await resolveConfigurationResult(
      resolveDeliveryConfiguration(validPreferences({ smtpPort: "65536" })),
    );
    const validLow = await resolveConfigurationResult(
      resolveDeliveryConfiguration(validPreferences({ smtpPort: "1" })),
    );
    const validHigh = await resolveConfigurationResult(
      resolveDeliveryConfiguration(validPreferences({ smtpPort: "65535" })),
    );

    expectDeliveryConfigFailure(tooLow);
    expectDeliveryConfigFailure(tooHigh);
    expect(validLow).toMatchObject({ ok: true, value: { smtpPort: 1 } });
    expect(validHigh).toMatchObject({ ok: true, value: { smtpPort: SMTP_PORT_RANGE.max } });
  });

  it("applies implicit TLS defaults and marks secure transport", async () => {
    const { resolveDeliveryConfiguration, buildTransportOptions } = await resolveDeliveryFns();
    const configurationResult = await resolveConfigurationResult(resolveDeliveryConfiguration(validPreferences({})));

    if (!configurationResult.ok) {
      throw new Error(`Expected valid delivery preferences, got ${configurationResult.failure.code}`);
    }
    const configuration = configurationResult.value;
    if (configuration === undefined) {
      throw new Error("Expected delivery configuration when SMTP fields are set");
    }

    const transport = await Promise.resolve(buildTransportOptions(configuration));

    expect(configuration).toMatchObject({
      smtpPort: SMTP_DEFAULT_PORTS.implicitTls,
      securityMode: "implicit_tls",
    });
    expect(transport).toMatchObject({ secure: true });
    expect(transport.secure).toBe(true);
    expect(transport.requireTLS).not.toBe(true);
    expect(transport.ignoreTLS).not.toBe(true);
  });

  it("requires STARTTLS and requires transport upgrade", async () => {
    const { resolveDeliveryConfiguration, buildTransportOptions } = await resolveDeliveryFns();
    const configurationResult = await resolveConfigurationResult(
      resolveDeliveryConfiguration(validPreferences({ securityMode: "starttls", smtpPort: "" })),
    );

    if (!configurationResult.ok) {
      throw new Error(`Expected valid delivery preferences, got ${configurationResult.failure.code}`);
    }
    if (configurationResult.value === undefined) {
      throw new Error("Expected delivery configuration when securityMode is set");
    }

    const transport = await Promise.resolve(buildTransportOptions(configurationResult.value));

    expect(configurationResult.value).toMatchObject({
      securityMode: "starttls",
      smtpPort: SMTP_DEFAULT_PORTS.starttls,
    });
    expect(transport).toMatchObject({
      secure: false,
      requireTLS: true,
    });
  });

  it("enforces TLS 1.2 minimum and does not disable certificate checks", async () => {
    const { resolveDeliveryConfiguration, buildTransportOptions } = await resolveDeliveryFns();
    const configurationResult = await resolveConfigurationResult(
      resolveDeliveryConfiguration(validPreferences({ securityMode: "starttls", smtpPort: "" })),
    );

    if (!configurationResult.ok) {
      throw new Error(`Expected valid delivery preferences, got ${configurationResult.failure.code}`);
    }
    if (configurationResult.value === undefined) {
      throw new Error("Expected delivery configuration when securityMode is set");
    }

    const transport = await Promise.resolve(buildTransportOptions(configurationResult.value));
    const tls = extractTransportTls(transport);

    expect(tls.minVersion).toBe("TLSv1.2");
    expect(tls.rejectUnauthorized).not.toBe(false);
  });

  it("rejects plaintext/unsafe modes and avoids explicit TLS downgrade options", async () => {
    const { resolveDeliveryConfiguration, buildTransportOptions } = await resolveDeliveryFns();
    const invalidMode = await resolveConfigurationResult(
      resolveDeliveryConfiguration(validPreferences({ securityMode: "plaintext" as unknown as string })),
    );
    expectDeliveryConfigFailure(invalidMode);

    const configurationResult = await resolveConfigurationResult(
      resolveDeliveryConfiguration(validPreferences({ securityMode: "starttls", smtpPort: "" })),
    );
    if (!configurationResult.ok || configurationResult.value === undefined) {
      throw new Error("Expected valid delivery configuration for STARTTLS");
    }
    const transport = await Promise.resolve(buildTransportOptions(configurationResult.value));

    expect(transport.ignoreTLS).not.toBe(true);
    expect(extractTransportTls(transport).minVersion).toBe("TLSv1.2");
  });

  it("preserves app password as a non-empty secret value", async () => {
    const { resolveDeliveryConfiguration } = await resolveDeliveryFns();
    const result = await resolveConfigurationResult(
      resolveDeliveryConfiguration(validPreferences({ appPassword: "app-pass-123" })),
    );

    expect(result).toMatchObject({
      ok: true,
      value: {
        senderAddress: "reader@example.com",
        smtpHost: "smtp.example.com",
        smtpPort: SMTP_DEFAULT_PORTS.implicitTls,
        securityMode: "implicit_tls",
        username: "reader@example.com",
        kindleAddress: "reader@kindle.com",
        appPassword: "app-pass-123",
      },
    });
  });
});
