# Implementation Plan: Transient Feedback and Send History

**Planning Identifier**: `009-transient-feedback-history`

**Checkout Branch**: `main`

**Date**: 2026-07-30

**Spec**: [spec.md](./spec.md)

**Input**: Feature specification from
`/specs/009-transient-feedback-history/spec.md`

## Summary

Make successful and informational action acknowledgements disappear after a
four-second interval, replace the completed-batch primary action with
`Send More Books`, and add a bounded local `History` tab inside the existing
`Send Book` screen. The implementation extends the current typed feedback
system with cancellation-safe expiry scheduling, makes completed batches
immutable until an explicit reset, and records one local history entry
immediately after each definitive SMTP acceptance.

History is implemented as a typed application service plus an actor-owned,
versioned JSON adapter in Application Support. It stores only an attempt
identifier, sanitized original display name, and acceptance timestamp, orders
records newest first, deduplicates by attempt identifier, and retains the latest
500 records. Persistence failure produces separate actionable feedback and
never changes or retries the successful delivery.

## Technical Context

**Language/Version**: Swift 6.0 with complete concurrency checking

**Primary Dependencies**: SwiftUI, AppKit, Observation, Foundation,
Security.framework, UniformTypeIdentifiers; existing exact packages only:
KeyboardShortcuts 3.0.1, Sparkle 2.9.2, ZIPFoundation 0.9.19, swift-nio 2.86.0,
and swift-nio-ssl 2.35.0

**Storage**: Traditional file-based macOS Keychain for SMTP credentials;
existing preferences for non-secret setup and shortcut values; existing
collision-safe workspace for prepared copies; one versioned, atomically
replaced JSON history file in Application Support containing at most 500
identifier/name/timestamp records

**Testing**: Swift Testing for feedback timing, replacement, history model,
application service, persistence, pipeline integration, reset, stale-event,
failure-isolation, privacy, and retention contracts; XCTest/XCUITest for local
tabs, keyboard access, accessibility announcements, confirmations, empty state,
relaunch persistence, and completed-batch journeys

**Target Platform**: macOS 26.0+

**Project Type**: Single native macOS application

**Performance Goals**: Transient acknowledgements remain visible for four
seconds and disappear no later than five; tab switching remains immediate and
does not disturb pipeline work; history loads without blocking the main actor;
insertion, ordering, deduplication, retention, and clearing remain bounded to
500 records; the existing 20-item sequential batch stays responsive

**Constraints**: Exactly two primary screens; `Send` and `History` are local
tabs inside `Send Book`; no new dependency, helper process, database, remote
service, telemetry, file-management action, resend action, analytics, search,
filter, export, conversion, or background delivery; originals remain immutable;
failed, cancelled, excluded, unattempted, and `Delivery Unknown` outcomes never
enter successful history

**Scale/Scope**: Temporary confirmed batches up to 20 books, processed and
delivered sequentially; one history record per definitive accepted attempt;
newest 500 records retained locally; repeated accepted sends of the same display
name remain separate

## Constitution Check

### Pre-research gate

**Result: PASS**

- **Mission and surface**: The feature directly improves repeated sending and
  introduces only the constitution-approved bounded local submission history.
  `Send` and `History` remain local tabs in `Send Book`; application routing
  still has exactly `Delivery Setup` and `Send Book`.
- **Native boundary**: The approach uses one Swift/SwiftUI application,
  Foundation file persistence, and the already approved package set. It adds no
  helper, executable, database, service, or processing dependency.
- **Minimal interaction**: Successful and informational acknowledgements expire
  automatically. Active work, validation, failure, cancellation, and
  uncertainty remain until state changes or the user deliberately clears them.
- **Background pipeline**: EPUB preparation, PDF eligibility, sequential SMTP
  delivery, confirmation, cancellation, and per-book failure isolation remain
  unchanged. History observes only definitive accepted outcomes.
- **Original preservation**: History stores no book content or path and never
  modifies an original or prepared copy. Batch reset uses the existing workspace
  cleanup boundary.
- **Input safety**: Archive and XML limits remain in the existing domain and
  adapters. The history adapter validates its own schema, record count, string
  bounds, and file size before decoding.
- **Batch reliability**: A completed batch becomes read-only until explicit
  reset. Failed items retain retry, `Delivery Unknown` requires acknowledgement,
  and events from an old batch cannot mutate a new batch.
- **Delivery and privacy**: Delivery remains explicit SMTP. Credentials remain
  in the traditional Keychain. History records only a local identifier, safe
  display name, and definitive acceptance timestamp.
- **History boundary**: Records are newest first, capped at 500, clearable with
  confirmation, and never imply Kindle receipt. No resend, locate, preview,
  management, analytics, export, or synchronization behavior is added.
- **Architecture and tests**: Dependency direction is
  `SwiftUI History Presentation -> Application History Service -> Typed
  Submission Records -> Local History Adapter`. Timing, record-once, filtering,
  retention, persistence, reset, stale events, accessibility, and privacy
  receive deterministic tests.
- **Migration and distribution**: No product migration, package, entitlement,
  signing, Sparkle, packaging, or publication rule changes.

### Post-design gate

**Result: PASS**

The Phase 1 design keeps transient timing in presentation state, submission
truth at the application pipeline boundary, and durable I/O in one actor-owned
adapter. The stored schema is smaller than the presentation receipt and excludes
batch identifiers, paths, addresses, credentials, provider data, and book
content. The reset and tab contracts preserve the current batch unless the user
explicitly starts another send. No constitutional exception or complexity
justification is required.

## Project Structure

### Documentation (this feature)

```text
specs/009-transient-feedback-history/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── completed-batch-reset.md
│   ├── feedback-lifecycle.md
│   ├── send-history-storage.md
│   └── send-history-ui.md
├── checklists/
│   └── requirements.md
└── tasks.md                         # generated by speckit-tasks
```

### Source Code (repository root)

```text
BookSender/
├── App/
│   ├── AppDependencies.swift        # compose history store/service and sleeper
│   └── AppModel.swift               # own tabs, expiry tasks, reset, history UI state
├── Features/
│   └── SendBook/
│       ├── SendBookView.swift       # local Send/History tabs and primary action
│       └── SendHistoryView.swift    # simple list, empty state, clear confirmation
├── Application/
│   ├── History/
│   │   └── SendHistoryService.swift
│   ├── Pipeline/
│   │   └── PipelineActor.swift      # persist immediately after SMTP acceptance
│   └── Presentation/
│       └── ActionFeedbackService.swift
├── Domain/
│   ├── Models/
│   │   ├── FeedbackModels.swift
│   │   ├── HistoryModels.swift
│   │   └── PipelineModels.swift
│   └── Ports/
│       └── HistoryProtocols.swift
└── Adapters/
    └── History/
        └── FileSendHistoryStore.swift

BookSenderTests/
├── Adapters/
│   └── FileSendHistoryStoreTests.swift
├── Application/
│   ├── ActionFeedbackExpiryTests.swift
│   ├── CompletedBatchResetTests.swift
│   ├── PipelineHistoryTests.swift
│   └── SendHistoryServiceTests.swift
├── Domain/
│   └── HistoryModelsTests.swift
├── Privacy/
│   └── SendHistoryPrivacyTests.swift
└── Support/
    └── TestDoubles.swift

BookSenderUITests/
├── AccessibilityUITests.swift
├── BatchSendUITests.swift
└── SendHistoryUITests.swift
```

**Structure Decision**: Extend the existing layered application with one
vertical history slice. `AppModel` owns view selection and transient
presentation tasks, `PipelineActor` identifies definitive SMTP acceptance,
`SendHistoryService` enforces record-once/order/retention behavior, and
`FileSendHistoryStore` owns versioned atomic persistence. SwiftUI never reads or
writes the file and the persistence adapter never decides delivery outcome.

## Design

### 1. Cancellation-safe transient feedback

Keep `ActionFeedbackService` pure and express automatic expiry through
`FeedbackDismissalPolicy.delayed(minimumVisibleDuration: 4)`. Successful and
informational terminal results use that policy by default. Active, validation,
blocked, failed, cancelled, partial, and unknown results remain persistent or
explicit according to their current recovery behavior.

`AppModel` owns one cancellation-aware expiry task per feedback scope, keyed by
feedback identity. Publishing a replacement cancels the old task and starts a
complete new interval. When the interval ends, the task removes feedback only
if the same identity and delayed policy are still current. This identity check
prevents an old task from clearing newer feedback. A dependency-injected sleeper
allows tests to advance time without real four-second waits.

Expiry removes the feedback value itself, so no empty layout container remains.
Accessibility announcements continue to use feedback identity/state
deduplication and are posted once when feedback appears, not again when it
expires.

### 2. Completed batch as an explicit reset boundary

Once every confirmed item is terminal, the batch enters `completed` and the
primary action becomes `Send More Books`. Intake and addition are unavailable
while that completed batch remains visible. Definitively failed items retain
their existing `Retry Failed` action alongside the new reset action.

`Send More Books` calls a dedicated main-actor reset operation that delegates
workspace and attempt cleanup to `PipelineActor.clear()`, then clears aggregate
presentation, confirmation, selection/detail disclosure, current batch/item
feedback, and batch-scoped diagnostics. It preserves saved setup, Keychain
credentials, shortcut/application preferences, selected tab, and history.

If any item is `Delivery Unknown`, the reset first presents a native
confirmation that the provider may already have accepted it. Cancelling the
confirmation changes nothing. Confirming creates a new empty batch identifier.
Pipeline events carry or resolve against their originating batch identifier,
and `AppModel` ignores events that do not match the current batch after reset.
`PipelineActor.add` also rejects intake into a completed batch so the boundary
is enforced below SwiftUI.

### 3. Definitive submission receipt

After the SMTP adapter returns definitive acceptance, the delivery attempt owns:

- its existing locally generated attempt identifier;
- originating batch, snapshot, and item identifiers;
- the sanitized original display name already produced by intake;
- the acceptance timestamp assigned when the attempt becomes terminal.

The application pipeline creates a typed `SubmissionReceipt` from those values.
Only its record projection—attempt identifier, display name, and acceptance
timestamp—is eligible for storage. Failed, cancelled, excluded, unattempted,
and uncertain attempts never create a receipt.

### 4. Record before advancing the accepted attempt

`PipelineActor` asks the shared `SendHistoryService` to record the receipt
immediately after definitive SMTP acceptance and before advancing to later
items or publishing batch completion. This closes the quit-after-acceptance gap
and makes the attempt identifier an idempotency key if an event is observed
again.

The history write is best effort relative to delivery truth. If persistence
fails, the item remains `Submitted`, the delivery is not retried, and the
pipeline emits a typed history-persistence failure. `AppModel` presents that
failure separately from the successful delivery result with a safe recovery
action. It never changes the SMTP outcome or claims the submission failed.

### 5. Bounded local history adapter

`FileSendHistoryStore` is an actor and the only production owner of
`Application Support/Book Sender/SendHistory/history-v1.json`. It reads and
writes a versioned Codable envelope with a 1 MiB encoded-file limit. The
directory and file use app-private permissions, and writes use a same-directory
temporary file plus atomic replacement. The adapter validates schema version
and fields, rejects malformed data with a typed filesystem failure, and never
silently deletes an unreadable store.

`SendHistoryService` owns semantic rules: deduplicate by record identifier,
sort by acceptance timestamp newest first with identifier as a stable
tie-breaker, retain the newest 500, and clear only after the UI's explicit
confirmation. The service returns immutable snapshots to presentation state.
The app never persists paths, source URLs, content, credentials, addresses,
SMTP replies, batch identifiers, telemetry identifiers, or Kindle state.

### 6. Local Send and History tabs

`SendBookView` adds a native selection control with exactly `Send` and
`History`. `Send` remains the default. The existing send workflow stays in the
Send tab; `SendHistoryView` renders a simple newest-first list with display name
and a locale/time-zone-aware formatted date and time.

Switching tabs is presentation-only: it neither calls the pipeline nor resets,
cancels, retries, imports, or duplicates work. History loads through the shared
service and refreshes after accepted records and clear operations. An empty
snapshot displays `No books submitted yet.`. `Clear History` is a quiet
secondary action with native confirmation and does not affect the current
batch.

### 7. Dependency injection and tests

`AppDependencies` creates one shared history adapter and service, passes it to
the pipeline and `AppModel`, and supplies the production sleeper. UI-test
dependencies use an isolated temporary history root and deterministic delivery
outcomes. Unit tests use an in-memory history store and controllable sleeper.

No production preview or demo bypass is added. UI-test launch configuration may
reset or seed only the isolated test history store so relaunch, retention,
failure, and empty-state scenarios remain deterministic.

## Requirement Traceability

| Requirement group | Design owner | Primary verification |
|---|---|---|
| FR-001 through FR-006: transient timing, replacement, persistence classes, accessibility | `AppModel`, feedback policy, injected sleeper | Unit timing/replacement tests and accessibility UI tests |
| FR-007 through FR-014: completed-batch action, reset, unknown confirmation, stale events | `AppModel`, `PipelineActor`, `SendBookView` | Reset/pipeline unit tests and mixed-outcome UI journeys |
| FR-015 through FR-016: local tabs and batch stability | `SendBookView`, `SendBookTab` | UI tab-switch tests during active delivery |
| FR-017 through FR-022: accepted-only record, timestamp, order, retention, privacy | Pipeline receipt, history service/store | Pipeline, service, adapter, relaunch, and privacy tests |
| FR-023 through FR-024: clear confirmation and empty accessibility | `SendHistoryView`, `AppModel` | UI confirmation, keyboard, focus, and empty-state tests |
| FR-025: persistence failure isolation | Pipeline history integration and feedback mapping | Injected write-failure tests |
| FR-026: submission-only wording | History presentation contract | String/catalog and UI tests |

## Validation Strategy

1. **Static source gate**: Confirm the two-route boundary, exact tab labels,
   absence of prohibited history fields/actions, no new package, and clean
   documentation diffs.
2. **Compilation gate**: Compile the Swift 6 macOS target with complete
   concurrency checking.
3. **Deterministic test gate**: Run domain, application, adapter, privacy,
   pipeline, and fixture tests using an injected sleeper and isolated stores.
4. **UI/accessibility gate**: Exercise feedback expiry, replacement, tabs,
   active-send switching, reset, unknown confirmation, history clear, relaunch,
   keyboard navigation, and announcements in XCUITest.
5. **Runtime gate**: Inspect the built application with locale, time-zone,
   relaunch, inactive/reactivated window, Reduce Transparency, Increase
   Contrast, VoiceOver, and storage-failure scenarios.
6. **Authenticated provider gate**: With explicit authorization and dedicated
   credentials, verify that only a definitive SMTP acceptance creates history;
   this gate must not infer Kindle receipt or library availability.
7. **Release gate**: Keep signing, clean-runner install, launch, Sparkle feed,
   and publication verification separate from feature acceptance.

Build, test, UI, runtime, authenticated SMTP, and release commands are not
executed during planning.

## Complexity Tracking

No constitution violations require justification.
