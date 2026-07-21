import type { InternalPath } from "../models/archive";

const MAX_XML_BYTES = 10_000_000;

export interface NormalizedInternalPathEntry {
  readonly path: InternalPath;
  readonly content: Uint8Array;
}

export function writeCanonicalMimetype(): Uint8Array {
  return Buffer.from("application/epub+zip", "ascii");
}

export function rebuildContainerForSingleOpf(packagePath: InternalPath): Uint8Array {
  const escapedPath = escapeXmlAttribute(packagePath, '"');
  const output = Buffer.from(
    `<?xml version="1.0" encoding="UTF-8"?>\n` +
      `<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">\n` +
      `  <rootfiles>\n` +
      `    <rootfile full-path="${escapedPath}" media-type="application/oebps-package+xml"/>\n` +
      `  </rootfiles>\n` +
      `</container>`,
    "utf8",
  );
  assertBounded(output);
  return output;
}

export function correctManifestMediaType(input: Uint8Array, manifestId: string, mediaType: string): Uint8Array {
  const text = decodeUtf8(input);
  const tags = startTags(text).filter(({ localName }) => localName === "item");
  const matches = tags.filter((tag) => attribute(tag, "id")?.decodedValue === manifestId);
  if (matches.length !== 1) throw new Error("The planned manifest item is not unique.");

  const mediaTypeAttribute = attribute(matches[0], "media-type");
  if (mediaTypeAttribute === undefined) throw new Error("The planned manifest item has no media-type.");
  if (mediaTypeAttribute.decodedValue === mediaType) return Buffer.from(input);
  return replaceRange(
    text,
    mediaTypeAttribute.valueStart,
    mediaTypeAttribute.valueEnd,
    escapeXmlAttribute(mediaType, mediaTypeAttribute.quote),
  );
}

export function correctUniqueReference(
  input: Uint8Array,
  originalReference: string,
  replacementReference: string,
): Uint8Array {
  const text = decodeUtf8(input);
  const references = startTags(text).flatMap(referenceAttributes);
  const originalMatches = references.filter(({ decodedValue }) => decodedValue === originalReference);
  if (originalMatches.length > 1) throw new Error("The planned XML reference is not unique.");
  if (originalMatches.length === 0) {
    const replacementMatches = references.filter(({ decodedValue }) => decodedValue === replacementReference);
    if (replacementMatches.length === 1) return Buffer.from(input);
    throw new Error("The planned XML reference was not found.");
  }

  const target = originalMatches[0];
  return replaceRange(text, target.valueStart, target.valueEnd, escapeXmlAttribute(replacementReference, target.quote));
}

export function normalizeEquivalentInternalPath(
  sourcePath: InternalPath,
  targetPath: InternalPath,
  content: Uint8Array,
): NormalizedInternalPathEntry {
  if (sourcePath === targetPath) throw new Error("Equivalent path repair requires distinct paths.");
  return { path: targetPath, content };
}

export function normalizeXmlEncoding(input: Uint8Array): Uint8Array {
  assertBounded(input);
  const { text } = decodeXml(input);
  const declaration = /^(\s*<\?xml\s[^?]*\bencoding\s*=\s*["'])([^"']+)(["'][^?]*\?>)/iu;
  const normalized = declaration.test(text) ? text.replace(declaration, "$1UTF-8$3") : text;
  const output = Buffer.from(normalized, "utf8");
  assertBounded(output);
  return output;
}

interface AttributeToken {
  readonly localName: string;
  readonly decodedValue: string;
  readonly quote: '"' | "'";
  readonly valueStart: number;
  readonly valueEnd: number;
}

interface StartTagToken {
  readonly localName: string;
  readonly attributes: readonly AttributeToken[];
}

function startTags(text: string): StartTagToken[] {
  const tags: StartTagToken[] = [];
  let cursor = 0;
  while (cursor < text.length) {
    const start = text.indexOf("<", cursor);
    if (start < 0) break;
    if (text.startsWith("<!--", start)) {
      const end = text.indexOf("-->", start + 4);
      cursor = end < 0 ? text.length : end + 3;
      continue;
    }
    if (text.startsWith("<![CDATA[", start)) {
      const end = text.indexOf("]]>", start + 9);
      cursor = end < 0 ? text.length : end + 3;
      continue;
    }
    if (text[start + 1] === "?" || text[start + 1] === "!" || text[start + 1] === "/") {
      const end = text.indexOf(">", start + 2);
      cursor = end < 0 ? text.length : end + 1;
      continue;
    }

    const end = tagEnd(text, start + 1);
    if (end < 0) throw new Error("The XML start tag is incomplete.");
    const body = text.slice(start + 1, end);
    const nameMatch = /^\s*([^\s/>]+)/u.exec(body);
    if (nameMatch !== null) {
      const name = nameMatch[1];
      const attributes: AttributeToken[] = [];
      const attributePattern = /([^\s=/>]+)\s*=\s*(["'])(.*?)\2/gu;
      attributePattern.lastIndex = nameMatch.index + nameMatch[0].length;
      for (let match = attributePattern.exec(body); match !== null; match = attributePattern.exec(body)) {
        const rawName = match[1];
        const rawValue = match[3];
        const valueOffset = match[0].indexOf(rawValue, match[0].indexOf(match[2]) + 1);
        const valueStart = start + 1 + match.index + valueOffset;
        attributes.push({
          localName: rawName.split(":").at(-1)!,
          decodedValue: decodeXmlEntities(rawValue),
          quote: match[2] as '"' | "'",
          valueStart,
          valueEnd: valueStart + rawValue.length,
        });
      }
      tags.push({ localName: name.split(":").at(-1)!, attributes });
    }
    cursor = end + 1;
  }
  return tags;
}

function tagEnd(text: string, start: number): number {
  let quote: '"' | "'" | undefined;
  for (let index = start; index < text.length; index += 1) {
    const character = text[index];
    if (quote !== undefined) {
      if (character === quote) quote = undefined;
    } else if (character === '"' || character === "'") {
      quote = character;
    } else if (character === ">") {
      return index;
    }
  }
  return -1;
}

function attribute(tag: StartTagToken, localName: string): AttributeToken | undefined {
  const matches = tag.attributes.filter((candidate) => candidate.localName === localName);
  if (matches.length > 1) throw new Error(`The XML attribute ${localName} is not unique.`);
  return matches[0];
}

function referenceAttributes(tag: StartTagToken): readonly AttributeToken[] {
  let names: readonly string[] = [];
  if (tag.localName === "a" || tag.localName === "link") names = ["href"];
  else if (["img", "source", "audio", "embed", "iframe", "script", "video"].includes(tag.localName)) {
    names = ["src"];
  } else if (tag.localName === "image") names = ["href", "src"];
  else if (tag.localName === "object") names = ["data"];
  return tag.attributes.filter(({ localName }) => names.includes(localName));
}

function decodeUtf8(input: Uint8Array): string {
  assertBounded(input);
  try {
    return new TextDecoder("utf-8", { fatal: true, ignoreBOM: true }).decode(input);
  } catch {
    throw new Error("The planned XML entry is not valid UTF-8.");
  }
}

function decodeXml(input: Uint8Array): { readonly text: string } {
  let encoding: "utf-8" | "utf-16le" | "utf-16be" = "utf-8";
  let offset = 0;
  if (input[0] === 0xff && input[1] === 0xfe) {
    encoding = "utf-16le";
    offset = 2;
  } else if (input[0] === 0xfe && input[1] === 0xff) {
    encoding = "utf-16be";
    offset = 2;
  } else if (input[0] === 0xef && input[1] === 0xbb && input[2] === 0xbf) {
    offset = 3;
  } else if (input[0] === 0x3c && input[1] === 0x00) {
    encoding = "utf-16le";
  } else if (input[0] === 0x00 && input[1] === 0x3c) {
    encoding = "utf-16be";
  }
  try {
    return { text: new TextDecoder(encoding, { fatal: true }).decode(input.subarray(offset)) };
  } catch {
    throw new Error("The planned XML entry has an unsupported encoding.");
  }
}

function replaceRange(text: string, start: number, end: number, replacement: string): Uint8Array {
  const output = Buffer.from(text.slice(0, start) + replacement + text.slice(end), "utf8");
  assertBounded(output);
  return output;
}

function escapeXmlAttribute(value: string, quote: '"' | "'"): string {
  void quote;
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
}

function decodeXmlEntities(value: string): string {
  return value.replace(/&(?:#x([0-9a-f]+)|#([0-9]+)|(amp|apos|gt|lt|quot));/giu, (_, hex, decimal, named) => {
    if (hex !== undefined) return String.fromCodePoint(Number.parseInt(hex, 16));
    if (decimal !== undefined) return String.fromCodePoint(Number.parseInt(decimal, 10));
    return ({ amp: "&", apos: "'", gt: ">", lt: "<", quot: '"' } as const)[
      named.toLowerCase() as "amp" | "apos" | "gt" | "lt" | "quot"
    ];
  });
}

function assertBounded(input: Uint8Array): void {
  if (input.byteLength > MAX_XML_BYTES) throw new RangeError("The XML byte limit was exceeded.");
}
