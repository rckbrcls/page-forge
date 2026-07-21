import { SaxesParser, type SaxesAttributeNS, type SaxesTagNS } from "saxes";

export type XmlByteSource = Uint8Array | AsyncIterable<Uint8Array>;

export interface SafeXmlLimits {
  readonly maxBytes: number;
  readonly maxDepth?: number;
}

export interface XmlLocation {
  readonly line: number;
  readonly column: number;
}

export interface XmlExpandedName {
  readonly uri: string;
  readonly local: string;
  readonly prefix: string;
}

export interface XmlAttribute extends XmlExpandedName {
  readonly name: string;
  readonly value: string;
}

export interface XmlOpenElement extends XmlExpandedName {
  readonly name: string;
  readonly attributes: readonly XmlAttribute[];
  readonly selfClosing: boolean;
  readonly depth: number;
  readonly location: XmlLocation;
}

export interface XmlCloseElement extends XmlExpandedName {
  readonly name: string;
  readonly depth: number;
  readonly location: XmlLocation;
}

export interface SafeXmlHandlers {
  readonly onOpenElement?: (element: XmlOpenElement) => void;
  readonly onText?: (text: string, location: XmlLocation) => void;
  readonly onCloseElement?: (element: XmlCloseElement) => void;
}

export type SafeXmlErrorCode =
  | "encoding_invalid"
  | "too_large"
  | "too_deep"
  | "version_unsupported"
  | "doctype_forbidden"
  | "entity_forbidden"
  | "malformed"
  | "cancelled";

export class SafeXmlError extends Error {
  readonly code: SafeXmlErrorCode;
  readonly location?: XmlLocation;

  constructor(code: SafeXmlErrorCode, message: string, location?: XmlLocation) {
    super(message);
    this.name = "SafeXmlError";
    this.code = code;
    this.location = location;
  }
}

export interface ParsedXml {
  readonly encoding: "utf-8" | "utf-16le" | "utf-16be";
  readonly byteLength: number;
}

const DEFAULT_MAX_DEPTH = 64;
const XML_DECLARATION_ENCODING = /^\s*<\?xml\s[^?]*\bencoding\s*=\s*(["'])([^"']+)\1/i;

export async function parseSafeXml(
  source: XmlByteSource,
  limits: SafeXmlLimits,
  signal: AbortSignal,
  handlers: SafeXmlHandlers = {},
): Promise<ParsedXml> {
  const bytes = await readBoundedBytes(source, limits.maxBytes, signal);
  const { encoding, text } = decodeXml(bytes);
  validateDeclaredEncoding(text, encoding);

  const parser = new SaxesParser<{ xmlns: true }>({ xmlns: true });
  const maxDepth = limits.maxDepth ?? DEFAULT_MAX_DEPTH;
  let depth = 0;

  parser.on("xmldecl", (declaration) => {
    if (declaration.version !== undefined && declaration.version !== "1.0") {
      throw xmlError(parser, "version_unsupported", "Only XML 1.0 is supported.");
    }
  });
  parser.on("doctype", () => {
    throw xmlError(parser, "doctype_forbidden", "DOCTYPE declarations are not supported.");
  });
  parser.on("opentag", (tag) => {
    depth += 1;
    if (depth > maxDepth) {
      throw xmlError(parser, "too_deep", "The XML nesting limit was exceeded.");
    }
    handlers.onOpenElement?.(openElement(tag, depth, location(parser)));
  });
  parser.on("text", (textValue) => handlers.onText?.(textValue, location(parser)));
  parser.on("cdata", (textValue) => handlers.onText?.(textValue, location(parser)));
  parser.on("closetag", (tag) => {
    handlers.onCloseElement?.({
      name: tag.name,
      uri: tag.uri,
      local: tag.local,
      prefix: tag.prefix,
      depth,
      location: location(parser),
    });
    depth -= 1;
  });
  parser.on("error", (error) => {
    const code = /entity/i.test(error.message) ? "entity_forbidden" : "malformed";
    throw xmlError(parser, code, "The XML document is malformed.");
  });

  throwIfAborted(signal);
  try {
    parser.write(text).close();
  } catch (error) {
    if (error instanceof SafeXmlError) throw error;
    throw new SafeXmlError("malformed", "The XML document is malformed.", location(parser));
  }
  throwIfAborted(signal);

  return { encoding, byteLength: bytes.byteLength };
}

async function readBoundedBytes(source: XmlByteSource, maxBytes: number, signal: AbortSignal): Promise<Uint8Array> {
  if (!Number.isSafeInteger(maxBytes) || maxBytes < 0) {
    throw new RangeError("maxBytes must be a non-negative safe integer.");
  }
  if (source instanceof Uint8Array) {
    throwIfAborted(signal);
    if (source.byteLength > maxBytes) {
      throw new SafeXmlError("too_large", "The XML byte limit was exceeded.");
    }
    return source;
  }

  const chunks: Uint8Array[] = [];
  let byteLength = 0;
  for await (const chunk of source) {
    throwIfAborted(signal);
    byteLength += chunk.byteLength;
    if (byteLength > maxBytes) {
      throw new SafeXmlError("too_large", "The XML byte limit was exceeded.");
    }
    chunks.push(chunk);
    await Promise.resolve();
  }

  const bytes = new Uint8Array(byteLength);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return bytes;
}

function decodeXml(bytes: Uint8Array): {
  readonly encoding: ParsedXml["encoding"];
  readonly text: string;
} {
  let encoding: ParsedXml["encoding"] = "utf-8";
  let offset = 0;

  if (startsWith(bytes, [0xef, 0xbb, 0xbf])) {
    offset = 3;
  } else if (startsWith(bytes, [0xff, 0xfe])) {
    encoding = "utf-16le";
    offset = 2;
  } else if (startsWith(bytes, [0xfe, 0xff])) {
    encoding = "utf-16be";
    offset = 2;
  } else if (startsWith(bytes, [0x3c, 0x00])) {
    encoding = "utf-16le";
  } else if (startsWith(bytes, [0x00, 0x3c])) {
    encoding = "utf-16be";
  }

  try {
    return {
      encoding,
      text: new TextDecoder(encoding, { fatal: true }).decode(bytes.subarray(offset)),
    };
  } catch {
    throw new SafeXmlError("encoding_invalid", "The XML encoding is invalid.");
  }
}

function validateDeclaredEncoding(text: string, actual: ParsedXml["encoding"]): void {
  const declared = XML_DECLARATION_ENCODING.exec(text)?.[2]?.toLowerCase();
  if (declared === undefined) return;

  const accepted =
    actual === "utf-8" ? declared === "utf-8" || declared === "utf8" : declared === "utf-16" || declared === actual;
  if (!accepted) {
    throw new SafeXmlError("encoding_invalid", "The XML declaration does not match its bytes.");
  }
}

function openElement(tag: SaxesTagNS, depth: number, at: XmlLocation): XmlOpenElement {
  return {
    name: tag.name,
    uri: tag.uri,
    local: tag.local,
    prefix: tag.prefix,
    attributes: Object.values(tag.attributes).map(attribute),
    selfClosing: tag.isSelfClosing,
    depth,
    location: at,
  };
}

function attribute(value: SaxesAttributeNS): XmlAttribute {
  return {
    name: value.name,
    uri: value.uri,
    local: value.local,
    prefix: value.prefix,
    value: value.value,
  };
}

function location(parser: SaxesParser<{ xmlns: true }>): XmlLocation {
  return { line: parser.line, column: parser.column };
}

function xmlError(parser: SaxesParser<{ xmlns: true }>, code: SafeXmlErrorCode, message: string): SafeXmlError {
  return new SafeXmlError(code, message, location(parser));
}

function startsWith(bytes: Uint8Array, prefix: readonly number[]): boolean {
  return prefix.every((value, index) => bytes[index] === value);
}

function throwIfAborted(signal: AbortSignal): void {
  if (signal.aborted) {
    throw new SafeXmlError("cancelled", "XML parsing was cancelled.");
  }
}
