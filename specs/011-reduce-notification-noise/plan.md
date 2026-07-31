# Implementation Plan: Essential Notification Feedback

**Planning Identifier**: `011-reduce-notification-noise`

**Checkout Branch**: `main`

**Date**: 2026-07-31

**Spec**: [spec.md](./spec.md)

**Input**: Feature specification from
`/specs/011-reduce-notification-noise/spec.md`

## Summary

Reduce production floating notifications from a general projection of every
`ActionFeedback` lifecycle to an explicit, terminal-only catalogue for outcomes
that are not otherwise visible. Keep semantic feedback creation, diagnostics,
workflow state, the reusable Liquid Glass card, destination isolation, queueing,
timing, actions, and test-only component scenarios intact.

The implementation introduces an explicit publication intent whose default is
contextual silence. `AppModel` continues recording every typed feedback
lifecycle, but only approved terminal outcomes are projected into
`FloatingNotificationCenter`: diagnostic-copy success/failure, protected setup
persistence success, setup deletion/Keychain outcomes, and history persistence
failure after definitive SMTP acceptance. Contextual views read semantic
feedback independently from the notification center so field errors, failure
details, batch state, history state, and shortcut guidance remain durable after
redundant cards are suppressed.

## Technical Context

**Language/Version**: Swift 6.0 with complete concurrency checking

**Primary Dependencies**: SwiftUI, AppKit, Observation, Foundation,
Security.framework, UniformTypeIdentifiers; existing exact packages only:
KeyboardShortcuts 3.0.1, Sparkle 2.9.2, ZIPFoundation 0.9.19, swift-nio 2.86.0,
and swift-nio-ssl 2.35.0

**Storage**: No new durable or ephemeral storage. Existing semantic feedback,
notification entries, Keychain credentials, local preferences, diagnostics,
temporary/prepared copies, and bounded send history retain their current
lifecycles. Eligibility decisions are typed in-process values and are not
persisted.

**Testing**: Swift Testing for exhaustive production eligibility, semantic-state
retention, destination routing, stale-card removal, invisible-side-effect
publication, and contextual silence; existing center/model/queue/timing tests
for the isolated notification component; XCTest/XCUITest for zero-card normal
send journeys, visible contextual evidence, approved clipboard/setup/history
cards, accessibility announcement reduction, and retained component matrix

**Target Platform**: macOS 26.0+

**Project Type**: Single native macOS application with one singleton main
`Window` scene and one native `Settings` scene

**Performance Goals**: Normal intake, preparation, confirmation, delivery,
history, shortcut, update-check, and batch-reset flows enqueue zero notification
entries; eligibility evaluation completes synchronously without I/O; approved
terminal publication remains within one main-actor turn; the existing responsive
20-item sequential batch and four-second temporary expiry remain unchanged

**Constraints**: Exactly two primary screens; default notification decision is
contextual; no in-progress notification; no runtime inspection of visual frames
to decide eligibility; no loss of field validation, failure detail, per-book
state, aggregate state, history state, modal confirmation, or uncertainty; no
new dependency, process, storage, entitlement, telemetry, notification history,
or system notification

**Scale/Scope**: Twenty `FeedbackAction` cases receive an exhaustive production
classification; four current action paths may publish approved terminal cards;
test-only component scenarios still exercise up to three visible cards and one
queued card per destination; temporary batches remain capped at 20 books and
send history remains capped at 500 records

## Constitution Check

### Pre-research gate

**Result: PASS**

- **Mission and surface**: The change reduces visual noise within the existing
  setup, send, history, and Settings surfaces. It adds no screen, route, window,
  tab, library, queue, or management destination.
- **Native boundary**: The plan uses the existing native application and shared
  notification system. It adds no web toast library, package, helper, executable,
  download, service, or parallel product.
- **Minimal interaction**: Contextual states become the default presentation;
  only invisible or consequential hidden outcomes use a floating card. This
  directly supports the constitutional requirement for quiet, concise feedback.
- **Background pipeline**: EPUB/PDF preparation, readiness derivation, progress,
  cancellation, and evidence remain unchanged and contextual.
- **Original preservation**: No file-processing or cleanup behavior changes.
- **Input safety**: Archive, XML, workspace, and bounded-processing rules remain
  untouched.
- **Batch reliability**: Stable confirmation, sequential preparation/delivery,
  isolated outcomes, cancellation, retry, and `delivery_unknown` remain
  unchanged and visible in the send workflow.
- **Delivery and privacy**: SMTP remains explicit; no notification changes an
  outcome or transmits/persists content. Keychain and redaction contracts remain
  unchanged.
- **History boundary**: Record eligibility, 500-entry retention, local privacy,
  clearing, and non-management behavior remain unchanged. A history-write
  notification reports persistence failure separately from delivery success.
- **Architecture and tests**: Semantic feedback stays typed and separate from
  optional presentation. Eligibility is application-presentation policy, not a
  SwiftUI or domain rule. Tests cover every current action classification.
- **Migration and distribution**: No package, project, entitlement, signing,
  Sparkle, installer, release, or deployment behavior changes. Validation gates
  remain explicitly separate.

### Post-design gate

**Result: PASS**

The design keeps `ActionFeedback` as durable in-process semantic truth and makes
floating publication an explicit optional projection. Contextual screens no
longer query the floating center for the failure data they must retain. This
prevents suppression or dismissal from erasing field guidance, failure detail,
batch state, history recovery, shortcut status, or delivery uncertainty.

The publication default is contextual, all in-progress states are silent, and
only named terminal call sites can opt into an auditable reason. Test-only
direct publications remain isolated behind existing UI-test launch scenarios so
the shared card, stack, actions, timing, and accessibility contract can still be
verified without broadening production coverage. No constitutional exception or
complexity justification is required.

## Project Structure

### Documentation (this feature)

```text
specs/011-reduce-notification-noise/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── approved-notification-catalogue.md
│   ├── contextual-feedback.md
│   └── notification-eligibility.md
├── checklists/
│   └── requirements.md
└── tasks.md                         # generated by speckit-tasks
```

### Source Code (repository root)

```text
BookSender/
├── App/
│   └── AppModel.swift
├── Application/
│   ├── Presentation/
│   │   ├── ActionFeedbackService.swift
│   │   ├── FloatingNotificationCenter.swift
│   │   └── FloatingNotificationModels.swift
│   └── Shortcut/
│       └── ShortcutService.swift
└── Features/
    ├── DeliverySetup/
    │   └── DeliverySetupView.swift
    ├── SendBook/
    │   ├── SendBookView.swift
    │   └── SendHistoryView.swift
    ├── Settings/
    │   └── ShortcutSettingsView.swift
    └── Shared/
        ├── FailureDetailView.swift
        ├── FloatingNotificationCard.swift
        └── FloatingNotificationHost.swift

BookSenderTests/
├── Application/
│   ├── ActionFeedbackExpiryTests.swift
│   ├── ActionFeedbackServiceTests.swift
│   ├── AppModelDiagnosticsTests.swift
│   ├── AppModelNotificationRoutingTests.swift
│   ├── AppModelSetupTests.swift
│   ├── FirstBookJourneyTests.swift
│   └── FloatingNotification*Tests.swift
└── Support/
    └── NotificationTestFixtures.swift

BookSenderUITests/
├── AccessibilityUITests.swift
├── BatchSendUITests.swift
├── FloatingNotificationAppearanceUITests.swift
├── FloatingNotificationUITests.swift
├── RecoveryJourneyUITests.swift
├── SendHistoryUITests.swift
└── SettingsUITests.swift

README.md
docs/desktop-migration.md
docs/troubleshooting.md
```

**Structure Decision**: Keep the existing Feature 010 presentation slice and
add no source directory or dependency. Put the explicit eligibility/reason value
beside the notification presentation models, keep semantic feedback construction
in `ActionFeedbackService`, and make `AppModel` the sole production projection
gate. Feature views return to semantic `AppModel.feedback(for:)` queries for
durable failure content. `FloatingNotificationCenter`, host, and card remain
generic and unaware of product eligibility.

## Design

### 1. Preserve every semantic feedback lifecycle

`beginFeedback`, `updateProgressFeedback`, and `finishFeedback` continue updating
`feedbackByScope`, occurrence counts, sanitized failure presentation,
diagnostics, and action state. Suppressing a card must not remove these values or
change operation sequencing.

`beginFeedback` stops publishing `inProgress` entries. It still records the
originating destination for later eligible terminal routing and removes an older
floating presentation for the same scope and destination so a stale success or
failure cannot remain over a newer contextual action.

`updateProgressFeedback` updates semantic state only. Progress remains visible
through buttons, batch rows, aggregate text, history loading, confirmation, and
other existing contextual controls.

### 2. Make floating publication an explicit terminal opt-in

Add a small sendable publication intent with a contextual default and a floating
case that requires an auditable reason. Approved reasons are bounded to:

- protected credential persistence;
- protected credential deletion;
- clipboard write;
- submission-history persistence;
- consequential hidden failure;
- auxiliary system action failure.

`finishFeedback` accepts the intent with `.contextual` as its default. It always
stores the reconciled semantic terminal result. It calls the existing
notification configuration and center only for `.floating(reason)`.

Do not infer eligibility from success/failure state alone. Do not inspect view
visibility, scroll position, window geometry, or accessibility focus at runtime.
The producer that understands whether the outcome is invisible supplies the
reason explicitly, and tests exhaustively review the catalogue.

### 3. Retain exactly the approved current producers

Opt terminal publication in only at these current paths:

1. successful delivery-setup save, confirming protected setup/credential
   persistence;
2. delivery-setup deletion success or partial Keychain outcome;
3. diagnostic-copy success or failure at the originating destination;
4. submission-history persistence failure after definitive SMTP acceptance.

Setup validation/storage failures remain contextual because the form and
`FailureDetailView` retain them. Application restore, intake, preparation,
remove, clear, confirmation, send, cancellation, retry, reset, history
load/clear, shortcut, and successful update-check events use the default silent
intent.

No new Sparkle failure callback is added in this feature. The auxiliary-system
failure reason reserves the contract for a future typed failure path; successful
opening remains silent.

### 4. Decouple contextual evidence from notification visibility

Change `DeliverySetupView`, `SendBookView`, `SendHistoryView`, and
`ShortcutSettingsView` to read their semantic scoped feedback from
`AppModel.feedback(for:)`, not `FloatingNotificationCenter.feedback`.

The contextual selection rules become:

- Delivery Setup: `.deliverySetup` failure plus existing `setupMessage` and
  field errors;
- Send: `.batch` failure plus per-item diagnostic/failure disclosure; no
  application/setup success fallback;
- History: `.history` failure plus `historyLoadState` and current records;
- Shortcut Settings: `.shortcut` failure plus the existing registration state.

Notification close, expiry, host detachment, queue replacement, and suppression
therefore cannot remove contextual evidence. The compatibility
`notificationFeedback` query may remain only where notification-specific tests
need it or be removed once no production view consumes it.

### 5. Keep the reusable component independent

Do not change `FloatingNotificationCard`, `FloatingNotificationHost`, or the
center's generic queue, deduplication, close, action, destination, timing, or
accessibility behavior except for any narrowly required stale-entry cleanup.

Existing synthetic launch scenarios for notification matrix, stack/queue, and
appearance publish directly to the center and bypass production eligibility by
design. They are component fixtures, not product events.

### 6. Reconcile tests around silence versus component capability

Update application and workflow tests to assert both sides of the separation:

- semantic feedback still reaches its expected terminal state;
- contextual UI evidence remains visible and actionable;
- redundant production events create no visible or queued entry;
- approved invisible outcomes create exactly one correctly routed entry;
- starting a new contextual action removes stale floating state for its scope;
- component-only configuration, queue, timing, focus, and appearance tests remain
  unchanged or receive only fixture-name adjustments.

Targeted test migrations include:

- `AppModelNotificationRoutingTests`: replace shortcut/update/batch publication
  expectations with silence; retain main/Settings isolation for approved setup
  and diagnostic-copy cards;
- `ActionFeedbackExpiryTests`: retain expiry for approved setup/copy successes;
  remove update/batch integration assumptions while leaving center timing tests;
- `AppModelDiagnosticsTests`: retain diagnostic-copy success/failure coverage;
- `AppModelSetupTests` and `FirstBookJourneyTests`: retain semantic feedback and
  contextual state assertions while asserting no application/batch cards;
- `FloatingNotificationUITests`: convert normal batch and shortcut journeys to
  silence; retain synthetic matrix, stack, action, focus, and destination tests;
- `AccessibilityUITests`, `BatchSendUITests`, `SettingsUITests`, and
  `SendHistoryUITests`: replace contextual card expectations with visible row,
  form, switch, alert, list, unavailable, and failure-detail evidence;
- `RecoveryJourneyUITests` and appearance/component tests: retain approved
  diagnostic-copy and synthetic card behavior.

### 7. Update product documentation

Revise `README.md`, `docs/desktop-migration.md`, and
`docs/troubleshooting.md` so they no longer promise a card for every action,
active state, cancellation, or visible delivery result. Document the contextual
default, the small approved invisible-side-effect catalogue, terminal timing,
and the fact that component capacity does not represent normal production
volume.

Add Feature 011 to the README specification chain as the coverage policy that
narrows Feature 010 without replacing its reusable presentation contract.

## Requirement Traceability

| Requirement group | Design evidence | Planned validation |
|---|---|---|
| FR-001–FR-008 | explicit default-contextual publication intent; no progress publication | exhaustive action classification and zero-card workflow checks |
| FR-009–FR-016 | four current approved producer paths and bounded reasons | setup, deletion, diagnostic-copy, history-persistence unit/UI journeys |
| FR-017–FR-023 | terminal-only opt-in, presentation-only close, stale-card removal | intent normalization, expiry, replacement, and semantic-retention tests |
| FR-024–FR-028 | semantic/context separation and retained test fixtures | announcement-count, focus, contextual accessibility, matrix/stack tests |
| CC-001–CC-008 | no new surface, storage, dependency, or behavior change | constitution review plus separate static/build/test/runtime gates |

## Validation Strategy

1. **Static source gate**: Verify no production `inProgress` publication, every
   floating opt-in has an approved reason, contextual views query semantic
   feedback, synthetic test publication remains fixture-gated, no package or
   storage is added, docs reflect contextual default, and Swift parses.
2. **Compilation gate**: Compile the Swift 6 target with complete concurrency
   checking and verify intent exhaustiveness, actor isolation, and view queries.
3. **Deterministic unit gate**: Run eligibility, AppModel routing, semantic
   retention, expiry, center, diagnostics, setup, history, and journey tests.
4. **UI/accessibility gate**: Run zero-card normal workflow tests, approved
   notification journeys, contextual failure evidence, keyboard focus,
   announcements, component matrix/stack, and appearance tests.
5. **Manual runtime gate**: Inspect one successful send, mixed/unknown delivery,
   setup save/delete, clipboard success/failure, history persistence failure,
   main/Settings coexistence, VoiceOver, Reduce Motion, Reduce Transparency, and
   Increase Contrast.
6. **Authenticated provider gate**: Existing SMTP acceptance and history-write
   separation remain a distinct optional validation; this feature changes no
   SMTP behavior.
7. **Release gate**: Signing, clean-runner installation, Sparkle, appcast,
   publication, and public endpoint checks remain separate from feature
   acceptance.

Build, test, app launch, UI automation, authenticated SMTP, signing, and release
commands are not executed during planning.

## Agent Context Update

The active feature pointer is
`.specify/feature.json -> specs/011-reduce-notification-noise`. The installed
Spec Kit 0.12.9 Codex integration provides no `update-agent-context.sh` script;
read-only `specify integration status` confirms the Codex integration is
installed with no missing managed files. Planning therefore changes no managed
agent instruction file and uses the active feature pointer plus these artifacts
as downstream context.

## Complexity Tracking

No constitution violations require justification.
