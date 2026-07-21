import { accountAuditRules, type AuditRuleStage } from "./rule-catalog";
import { deriveHealth, sortFindings } from "./derive-health";
import { createFinding } from "./finding-catalog";
import { inspectArchivePathSafety } from "./archive-path-safety";
import { inspectArchiveStructureSafety } from "./archive-structure-safety";
import { parseInternalPath } from "./internal-path";
import { ARCHIVE_LIMITS, XML_LIMITS } from "./limits";
import { resolveReferencePath } from "./resolve-reference";
import { auditArchiveIdentity } from "./rules/archive-identity";
import { auditContainer } from "./rules/container";
import { auditContent } from "./rules/content";
import { auditMimetype } from "./rules/mimetype";
import { auditPackageRules } from "./rules/package";
import type { ArchiveEntryDescriptor, ArchiveProjection, InternalPath, PreflightOutcome } from "../models/archive";
import type {
  ContainerProjection,
  ContentProjection,
  MimetypeProjection,
  PackageProjection,
  ParseOutcome,
  SelectedEpub,
  SelectedEpubId,
  Sha256Digest,
  SourceFingerprint,
  VerifiedReadDescriptor,
} from "../models/epub-document";
import type { Finding } from "../models/finding";
import type { EpubVersion, HealthReport } from "../models/health-report";
import type { ProcessingFailure } from "../models/processing-failure";
import { err, ok, type Result } from "../models/result";

export interface AuditBytesInput {
  readonly bytes: Uint8Array;
  readonly displayName: string;
}

export interface AuditReadable extends AsyncIterable<Uint8Array> {
  readonly close: () => Promise<Result<void, ProcessingFailure>>;
}

export interface AuditArchiveSession {
  readonly projection: ArchiveProjection;
  readonly openEntry: (
    entry: ArchiveEntryDescriptor,
    signal: AbortSignal,
  ) => Promise<Result<AuditReadable, ProcessingFailure>>;
  readonly close: () => Promise<Result<void, ProcessingFailure>>;
}

interface AuditPreflightResult {
  readonly outcome: PreflightOutcome<ArchiveProjection>;
  readonly session?: AuditArchiveSession;
}

export interface AuditEpubPorts {
  readonly filesystem: {
    readonly openVerifiedSource: (source: SelectedEpub) => Promise<Result<VerifiedReadDescriptor, ProcessingFailure>>;
    readonly fingerprint: (
      descriptor: VerifiedReadDescriptor,
      signal: AbortSignal,
    ) => Promise<Result<SourceFingerprint, ProcessingFailure>>;
  };
  readonly archive: {
    readonly preflightArchive: (
      descriptor: VerifiedReadDescriptor,
      limits: typeof ARCHIVE_LIMITS,
      signal: AbortSignal,
    ) => Promise<Result<AuditPreflightResult, ProcessingFailure>>;
  };
  readonly xml: {
    readonly parseContainer: (
      xml: AuditReadable,
      path: InternalPath,
      limits: typeof XML_LIMITS,
      signal: AbortSignal,
    ) => Promise<Result<ParseOutcome<ContainerProjection>, ProcessingFailure>>;
    readonly parsePackage: (
      xml: AuditReadable,
      path: InternalPath,
      limits: typeof XML_LIMITS,
      signal: AbortSignal,
    ) => Promise<Result<ParseOutcome<PackageProjection>, ProcessingFailure>>;
    readonly parseContentReferences: (
      xml: AuditReadable,
      path: InternalPath,
      mediaType: string,
      limits: typeof XML_LIMITS,
      signal: AbortSignal,
    ) => Promise<Result<ParseOutcome<ContentProjection>, ProcessingFailure>>;
  };
  readonly clock: { readonly nowMs: () => number };
}

interface AuditFacts {
  readonly findings: readonly Finding[];
  readonly epubVersion: EpubVersion;
  readonly completedStages: ReadonlySet<AuditRuleStage>;
  readonly terminalReason?: string;
  readonly existingRuleResults?: PreflightOutcome<ArchiveProjection>["ruleResults"];
}

export function auditEpub(input: AuditBytesInput): Promise<HealthReport>;
export function auditEpub(
  source: SelectedEpub,
  ports: AuditEpubPorts,
  signal: AbortSignal,
): Promise<Result<HealthReport, ProcessingFailure>>;
export async function auditEpub(
  input: AuditBytesInput | SelectedEpub,
  ports?: AuditEpubPorts,
  signal?: AbortSignal,
): Promise<HealthReport | Result<HealthReport, ProcessingFailure>> {
  if ("bytes" in input) return auditBytes(input);
  if (ports === undefined || signal === undefined) {
    return err(internalFailure("Audit ports and an abort signal are required."));
  }
  return auditSelectedEpub(input, ports, signal);
}

async function auditSelectedEpub(
  source: SelectedEpub,
  ports: AuditEpubPorts,
  signal: AbortSignal,
): Promise<Result<HealthReport, ProcessingFailure>> {
  const startedAtMs = ports.clock.nowMs();
  const descriptor = await ports.filesystem.openVerifiedSource(source);
  if (!descriptor.ok) return descriptor;
  const fingerprint = await ports.filesystem.fingerprint(descriptor.value, signal);
  if (!fingerprint.ok) return fingerprint;
  const preflight = await ports.archive.preflightArchive(descriptor.value, ARCHIVE_LIMITS, signal);
  if (!preflight.ok) return preflight;

  const inspectedAtMs = ports.clock.nowMs();
  if (preflight.value.outcome.terminal) {
    return ok(
      createReport(source.id, fingerprint.value, inspectedAtMs, startedAtMs, {
        findings: preflight.value.outcome.findings,
        epubVersion: "unknown",
        completedStages: new Set(),
        terminalReason: "Archive preflight produced a terminal finding.",
        existingRuleResults: preflight.value.outcome.ruleResults,
      }),
    );
  }

  const session = preflight.value.session;
  const projection = preflight.value.outcome.projection;
  if (session === undefined || projection === undefined) {
    return err(internalFailure("Archive preflight did not provide a readable projection."));
  }

  const audited = await auditSession(session, projection, preflight.value.outcome, ports, signal);
  const closed = await session.close();
  if (!audited.ok) return audited;
  if (!closed.ok) return closed;
  return ok(createReport(source.id, fingerprint.value, ports.clock.nowMs(), startedAtMs, audited.value));
}

async function auditSession(
  session: AuditArchiveSession,
  projection: ArchiveProjection,
  preflight: PreflightOutcome<ArchiveProjection>,
  ports: AuditEpubPorts,
  signal: AbortSignal,
): Promise<Result<AuditFacts, ProcessingFailure>> {
  const findings: Finding[] = [...preflight.findings];
  const completedStages = new Set<AuditRuleStage>(["preflight"]);

  const mimetypeEntry = projection.entryIndex.get("mimetype" as InternalPath);
  let mimetype: MimetypeProjection | undefined;
  if (mimetypeEntry !== undefined) {
    const value = await readEntryBytes(session, mimetypeEntry, signal);
    if (!value.ok) return value;
    mimetype = {
      entryIndex: mimetypeEntry.index,
      compressionMethod: mimetypeEntry.compressionMethod,
      localHeaderExtraLength: mimetypeEntry.localHeaderExtraLength,
      value: new TextDecoder().decode(value.value),
    };
  }
  findings.push(...auditMimetype(mimetype));
  completedStages.add("mimetype");

  const containerEntry = projection.entryIndex.get("META-INF/container.xml" as InternalPath);
  let container: ContainerProjection | undefined;
  let containerXmlInvalid = false;
  if (containerEntry !== undefined) {
    const parsed = await parseEntry(session, containerEntry, signal, (readable) =>
      ports.xml.parseContainer(readable, containerEntry.path as InternalPath, XML_LIMITS, signal),
    );
    if (!parsed.ok) return parsed;
    container = parsed.value.projection;
    findings.push(...parsed.value.findings);
    containerXmlInvalid = container === undefined;
  }

  const packageEntries = projection.entries.filter(
    (entry) => entry.kind === "file" && typeof entry.path === "string" && /\.opf$/iu.test(entry.path),
  );
  const packages: PackageProjection[] = [];
  let packageXmlInvalid = false;
  let packageXmlInvalidPath: InternalPath | undefined;
  for (const entry of packageEntries) {
    const parsed = await parseEntry(session, entry, signal, (readable) =>
      ports.xml.parsePackage(readable, entry.path as InternalPath, XML_LIMITS, signal),
    );
    if (!parsed.ok) return parsed;
    findings.push(...parsed.value.findings);
    if (parsed.value.projection !== undefined) packages.push(parsed.value.projection);
    else {
      packageXmlInvalid = true;
      packageXmlInvalidPath = entry.path as InternalPath;
    }
  }

  findings.push(
    ...auditContainer({
      container,
      packages,
      entryIndex: projection.entryIndex,
      containerXmlInvalid,
      packageXmlInvalid,
      packageXmlInvalidPath,
    }),
  );
  completedStages.add("discovery");

  const packageDocument = packages.length === 1 ? packages[0] : undefined;
  if (packageDocument === undefined || packageXmlInvalid || packageDocument.version === "unknown") {
    return ok({
      findings,
      epubVersion: packageDocument?.version ?? "unknown",
      completedStages,
      terminalReason: "Package discovery did not produce one supported package document.",
      existingRuleResults: preflight.ruleResults,
    });
  }

  findings.push(...auditPackageRules(packageDocument, projection.entryIndex));
  completedStages.add("package");

  const contentDocuments: ContentProjection[] = [];
  const malformedXhtmlPaths: InternalPath[] = [];
  for (const item of packageDocument.manifest) {
    if (item.resolvedPath === undefined || !["application/xhtml+xml", "image/svg+xml"].includes(item.mediaType ?? "")) {
      continue;
    }
    const entry = projection.entryIndex.get(item.resolvedPath);
    if (entry === undefined) continue;
    const parsed = await parseEntry(session, entry, signal, (readable) =>
      ports.xml.parseContentReferences(readable, entry.path as InternalPath, item.mediaType!, XML_LIMITS, signal),
    );
    if (!parsed.ok) return parsed;
    findings.push(...parsed.value.findings);
    if (parsed.value.projection !== undefined) contentDocuments.push(parsed.value.projection);
    else malformedXhtmlPaths.push(item.resolvedPath);
  }

  const relevantResourceBytes = new Map<InternalPath, number>();
  for (const item of packageDocument.manifest) {
    if (item.resolvedPath === undefined) continue;
    const entry = projection.entryIndex.get(item.resolvedPath);
    if (entry !== undefined) relevantResourceBytes.set(item.resolvedPath, entry.expandedSize);
  }
  findings.push(
    ...auditContent({
      packageDocument,
      contentDocuments,
      malformedXhtmlPaths,
      existingPaths: [...projection.entryIndex.keys()],
      relevantResourceBytes,
    }),
  );
  completedStages.add("content");
  return ok({
    findings,
    epubVersion: packageDocument.version,
    completedStages,
    existingRuleResults: preflight.ruleResults,
  });
}

async function parseEntry<T>(
  session: AuditArchiveSession,
  entry: ArchiveEntryDescriptor,
  signal: AbortSignal,
  parse: (readable: AuditReadable) => Promise<Result<ParseOutcome<T>, ProcessingFailure>>,
): Promise<Result<ParseOutcome<T>, ProcessingFailure>> {
  const opened = await session.openEntry(entry, signal);
  if (!opened.ok) return opened;
  const parsed = await parse(opened.value);
  const closed = await opened.value.close();
  return parsed.ok && !closed.ok ? closed : parsed;
}

async function readEntryBytes(
  session: AuditArchiveSession,
  entry: ArchiveEntryDescriptor,
  signal: AbortSignal,
): Promise<Result<Uint8Array, ProcessingFailure>> {
  const opened = await session.openEntry(entry, signal);
  if (!opened.ok) return opened;
  const chunks: Uint8Array[] = [];
  let byteLength = 0;
  for await (const chunk of opened.value) {
    chunks.push(chunk);
    byteLength += chunk.byteLength;
  }
  const closed = await opened.value.close();
  if (!closed.ok) return closed;
  const bytes = new Uint8Array(byteLength);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return ok(bytes);
}

async function auditBytes(input: AuditBytesInput): Promise<HealthReport> {
  const startedAtMs = Date.now();
  const sourceId = `memory:${input.displayName}` as SelectedEpubId;
  const fingerprint: SourceFingerprint = {
    identity: { device: "memory", file: input.displayName },
    sizeBytes: input.bytes.byteLength,
    modifiedAtMs: 0,
    sha256: await sha256(input.bytes),
  };

  const structureSafety = inspectArchiveStructureSafety(input.bytes);
  if (structureSafety.findings.length > 0) {
    return createReport(sourceId, fingerprint, Date.now(), startedAtMs, {
      findings: structureSafety.findings,
      epubVersion: "unknown",
      completedStages: new Set(),
      terminalReason: "Archive preflight produced a terminal finding.",
    });
  }

  let archive: MemoryArchive;
  try {
    archive = parseMemoryArchive(input.bytes);
  } catch {
    const finding = createFinding("ZIP_INVALID");
    return createReport(sourceId, fingerprint, Date.now(), startedAtMs, {
      findings: [finding],
      epubVersion: "unknown",
      completedStages: new Set(),
      terminalReason: "Archive preflight produced a terminal finding.",
    });
  }

  const findings: Finding[] = [];
  const seenFindings = new Set<string>();
  const addFindings = (next: readonly Finding[]): void => {
    for (const finding of next) {
      if (seenFindings.has(finding.identity)) continue;
      seenFindings.add(finding.identity);
      findings.push(finding);
    }
  };

  const pathSafety = inspectArchivePathSafety(archive.entries);
  if (pathSafety.findings.length > 0) {
    addFindings(pathSafety.findings);
    return createReport(sourceId, fingerprint, Date.now(), startedAtMs, {
      findings,
      epubVersion: "unknown",
      completedStages: new Set(),
      terminalReason: "Archive preflight produced a terminal finding.",
    });
  }

  addFindings(auditArchiveIdentity(archive.entries));

  if (archive.entries.length === 0) {
    return createReport(sourceId, fingerprint, Date.now(), startedAtMs, {
      findings,
      epubVersion: "unknown",
      completedStages: new Set(),
      terminalReason: "Archive preflight produced a terminal finding.",
    });
  }

  const completedStages = new Set<AuditRuleStage>(["preflight"]);
  const mimetypeEntry = archive.entries.find(({ path }) => path === "mimetype");
  const mimetype =
    mimetypeEntry === undefined
      ? undefined
      : {
          entryIndex: mimetypeEntry.index,
          compressionMethod: mimetypeEntry.compressionMethod,
          localHeaderExtraLength: mimetypeEntry.localHeaderExtraLength,
          value: new TextDecoder().decode(await archive.read(mimetypeEntry.index)),
        };
  findings.push(...auditMimetype(mimetype));
  completedStages.add("mimetype");

  const containerEntry = archive.entries.find(({ path }) => path === "META-INF/container.xml");
  let container: ContainerProjection | undefined;
  let containerXmlInvalid = false;
  if (containerEntry !== undefined) {
    const xml = new TextDecoder().decode(await archive.read(containerEntry.index));
    container = parseContainerXml(xml);
    containerXmlInvalid = container === undefined;
  }

  const packages: PackageProjection[] = [];
  let packageXmlInvalid = false;
  let packageXmlInvalidPath: InternalPath | undefined;
  for (const entry of archive.entries) {
    if (entry.kind !== "file" || typeof entry.path !== "string" || !/\.opf$/iu.test(entry.path)) {
      continue;
    }
    const xml = new TextDecoder().decode(await archive.read(entry.index));
    const packageDocument = parsePackageXml(xml, entry.path);
    if (packageDocument === undefined) {
      packageXmlInvalid = true;
      packageXmlInvalidPath = entry.path;
    } else packages.push(packageDocument);
  }

  findings.push(
    ...auditContainer({
      container,
      packages,
      entryIndex: archive.entryIndex,
      containerXmlInvalid,
      packageXmlInvalid,
      packageXmlInvalidPath,
    }),
  );
  completedStages.add("discovery");
  const packageDocument = packages.length === 1 ? packages[0] : undefined;
  if (packageDocument === undefined || packageXmlInvalid || packageDocument.version === "unknown") {
    return createReport(sourceId, fingerprint, Date.now(), startedAtMs, {
      findings,
      epubVersion: packageDocument?.version ?? "unknown",
      completedStages,
      terminalReason: "Package discovery did not produce one supported package document.",
    });
  }

  findings.push(...auditPackageRules(packageDocument, archive.entryIndex));
  completedStages.add("package");
  findings.push(
    ...auditContent({
      packageDocument,
      contentDocuments: [],
      malformedXhtmlPaths: [],
      existingPaths: [...archive.entryIndex.keys()],
      relevantResourceBytes: new Map(
        packageDocument.manifest.flatMap((item) => {
          if (item.resolvedPath === undefined) return [];
          const entry = archive.entryIndex.get(item.resolvedPath);
          return entry === undefined ? [] : [[item.resolvedPath, entry.expandedSize] as const];
        }),
      ),
    }),
  );
  completedStages.add("content");
  return createReport(sourceId, fingerprint, Date.now(), startedAtMs, {
    findings,
    epubVersion: packageDocument.version,
    completedStages,
  });
}

function createReport(
  sourceId: SelectedEpubId,
  sourceFingerprint: SourceFingerprint,
  inspectedAtMs: number,
  startedAtMs: number,
  facts: AuditFacts,
): HealthReport {
  const findings = sortFindings(facts.findings);
  return {
    sourceId,
    sourceFingerprint,
    epubVersion: facts.epubVersion,
    health: deriveHealth(findings),
    findings,
    inspectedAtMs,
    durationMs: Math.max(0, inspectedAtMs - startedAtMs),
    ruleResults: accountAuditRules(findings, {
      completedStages: facts.completedStages,
      terminalReason: facts.terminalReason,
      existing: facts.existingRuleResults,
    }),
  };
}

interface MemoryArchive {
  readonly entries: readonly ArchiveEntryDescriptor[];
  readonly entryIndex: ReadonlyMap<InternalPath, ArchiveEntryDescriptor>;
  readonly read: (index: number) => Promise<Uint8Array>;
}

interface MemoryEntryData {
  readonly method: number;
  readonly bytes: Uint8Array;
}

function parseMemoryArchive(bytes: Uint8Array): MemoryArchive {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const endOffset = findEndOfCentralDirectory(view);
  const entryCount = view.getUint16(endOffset + 10, true);
  const centralSize = view.getUint32(endOffset + 12, true);
  const centralOffset = view.getUint32(endOffset + 16, true);
  if (centralOffset + centralSize > endOffset) throw new Error("Invalid central directory");

  const entries: ArchiveEntryDescriptor[] = [];
  const entryIndex = new Map<InternalPath, ArchiveEntryDescriptor>();
  const data = new Map<number, MemoryEntryData>();
  let offset = centralOffset;
  for (let index = 0; index < entryCount; index += 1) {
    if (view.getUint32(offset, true) !== 0x02014b50) throw new Error("Invalid entry");
    const flags = view.getUint16(offset + 8, true);
    const method = view.getUint16(offset + 10, true);
    const crc32 = view.getUint32(offset + 16, true);
    const compressedSize = view.getUint32(offset + 20, true);
    const expandedSize = view.getUint32(offset + 24, true);
    const nameLength = view.getUint16(offset + 28, true);
    const extraLength = view.getUint16(offset + 30, true);
    const commentLength = view.getUint16(offset + 32, true);
    const externalAttributes = view.getUint32(offset + 38, true);
    const localOffset = view.getUint32(offset + 42, true);
    const nameBytes = bytes.subarray(offset + 46, offset + 46 + nameLength);
    const originalName = new TextDecoder().decode(nameBytes);
    if (view.getUint32(localOffset, true) !== 0x04034b50) throw new Error("Invalid local entry");
    const localNameLength = view.getUint16(localOffset + 26, true);
    const localExtraLength = view.getUint16(localOffset + 28, true);
    const dataOffset = localOffset + 30 + localNameLength + localExtraLength;
    if (dataOffset + compressedSize > bytes.byteLength) throw new Error("Invalid entry data");
    const parsedPath = parseInternalPath(originalName);
    const path = parsedPath.ok ? parsedPath.value.path : { originalName, reason: parsedPath.failure };
    const fileType = (externalAttributes >>> 16) & 0xf000;
    const kind =
      originalName.endsWith("/") || fileType === 0x4000
        ? "directory"
        : fileType === 0xa000
          ? "symlink"
          : fileType === 0 || fileType === 0x8000
            ? "file"
            : "special";
    const descriptor: ArchiveEntryDescriptor = {
      index,
      originalName,
      originalNameBytes: nameBytes,
      path,
      kind,
      compressionMethod: method,
      compressedSize,
      expandedSize,
      crc32,
      encrypted: (flags & 1) !== 0,
      externalAttributes,
      flags,
      localHeaderExtraLength: localExtraLength,
    };
    entries.push(descriptor);
    if (typeof path === "string") entryIndex.set(path, descriptor);
    data.set(index, { method, bytes: bytes.slice(dataOffset, dataOffset + compressedSize) });
    offset += 46 + nameLength + extraLength + commentLength;
  }
  if (offset !== centralOffset + centralSize) throw new Error("Invalid central directory size");

  return {
    entries,
    entryIndex,
    read: async (index) => {
      const entry = data.get(index);
      if (entry === undefined) throw new Error("Missing entry");
      if (entry.method === 0) return entry.bytes;
      if (entry.method !== 8) return new Uint8Array();
      const decompressed = new Blob([new Uint8Array(entry.bytes)])
        .stream()
        .pipeThrough(new DecompressionStream("deflate-raw"));
      return new Uint8Array(await new Response(decompressed).arrayBuffer());
    },
  };
}

function findEndOfCentralDirectory(view: DataView): number {
  const minimum = Math.max(0, view.byteLength - 65_557);
  for (let offset = view.byteLength - 22; offset >= minimum; offset -= 1) {
    if (
      view.getUint32(offset, true) === 0x06054b50 &&
      offset + 22 + view.getUint16(offset + 20, true) === view.byteLength
    ) {
      if (view.getUint16(offset + 4, true) !== 0 || view.getUint16(offset + 6, true) !== 0) {
        throw new Error("Multi-disk ZIP");
      }
      return offset;
    }
  }
  throw new Error("Missing end of central directory");
}

function parseContainerXml(xml: string): ContainerProjection | undefined {
  if (!isWellFormedXml(xml)) return undefined;
  const rootfiles = [...xml.matchAll(/<(?:[\w.-]+:)?rootfile\b([^>]*)\/?\s*>/giu)].flatMap((match) => {
    const values = attributes(match[1]);
    const fullPath = values.get("full-path");
    if (fullPath === undefined) return [];
    const parsed = parseInternalPath(decodeXml(fullPath));
    return [
      {
        fullPath: decodeXml(fullPath),
        ...(values.get("media-type") === undefined ? {} : { mediaType: decodeXml(values.get("media-type")!) }),
        ...(parsed.ok ? { resolvedPath: parsed.value.path } : {}),
      },
    ];
  });
  return { path: "META-INF/container.xml" as InternalPath, rootfiles };
}

function parsePackageXml(xml: string, path: InternalPath): PackageProjection | undefined {
  if (!isWellFormedXml(xml)) return undefined;
  const packageTag = /<(?:[\w.-]+:)?package\b([^>]*)>/iu.exec(xml);
  if (packageTag === null) return undefined;
  const packageAttributes = attributes(packageTag[1]);
  const rawVersion = packageAttributes.get("version") ?? "";
  const version = rawVersion.startsWith("2") ? "2" : rawVersion.startsWith("3") ? "3" : "unknown";
  const titles = elementTexts(xml, "title");
  const languages = elementTexts(xml, "language");
  const identifiers = [
    ...xml.matchAll(/<(?:[\w.-]+:)?identifier\b([^>]*)>([\s\S]*?)<\/(?:[\w.-]+:)?identifier\s*>/giu),
  ].map((match) => {
    const id = attributes(match[1]).get("id");
    return { ...(id === undefined ? {} : { id }), value: decodeXml(stripTags(match[2])).trim() };
  });
  const manifest = [...xml.matchAll(/<(?:[\w.-]+:)?item\b([^>]*)\/?\s*>/giu)].flatMap((match) => {
    const values = attributes(match[1]);
    const id = values.get("id");
    const href = values.get("href");
    if (id === undefined || href === undefined) return [];
    const resolved = resolveReferencePath(path, decodeXml(href));
    return [
      {
        id: decodeXml(id),
        href: decodeXml(href),
        ...(resolved.requestedPath === undefined ? {} : { resolvedPath: resolved.requestedPath }),
        ...(values.get("media-type") === undefined ? {} : { mediaType: decodeXml(values.get("media-type")!) }),
        properties: (values.get("properties") ?? "").split(/\s+/u).filter(Boolean),
      },
    ];
  });
  const spineTag = /<(?:[\w.-]+:)?spine\b([^>]*)>/iu.exec(xml);
  const spine = [...xml.matchAll(/<(?:[\w.-]+:)?itemref\b([^>]*)\/?\s*>/giu)].map((match) => {
    const values = attributes(match[1]);
    const idref = values.get("idref");
    const linear = values.get("linear");
    return {
      ...(idref === undefined ? {} : { idref: decodeXml(idref) }),
      ...(linear === undefined ? {} : { linear: linear.toLowerCase() !== "no" }),
    };
  });
  const renditionLayout = [...xml.matchAll(/<(?:[\w.-]+:)?meta\b([^>]*)>([\s\S]*?)<\/(?:[\w.-]+:)?meta\s*>/giu)].find(
    (match) => attributes(match[1]).get("property") === "rendition:layout",
  )?.[2];
  return {
    path,
    version,
    metadata: {
      titles,
      identifiers,
      languages,
      ...(packageAttributes.get("unique-identifier") === undefined
        ? {}
        : { uniqueIdentifier: decodeXml(packageAttributes.get("unique-identifier")!) }),
      ...(renditionLayout === undefined ? {} : { renditionLayout: decodeXml(stripTags(renditionLayout)).trim() }),
    },
    manifest,
    spine,
    ...(spineTag === null || attributes(spineTag[1]).get("toc") === undefined
      ? {}
      : { spineToc: decodeXml(attributes(spineTag[1]).get("toc")!) }),
  };
}

function isWellFormedXml(xml: string): boolean {
  const stack: string[] = [];
  const tokens = xml.match(/<[^>]+>/gu) ?? [];
  for (const token of tokens) {
    if (/^<\?|^<!/u.test(token) || /\/>$/u.test(token)) continue;
    const close = /^<\/\s*([^\s>]+)/u.exec(token);
    if (close !== null) {
      if (stack.pop() !== close[1]) return false;
      continue;
    }
    const open = /^<\s*([^\s/>]+)/u.exec(token);
    if (open !== null) stack.push(open[1]);
  }
  return stack.length === 0;
}

function attributes(source: string): Map<string, string> {
  return new Map([...source.matchAll(/([\w:.-]+)\s*=\s*(["'])(.*?)\2/gu)].map((match) => [match[1], match[3]]));
}

function elementTexts(xml: string, localName: string): string[] {
  const expression = new RegExp(
    `<(?:[\\w.-]+:)?${localName}\\b[^>]*>([\\s\\S]*?)<\\/(?:[\\w.-]+:)?${localName}\\s*>`,
    "giu",
  );
  return [...xml.matchAll(expression)].map((match) => decodeXml(stripTags(match[1])).trim());
}

function stripTags(value: string): string {
  return value.replace(/<[^>]*>/gu, "");
}

function decodeXml(value: string): string {
  return value
    .replaceAll("&quot;", '"')
    .replaceAll("&apos;", "'")
    .replaceAll("&lt;", "<")
    .replaceAll("&gt;", ">")
    .replaceAll("&amp;", "&");
}

async function sha256(bytes: Uint8Array): Promise<Sha256Digest> {
  const digest = await globalThis.crypto.subtle.digest("SHA-256", new Uint8Array(bytes));
  return [...new Uint8Array(digest)].map((value) => value.toString(16).padStart(2, "0")).join("") as Sha256Digest;
}

function internalFailure(safeMessage: string): ProcessingFailure {
  return {
    category: "internal",
    code: "INTERNAL_FAILURE",
    safeMessage,
    retryable: false,
    phase: "preflight",
  };
}
