import { caseFold } from "unicode-case-folding";

import type { InternalPath } from "../models/archive";
import { err, ok, type Result } from "../models/result";

export type InternalPathError =
  | "absolute"
  | "traversal"
  | "empty"
  | "nul"
  | "backslash"
  | "invalid_unicode"
  | "invalid_directory_marker";

export interface ParsedInternalPath {
  readonly path: InternalPath;
  readonly isDirectory: boolean;
  readonly segments: readonly string[];
}

const DRIVE_PATH = /^[A-Za-z]:/;
const UNPAIRED_SURROGATE = /[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(^|[^\uD800-\uDBFF])[\uDC00-\uDFFF]/;

export function parseInternalPath(value: string): Result<ParsedInternalPath, InternalPathError> {
  if (value.length === 0) return err("empty");
  if (value.startsWith("/") || value.startsWith("\\\\") || DRIVE_PATH.test(value)) {
    return err("absolute");
  }
  if (value.includes("\0")) return err("nul");
  if (value.includes("\\")) return err("backslash");
  if (UNPAIRED_SURROGATE.test(value)) return err("invalid_unicode");

  const isDirectory = value.endsWith("/");
  if (isDirectory && value.endsWith("//")) return err("invalid_directory_marker");

  const pathWithoutMarker = isDirectory ? value.slice(0, -1) : value;
  const segments = pathWithoutMarker.split("/");
  if (segments.some((segment) => segment.length === 0)) return err("empty");
  if (segments.some((segment) => segment === "." || segment === "..")) return err("traversal");

  return ok({ path: value as InternalPath, isDirectory, segments });
}

export function withoutDirectoryMarker(path: InternalPath): string {
  return path.endsWith("/") ? path.slice(0, -1) : path;
}

export function internalPathCollisionKey(path: InternalPath): string {
  return caseFold(withoutDirectoryMarker(path).normalize("NFC"));
}

export function internalPathIdentity(path: InternalPath): string {
  return withoutDirectoryMarker(path).normalize("NFC");
}

export function referenceIdentity(path: InternalPath, fragment?: string): string {
  const normalizedFragment = fragment?.normalize("NFC") ?? "";
  return `${internalPathIdentity(path)}#${normalizedFragment}`;
}

export function isPathAncestor(ancestor: InternalPath, descendant: InternalPath): boolean {
  const prefix = `${withoutDirectoryMarker(ancestor)}/`;
  return withoutDirectoryMarker(descendant).startsWith(prefix);
}
