# Contract: EPUB Safety, Audit, and Repair

## Archive preflight

Before extracting content, the adapter enumerates the central directory and
rejects:

- absolute, escaping, empty, invalid UTF-8, or ambiguous normalized paths;
- `..` traversal and platform path separator tricks;
- duplicate or case/normalization-colliding entries;
- symlinks, hard links, devices, and unsupported entry types;
- encryption, unsupported compression, or inconsistent sizes;
- excessive entry count, compressed bytes, expanded bytes, aggregate bytes,
  per-entry expansion ratio, processing time, or memory.

Numeric limit values are centralized, versioned, tested at `limit - 1`, `limit`,
and `limit + 1`, and documented in implementation tasks.

## XML boundary

Only bounded byte buffers enter `XMLParser`. Namespace processing is enabled;
external entities and external DTD loading are disabled; DTD/entity declarations,
remote resource reads, excessive depth, elements, attributes, text, and parse
time produce typed rejection. XML never reads referenced local or remote content.

## Automatic action rule

An action is automatic only if:

1. its finding has concrete stable evidence;
2. there is exactly one supported correction;
3. the correction preserves content meaning;
4. its preconditions can be checked before writing;
5. its postcondition can be checked after writing;
6. a focused fixture proves success and non-application to ambiguous cases.

Ambiguous, editorial, destructive, DRM-related, or content-inventing actions are
forbidden.

## Writing

The working archive is written under an app-owned UUID path to
`prepared.partial.epub`. EPUB `mimetype` is the first local entry, stored without
compression and contains the exact required media type. Remaining permitted
entries are streamed without escaping the workspace. Closing the writer does not
make the file ready.

## Revalidation

The adapter reopens the written archive through the same safety path. The domain
reruns audit and compares reports. Promotion to `prepared.epub` requires verified
actions, all eligibility rules, and no introduced critical finding. Failure
removes partial output and preserves the source snapshot and original.

## Required fixture families

Valid EPUB 2/3, invalid/late/compressed `mimetype`, missing/ambiguous container,
single/multiple package, bad media types, uniquely resolvable/broken references,
encrypted content, traversal, absolute paths, duplicate paths, links, invalid
names, unsupported compression, ZIP bomb boundaries, external entities, DTD,
deep/large XML, remote references, cancellation, and revalidation regression.
