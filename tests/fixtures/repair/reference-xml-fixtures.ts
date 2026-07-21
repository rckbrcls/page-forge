import { parseInternalPath } from "../../../src/domain/audit/internal-path";
import type { InternalPath } from "../../../src/domain/models/archive";
import {
  createImageFixture,
  createMinimalEpub,
} from "../../support/epub-fixture-factory";
import type { ZipFixtureEntry } from "../../support/fixture-builder";

export interface XmlReplacementFixture {
  readonly name: string;
  readonly epub: Uint8Array;
  readonly input: Uint8Array;
  readonly expected: Uint8Array;
}

export interface MediaTypeRepairFixture extends XmlReplacementFixture {
  readonly manifestId: string;
  readonly mediaType: string;
}

export interface ReferenceRepairFixture extends XmlReplacementFixture {
  readonly originalReference: string;
  readonly replacementReference: string;
}

export interface EquivalentPathRepairFixture {
  readonly name: string;
  readonly epub: Uint8Array;
  readonly sourcePath: InternalPath;
  readonly targetPath: InternalPath;
  readonly content: Uint8Array;
}

export type XmlEncodingRepairFixture = XmlReplacementFixture;

function bytes(value: string): Buffer {
  return Buffer.from(value, "utf8");
}

function internalPath(value: string): InternalPath {
  const parsed = parseInternalPath(value);
  if (!parsed.ok || parsed.value.isDirectory) throw new Error(`Invalid fixture path: ${value}`);
  return parsed.value.path;
}

function epubWithEntry(name: string, data: string | Uint8Array): Buffer {
  return createMinimalEpub({
    transformEntries: (entries) =>
      entries.map((entry): ZipFixtureEntry => (entry.name === name ? { ...entry, data } : entry)),
  });
}

function equivalentPathFixture(
  name: string,
  sourceValue: string,
  targetValue: string,
): EquivalentPathRepairFixture {
  const sourcePath = internalPath(sourceValue);
  const targetPath = internalPath(targetValue);
  const content = createImageFixture();
  const targetReference = `../${targetValue.slice("EPUB/".length)}`;
  return {
    name,
    sourcePath,
    targetPath,
    content,
    epub: createMinimalEpub({
      transformEntries: (entries) =>
        entries.map((entry) => {
          if (entry.name === "EPUB/images/cover.png") {
            return { ...entry, name: sourcePath, data: content };
          }
          if (entry.name === "EPUB/text/chapter.xhtml") {
            return {
              ...entry,
              data: String(entry.data).replace("../images/cover.png", targetReference),
            };
          }
          return entry;
        }),
    }),
  };
}

function utf16le(value: string): Buffer {
  return Buffer.concat([Buffer.from([0xff, 0xfe]), Buffer.from(value, "utf16le")]);
}

function utf16be(value: string): Buffer {
  const littleEndian = Buffer.from(value, "utf16le");
  for (let index = 0; index < littleEndian.length; index += 2) {
    const low = littleEndian[index];
    littleEndian[index] = littleEndian[index + 1];
    littleEndian[index + 1] = low;
  }
  return Buffer.concat([Buffer.from([0xfe, 0xff]), littleEndian]);
}

const packageBefore = `<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="book-id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="book-id">urn:uuid:fixture</dc:identifier>
    <dc:title>Keep text/plain &amp; punctuation exactly.</dc:title>
  </metadata>
  <manifest>
    <item id="chapter" href="text/chapter.xhtml" media-type="application/xhtml+xml"/>
    <item data-note="text/plain" media-type="text/plain" href="images/cover.png" id="cover-image"/>
  </manifest>
  <spine><itemref idref="chapter"/></spine>
</package>`;

const packageAfter = packageBefore.replace(
  'data-note="text/plain" media-type="text/plain" href="images/cover.png" id="cover-image"',
  'data-note="text/plain" media-type="image/png" href="images/cover.png" id="cover-image"',
);

export const mediaTypeRepairFixture: MediaTypeRepairFixture = {
  name: "manifest media type with reordered attributes and editorial decoys",
  epub: epubWithEntry("EPUB/package.opf", packageBefore),
  input: bytes(packageBefore),
  expected: bytes(packageAfter),
  manifestId: "cover-image",
  mediaType: "image/png",
};

const originalReference = "../images/missing-cover.png#hero";
const replacementReference = "../images/cover.png#hero";
const referenceBefore = `<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head><title>${originalReference}</title></head>
  <body data-note="${originalReference}">
    <p>Keep ${originalReference} as authored text.</p>
    <img alt="Cover &amp; portrait" src="${originalReference}"/>
  </body>
</html>`;
const referenceAfter = referenceBefore.replace(
  `src="${originalReference}"`,
  `src="${replacementReference}"`,
);

export const referenceRepairFixture: ReferenceRepairFixture = {
  name: "one matching XML reference with text and non-reference attribute decoys",
  epub: epubWithEntry("EPUB/text/chapter.xhtml", referenceBefore),
  input: bytes(referenceBefore),
  expected: bytes(referenceAfter),
  originalReference,
  replacementReference,
};

export const equivalentPathRepairFixtures = [
  equivalentPathFixture(
    "unique case-equivalent archive path",
    "EPUB/images/cover.png",
    "EPUB/Images/Cover.PNG",
  ),
  equivalentPathFixture(
    "unique Unicode-normalization-equivalent archive path",
    "EPUB/images/café.png",
    "EPUB/images/café.png",
  ),
] as const satisfies readonly EquivalentPathRepairFixture[];

const encodingBody = `<package xmlns="http://www.idpf.org/2007/opf" version="3.0">
  <!-- Preserve spacing, comments, entities, and authored Unicode. -->
  <metadata><title>Café &amp; Tea</title><meta property="custom">  Keep  spaces  </meta></metadata>
</package>`;
const utf16Document = `<?xml version="1.0" encoding="UTF-16"?>\n${encodingBody}`;
const utf8Document = `<?xml version="1.0" encoding="UTF-8"?>\n${encodingBody}`;

export const xmlEncodingRepairFixtures = [
  {
    name: "UTF-16LE XML",
    epub: epubWithEntry("EPUB/package.opf", utf16le(utf16Document)),
    input: utf16le(utf16Document),
    expected: bytes(utf8Document),
  },
  {
    name: "UTF-16BE XML",
    epub: epubWithEntry("EPUB/package.opf", utf16be(utf16Document)),
    input: utf16be(utf16Document),
    expected: bytes(utf8Document),
  },
] as const satisfies readonly XmlEncodingRepairFixture[];
