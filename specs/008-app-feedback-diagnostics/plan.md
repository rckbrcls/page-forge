# Implementation Plan: App Feedback and Diagnostics

**Planning Identifier**: `008-app-feedback-diagnostics`

**Checkout Branch**: `main`

**Date**: 2026-07-30

**Spec**: [spec.md](./spec.md)

**Input**: Feature specification from
`/specs/008-app-feedback-diagnostics/spec.md`

## Summary

Improve feedback for every supported Book Sender action and replace vague error
presentation with phase-aware, privacy-safe diagnostics. The implementation
introduces one shared action-feedback model, a stable failure-presentation
catalog, typed diagnostic evidence, one local unified-logging adapter, and an
explicit `Copy Error Details` path. Existing setup, send, Settings, shortcut,
pipeline, SMTP, and updater surfaces remain in place; no primary screen,
telemetry service, custom diagnostic archive, or persistent in-app diagnostic
history is added. The separate bounded send history belongs to Feature 009.

The design preserves raw technical failures inside adapters. Adapters translate
them into typed safe evidence, application boundaries record each terminal
failure once, and presentation services derive concise summaries, expandable
details, recovery actions, accessible announcements, and deterministic copied
text. SMTP diagnostics retain the delivery phase plus safe numeric and enhanced
status codes while discarding reply text and protocol content.

## Technical Context

**Language/Version**: Swift 6.0 with complete concurrency checking

**Primary Dependencies**: SwiftUI, AppKit, Observation, Foundation,
Security.framework, OSLog, macOS accessibility APIs, UniformTypeIdentifiers;
existing exact packages only: KeyboardShortcuts 3.0.1, Sparkle 2.9.2,
ZIPFoundation 0.9.19, swift-nio 2.86.0, and swift-nio-ssl 2.35.0

**Storage**: Traditional file-based macOS Keychain for SMTP credentials;
existing preferences for non-secret setup and shortcut values; Apple unified
logging for bounded local diagnostic retention; no custom diagnostic files,
database, archive, cloud storage, or in-app diagnostic history

**Testing**: Swift Testing for domain, application, adapter, redaction, catalog,
and formatter contracts; XCTest/XCUITest for UI state, accessibility,
announcements, copying, and end-to-end failure presentation; existing EPUB,
PDF, malicious-archive, pipeline, credential, and SMTP fixtures

**Target Platform**: macOS 26.0+

**Project Type**: Single native macOS application

**Performance Goals**: Accepted foreground actions expose acknowledgement or
progress within one UI update; diagnostic formatting and recording remain
off the main interaction path; a 20-item sequential batch preserves responsive
per-item and aggregate feedback; unchanged states do not generate duplicate
visual notices or announcements

**Constraints**: Exactly two primary screens; existing Delivery and Shortcut
Settings tabs only; all processing remains local; credentials and private
content never enter display, logs, or clipboard; no raw exception, provider
reply, protocol transcript, address, path, filename, book content, or message
bytes in diagnostics; no new source dependency, helper process, executable
download, telemetry, or custom persistent diagnostic history

**Scale/Scope**: All supported launch restoration, setup, Settings, shortcut,
intake, preparation, batch, SMTP, cancellation, recovery, and updater
interactions; stable confirmed batches remain sequential and failure-isolated

## Constitution Check

### Pre-research gate

**Result: PASS**

- **Mission and surface**: The feature improves setup and sending feedback
  without adding a primary screen, workflow, diagnostic-history browser, or
  diagnostic destination.
- **Native boundary**: The selected approach uses only the existing Swift
  application, macOS frameworks, and approved packages. No helper or external
  engine is introduced.
- **Minimal interaction**: Default feedback remains concise and inline.
  Technical evidence appears only for blocked, failed, uncertain, or
  user-requested expanded states.
- **Background pipeline**: Audit, repair, revalidation, PDF delivery, stable
  batch ordering, and cancellation contracts remain unchanged. The feature
  observes and presents their typed events.
- **Original preservation**: No original, prepared-copy, workspace, or cleanup
  rule changes.
- **Input safety**: Archive and XML safety limits remain in the current domain
  and adapters. Diagnostics expose only stable rule codes and allow-listed
  context.
- **Batch reliability**: Per-item failures stay isolated, aggregate status
  remains derived, and post-transmission uncertainty retains
  `delivery_unknown`.
- **Delivery and privacy**: Delivery remains explicit SMTP. Credentials stay in
  the traditional Keychain; provider text and private input data are discarded
  before presentation, logging, or copying.
- **Architecture and tests**: Typed models and ports preserve the required
  dependency direction. Each diagnostic mapping and redaction rule receives
  deterministic tests.
- **Distribution**: Existing Sparkle behavior remains owned by its standard
  updater controller. Release signing, packaging, and clean-runner gates are
  unchanged.

### Post-design gate

**Result: PASS**

The Phase 1 design introduces only cross-cutting models, services, adapters, and
shared inline views required to satisfy the feature. Unified logging is
encapsulated behind one domain port and one vetted adapter; the existing privacy
test is narrowed to permit that adapter while continuing to reject logging from
all other production files. No constitutional exception or complexity
justification is required.

## Project Structure

### Documentation (this feature)

```text
specs/008-app-feedback-diagnostics/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── action-feedback-and-accessibility.md
│   ├── failure-diagnostics-and-redaction.md
│   ├── local-recording-and-copy.md
│   └── smtp-provider-diagnostics.md
├── checklists/
│   └── requirements.md
└── tasks.md                         # generated by speckit-tasks
```

### Source Code (repository root)

```text
BookSender/
├── App/
│   ├── AppDependencies.swift        # compose diagnostic services and adapters
│   ├── AppModel.swift               # own action feedback and terminal recording
│   └── BookSenderApp.swift          # startup and updater boundary
├── Features/
│   ├── DeliverySetup/
│   ├── SendBook/
│   ├── Settings/
│   └── Shared/                      # shared inline feedback and details
├── Application/
│   ├── Diagnostics/                 # format, record, and deduplicate evidence
│   ├── Pipeline/
│   └── Presentation/
│       └── FailurePresentationService.swift
├── Domain/
│   ├── Models/
│   │   ├── DiagnosticModels.swift
│   │   └── FeedbackModels.swift
│   └── Ports/
│       └── DiagnosticProtocols.swift
├── Adapters/
│   ├── Diagnostics/
│   │   ├── AppKitDiagnosticClipboard.swift
│   │   └── UnifiedDiagnosticRecorder.swift
│   ├── Credentials/
│   └── SMTP/
└── Resources/

BookSenderTests/
├── Adapters/
├── Application/
├── Domain/
├── Integration/
└── Privacy/

BookSenderUITests/
├── AccessibilityUITests.swift
├── DeliverySetupUITests.swift
├── FirstBookJourneyUITests.swift
└── SettingsUITests.swift
```

**Structure Decision**: Keep the existing layered native application and add a
small diagnostics slice across the same dependency direction:
`SwiftUI Features -> Application Diagnostics/Presentation -> Domain Models and
Ports -> OSLog/AppKit/SMTP/Credential Adapters`. Shared views render application
models only and never inspect raw adapter failures.

## Design

### 1. Shared action feedback

Represent each accepted action as an `ActionFeedback` value with a stable
identity, scope, action, lifecycle state, concise title, optional detail,
timestamps, dismissal policy, and optional failure presentation. `AppModel`
publishes feedback for app-wide actions and existing feature models continue to
own per-item batch state.

The lifecycle is `acknowledged -> inProgress -> terminal`, where terminal is
one of `succeeded`, `failed`, `cancelled`, `partial`, or `unknown`. Immediate
actions may transition directly from acknowledged to terminal within one update.
Replacing the same unchanged feedback does not create a new identity, notice,
or accessibility announcement.

Setup success explicitly confirms both persistence outcomes:
`Setup saved. App password stored securely.` Clearing the secret field after a
successful save is paired with that confirmation. Remove, clear, cancellation,
shortcut edits, update checks, and confirmation dismissal receive proportional
feedback using the same model.

### 2. Failure catalog and progressive disclosure

Expand the existing `FailurePresentationService` into the single catalog for
stable failure codes and families. Each entry derives:

- affected action or item;
- concise summary;
- plain-language explanation;
- delivery or processing phase;
- impact and retry disposition;
- recommended recovery action and control label;
- stable diagnostic code;
- copyable technical details when useful.

Known codes must have explicit entries. Unknown codes fall back to an
`unexpected.*` presentation that preserves the originating family and phase
without displaying raw error text. A catalog-completeness test enumerates every
typed production failure code and fails when a code lacks a presentation.

### 3. Typed diagnostic evidence

Extend `SanitizedFailure` with typed optional evidence rather than an arbitrary
metadata dictionary. Evidence includes `DiagnosticPhase`, severity,
`RetryDisposition`, optional safe provider status, and a closed set of context
fields such as app version, anonymous operation identifier, setup revision,
batch counts, transmission-started state, and named safety limit.

Adapters translate platform or protocol failures immediately. Raw `Error`
values, `localizedDescription`, archive/XML input, provider reply lines, file
locations, message content, addresses, credentials, and Keychain data never
cross the adapter boundary.

### 4. Record once at terminal boundaries

Create a `DiagnosticRecording` port and one
`UnifiedDiagnosticRecorder` adapter backed by `OSLog.Logger`. Application
boundaries record failed and uncertain operations exactly once:

- startup restoration and fatal app failures in app composition;
- setup, preferences, Keychain, and shortcut failures in their application
  services;
- pipeline and delivery outcomes where terminal events are consumed.

The recorder accepts only a `DiagnosticEvent`; it cannot accept free-form
strings or dictionaries. Log messages use static templates and interpolate only
validated, already-sanitized codes and enum values. The operating system owns
retention and viewing through Console or standard log tooling. Book Sender
creates no diagnostic log file, archive, export browser, or diagnostic-history
screen.

### 5. Copy Error Details

`DiagnosticFormatter` produces compact deterministic text from the same
`DiagnosticEvent` used for local recording. A narrow `DiagnosticClipboard`
port exposes an explicit write operation, and
`AppKitDiagnosticClipboard` clears and writes the general pasteboard only after
the user chooses `Copy Error Details`.

Copied text contains the stable code, subsystem, phase, safe provider status,
impact, retry guidance, timestamp, and app version when available. It never
contains raw exceptions, provider reply text, credentials, addresses, paths,
filenames, book content, or message data.

### 6. SMTP phase-aware failures

Move SMTP rejection mapping after state-aware reply interpretation so every
failure retains the active phase:

`connecting`, `securing`, `authenticating`, `sender`, `recipient`, `data`, or
`finalAcceptance`.

Retain only the three-digit reply code and a syntactically valid enhanced status
code. Provider prose and protocol lines are discarded. Credential and account
authentication codes, including 534 and 535, resolve to edit-setup guidance.
Retry disposition depends on both phase and whether message data began:

- before data transmission: retry may be safe when the failure is transient;
- after transmission begins: outcome may be `delivery_unknown`, and guidance
  tells the user to check the destination before retrying.

### 7. Accessible, calm presentation

Add shared inline feedback and failure-detail views that use native controls and
existing visual conventions. Status is communicated through text and accessible
labels, not color alone. Buttons expose loading, disabled, focus, pressed,
success, and error states; non-obvious disabled reasons use help text and
accessibility hints.

Important progress and terminal transitions emit one macOS accessibility
announcement keyed by feedback identity and state. Per-item batch announcements
are bounded so a 20-item batch remains understandable without flooding the
announcement queue. Expanded details remain keyboard reachable and preserve
reading order under increased contrast, reduced motion, and larger text.

### 8. Updater boundary

Keep `SPUStandardUpdaterController` and its standard user interface as the owner
of update progress, no-update, available-update, and updater-error feedback.
Book Sender continues to expose the existing menu action and disabled state.
Only startup or configuration failures that already cross the application
boundary are eligible for the shared diagnostic path. Installer, CI, signing,
release publication, and remote feed diagnostics remain outside this feature.

## Requirement Traceability

| Requirement group | Design owner | Primary verification |
|---|---|---|
| FR-001 through FR-012: action lifecycle and perceivable feedback | Shared action feedback; accessible presentation | Action matrix, setup-save tests, deduplication, mixed batch |
| FR-013 through FR-019: specific and stable failure presentation | Failure catalog; typed diagnostic evidence | Catalog completeness, expected/unexpected fixtures, occurrence grouping |
| FR-020 through FR-024: SMTP phase, provider status, and certainty | SMTP phase-aware failures | State-machine matrix, enhanced-code parser, pre/post-DATA tests |
| FR-025 through FR-031: local diagnostics, copying, and privacy | Typed evidence; terminal recording; copied details | Recorder spy, deterministic formatter, clipboard tests, redaction canaries |
| FR-032 through FR-036: accessible inline detail | Accessible, calm presentation | UI semantics, announcement deduplication, accessibility settings |
| FR-037 through FR-040: coverage, regression, controls, restart correlation | All design slices and validation gates | Full action/failure matrix, static privacy scans, runtime correlation |
| SC-001 through SC-012 | Validation Strategy and quickstart | Deterministic, UI/runtime, and provider gates remain separately evidenced |

## Implementation Sequence

1. Add domain feedback and diagnostic models, validation, stable phases, safe
   provider status, retry disposition, and diagnostic ports.
2. Add catalog, formatter, deduplication, and terminal-recording application
   services with unit tests.
3. Add the unified-logging and explicit clipboard adapters; update privacy tests
   to allow logging only in the vetted adapter.
4. Make SMTP and credential adapters emit phase-aware safe evidence without raw
   exception or reply text.
5. Integrate dependencies and action lifecycle state into `AppModel`, pipeline
   consumption, setup, shortcut, and startup boundaries.
6. Add shared inline feedback and details to Delivery Setup, Send Book, and
   Settings; retain Sparkle's standard update UI.
7. Add accessibility announcements, disabled-state explanations, UI coverage,
   redaction canaries, catalog completeness, and the controlled provider matrix.

Task-level decomposition is intentionally deferred to `speckit-tasks`.

## Validation Strategy

### Static and deterministic gates

- Every supported action has an acknowledgement/progress/terminal mapping.
- Every typed expected failure code has a catalog entry and recovery
  disposition.
- Display, recording, and copying use the same sanitized diagnostic value.
- `Logger` appears only in the vetted diagnostics adapter.
- Production sources contain no arbitrary logging calls, telemetry SDK, custom
  diagnostic persistence, or third primary screen.
- Redaction canaries cover passwords, email addresses, Kindle addresses, file
  paths, filenames, book content, message data, raw provider replies, and raw
  platform errors.
- The existing exact source dependency set remains unchanged.

### Build and test gates

Swift compilation, Swift Testing, XCTest/XCUITest, app launch, and accessibility
runtime verification remain separate gates. They require explicit authorization
under the repository workflow rules and are not executed by this planning
command.

### Provider acceptance gate

Controlled SMTP acceptance uses dedicated non-personal test credentials and
fixture servers or explicitly authorized provider accounts. Evidence records
only phase, stable diagnostic code, safe numeric/enhanced status, retry
disposition, and pass/fail outcome. A local static or fixture pass is not a
claim that Gmail or Kindle accepted a real delivery.

## Complexity Tracking

No constitution violations or justified exceptions.
