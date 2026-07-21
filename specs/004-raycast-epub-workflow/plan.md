# Implementation Plan: Self-Contained Raycast EPUB Workflow

**Branch**: `004-raycast-epub-workflow` | **Date**: 2026-07-20 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/004-raycast-epub-workflow/spec.md`

## Summary

Replace the SwiftUI, Calibre, Python, and desktop-distribution product with Book Sender, one public macOS Raycast extension exposing exactly one view command for Kindle delivery. The command accepts EPUB and PDF, runs EPUB inspection and deterministic repair internally, revalidates repaired copies, and submits one eligible book per SMTP message only after explicit delivery confirmation.

## Technical Context

**Language/Version**: TypeScript 6.0.x in strict mode; Node.js `>=22.22.2 <23`, matching the current `@raycast/api` runtime requirement

**Primary Dependencies**: React 19 and `@raycast/api` for the product surface; `yauzl` for central-directory ZIP inspection; `yazl` for ordered streaming ZIP reconstruction; `saxes` for bounded namespace-aware XML parsing; `nodemailer` for TLS-protected SMTP; `unicode-case-folding` for canonical path collision checks; `buffer-crc32` for streamed integrity checks. `@raycast/utils` is omitted unless implementation identifies a concrete use.

**Storage**: User-selected local EPUB inputs; same-directory temporary and final output paths; optional SMTP values in Raycast command preferences, with the application password declared as a password preference. No database, backend, book cache, report persistence, analytics, or secret duplication.

**Testing**: Vitest 4.x in Node environment with V8 coverage; deterministic TypeScript fixture builder for valid and adversarial ZIP bytes; focused domain, adapter, application, and thin command-contract tests. Every audit and repair rule maps to a fixture-backed test.

**Target Platform**: Public Raycast extension on supported macOS versions; package manifest restricts `platforms` to `macOS`

**Project Type**: Single npm package and single public Raycast extension at repository root

**Performance Goals**: 95% of healthy EPUBs up to 50 MB and 2,000 entries inspected within 10 seconds on the reference Mac; UI yields at least once per second; one active EPUB and one active archive entry at a time; batches of 20 return isolated results.

**Constraints**: EPUB-only; original bytes immutable; local inspection and repair; no Calibre, installed EPUBCheck, helper process, executable, runtime download, or remote processing; safety caps of 200 MB source, 10,000 entries, 100 MB per expanded entry, 1 GB expanded total, 100:1 expansion ratio, 10 MB XML, depth 64, and 120 seconds per file; no plaintext SMTP or disabled certificate validation.

**Scale/Scope**: Three commands; sequential snapshots of up to 20 acceptance-test files; EPUB 2 and EPUB 3 structural inspection; closed v1 finding catalog; deterministic repairs listed in the specification; one SMTP message with one attachment per eligible EPUB.

## Constitution Check

_GATE: Passed before Phase 0 research and passed again after Phase 1 design._

| Principle                              | Pre-Research Evaluation                                                                        | Post-Design Evaluation                                                                                                                |
| -------------------------------------- | ---------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| Minimum, EPUB-only scope               | PASS: exactly inspect, prepare, and send EPUB workflows; no conversion or reader/library scope | PASS: contracts expose only the three specified EPUB commands                                                                         |
| Self-contained Raycast extension       | PASS: one TypeScript/React package with pure JS/TS and Node APIs only                          | PASS: selected dependencies contain no native runtime binaries or helper services                                                     |
| Original immutability                  | PASS: source is read-only and outputs are separate                                             | PASS: same-directory temporary output is promoted to a collision-safe final path only after complete write and revalidation           |
| Safe deterministic repairs             | PASS: repair allowlist comes directly from the constitution and spec                           | PASS: the plan contract rejects ambiguous candidates and records exact changed entries                                                |
| Untrusted archive safety               | PASS: explicit ZIP, XML, size, ratio, count, timeout, and active-content limits exist          | PASS: central-directory preflight precedes content reads; streamed counters verify metadata; XML rejects DTDs and external resolution |
| Local processing and explicit delivery | PASS: only user-confirmed SMTP transmits a book                                                | PASS: inspect/prepare have no network adapter; send requires reviewed eligibility and confirmation; web fallback is a handoff only    |
| Evidence-based reports                 | PASS: health derives from typed findings                                                       | PASS: stable finding catalog and report contract define severity, location, repairability, evidence, and revalidation status          |
| Validate before and after repair       | PASS: full audit surrounds repair                                                              | PASS: comparison blocks Kindle-ready success for any newly introduced Error or Critical finding                                       |
| Domain-first typed architecture        | PASS: required dependency direction is adopted                                                 | PASS: commands depend on application ports; domain has no Raycast, ZIP-library, filesystem, or SMTP imports                           |
| Fixture-backed assurance               | PASS: every rule and repair requires a fixture                                                 | PASS: fixture matrix and deterministic adversarial ZIP builder are part of the test design                                            |
| Native Raycast interaction             | PASS: exactly one keyboard-first view command                                                  | PASS: Detail, Form, ActionPanel, native file/system actions, progress, and cancellation compose the UI without desktop-app imitation  |
| Privacy and credentials                | PASS: no telemetry or remote report storage; password uses secure preference type              | PASS: errors are allowlisted and sanitized; raw SMTP errors, paths, filenames, and content are never logged                           |
| Simple distribution                    | PASS: one package, no monorepo                                                                 | PASS: dependencies are individually justified; desktop release, appcast, scripts, and legacy products are removed                     |

No constitutional violation or exception is required.

## Phase 0: Research Outcomes

Research is consolidated in [research.md](./research.md). All technical unknowns are resolved:

- Raycast file intake, UI, secure preferences, progress, cancellation, and Store constraints
- Incremental ZIP preflight and reconstruction with EPUB-compliant `mimetype`
- Safe namespace-aware XML parsing and bounded decoding
- Explicit TLS SMTP delivery, cancellation semantics, and sanitized failures
- TypeScript, Node, lint, test, fixture, coverage, and publication toolchain
- Repository replacement boundary and final cleanup inventory

## Phase 1: Design Outcomes

- [data-model.md](./data-model.md) defines entities, validation rules, relationships, and state transitions.
- [contracts/commands.md](./contracts/commands.md) defines the three Raycast command interactions and batch semantics.
- [contracts/engine.md](./contracts/engine.md) defines typed application, audit, repair, archive, XML, filesystem, and cancellation boundaries.
- [contracts/findings.md](./contracts/findings.md) defines the closed v1 finding categories and stable codes.
- [contracts/delivery.md](./contracts/delivery.md) defines SMTP configuration, preflight, one-attachment submission, redaction, and uncertain outcomes.
- [quickstart.md](./quickstart.md) defines runnable end-to-end validation after implementation.

## Project Structure

### Documentation (this feature)

```text
specs/004-raycast-epub-workflow/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── commands.md
│   ├── delivery.md
│   ├── engine.md
│   └── findings.md
├── checklists/
│   └── requirements.md
└── tasks.md
```

`tasks.md` is created by `/speckit-tasks`, not by this planning command.

### Source Code (repository root)

```text
package.json
package-lock.json
tsconfig.json
eslint.config.js
prettier.config.js
vitest.config.ts
raycast-env.d.ts
README.md
LICENSE
assets/
└── extension-icon.png
src/
├── inspect-epub.tsx
├── prepare-epub-for-kindle.tsx
├── send-epub-to-kindle.tsx
├── commands/
│   ├── inspect-command.tsx
│   ├── prepare-command.tsx
│   ├── send-command.tsx
│   └── components/
├── application/
│   ├── inspect-epubs.ts
│   ├── prepare-epubs.ts
│   ├── send-epubs.ts
│   ├── select-epubs.ts
│   └── process-batch.ts
├── domain/
│   ├── models/
│   ├── audit/
│   │   ├── audit-epub.ts
│   │   ├── derive-health.ts
│   │   └── rules/
│   └── repair/
│       ├── create-repair-plan.ts
│       ├── apply-repair-plan.ts
│       └── compare-revalidation.ts
└── adapters/
    ├── archive/
    ├── xml/
    ├── filesystem/
    ├── delivery/
    └── raycast/
tests/
├── application/
├── domain/
│   ├── audit/
│   └── repair/
├── adapters/
├── commands/
├── support/
│   ├── fixture-builder.ts
│   ├── hashes.ts
│   └── test-filesystem.ts
└── fixtures/
    ├── valid/
    ├── mimetype/
    ├── container/
    ├── package/
    ├── content/
    ├── encrypted/
    └── malicious/
docs/
├── finding-catalog.md
├── privacy.md
├── publication.md
└── repair-policy.md
.github/workflows/ci.yml
```

**Structure Decision**: Keep Raycast-required entrypoints at `src/` as three one-export shims and place all view composition under `src/commands/`. Application services own workflow and batch orchestration. The pure domain owns health derivation, rule semantics, repair planning, and comparison. Adapters own all ZIP, XML, filesystem, SMTP, and Raycast APIs. Tests mirror these boundaries. The repository remains one package; no `packages/`, workspace, companion app, or retained legacy tree is permitted.

## Key Design Decisions

### Intake and Batch Processing

- Each command first snapshots `getSelectedFinderItems()` and falls back to a multi-select `Form.FilePicker` when no supported Finder selection exists.
- Extension matching is case-insensitive, then every path is revalidated as a readable regular file before work starts.
- Duplicate selected paths are collapsed by filesystem identity without exposing full paths in reports.
- Batches are sequential to bound memory. Failure isolation preserves completed results; cancellation stops future scheduling and cooperatively interrupts the active phase.
- The send command accepts multiple selected EPUBs to satisfy the shared intake contract, but submits one separately confirmed batch as one SMTP transaction per eligible file, each containing exactly one attachment. No automatic retry occurs.

### Archive and XML Safety

- `yauzl` reads the central directory lazily with one active entry. All entry metadata and path collisions are validated before content parsing or repair.
- Every content stream enforces actual byte counts and CRC, not only declared ZIP metadata.
- Exact, normalized, Unicode-folded, file/directory, absolute, traversal, backslash, NUL, symlink, special-file, encrypted, method, size, ratio, count, and aggregate conflicts become typed `Unsafe` findings or failures.
- `saxes` parses UTF-8 and UTF-16 XML incrementally with namespace URI/local-name matching, 10 MB and depth-64 limits, no XML 1.1, no DTD, no external entities, no local/remote resolution, and cancellation checkpoints between chunks.
- Content references are normalized relative to the owning document but may never escape the archive namespace.

### Repair and Atomic Output

- Plans contain only operations from the constitutional allowlist. A repair with zero or multiple plausible targets is not scheduled.
- Output naming is predicted as `<base>-kindle-ready.epub`, then `<base>-kindle-ready-2.epub`, `-3`, and so on. The plan does not create or reserve a visible final file before confirmation.
- Reconstruction emits canonical `mimetype` first with STORE and no local-header extras, then preserves unchanged entries in original relative order. Changed XML is bounded in memory; unchanged resources stream entry-to-entry.
- A random same-directory temporary name is never exposed as final. On success it is completely closed, reopened through a verified descriptor, fully audited, and compared. Only a final `Healthy` comparison with every confirmed operation applied is promoted using an atomic no-clobber hard link; an `EEXIST` collision selects the next suffix, and unsupported no-clobber promotion fails safely rather than overwriting.
- A failed comparison retains no Kindle-ready final file. Cleanup failure is reported without deleting originals or prior outputs.

### Reports and Health

- Health precedence is `Unsafe > Unsupported > Needs Review > Repairable > Healthy`.
- Any unresolved Warning, Error, or Critical finding prevents `Healthy`. A file is `Repairable` only when every relevant finding has a permitted operation. Any relevant nonrepairable or ambiguous finding produces `Needs Review` unless a higher state applies.
- Finding identity is stable code plus normalized internal location and relevant target identifier. Revalidation uses this identity to group resolved, remaining, and new findings.
- The v1 rule set is closed by [contracts/findings.md](./contracts/findings.md); “complete inspection” means accounting for every catalogued v1 rule as completed, not applicable, or safely stopped by a terminal preflight finding, not claiming full EPUBCheck equivalence or visual Kindle validation.

### Delivery

- SMTP supports implicit TLS and required STARTTLS only, certificate verification enabled, TLS 1.2 minimum, configurable port, and no plaintext mode.
- Command preferences remain optional so unconfigured users can still open the command and use manual Send to Kindle handoff.
- Before any network connection, the reviewed EPUB is copied through its verified descriptor to a random mode-0600 delivery snapshot, hashed against the reviewed health report, closed, and reopened for streaming. Only its basename is exposed to MIME; the snapshot is always cleaned up, and no local path or book metadata enters headers, body, or logs.
- SMTP `2xx` means “submitted to the SMTP server,” never guaranteed Kindle delivery.
- Cancellation before SMTP starts is definitive. After message data may have reached the server, interruption or timeout yields `delivery_unknown`; there is no automatic retry because duplicate delivery is possible.

### Migration and Publication

- Replace the root product with the npm package before deleting useful behavior references, then remove `PageForge/`, `PageForgeTests/`, `PageForge.xcodeproj/`, `legacy/`, desktop scripts, Sparkle appcast/release workflow, obsolete docs/assets/specs, and generated artifacts.
- Preserve `.specify/`, `.agents/`, and this feature's artifacts. Rewrite `AGENTS.md`, `README.md`, `.gitignore`, and CI for the new product.
- Keep only dependencies used by production or validation. Pin the lockfile, audit licenses, provide a 512x512 owned icon and MIT license, and run Store validation before publication.
- Published GitHub releases, appcast clients, repository metadata, and external desktop install links require an operational deprecation follow-up; they are not retained as a second implementation.

## Complexity Tracking

No constitutional violations require justification. The additional adapter directories correspond directly to required external boundaries: archive, XML, filesystem, SMTP delivery, and Raycast APIs.
