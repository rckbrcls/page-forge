import { parseInternalPath } from "../../domain/audit/internal-path";
import { resolveReferencePath } from "../../domain/audit/resolve-reference";
import type { InternalPath } from "../../domain/models/archive";
import type {
  ContainerProjection,
  ContentProjection,
  ManifestItemProjection,
  MetadataProjection,
  PackageProjection,
  SpineItemProjection,
} from "../../domain/models/epub-document";
import {
  parseSafeXml,
  type SafeXmlLimits,
  type XmlByteSource,
  type XmlCloseElement,
  type XmlOpenElement,
} from "./safe-xml-parser";

const CONTAINER_NS = "urn:oasis:names:tc:opendocument:xmlns:container";
const OPF_NS = "http://www.idpf.org/2007/opf";
const DC_NS = "http://purl.org/dc/elements/1.1/";
const XHTML_NS = "http://www.w3.org/1999/xhtml";
const SVG_NS = "http://www.w3.org/2000/svg";
const XLINK_NS = "http://www.w3.org/1999/xlink";

export async function parseContainerProjection(
  source: XmlByteSource,
  path: InternalPath,
  limits: SafeXmlLimits,
  signal: AbortSignal,
): Promise<ContainerProjection> {
  const rootfiles: Array<ContainerProjection["rootfiles"][number]> = [];
  await parseSafeXml(source, limits, signal, {
    onOpenElement(element) {
      if (!isElement(element, CONTAINER_NS, "rootfile")) return;
      const fullPath = attributeValue(element, "full-path");
      if (fullPath === undefined) return;
      const resolvedPath = parseRootfilePath(fullPath);
      const mediaType = attributeValue(element, "media-type");
      rootfiles.push({
        fullPath,
        ...(mediaType === undefined ? {} : { mediaType }),
        ...(resolvedPath === undefined ? {} : { resolvedPath }),
      });
    },
  });

  return { path, rootfiles };
}

export async function parsePackageProjection(
  source: XmlByteSource,
  path: InternalPath,
  limits: SafeXmlLimits,
  signal: AbortSignal,
): Promise<PackageProjection> {
  let version: PackageProjection["version"] = "unknown";
  let uniqueIdentifier: string | undefined;
  let renditionLayout: string | undefined;
  let spineToc: string | undefined;
  let epub2CoverId: string | undefined;
  const titles: string[] = [];
  const identifiers: Array<{ id?: string; value: string }> = [];
  const languages: string[] = [];
  const manifest: ManifestItemProjection[] = [];
  const spine: SpineItemProjection[] = [];
  const captures: TextCapture[] = [];

  await parseSafeXml(source, limits, signal, {
    onOpenElement(element) {
      if (isElement(element, OPF_NS, "package")) {
        const rawVersion = attributeValue(element, "version") ?? "";
        version = rawVersion.startsWith("2") ? "2" : rawVersion.startsWith("3") ? "3" : "unknown";
        uniqueIdentifier = attributeValue(element, "unique-identifier");
      } else if (isElement(element, DC_NS, "title")) {
        captures.push({ kind: "title", depth: element.depth, value: "" });
      } else if (isElement(element, DC_NS, "identifier")) {
        captures.push({
          kind: "identifier",
          depth: element.depth,
          value: "",
          id: attributeValue(element, "id"),
        });
      } else if (isElement(element, DC_NS, "language")) {
        captures.push({ kind: "language", depth: element.depth, value: "" });
      } else if (isElement(element, OPF_NS, "meta")) {
        const property = attributeValue(element, "property");
        if (property === "rendition:layout") {
          captures.push({ kind: "rendition_layout", depth: element.depth, value: "" });
        }
        if (attributeValue(element, "name")?.toLowerCase() === "cover") {
          epub2CoverId = attributeValue(element, "content");
        }
      } else if (isElement(element, OPF_NS, "item")) {
        const id = attributeValue(element, "id");
        const href = attributeValue(element, "href");
        if (id === undefined || href === undefined) return;
        const resolved = resolveReferencePath(path, href);
        const mediaType = attributeValue(element, "media-type");
        manifest.push({
          id,
          href,
          ...(resolved.requestedPath === undefined ? {} : { resolvedPath: resolved.requestedPath }),
          ...(mediaType === undefined ? {} : { mediaType }),
          properties: tokens(attributeValue(element, "properties")),
        });
      } else if (isElement(element, OPF_NS, "spine")) {
        spineToc = attributeValue(element, "toc");
      } else if (isElement(element, OPF_NS, "itemref")) {
        const linear = attributeValue(element, "linear")?.toLowerCase();
        const idref = attributeValue(element, "idref");
        spine.push({
          ...(idref === undefined ? {} : { idref }),
          ...(linear === undefined ? {} : { linear: linear !== "no" }),
        });
      }
    },
    onText(value) {
      for (const capture of captures) capture.value += value;
    },
    onCloseElement(element) {
      finishCaptures(element, captures, (capture) => {
        const value = capture.value.trim();
        if (capture.kind === "title") titles.push(value);
        else if (capture.kind === "language") languages.push(value);
        else if (capture.kind === "identifier") {
          identifiers.push({ ...(capture.id === undefined ? {} : { id: capture.id }), value });
        } else renditionLayout = value;
      });
    },
  });

  const projectedManifest = manifest.map((item) =>
    item.id === epub2CoverId && !item.properties.includes("cover-image")
      ? { ...item, properties: [...item.properties, "cover-image"] }
      : item,
  );
  const metadata: MetadataProjection = {
    titles,
    identifiers,
    languages,
    ...(uniqueIdentifier === undefined ? {} : { uniqueIdentifier }),
    ...(renditionLayout === undefined ? {} : { renditionLayout }),
  };
  return {
    path,
    version,
    metadata,
    manifest: projectedManifest,
    spine,
    ...(spineToc === undefined ? {} : { spineToc }),
  };
}

export async function parseContentProjection(
  source: XmlByteSource,
  path: InternalPath,
  mediaType: string,
  limits: SafeXmlLimits,
  signal: AbortSignal,
): Promise<ContentProjection> {
  const references: ContentProjection["references"][number][] = [];
  let scripted = false;
  let interactive = false;
  let bodyDepth: number | undefined;
  let hasUsefulContent = false;

  await parseSafeXml(source, limits, signal, {
    onOpenElement(element) {
      if (isElement(element, XHTML_NS, "body")) bodyDepth = element.depth;
      if (isElement(element, XHTML_NS, "script")) scripted = true;
      if (
        element.uri === XHTML_NS &&
        ["audio", "button", "canvas", "form", "input", "select", "textarea", "video"].includes(element.local)
      ) {
        interactive = true;
      }
      if (element.attributes.some((attribute) => attribute.local.toLowerCase().startsWith("on"))) {
        scripted = true;
      }

      const reference = contentReference(element);
      if (reference !== undefined) {
        const resolved = resolveReferencePath(path, reference.rawReference);
        references.push({
          ...reference,
          ...(resolved.requestedPath === undefined ? {} : { targetPath: resolved.requestedPath }),
          ...(resolved.fragment === undefined ? {} : { fragment: resolved.fragment }),
        });
      }
      if (bodyDepth !== undefined && isUsefulElement(element)) hasUsefulContent = true;
    },
    onText(value) {
      if (bodyDepth !== undefined && value.trim().length > 0) hasUsefulContent = true;
    },
    onCloseElement(element) {
      if (isElement(element, XHTML_NS, "body")) bodyDepth = undefined;
    },
  });

  return { path, mediaType, references, scripted, interactive, hasUsefulContent };
}

export const parseContainer = parseContainerProjection;
export const parsePackage = parsePackageProjection;
export const parseContentReferences = parseContentProjection;

interface TextCapture {
  readonly kind: "title" | "identifier" | "language" | "rendition_layout";
  readonly depth: number;
  readonly id?: string;
  value: string;
}

function finishCaptures(
  element: XmlCloseElement,
  captures: TextCapture[],
  finish: (capture: TextCapture) => void,
): void {
  for (let index = captures.length - 1; index >= 0; index -= 1) {
    if (captures[index].depth !== element.depth) continue;
    const [capture] = captures.splice(index, 1);
    finish(capture);
  }
}

function isElement(
  element: Pick<XmlOpenElement | XmlCloseElement, "uri" | "local">,
  uri: string,
  local: string,
): boolean {
  return element.uri === uri && element.local === local;
}

function attributeValue(element: XmlOpenElement, local: string, uri = ""): string | undefined {
  return element.attributes.find((attribute) => attribute.uri === uri && attribute.local === local)?.value;
}

function tokens(value: string | undefined): readonly string[] {
  return value?.trim().split(/\s+/u).filter(Boolean) ?? [];
}

function parseRootfilePath(value: string): InternalPath | undefined {
  try {
    const parsed = parseInternalPath(decodeURIComponent(value).normalize("NFC"));
    return parsed.ok && !parsed.value.isDirectory ? parsed.value.path : undefined;
  } catch {
    return undefined;
  }
}

function contentReference(
  element: XmlOpenElement,
): { readonly rawReference: string; readonly kind: ContentProjection["references"][number]["kind"] } | undefined {
  if (element.uri === XHTML_NS && element.local === "a") {
    return referenceFromAttribute(element, "href", "link");
  }
  if (element.uri === XHTML_NS && ["img", "image", "source"].includes(element.local)) {
    return referenceFromAttribute(element, "src", "image");
  }
  if (element.uri === SVG_NS && element.local === "image") {
    return (
      referenceFromAttribute(element, "href", "image") ?? referenceFromAttribute(element, "href", "image", XLINK_NS)
    );
  }
  if (element.uri === XHTML_NS && element.local === "link") {
    const relation = tokens(attributeValue(element, "rel")).map((value) => value.toLowerCase());
    return referenceFromAttribute(element, "href", relation.includes("stylesheet") ? "stylesheet" : "other");
  }
  if (element.uri === XHTML_NS && ["audio", "embed", "iframe", "script", "video"].includes(element.local)) {
    return referenceFromAttribute(element, "src", "other");
  }
  if (element.uri === XHTML_NS && element.local === "object") {
    return referenceFromAttribute(element, "data", "other");
  }
  return undefined;
}

function referenceFromAttribute(
  element: XmlOpenElement,
  local: string,
  kind: ContentProjection["references"][number]["kind"],
  uri = "",
): { readonly rawReference: string; readonly kind: typeof kind } | undefined {
  const rawReference = attributeValue(element, local, uri);
  return rawReference === undefined ? undefined : { rawReference, kind };
}

function isUsefulElement(element: XmlOpenElement): boolean {
  return (
    (element.uri === XHTML_NS && ["img", "object", "svg", "video"].includes(element.local)) || element.uri === SVG_NS
  );
}
