# Implementation Plan: Native Quality Baseline

**Branch**: `007-native-quality-baseline` | **Date**: 2026-07-29 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/007-native-quality-baseline/spec.md`

## Summary

Raise Book Sender's native macOS quality baseline without expanding its two-screen
product or changing its external dependencies. The work removes a cancellation
race in SMTP reply waiting, makes every file intake attempt observable, derives
batch confirmation presentation from one optional value, replaces deprecated
SwiftUI and AppKit integration patterns, replaces the inaccessible Data
Protection credential query with the traditional Keychain, and makes the free
release identity stable and verifiable across updates.

The implementation remains local-first, processes stable batches sequentially,
preserves immutable originals, uses typed failures, and keeps SwiftUI limited to
presentation and intent forwarding.

## Technical Context

**Language/Version**: Swift 6 language mode with complete concurrency checking;
Apple Swift 6.3.3 in the currently selected toolchain

**Primary Dependencies**: SwiftUI, AppKit, Observation, Foundation,
Security.framework, UniformTypeIdentifiers, KeyboardShortcuts 3.0.1,
ZIPFoundation 0.9.19, swift-nio 2.86.0, swift-nio-ssl 2.35.0, Sparkle 2.9.2

**Storage**: Traditional file-based macOS Keychain for SMTP secrets, `UserDefaults` for
non-secret preferences, and collision-safe application workspaces for prepared
copies; no new persistence

**Testing**: Swift Testing for domain, application, adapter, privacy, and
performance contracts; XCTest/XCUITest for UI, accessibility, keyboard, and
journey behavior

**Target Platform**: macOS 26.0+

**Project Type**: Single native macOS application with unit and UI test targets

**Performance Goals**: A stalled operation reaches a terminal timeout outcome
within one second after its configured deadline; cancellation releases pending
work within one second; main-window interactions remain responsive during
intake, preparation, and sending

**Constraints**: Exactly two primary screens; native auxiliary Settings window;
maximum confirmed batch of 100 files; sequential processing; immutable originals;
local EPUB processing; TLS-only SMTP authentication; no new dependency, helper
process, executable download, external runtime, conversion workflow, or third
primary screen

**Scale/Scope**: One local user, one active batch, one EPUB/archive entry/delivery
attempt at a time, bounded ZIP/XML input, and transient UI feedback only

## Constitution Check

### Pre-design gate

| Principle | Status | Evidence |
|---|---|---|
| I. Focused Two-Screen Product | PASS | The plan preserves `Delivery Setup`, `Send Book`, and the existing auxiliary Settings window only. |
| II. Minimal Native UX | PASS | Changes use native SwiftUI/AppKit lifecycle patterns, semantic typography, explicit feedback, and keyboard/accessibility evidence. |
| III. Local, Lightweight Processing | PASS | No service, helper, executable download, conversion tool, or new runtime is introduced. |
| IV. Verifiable EPUB Audit and Cleanup | PASS | EPUB behavior is unchanged except for deterministic timeout/cancellation evidence around existing bounded adapters. |
| V. Immutable Originals and Explicit Consent | PASS | Intake and confirmation changes preserve stable confirmed batches and collision-safe working copies. |
| VI. Safety, Privacy, and Security | PASS | Feedback remains sanitized; SMTP secrets move to the traditional Keychain with no fallback; TLS and sandbox boundaries are unchanged. |
| VII. Quality Gates | PASS | The plan adds focused fixture/adapter tests and separates static, build, runtime, UI, and provider validation. |
| VIII. State, Concurrency, and Architecture Boundaries | PASS | Cancellation ownership stays in actors/adapters; presentation remains `@MainActor`; typed events cross boundaries. |
| IX. Dependency Discipline | PASS | Exact current dependencies are retained; no dependency is added or upgraded. |
| X. Distribution and First-Run Trust | PASS | One pinned self-signed identity, an exact designated requirement, Sparkle EdDSA, and a fail-closed installer preserve continuity without claiming Developer ID or notarization. |

No constitution violation requires a complexity exception.

## Project Structure

### Documentation

```text
specs/007-native-quality-baseline/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── credential-and-release-continuity.md
│   ├── intake-feedback.md
│   ├── native-ui-and-accessibility.md
│   └── timeout-and-cancellation.md
├── checklists/
│   └── requirements.md
└── spec.md
```

### Source Code

```text
BookSender/
├── App/
├── Features/
│   ├── DeliverySetup/
│   ├── SendBook/
│   └── Settings/
├── Application/
│   ├── Delivery/
│   ├── Intake/
│   ├── Pipeline/
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
│   └── XML/
└── Resources/

BookSenderTests/
├── Adapters/
├── Application/
├── Domain/
├── Fixtures/
├── Performance/
└── Privacy/

BookSenderUITests/
scripts/
├── signing/
└── tests/
.github/workflows/release.yml
```

**Structure Decision**: Preserve the existing single-app layered structure.
Place SMTP waiter ownership inside `Adapters/SMTP`, intake outcome aggregation
inside `Application/Intake`, and transient presentation state inside
`Application/Presentation`. Split oversized app-composition helpers into focused
files under `BookSender/App` only when that makes lifecycle ownership testable.
Do not create a new architectural layer.

## Implementation Strategy

### Phase A — Cancellation-safe timeout ownership

1. Replace array-only SMTP reply continuations with tokenized waiter ownership.
   Each pending waiter has one identifier and exactly one terminal transition:
   reply, queue finish, timeout cancellation, or caller cancellation.
2. Register cancellation with `withTaskCancellationHandler`, check for
   cancellation before suspending, and remove/resume the matching continuation
   through the queue actor. Never leave a cancelled checked continuation stored.
3. Preserve delivery uncertainty semantics: a failure after SMTP message data
   begins remains `delivery_unknown`; earlier failures remain retryable or
   terminal according to the existing typed mapping.
4. Review the existing archive and XML timeout races for the same structured
   concurrency property. Add a shared timeout helper only if it removes
   duplication without erasing adapter-specific failure types.
5. Add deterministic tests for cancellation before registration, cancellation
   after registration, reply-versus-timeout races, queue finish, and exactly-once
   continuation resumption.

### Phase B — Observable file intake

1. Model each Finder or drag-and-drop intake as a transient attempt containing
   ordered accepted URLs and sanitized failures.
2. Handle `fileImporter` results explicitly. Treat a normal user cancellation as
   no-op and convert every other failure to concise visible feedback.
3. Retain per-provider drop loading so each attempted item has an outcome, but
   replace deprecated item loading with `loadTransferable(type: URL.self)`.
4. Preserve accepted-item order, continue with valid items when peers fail, and
   expose a sanitized aggregate failure count without raw exceptions or paths.
5. Keep validation, deduplication, extension checks, and batch limits in the
   shared application intake path used by both Finder and drag-and-drop.

### Phase C — Single-source confirmation state

1. Make optional `ConfirmedBatchSummary` presence the sole presentation source.
2. Derive `isShowingConfirmation` when compatibility is needed; remove an
   independently mutable Boolean.
3. Present with item-driven sheet state so dismiss, cancel, and send all consume
   or release the same confirmed snapshot exactly once.
4. Add presentation-model tests covering prepare, dismiss, cancel, send, and
   repeated batch selection.

### Phase D — Native UI and lifecycle modernization

1. Replace deprecated Settings `.tabItem` declarations with the modern `Tab`
   API while preserving exactly `Delivery` and `Shortcut`.
2. Replace fixed point sizes and incidental `.caption2` usage with semantic text
   styles that preserve hierarchy under enlarged text settings.
3. Replace Sparkle KVO `DispatchQueue.main.async` bridging with explicit
   `Task { @MainActor in ... }` ownership.
4. Move window capture to an `NSVisualEffectView` lifecycle hook such as
   `viewDidMoveToWindow`, avoiding update-cycle dispatch and duplicate main
   windows.
5. Keep AppKit interop narrow and presentation-only. Do not move domain,
   pipeline, credential, archive, XML, filesystem, or SMTP behavior into views.

### Phase E — Evidence and regression coverage

1. Add adapter tests with short deterministic deadlines and explicit elapsed-time
   assertions for the one-second release budget.
2. Add application tests for mixed-success intake and sanitized error feedback.
3. Strengthen UI tests so keyboard actions assert observable results, not only
   focus or key delivery.
4. Cover Settings tabs, confirmation dismissal, reduced transparency, increased
   contrast, enlarged text, meaningful accessibility labels, and core two-screen
   journeys.
5. Record build, test, runtime, UI, provider, signing, notarization, and release
   gates separately. A passing source inspection or unit suite must not be
   reported as provider or production acceptance.

### Phase F — Credential and release identity continuity

1. Remove Data Protection, accessibility, and synchronization selectors from
   `KeychainCredentialStore` while preserving generic-password identity,
   revision-scoped transactions, sanitized errors, and public ports/models.
2. Add store-recreation, replacement rollback, deletion, source-policy, and
   privacy coverage. Remove the Keychain test exclusion from release CI.
3. Create the ten-year `Book Sender Release Signing` self-signed Code Signing
   identity, keep its encrypted PKCS#12 backup outside the repository, configure
   the two GitHub secrets, and version only its public DER certificate.
4. Import the identity into an ephemeral runner Keychain, compare it with the
   pinned public certificate, sign Sparkle and the app inside out, and require
   the exact main-app designated requirement.
5. Fail before packaging for absent or invalid secrets, certificate or
   requirement drift, ad-hoc signing, or invalid nested signatures. Clean every
   private temporary artifact on step exit.
6. Make the installer reject unsigned, ad-hoc, differently signed, or
   requirement-divergent archives before replacement. Keep Sparkle EdDSA
   independently mandatory.
7. Document that the first corrected version may request the password once and
   that same-identity updates preserve access; disclose the lack of Developer ID,
   notarization, and normal Gatekeeper trust.
8. Keep hardened runtime and add only the main-executable library-validation
   exception required by the pinned self-signed identity's missing Team ID.
9. Require the exact runtime/entitlement combination in CI and the installer,
   keep every Sparkle executable pinned, and launch the signed app before
   packaging.
10. Verify the GitHub asset SHA-256 digest and public DER fingerprint in the
    installer, then idempotently register only that public certificate in the
    user's default Keychain when absent. Never import a private key or install an
    explicit Always Trust override.
11. Transfer the packaged candidate to a separate clean macOS runner with no
    private signing material. Publish only after the real installer bootstrap,
    no-private-identity assertion, strict signature checks, and installed-app
    launch all pass.

## Post-Design Constitution Check

The design artifacts preserve all pre-design PASS results. No database,
preference schema, dependency, or new product surface is introduced. The
credential adapter changes only which system Keychain implementation answers
the existing port, while release signing adds repository and CI policy rather
than runtime scope. Tokenized waiter ownership strengthens the
constitution's concurrency and typed-failure rules. Intake feedback strengthens
determinism and privacy because failures are explicit but sanitized. Native UI
changes remain within SwiftUI/AppKit presentation boundaries.

## Complexity Tracking

No constitution exception is required.

| Potential complexity | Decision |
|---|---|
| A generic cross-adapter timeout framework | Rejected unless focused implementation proves it reduces duplication while preserving typed failures. |
| Replacing drop intake with a single opaque drop callback | Rejected because the feature must account for every attempted provider, including transfer failures. |
| A third primary status or diagnostics screen | Rejected; blocked-item detail remains inline and concise. |
| New logging, telemetry, persistence, or dependency | Rejected; existing typed events and local evidence are sufficient. |
