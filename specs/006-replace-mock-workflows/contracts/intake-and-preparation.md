# Contract: Intake and Book Preparation

## Shared intake

Finder and drag-and-drop submit ordered `[URL]` values to one intake service.
Each selected value produces an accepted or sanitized excluded outcome. Intake
validates regular-file status, readability, supported format, byte limits,
capacity, duplicate identity, source stability, and staged digest.

Security-scoped access is balanced around a streaming copy into an app-owned UUID
workspace. The original filename is metadata only and never selects a write path.

## PDF

A PDF is eligible only after:

- size and attachment limits pass;
- the staged snapshot is stable;
- a bounded signature check identifies PDF content;
- its staged-byte digest is recorded.

PDF bytes are not converted, rewritten, normalized, or parsed for content.

## EPUB archive boundary

Before entry content is read, preflight rejects unsafe or ambiguous paths,
canonical/case collisions, links and special entries, encryption, unsupported
compression, inconsistent sizes, excessive entry count, compressed/expanded
bytes, per-entry expansion ratio, total memory, cancellation, and timeout.

Directory entries are handled explicitly and do not bypass path validation.
Per-open archive state is cleared before enumeration.

## XML boundary

XML processing:

- uses bounded byte buffers;
- preserves nested element structure and namespaces;
- disables external entities and DTD loading;
- rejects DTD/entity declarations and external local or remote reads;
- enforces depth, element, attribute, total text, time, and cancellation limits.

Remote references become typed findings where the document can be inspected
safely; no referenced resource is fetched.

## Audit and repair

The audit covers every shipped finding code for `mimetype`, container, package,
manifest/media types, internal references, encryption, active content, remote
references, unsafe archive structure, and unsafe XML.

An automatic action is executable only when:

1. evidence identifies one correction;
2. its precondition is true;
3. content meaning is preserved;
4. the writer implements the action;
5. a focused fixture proves positive and ambiguous-negative behavior;
6. revalidation proves its postcondition.

## Writing and readiness

Every eligible EPUB is written as `prepared.partial.epub` with first
uncompressed exact `mimetype`, bounded entry streaming, and only plan-authorized
changes. The file is closed, reopened through the same safety adapter, audited,
compared, and promoted to `prepared.epub` only when all eligibility conditions
pass.

Failure or cancellation removes partial output and preserves the staged source
and selected original. Findings, applied actions, comparison, and digest remain
available to tests and actionable inline disclosure.

## Required fixture families

Valid EPUB 2/3, valid PDF, invalid PDF signature, missing/late/compressed/invalid
`mimetype`, missing/invalid/ambiguous container and package, manifest media type,
unique and ambiguous references, encryption/DRM, active content, remote
reference, traversal, absolute/invalid paths, duplicate normalized paths, links,
unsupported compression, size/count/ratio boundaries, DTD/entity, nested/deep
XML, excessive attributes/text, cancellation, timeout, write failure, and
revalidation regression.
