import { XML_LIMITS } from "../../../src/domain/audit/limits";

const encoder = new TextEncoder();

export function xmlBytes(value: string): Uint8Array {
  return encoder.encode(value);
}

export const rejectedXmlFixtures = [
  {
    name: "XML 1.1 declaration",
    bytes: xmlBytes('<?xml version="1.1"?><root/>'),
    code: "version_unsupported",
  },
  {
    name: "DOCTYPE declaration",
    bytes: xmlBytes('<!DOCTYPE root SYSTEM "https://example.invalid/book.dtd"><root/>'),
    code: "doctype_forbidden",
  },
  {
    name: "undeclared entity",
    bytes: xmlBytes("<root>&external;</root>"),
    code: "entity_forbidden",
  },
  {
    name: "invalid UTF-8",
    bytes: Uint8Array.from([
      0x3c, 0x72, 0x6f, 0x6f, 0x74, 0x3e, 0xc3, 0x28, 0x3c, 0x2f, 0x72, 0x6f, 0x6f, 0x74,
      0x3e,
    ]),
    code: "encoding_invalid",
  },
  {
    name: "unsupported declared encoding",
    bytes: xmlBytes('<?xml version="1.0" encoding="ISO-8859-1"?><root/>'),
    code: "encoding_invalid",
  },
  {
    name: "malformed recursive nesting",
    bytes: xmlBytes(`${"<n>".repeat(32)}</wrong>${"</n>".repeat(31)}`),
    code: "malformed",
  },
] as const;

export const recursiveEntityXml = xmlBytes(`<!DOCTYPE root [
  <!ENTITY loop "&loop;">
]><root>&loop;</root>`);

export const externalResolutionXml = [
  xmlBytes('<!DOCTYPE root SYSTEM "https://example.invalid/book.dtd"><root/>'),
  xmlBytes('<!DOCTYPE root SYSTEM "file:///etc/passwd"><root/>'),
] as const;

export const xmlSizeBoundaries = [
  { name: "immediately below", byteLength: XML_LIMITS.maxBytes - 1, accepted: true },
  { name: "at", byteLength: XML_LIMITS.maxBytes, accepted: true },
  { name: "immediately above", byteLength: XML_LIMITS.maxBytes + 1, accepted: false },
] as const;

export const xmlDepthBoundaries = [
  { name: "immediately below", depth: XML_LIMITS.maxDepth - 1, accepted: true },
  { name: "at", depth: XML_LIMITS.maxDepth, accepted: true },
  { name: "immediately above", depth: XML_LIMITS.maxDepth + 1, accepted: false },
] as const;

export function nestedXml(depth: number): Uint8Array {
  return xmlBytes(`${"<n>".repeat(depth)}${"</n>".repeat(depth)}`);
}

export async function* sizedXml(byteLength: number): AsyncIterable<Uint8Array> {
  const opening = xmlBytes("<root>");
  const closing = xmlBytes("</root>");
  const contentBytes = byteLength - opening.byteLength - closing.byteLength;
  if (contentBytes < 0) throw new RangeError("XML fixture is too small for its root element");

  yield opening;
  const chunk = new Uint8Array(64 * 1_024).fill(0x20);
  let remaining = contentBytes;
  while (remaining > 0) {
    const length = Math.min(remaining, chunk.byteLength);
    yield chunk.subarray(0, length);
    remaining -= length;
  }
  yield closing;
}

export function cancellableXml(controller: AbortController): AsyncIterable<Uint8Array> {
  return {
    async *[Symbol.asyncIterator]() {
      yield xmlBytes("<root>");
      controller.abort();
      yield xmlBytes("</root>");
    },
  };
}
