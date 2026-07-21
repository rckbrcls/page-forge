import { buildZip, type ZipFixtureEntry } from "./fixture-builder";

export type EpubVersion = 2 | 3;

export interface MinimalEpubOptions {
  version?: EpubVersion;
  packagePath?: string;
  title?: string;
  identifier?: string;
  language?: string;
  includeStylesheet?: boolean;
  includeImage?: boolean;
  includeFont?: boolean;
  includeEncryption?: boolean;
  additionalEntries?: readonly ZipFixtureEntry[];
  transformEntries?: (entries: ZipFixtureEntry[]) => ZipFixtureEntry[];
}

export interface PackageDocumentOptions {
  version: EpubVersion;
  title?: string;
  identifier?: string;
  language?: string;
  includeStylesheet?: boolean;
  includeImage?: boolean;
  includeFont?: boolean;
}

function xmlText(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
}

export function createContainerXml(packagePath = "EPUB/package.opf"): string {
  return `<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="${xmlText(packagePath)}" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>`;
}

export function createXhtmlDocument(options: {
  title?: string;
  stylesheetHref?: string;
  imageSrc?: string;
  body?: string;
} = {}): string {
  const title = xmlText(options.title ?? "Chapter One");
  const stylesheet = options.stylesheetHref
    ? `\n  <link rel="stylesheet" type="text/css" href="${xmlText(options.stylesheetHref)}"/>`
    : "";
  const image = options.imageSrc
    ? `\n    <img src="${xmlText(options.imageSrc)}" alt="Cover"/>`
    : "";
  return `<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <title>${title}</title>${stylesheet}
</head>
<body>
  <h1>${title}</h1>${image}
  ${options.body ?? "<p>Fixture content.</p>"}
</body>
</html>`;
}

export function createNavigationDocument(): string {
  return `<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<head><title>Contents</title></head>
<body>
  <nav epub:type="toc"><ol><li><a href="text/chapter.xhtml">Chapter One</a></li></ol></nav>
</body>
</html>`;
}

export function createNcxDocument(identifier = "urn:uuid:page-forge-fixture"): string {
  return `<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head><meta name="dtb:uid" content="${xmlText(identifier)}"/></head>
  <docTitle><text>Fixture Book</text></docTitle>
  <navMap><navPoint id="chapter" playOrder="1"><navLabel><text>Chapter One</text></navLabel><content src="text/chapter.xhtml"/></navPoint></navMap>
</ncx>`;
}

export function createStylesheet(options: { fontHref?: string } = {}): string {
  const fontFace = options.fontHref
    ? `@font-face { font-family: Fixture; src: url("${options.fontHref}"); }\n`
    : "";
  return `${fontFace}body { font-family: Fixture, serif; line-height: 1.4; }\nimg { max-width: 100%; }\n`;
}

export function createImageFixture(): Buffer {
  return Buffer.from(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=",
    "base64",
  );
}

export function createFontFixture(): Buffer {
  return Buffer.from([0x77, 0x4f, 0x46, 0x46, 0, 1, 0, 0, 0, 0, 0, 12]);
}

export function createEncryptionXml(paths: readonly string[] = ["EPUB/fonts/book.woff"]): string {
  const encryptedData = paths
    .map(
      (path) => `  <enc:EncryptedData>
    <enc:EncryptionMethod Algorithm="http://www.idpf.org/2008/embedding"/>
    <enc:CipherData><enc:CipherReference URI="${xmlText(path)}"/></enc:CipherData>
  </enc:EncryptedData>`,
    )
    .join("\n");
  return `<?xml version="1.0" encoding="UTF-8"?>
<encryption xmlns="urn:oasis:names:tc:opendocument:xmlns:container" xmlns:enc="http://www.w3.org/2001/04/xmlenc#">
${encryptedData}
</encryption>`;
}

export function createPackageDocument(options: PackageDocumentOptions): string {
  const title = xmlText(options.title ?? "Fixture Book");
  const identifier = xmlText(options.identifier ?? "urn:uuid:page-forge-fixture");
  const language = xmlText(options.language ?? "en");
  const stylesheetItem = options.includeStylesheet
    ? '\n    <item id="css" href="styles/book.css" media-type="text/css"/>'
    : "";
  const imageItem = options.includeImage
    ? `\n    <item id="cover-image" href="images/cover.png" media-type="image/png"${options.version === 3 ? ' properties="cover-image"' : ""}/>`
    : "";
  const fontItem = options.includeFont
    ? '\n    <item id="font" href="fonts/book.woff" media-type="font/woff"/>'
    : "";
  const versionSpecificMetadata =
    options.version === 3
      ? '\n    <meta property="dcterms:modified">2026-01-01T00:00:00Z</meta>'
      : options.includeImage
        ? '\n    <meta name="cover" content="cover-image"/>'
        : "";
  const navigationItem =
    options.version === 3
      ? '\n    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>'
      : '\n    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>';
  const spineAttributes = options.version === 2 ? ' toc="ncx"' : "";
  return `<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="${options.version === 3 ? "3.0" : "2.0"}" unique-identifier="book-id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="book-id">${identifier}</dc:identifier>
    <dc:title>${title}</dc:title>
    <dc:language>${language}</dc:language>${versionSpecificMetadata}
  </metadata>
  <manifest>
    <item id="chapter" href="text/chapter.xhtml" media-type="application/xhtml+xml"/>${navigationItem}${stylesheetItem}${imageItem}${fontItem}
  </manifest>
  <spine${spineAttributes}><itemref idref="chapter"/></spine>
</package>`;
}

export function createMinimalEpubEntries(options: MinimalEpubOptions = {}): ZipFixtureEntry[] {
  const version = options.version ?? 3;
  const packagePath = options.packagePath ?? "EPUB/package.opf";
  const includeStylesheet = options.includeStylesheet ?? true;
  const includeImage = options.includeImage ?? true;
  const includeFont = options.includeFont ?? true;
  const packageDirectory = packagePath.includes("/")
    ? packagePath.slice(0, packagePath.lastIndexOf("/"))
    : "";
  const resourcePath = (relative: string): string =>
    packageDirectory.length > 0 ? `${packageDirectory}/${relative}` : relative;

  const entries: ZipFixtureEntry[] = [
    { name: "mimetype", data: "application/epub+zip", method: 0, flags: 0 },
    { name: "META-INF/container.xml", data: createContainerXml(packagePath), method: 8 },
    {
      name: packagePath,
      data: createPackageDocument({
        version,
        title: options.title,
        identifier: options.identifier,
        language: options.language,
        includeStylesheet,
        includeImage,
        includeFont,
      }),
      method: 8,
    },
    {
      name: resourcePath("text/chapter.xhtml"),
      data: createXhtmlDocument({
        stylesheetHref: includeStylesheet ? "../styles/book.css" : undefined,
        imageSrc: includeImage ? "../images/cover.png" : undefined,
      }),
      method: 8,
    },
    version === 3
      ? { name: resourcePath("nav.xhtml"), data: createNavigationDocument(), method: 8 }
      : {
          name: resourcePath("toc.ncx"),
          data: createNcxDocument(options.identifier),
          method: 8,
        },
  ];

  if (includeStylesheet) {
    entries.push({
      name: resourcePath("styles/book.css"),
      data: createStylesheet({ fontHref: includeFont ? "../fonts/book.woff" : undefined }),
      method: 8,
    });
  }
  if (includeImage) {
    entries.push({ name: resourcePath("images/cover.png"), data: createImageFixture(), method: 8 });
  }
  if (includeFont) {
    entries.push({ name: resourcePath("fonts/book.woff"), data: createFontFixture(), method: 8 });
  }
  if (options.includeEncryption) {
    entries.push({
      name: "META-INF/encryption.xml",
      data: createEncryptionXml([resourcePath("fonts/book.woff")]),
      method: 8,
    });
  }
  entries.push(...(options.additionalEntries ?? []));

  return options.transformEntries ? options.transformEntries(entries) : entries;
}

export function createMinimalEpub(options: MinimalEpubOptions = {}): Buffer {
  return buildZip(createMinimalEpubEntries(options));
}

export function createMinimalEpub2(options: Omit<MinimalEpubOptions, "version"> = {}): Buffer {
  return createMinimalEpub({ ...options, version: 2 });
}

export function createMinimalEpub3(options: Omit<MinimalEpubOptions, "version"> = {}): Buffer {
  return createMinimalEpub({ ...options, version: 3 });
}
