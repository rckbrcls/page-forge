# Implementation Plan: Lightweight macOS Book Sender

**Feature ID**: `005-lightweight-macos-sender` | **Repository Branch**: `main` | **Date**: 2026-07-28 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/005-lightweight-macos-sender/spec.md`

## Summary

Replace the repository's Raycast, Node.js, Calibre-oriented, and obsolete
`PageForge` surfaces with one sandboxed native macOS application named
`Book Sender`. The application has exactly two primary SwiftUI screens:
`Delivery Setup` and `Send Book`, plus one auxiliary native Settings window
limited to `Delivery` and `Shortcut` tabs. It accepts temporary batches of EPUB
and PDF files, prepares them locally and sequentially through a typed safety,
audit, deterministic repair, working-copy, and revalidation pipeline, then
sends each eligible book through an independent explicitly confirmed SMTP
attempt.

The macOS 26 shell uses one adaptive behind-window material across the complete
window, including the titlebar area. Liquid Glass remains limited to the drop
target and primary actions so the content layer stays legible and visually calm.

Migration uses a staged replacement: create the clean `BookSender` target beside
the existing code, port behavior and fixtures into the new dependency direction,
prove the native product against the contracts in this directory, switch project
and release references atomically, and only then delete the obsolete products.
No legacy deletion occurs during planning.

## Technical Context

**Language/Version**: Swift 6, Swift language mode 6, complete concurrency checking

**Primary Dependencies**: SwiftUI, AppKit including `NSVisualEffectView`,
Observation, Foundation, Security.framework, UniformTypeIdentifiers,
ZIPFoundation `0.9.x` pinned to an exact compatible release,
KeyboardShortcuts `3.0.1`, swift-nio and swift-nio-ssl pinned to exact mutually
compatible releases

**Storage**: Data Protection Keychain for the SMTP app password; `UserDefaults`
for non-secret setup and shortcut preferences; security-scoped user-selected
inputs copied by streaming into UUID-named temporary batch workspaces; no
persistent queue, history, source bookmarks, or prepared-book cache

**Testing**: Swift Testing for domain, pipeline, filesystem, archive, XML,
credential, and SMTP contracts; XCTest/XCUITest for UI, accessibility, and
performance; deterministic EPUB, malicious archive/XML, repair, batch, and SMTP
fixtures

**Target Platform**: macOS 26.0 and later, Apple silicon and Intel where supported
by the selected stable Xcode 26 toolchain

**Project Type**: One native sandboxed macOS application, one unit-test target,
and one UI-test target

**Performance Goals**: Correct primary screen interactive within two seconds for
at least 95% of reference launches; accepted shortcut visible and focused within
one second; UI remains responsive throughout a sequential batch of 20 books;
archive/XML work remains within explicit per-item resource limits

**Constraints**: Exactly two primary screens; one primary window; one auxiliary
Settings window limited to delivery edits and shortcut preferences; adaptive
behind-window material; Liquid Glass only for important functional controls;
legibility with Reduce Transparency and Increase Contrast; local processing;
explicit SMTP confirmation; immutable originals; sequential batch; no Raycast,
Calibre, installed EPUBCheck, ebook-processing helper, executable download,
conversion, DRM removal, backend, analytics, or hidden transmission

**Scale/Scope**: One temporary ordered batch of up to 20 supported books within
individual safety and provider limits; one active preparation/archive operation
or SMTP attempt at a time; per-book failure isolation

## Constitution Check

### Pre-design gate

**Status: PASS**

- **Mission and surface**: The plan contains only `Delivery Setup` and
  `Send Book` as primary screens. The native Settings window is auxiliary and
  contains only delivery editing and shortcut preferences.
- **Native boundary**: The final product is one Swift/SwiftUI macOS app. Ebook
  processing remains inside the app process; Sparkle's embedded services are
  limited to application updates and add no downloadable executable.
- **Minimal interaction**: Views render derived states and actionable inline
  detail. They do not expose the audit engine as navigation.
- **Adaptive materials**: The macOS 26 window uses one system behind-window
  material, preserves standard window controls, and reserves Liquid Glass for
  the drop target and primary actions.
- **Background pipeline**: EPUB processing follows safety check, audit,
  deterministic repair, separate-copy write, and revalidation. PDF bytes are
  unchanged.
- **Original preservation**: User-selected inputs are read-only and snapshotted
  to private temporary workspaces. Outputs never replace originals.
- **Input safety**: Archive and XML adapters enforce typed path, entry, byte,
  ratio, depth, entity, link, memory, and time limits before readiness.
- **Batch reliability**: Confirmation freezes an ordered snapshot; a pipeline
  actor processes it sequentially, isolates results, and cooperatively cancels.
- **Delivery and privacy**: Only explicit SMTP delivery leaves the device.
  Secrets live in Keychain and are absent from presentation and diagnostics.
- **Architecture and tests**: Dependencies point from SwiftUI to application to
  domain to adapters. Every automatic rule requires a focused fixture.
- **Migration and distribution**: Obsolete products are deleted only after the
  native replacement passes independent static, compilation, test, runtime,
  ad-hoc signing, update, and release gates.

### Post-design gate

**Status: PASS**

The data model and contracts preserve the two-screen boundary, typed evidence,
stable sequential batches, immutable originals, strict untrusted-input limits,
explicit transmission, protected credentials, adaptive appearance, and
independent migration gates. No constitutional exception or complexity waiver
is required.

## Project Structure

### Documentation (this feature)

```text
specs/005-lightweight-macos-sender/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── checklists/
│   └── requirements.md
└── contracts/
    ├── background-pipeline.md
    ├── epub-safety-and-repair.md
    ├── migration-cutover.md
    ├── smtp-delivery.md
    ├── storage-and-credentials.md
    └── ui-and-shortcut.md
```

`tasks.md` is intentionally deferred to `/speckit.tasks`.

### Final source layout

```text
BookSender.xcodeproj/
BookSender/
├── App/
│   ├── BookSenderApp.swift
│   ├── AppModel.swift
│   └── WindowCoordinator.swift
├── Features/
│   ├── DeliverySetup/
│   ├── SendBook/
│   └── Settings/
├── Application/
│   ├── Intake/
│   └── Pipeline/
├── Domain/
│   ├── Audit/
│   ├── Repair/
│   └── Models/
├── Adapters/
│   ├── Archive/
│   ├── XML/
│   ├── Filesystem/
│   ├── SMTP/
│   └── Credentials/
├── Resources/
│   └── Assets.xcassets/
└── BookSender.entitlements
BookSenderTests/
├── Domain/
├── Application/
├── Adapters/
└── Fixtures/
BookSenderUITests/
```

**Structure Decision**: Build a clean `BookSender` source tree and targets rather
than rename the mixed legacy tree in place. During migration, the current
TypeScript implementation and selected Swift code are read-only behavioral
references. Reusable patterns are reimplemented inside the final dependency
direction; obsolete files are not copied wholesale. The final repository has no
production source outside `BookSender/**/*.swift`.

## Architecture

### Presentation

`BookSenderApp` owns one `WindowGroup("Book Sender", id: "main")`. Its root
chooses `DeliverySetupView` until setup is complete and `SendBookView`
afterwards. `AppModel` is `@MainActor @Observable`; it translates application
events into minimal view state. No archive, XML, repair, filesystem, credential,
or SMTP rule is allowed in a SwiftUI view.

The configurable global shortcut uses KeyboardShortcuts. `WindowCoordinator`
activates the app and reuses the existing main window without creating another
batch or triggering delivery. The app removes the standard new-window command.

### Application pipeline

`BookIntakeService` normalizes Finder and drag-and-drop URLs into the same intake
path. It briefly acquires security scope, copies each accepted file by streaming
into private staging, then releases the scope. `PipelineActor` owns the mutable
batch operation and emits `AsyncStream<PipelineEvent>` values to `AppModel`.

After explicit confirmation, the actor freezes a `ConfirmedBatchSnapshot` and
iterates it in order. Every long-running adapter accepts cooperative
cancellation. No `TaskGroup` schedules books concurrently.

### Domain

Immutable `Sendable` models describe setup, files, findings, health,
repairability, repair plans, applied actions, revalidation comparisons, batch
state, and delivery outcomes. The domain decides whether a book is eligible;
adapters only report typed observations and failures.

### Adapters

- ZIPFoundation reads and writes ZIP entries by streaming behind a strict EPUB
  archive adapter. It never extracts a whole untrusted archive without preflight.
- Foundation `XMLParser` resolves no external entities and parses only bounded
  data through delegates with explicit structural limits.
- The filesystem adapter owns UUID workspaces, `.partial` promotion, safe cleanup,
  and byte-for-byte original preservation assertions.
- A narrow SMTP state machine over SwiftNIO and NIOSSL supports implicit TLS and
  STARTTLS, TLS-only authentication, multiline replies, MIME streaming,
  dot-stuffing, timeouts, cancellation, and `delivery_unknown`.
- Security.framework stores the app password in the Data Protection Keychain.

## Migration and Removal Sequence

1. **Freeze the behavioral baseline**: inventory current TypeScript rules,
   fixtures, SMTP behaviors, Swift design tokens, Keychain patterns, intake
   behavior, release inputs, and unrelated dirty worktree changes.
2. **Create the native shell**: add `BookSender.xcodeproj`, the three final
   targets, sandbox entitlements, two screens, the single-window coordinator,
   and the shortcut boundary without deleting old sources.
3. **Port models and fixtures**: translate the typed audit/repair/result
   vocabulary and malicious/valid EPUB fixtures into Swift. Preserve stable rule
   identifiers so behavior can be compared.
4. **Implement safe local preparation**: replace every `Process`,
   `/usr/bin/zip`, `/usr/bin/unzip`, Calibre, conversion, and external-tool path
   with the bounded in-process archive/XML/filesystem pipeline.
5. **Implement batch orchestration**: shared intake, stable confirmation
   snapshot, sequential processing, cancellation, minimal events, and per-item
   isolation.
6. **Implement protected setup and delivery**: Keychain-backed secret, explicit
   confirmation, independent TLS SMTP attempts, and uncertain-delivery handling.
7. **Prove feature parity and product boundaries**: run contract, fixture,
   accessibility, UI, performance, and original-preservation verification.
8. **Atomic project cutover**: make `BookSender.xcodeproj` the sole app project,
   update bundle/product identifiers, documentation, icons, signing,
   packaging, and release workflow.
9. **Delete obsolete products** only after the cutover gate passes:
   - Raycast/Node source and tests: `src/`, TypeScript `tests/` after fixture
     translation, `package.json`, lockfiles, TypeScript/Vitest/ESLint/Prettier
     configuration, `raycast-env.d.ts`, Raycast assets, and generated Node output.
   - Old native product: `PageForge/`, `PageForgeTests/`, and
     `PageForge.xcodeproj` after every required behavior is represented in
     `BookSender`.
   - Historical implementation: `legacy/`.
   - Generated or local-only artifacts: `node_modules/`, `dist/`, `.raycast/`,
     `coverage/`, Xcode user data, `.DS_Store`, duplicate generated images, and
     obsolete PageForge/Raycast release assets.
   - Calibre, conversion, MOBI/AZW metadata, subprocess-based EPUB, and obsolete
     update/install paths. The approved Book Sender Sparkle/appcast path replaces
     the removed PageForge channel.
10. **Final absence scan and release verification**: confirm one app product,
    no stale project references or forbidden runtimes, then separately verify
    the ad-hoc signed archive, Sparkle signature, package contents, public
    release artifact, and installation on a clean supported macOS account.

Existing unrelated worktree changes, including current `.pi` and
`.pi-subagents` deletions, are outside this migration and must not be restored,
rewritten, or attributed to these tasks.

## Verification Strategy

Verification remains divided into independent claims:

1. Static structure and forbidden-reference scans.
2. Swift compilation with complete concurrency checking.
3. Unit and contract tests with deterministic fixtures.
4. Runtime behavior for setup, intake, batch, cancellation, SMTP, shortcut, and
   the two-screen boundary.
5. Performance, accessibility, memory, and hostile-input checks.
6. Ad-hoc code signing, sandbox entitlement, Sparkle EdDSA, archive-content,
   installation, and release verification.

Passing an earlier gate never implies a later gate. The exact future commands and
manual acceptance scenarios are documented in [quickstart.md](./quickstart.md);
none are executed by this planning command.

## Complexity Tracking

No constitution violations require justification.
