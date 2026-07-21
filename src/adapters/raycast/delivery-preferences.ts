import type { DeliveryConfiguration, DeliverySecret, DeliverySecurityMode } from "../../domain/models/delivery";
import type { DeliveryConfigurationFailureCode } from "../../domain/models/processing-failure";
import type { Result } from "../../domain/models/result";
import type { ProcessingFailure } from "../../domain/models/processing-failure";
import { err, ok } from "../../domain/models/result";
import { SMTP_DEFAULT_PORTS, SMTP_PORT_RANGE } from "../../domain/audit/limits";

export type RawDeliveryPreferences = Readonly<Record<string, string | undefined>>;

type DeliveryPreferencesFailureCode = DeliveryConfigurationFailureCode;

export function loadDeliveryConfiguration(
  preferences: RawDeliveryPreferences,
): Result<DeliveryConfiguration | undefined, ProcessingFailure> {
  return resolveDeliveryConfiguration(preferences);
}

export function resolveDeliveryConfiguration(
  preferences: RawDeliveryPreferences,
): Result<DeliveryConfiguration | undefined, ProcessingFailure> {
  return parseDeliveryConfiguration(preferences);
}

export function parseDeliveryConfiguration(
  preferences: RawDeliveryPreferences,
): Result<DeliveryConfiguration | undefined, ProcessingFailure> {
  const smtpPort = sanitize(preferences.smtpPort);
  const senderAddress = sanitize(preferences.senderAddress);
  const smtpHost = sanitize(preferences.smtpHost);
  const securityModeRaw = sanitize(preferences.securityMode);
  const username = sanitize(preferences.username);
  const appPassword = sanitize(preferences.appPassword);
  const kindleAddress = sanitize(preferences.kindleAddress);

  const hasValue = [smtpPort, senderAddress, smtpHost, username, appPassword, kindleAddress].some(
    (value) => value !== undefined,
  );
  if (!hasValue) return ok(undefined);

  const mode = resolveSecurityMode(securityModeRaw);
  if (mode === undefined) {
    return validationFailure("DELIVERY_CONFIG_INVALID", "Only implicit_tls and starttls are supported.");
  }

  if (
    senderAddress === undefined ||
    smtpHost === undefined ||
    username === undefined ||
    appPassword === undefined ||
    kindleAddress === undefined
  ) {
    return missingFailure("SMTP settings are incomplete.");
  }

  if (!isValidEmail(senderAddress)) {
    return validationFailure("DELIVERY_CONFIG_INVALID", "Sender address is not valid.");
  }
  if (!hasNoControl(smtpHost)) {
    return validationFailure("DELIVERY_CONFIG_INVALID", "SMTP host is not valid.");
  }
  if (smtpHost.trim().length === 0) {
    return missingFailure("SMTP host is required.");
  }
  if (!isSafeText(username)) {
    return validationFailure("DELIVERY_CONFIG_INVALID", "Username is not valid.");
  }
  if (username.trim().length === 0) {
    return missingFailure("SMTP username is required.");
  }
  if (!hasNoControl(appPassword) || appPassword.trim().length === 0) {
    return validationFailure("DELIVERY_CONFIG_INVALID", "App password is required.");
  }
  if (!isKindleAddress(kindleAddress)) {
    return validationFailure("DELIVERY_CONFIG_INVALID", "Kindle address must end with @kindle.com.");
  }

  const portValue = smtpPort !== undefined ? parseSmtpPort(smtpPort) : defaultPortFor(mode);
  if (typeof portValue !== "number") {
    return validationFailure(portValue.code, portValue.message);
  }

  const configuration: DeliveryConfiguration = {
    senderAddress,
    smtpHost,
    smtpPort: portValue,
    securityMode: mode,
    username,
    appPassword: appPassword as DeliverySecret,
    kindleAddress,
  };
  return ok(configuration);
}

export const validateDeliveryConfiguration = parseDeliveryConfiguration;
export const validateDeliveryPreferences = parseDeliveryConfiguration;
export const resolveDeliveryPreferences = parseDeliveryConfiguration;

export function parseSmtpPort(
  value: string,
):
  | number
  | { readonly code: "DELIVERY_CONFIG_INVALID"; readonly message: string }
  | { readonly code: "DELIVERY_CONFIG_MISSING"; readonly message: string } {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isSafeInteger(parsed) || String(parsed) !== value.trim()) {
    return { code: "DELIVERY_CONFIG_INVALID", message: "SMTP port must be an integer." };
  }
  if (parsed < SMTP_PORT_RANGE.min || parsed > SMTP_PORT_RANGE.max) {
    return { code: "DELIVERY_CONFIG_INVALID", message: "SMTP port is outside allowed bounds." };
  }
  return parsed;
}

export function validateAndBuildTransportOptions(configuration: DeliveryConfiguration): Record<string, unknown> {
  return {
    host: configuration.smtpHost,
    port: configuration.smtpPort,
    secure: configuration.securityMode === "implicit_tls",
    requireTLS: configuration.securityMode === "starttls",
    ignoreTLS: false,
    tls: {
      minVersion: "TLSv1.2",
      rejectUnauthorized: true,
    },
    auth: {
      user: configuration.username,
      pass: configuration.appPassword,
    },
    connectionTimeout: 20_000,
    greetingTimeout: 20_000,
  };
}

export const buildSmtpTransportOptions = validateAndBuildTransportOptions;
export const buildTransportOptions = validateAndBuildTransportOptions;
export const createTransportOptions = validateAndBuildTransportOptions;
export const createSmtpTransportOptions = validateAndBuildTransportOptions;
export const deliveryTransportOptions = validateAndBuildTransportOptions;
export const toSmtpTransportOptions = validateAndBuildTransportOptions;
export const toTransportOptions = validateAndBuildTransportOptions;

export const deliveryPreferences = {
  loadDeliveryConfiguration,
  resolveDeliveryConfiguration,
  parseDeliveryConfiguration,
  validateDeliveryConfiguration,
  validateDeliveryPreferences,
  resolveDeliveryPreferences,
  buildSmtpTransportOptions,
  buildTransportOptions,
  createTransportOptions,
  createSmtpTransportOptions,
  deliveryTransportOptions,
  toSmtpTransportOptions,
  toTransportOptions,
};

function validationFailure(
  code: DeliveryPreferencesFailureCode,
  safeMessage: string,
): Result<never, ProcessingFailure> {
  return err({
    category: "delivery_config",
    code,
    safeMessage,
    retryable: true,
    phase: "checking_delivery_eligibility",
  });
}

function missingFailure(safeMessage: string): Result<never, ProcessingFailure> {
  return err({
    category: "delivery_config",
    code: "DELIVERY_CONFIG_MISSING",
    safeMessage,
    retryable: true,
    phase: "checking_delivery_eligibility",
  });
}

function sanitize(value: string | undefined): string | undefined {
  if (value === undefined) return undefined;
  const trimmed = value.trim();
  if (trimmed.length === 0) return undefined;
  return trimmed;
}

function hasNoControl(value: string): boolean {
  return value.indexOf("\r") === -1 && value.indexOf("\n") === -1;
}

function isSafeText(value: string): boolean {
  return hasNoControl(value);
}

function isValidEmail(address: string): boolean {
  if (!hasNoControl(address)) return false;
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/u.test(address);
}

function isKindleAddress(address: string): boolean {
  return isValidEmail(address) && /@kindle\.com$/iu.test(address);
}

function resolveSecurityMode(value: string | undefined): DeliverySecurityMode | undefined {
  if (value === undefined) return "implicit_tls";
  const normalised = value.trim().toLocaleLowerCase("en-US");
  if (normalised === "implicit_tls" || normalised === "implicit tls") return "implicit_tls";
  if (normalised === "starttls") return "starttls";
  return undefined;
}

function defaultPortFor(mode: DeliverySecurityMode): number {
  if (mode === "starttls") return SMTP_DEFAULT_PORTS.starttls;
  return SMTP_DEFAULT_PORTS.implicitTls;
}
