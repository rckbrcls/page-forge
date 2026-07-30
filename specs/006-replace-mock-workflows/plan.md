# Implementation Plan: Replace Mock Workflows

**Feature ID**: `006-replace-mock-workflows` | **Repository Branch**: `main` | **Date**: 2026-07-29 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/006-replace-mock-workflows/spec.md`

## Summary

Complete the existing native Book Sender application so every visible state is
backed by real local preparation or an observed SMTP result. Delete the preview
route and its parallel item model, make `PipelineActor` the authoritative batch
owner, harden setup persistence around protected credentials, complete bounded
EPUB audit/repair/write/revalidation, implement the already-planned
SwiftNIO/NIOSSL SMTP state machine, and project all real item outcomes into the
two-screen interface.

This is an incremental completion of the current `BookSender` target, not another
migration. It reuses the existing exact package set, App Sandbox entitlements,
domain vocabulary, native Settings window, Sparkle channel, and synchronized
Xcode groups. No new dependency, target, process, product surface, or third
primary screen is required.

## Technical Context

**Language/Version**: Swift 6.0 with complete concurrency checking

**Primary Dependencies**: SwiftUI, AppKit, Observation, Foundation,
Security.framework, CryptoKit, UniformTypeIdentifiers; exact package versions
already resolved in the project: KeyboardShortcuts 3.0.1, ZIPFoundation 0.9.19,
swift-nio 2.86.0, swift-nio-ssl 2.35.0, and Sparkle 2.9.2

**Storage**: Traditional file-based macOS Keychain for the SMTP credential;
`UserDefaults`
for non-secret setup and shortcut preferences only; app-owned UUID temporary
workspaces for staged inputs, partial writes, and revalidated EPUB copies; no
persistent batch, book path, or delivery history

**Testing**: Swift Testing for domain, application, archive, XML, filesystem,
credential, MIME, SMTP, and pipeline contracts; NIOEmbedded for deterministic
protocol state; XCTest/XCUITest for UI, accessibility, performance, and complete
journeys; native deterministic EPUB/PDF and malicious fixtures

**Target Platform**: macOS 26.0 or later

**Project Type**: One native macOS application with one unit-test target and one
UI-test target

**Performance Goals**: Correct primary screen interactive within two seconds for
at least 95% of normal launches; accepted shortcut focused within one second for
at least 95% of invocations; responsive cancellation and status controls without
visible stalls longer than one second; a mixed 20-book acceptance batch completes
with independent outcomes

**Constraints**: Exactly two primary screens; auxiliary Settings limited to
`Delivery` and `Shortcut`; local processing; immutable originals; secure
explicit SMTP only; one active preparation and delivery attempt; bounded
archive/XML/MIME work; no preview state, fake readiness, external ebook engine,
helper process, executable download, conversion, DRM removal, analytics, or
hidden network request

**Scale/Scope**: Temporary ordered batches; enforce the centralized hard batch
and per-file safety limits, while proving the specified 20-item acceptance
capacity; sequential preparation and independent sequential delivery

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design._

### Pre-research gate

**Status: PASS**

- **Mission and surface**: The feature removes a preview bypass and completes
  setup, intake, preparation, confirmation, delivery, recovery, Settings, and
  shortcut behavior without adding a primary screen.
- **Native boundary**: The existing Swift/SwiftUI target and its exact source
  packages are sufficient. No helper, external engine, executable download, or
  parallel product is introduced.
- **Minimal interaction**: The UI retains concise real states and exposes detail
  only for blocked, restored, failed, or uncertain items. Invented progress and
  simulated readiness are deleted.
- **Background pipeline**: Every EPUB follows bounded safety, audit, deterministic
  plan, separate-copy writing, reopen, revalidation, and comparison. PDF remains
  unchanged.
- **Original preservation**: All work uses the staged read-only snapshot and an
  app-owned workspace. Partial promotion, digest comparison, cleanup, and orphan
  sweep are explicit work items.
- **Input safety**: The design fills the current archive/XML gaps for encryption,
  compression, links, path ambiguity, limits, active content, references,
  cancellation, memory, and time.
- **Batch reliability**: The actor freezes value snapshots rather than mutable
  IDs, processes sequentially, isolates failures, preserves completed results,
  and owns cancellation and retry rules.
- **Delivery and privacy**: A transient credential read occurs only after
  explicit confirmation. TLS, SMTP DATA uncertainty, redaction, and zero hidden
  egress are mandatory.
- **Architecture and tests**: `AppModel` becomes presentation-only; the actor and
  application services own orchestration; adapters own framework behavior; every
  automatic rule receives a focused native fixture.
- **Migration and distribution**: Legacy removal is already recorded. This
  feature updates provisional documentation only after runtime gates pass and
  preserves separate compilation, tests, authenticated SMTP, signing, update,
  and release claims.

### Post-design gate

**Status: PASS**

The data model and contracts below resolve setup consistency, authoritative
batch ownership, immutable confirmation, real preparation evidence, SMTP
uncertainty, explicit retry, auxiliary Settings, shortcut routing, fixture
coverage, and validation boundaries without a constitutional exception.

## Project Structure

### Documentation (this feature)

```text
specs/006-replace-mock-workflows/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── checklists/
│   └── requirements.md
└── contracts/
    ├── setup-routing-and-storage.md
    ├── intake-and-preparation.md
    ├── batch-and-smtp-delivery.md
    └── ui-settings-and-shortcut.md
```

`tasks.md` remains deferred to `/speckit-tasks`.

### Source Code (repository root)

```text
BookSender/
├── App/
│   ├── AppModel.swift
│   ├── BookSenderApp.swift
│   └── WindowCoordinator.swift
├── Features/
│   ├── DeliverySetup/
│   ├── SendBook/
│   └── Settings/
├── Application/
│   ├── Delivery/
│   │   ├── DeliverySetupService.swift
│   │   └── BookDeliveryService.swift          # new
│   ├── Intake/
│   │   └── BookIntakeService.swift
│   ├── Pipeline/
│   │   ├── PipelineActor.swift
│   │   └── BatchCommandService.swift
│   ├── Presentation/
│   └── Shortcut/
├── Domain/
│   ├── Audit/
│   ├── Delivery/
│   ├── Models/
│   ├── Ports/
│   └── Repair/
├── Adapters/
│   ├── Archive/
│   ├── Credentials/
│   ├── Filesystem/
│   ├── SMTP/
│   │   ├── MIMEMessageEncoder.swift
│   │   └── NIOSMTPClient.swift                # new
│   └── XML/
└── Resources/
BookSenderTests/
├── Adapters/
├── Application/
├── Domain/
├── Fixtures/
├── Integration/
└── Support/
    └── FixtureFactory.swift                   # new
BookSenderUITests/
```

**Structure Decision**: Complete the current filesystem-synchronized
`BookSender` project in place. Keep the existing dependency direction and
compose concrete adapters only at the app/application boundary. Delete
`BookSender/Features/SendBook/PreviewBookItem.swift` and
`BookSenderTests/Application/PreviewBookIntakeTests.swift`; no replacement mock,
parallel model, or test-only production route is permitted.

## Design

### 1. Setup and route validity

`DeliverySetupService` remains the single setup boundary. A complete setup means
validated non-secret values plus an existing readable credential reference.
Load checks credential existence without exposing the secret to `AppModel`.

Credential replacement uses a new revision-scoped Keychain reference. The
service stores the new credential, persists the new non-secret setup, then
deletes the superseded reference only after persistence succeeds. Failure deletes
only the new reference and leaves the last valid setup intact. Saving with a
blank password reuses the existing reference. Setup edits are disabled while a
confirmed send is active so a credential cannot disappear beneath an attempt.

`AppModel` routes to `Send Book` only from a validated load/save result. Missing
or unreadable credential state returns to `Delivery Setup` with non-secret draft
values preserved and a sanitized credential action.

### 2. One authoritative batch pipeline

`PipelineActor` becomes the sole mutable owner of `CurrentBatch`. `AppModel` no
longer appends, replaces, or removes an independent item array; it projects actor
snapshots/events onto `@MainActor` presentation state.

Both intake surfaces continue to pass `[URL]` through `BookIntakeService`.
Intake returns ordered typed outcomes for accepted, duplicate, unsupported,
unreadable, changed, oversized, and over-capacity inputs instead of silently
dropping failures. Accepted files are streamed into UUID workspaces, then
fingerprinted from staged bytes. A bounded PDF signature/size eligibility check
produces a prepared immutable snapshot without parsing or rewriting content.

The actor queues intake and EPUB preparation sequentially, publishes real
checking/preparing/ready/attention events, enforces batch and operation limits,
and retains cancellable tasks. New input may append only outside an active
confirmed snapshot.

### 3. Complete EPUB preparation

The archive preflight clears per-open state and validates paths, canonical and
case collisions, directories, links, encryption, compression method, entry
counts, compressed/expanded sizes, per-entry ratio, total limits, cancellation,
and timeout before content reads.

The audit implements every shipped `FindingCode`: EPUB `mimetype`, container and
package selection, manifest media types, internal references, encryption/DRM
classification, active content, and remote references. XML projection becomes
structurally correct for nested elements and enforces bounded bytes, depth,
elements, attributes, total text, external entities, remote reads, cancellation,
and timeout.

`EPUBRepairEngine` returns a complete `PreparationResult` containing the original
audit, plan, applied actions, prepared audit, comparison, digest, and prepared
book. An EPUB is never delivered from the original selection or unvalidated
snapshot: healthy and repairable EPUBs are written as separate bounded working
copies, reopened, re-audited, compared, and promoted only when eligible.

`EPUBArchiveWriter` executes only actions present in the plan, streams one
bounded entry at a time, preserves required resources and ordering, writes the
first uncompressed `mimetype`, and removes partial output on every failure or
cancellation. Unsupported repair actions stay blocked until a fixture proves
their preconditions, write behavior, and postconditions.

### 4. Stable confirmation and real delivery

Final confirmation asks `PipelineActor` to freeze a
`ConfirmedBatchSnapshot` containing value copies of the validated setup and
ordered `ConfirmedBatchItem` values with prepared file references and digests.
The actor transitions out of editing before exposing the snapshot; later UI
changes cannot mutate the approved set.

`BookDeliveryService` reads the credential transiently from the protected store
after confirmation and passes it directly to one `NIOSMTPClient` attempt. The
credential never enters `AppModel`, snapshots, events, logs, or stored batch
state.

`NIOSMTPClient` uses one connection per book. It supports implicit TLS and
STARTTLS with a second EHLO, TLS 1.2 or later, certificate and hostname
verification, AUTH PLAIN/LOGIN only after TLS, bounded multiline replies,
sanitized envelope commands, stage timeouts, streamed MIME/base64,
dot-stuffing, cancellation, and best-effort QUIT.

The attempt marks `dataTransmissionStarted` only after the server accepts DATA
and the first message byte is written. Final `250` means `Submitted`; definitive
rejection means `Failed`; cancellation before DATA means `Cancelled`; connection
loss, timeout, or cancellation after DATA starts without a definitive final
reply means `Delivery Unknown`.

### 5. Recovery, Settings, and shortcut

The actor preserves completed outcomes and marks unscheduled confirmed items
cancelled. `Retry Failed` creates a fresh explicit snapshot containing only
definitively failed items; `Delivery Unknown` is never included automatically.
Remove and clear operate only when the actor is not sending or cancelling.

`SendBookView` exposes cancel during active preparation/delivery, retry after
definitive failures, and the existing remove/clear actions using actor-derived
availability. Technical findings stay collapsed except for actionable detail.

Settings remains an auxiliary two-tab window. Delivery edits reuse the
transactional setup service. `ShortcutPreference` becomes the source for enabled,
disabled, registered, and conflict presentation. Shortcut invocation reconciles
the route from validated setup state, activates the app, and reveals or reopens
the captured main window; it never selects, confirms, or sends a book.

### 6. Test and release cutover

Create native deterministic fixture bytes and a manifest with local provenance,
original digests, expected findings, repair actions, and readiness. Replace every
preview test with real intake, preparation, pipeline, and UI coverage. UI-test
launch state uses explicitly isolated stores and credentials rather than
unconsumed launch arguments or residual user defaults.

README and release notes retain the current experimental/unavailable statement
until compilation, automated contracts, controlled SMTP integration, manual
authorized provider delivery, accessibility, performance, and privacy gates pass.
The release workflow must run the approved test suite before publishing a version
that claims real delivery. Pinned self-signed signing, exact designated
requirement verification, Sparkle EdDSA, appcast, clean-account installation,
credential continuity, and public artifact verification remain separate release
gates.

## Implementation Sequence

1. Preserve the current dirty worktree and add failing acceptance coverage for
   preview absence, setup transactions, typed intake outcomes, real fixtures,
   batch snapshots, and SMTP state.
2. Remove all preview-only source, tests, conditions, identifiers, and UI
   controls; keep the send route reachable only through valid setup.
3. Make setup load/save transactional and credential-aware; add isolated
   preferences and Keychain tests.
4. Make `PipelineActor` authoritative; replace duplicate `AppModel` mutation with
   complete event/snapshot projection and cancellable commands.
5. Implement typed intake exclusions, PDF validation, digests, batch limits,
   workspace cleanup, and startup orphan sweep.
6. Complete archive/XML boundaries, audit rules, deterministic repair actions,
   streaming writing, revalidation, evidence projection, and fixture coverage.
7. Add `BookDeliveryService` and `NIOSMTPClient`; prove protocol transitions and
   DATA uncertainty with deterministic transcripts and controlled TLS.
8. Wire explicit confirmation, cancel, failed-only retry, clear/remove, Settings,
   shortcut conflict/routing, and real terminal outcomes into the UI.
9. Run the independent static, compilation, unit, UI, runtime, authenticated
   delivery, accessibility, performance, privacy, signing, update, and release
   gates in order. Update provisional documentation only when its corresponding
   gate passes.

## Verification Strategy

Verification is deliberately split into:

1. Static structure, placeholder absence, project/plist, dependency, and
   forbidden-reference checks.
2. Swift 6 compilation with complete concurrency checking.
3. Unit and integration contracts using deterministic files, transcripts, and
   controlled local TLS.
4. UI and accessibility automation using isolated test state.
5. Manual runtime acceptance for setup, intake, EPUB/PDF preparation, batch
   recovery, shortcut, performance, and original preservation.
6. Separately authorized real-provider SMTP delivery with redacted evidence.
7. Pinned self-signed signing, designated requirement verification, Sparkle
   signature/appcast, archive inspection, clean-account installation, credential
   continuity, update, publication, and public artifact verification.

Passing one gate never implies a later gate. This planning command executes none
of the build, test, runtime, provider, signing, or release commands listed in
[quickstart.md](./quickstart.md).

## Complexity Tracking

No constitution violations require justification.
