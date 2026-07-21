import type { InternalPath } from "../models/archive";
import { internalPathCollisionKey, parseInternalPath } from "./internal-path";

export type ReferenceResolutionKind =
  | "exact"
  | "unique_equivalent"
  | "missing"
  | "ambiguous_equivalent"
  | "external"
  | "invalid";

export interface ReferenceResolution {
  readonly kind: ReferenceResolutionKind;
  readonly rawReference: string;
  readonly fragment?: string;
  readonly requestedPath?: InternalPath;
  readonly targetPath?: InternalPath;
  readonly equivalentTargets: readonly InternalPath[];
}

const URI_SCHEME = /^[A-Za-z][A-Za-z0-9+.-]*:/;

export function resolveReferencePath(
  ownerPath: InternalPath,
  rawReference: string,
): Omit<ReferenceResolution, "kind" | "targetPath" | "equivalentTargets"> & {
  readonly kind: "unresolved" | "external" | "invalid";
} {
  const hashIndex = rawReference.indexOf("#");
  const beforeFragment = hashIndex < 0 ? rawReference : rawReference.slice(0, hashIndex);
  const rawFragment = hashIndex < 0 ? undefined : rawReference.slice(hashIndex + 1);
  const queryIndex = beforeFragment.indexOf("?");
  const rawPath = queryIndex < 0 ? beforeFragment : beforeFragment.slice(0, queryIndex);
  const fragment = decodeComponent(rawFragment);

  if (
    fragment === null ||
    hasControlCharacter(rawReference) ||
    (fragment !== undefined && hasControlCharacter(fragment))
  ) {
    return { kind: "invalid", rawReference };
  }
  if (URI_SCHEME.test(rawPath) || rawPath.startsWith("//")) {
    return { kind: "external", rawReference, ...(fragment === undefined ? {} : { fragment }) };
  }

  const decodedPath = decodeComponent(rawPath);
  if (
    decodedPath === null ||
    decodedPath.startsWith("/") ||
    decodedPath.includes("\\") ||
    hasControlCharacter(decodedPath)
  ) {
    return { kind: "invalid", rawReference, ...(fragment === undefined ? {} : { fragment }) };
  }

  const ownerSegments = ownerPath.split("/");
  if (ownerSegments.length === 0 || ownerPath.endsWith("/")) {
    return { kind: "invalid", rawReference, ...(fragment === undefined ? {} : { fragment }) };
  }
  ownerSegments.pop();

  const segments = rawPath.length === 0 ? ownerPath.split("/") : ownerSegments;
  if (rawPath.length > 0) {
    for (const segment of decodedPath.split("/")) {
      if (segment.length === 0 || segment === ".") continue;
      if (segment === "..") {
        if (segments.length === 0) {
          return { kind: "invalid", rawReference, ...(fragment === undefined ? {} : { fragment }) };
        }
        segments.pop();
      } else {
        segments.push(segment);
      }
    }
  }

  const parsed = parseInternalPath(segments.join("/"));
  if (!parsed.ok || parsed.value.isDirectory) {
    return { kind: "invalid", rawReference, ...(fragment === undefined ? {} : { fragment }) };
  }
  return {
    kind: "unresolved",
    rawReference,
    requestedPath: parsed.value.path,
    ...(fragment === undefined ? {} : { fragment }),
  };
}

export function resolveReference(
  ownerPath: InternalPath,
  rawReference: string,
  availablePaths: Iterable<InternalPath>,
): ReferenceResolution {
  const pathResolution = resolveReferencePath(ownerPath, rawReference);
  if (pathResolution.kind !== "unresolved" || pathResolution.requestedPath === undefined) {
    return { ...pathResolution, equivalentTargets: [] };
  }

  const paths = [...availablePaths];
  const exact = paths.find((path) => path === pathResolution.requestedPath);
  if (exact !== undefined) {
    return { ...pathResolution, kind: "exact", targetPath: exact, equivalentTargets: [] };
  }

  const key = internalPathCollisionKey(pathResolution.requestedPath);
  const equivalents = paths.filter((path) => internalPathCollisionKey(path) === key);
  if (equivalents.length === 1) {
    return {
      ...pathResolution,
      kind: "unique_equivalent",
      targetPath: equivalents[0],
      equivalentTargets: equivalents,
    };
  }
  return {
    ...pathResolution,
    kind: equivalents.length === 0 ? "missing" : "ambiguous_equivalent",
    equivalentTargets: equivalents,
  };
}

function decodeComponent(value: string | undefined): string | undefined | null {
  if (value === undefined) return undefined;
  try {
    return decodeURIComponent(value).normalize("NFC");
  } catch {
    return null;
  }
}

function hasControlCharacter(value: string): boolean {
  for (let index = 0; index < value.length; index += 1) {
    const code = value.charCodeAt(index);
    if (code === 0 || code < 0x20 || code === 0x7f) return true;
  }
  return false;
}
