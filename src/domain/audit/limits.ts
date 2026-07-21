export const ARCHIVE_LIMITS = {
  maxSourceBytes: 200_000_000,
  maxEntryCount: 10_000,
  maxExpandedEntryBytes: 100_000_000,
  maxExpandedTotalBytes: 1_000_000_000,
  maxExpansionRatio: 100,
  maxOutputBytes: 200_000_000,
} as const;

export const XML_LIMITS = {
  maxBytes: 10_000_000,
  maxDepth: 64,
} as const;

export const OPERATION_LIMITS = {
  perFileTimeoutMs: 120_000,
  maxUiBlockMs: 1_000,
} as const;

export const DELIVERY_TIMEOUTS = {
  dnsMs: 10_000,
  connectionMs: 20_000,
  greetingMs: 20_000,
  socketMs: 120_000,
} as const;

export const SMTP_PORT_RANGE = { min: 1, max: 65_535 } as const;
export const SMTP_DEFAULT_PORTS = { implicitTls: 465, starttls: 587 } as const;
export const ZIP_COMPRESSION_METHODS = { store: 0, deflate: 8 } as const;
