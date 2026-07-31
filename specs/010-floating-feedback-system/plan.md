# Implementation Plan: Floating Feedback System

**Planning Identifier**: `010-floating-feedback-system`

**Checkout Branch**: `main`

**Date**: 2026-07-31

**Spec**: [spec.md](./spec.md)

**Input**: Feature specification from
`/specs/010-floating-feedback-system/spec.md`

## Summary

Replace the screen-specific inline `ActionFeedbackView` placements with one
reusable floating notification system presented as a top-trailing overlay in
the main window and a separate top-trailing overlay in Settings. The system
keeps the existing typed `ActionFeedback` lifecycle as its semantic input, adds
window destination and presentation configuration, displays at most three
cards per window, queues additional relevant results, starts temporary timers
only after a card becomes visible, and routes optional actions through typed
commands rather than stored cross-actor closures.

The implementation separates notification presentation from durable workflow
state. Field validation, active progress, per-book status, aggregate guidance,
failure evidence, empty/loading/unavailable states, sheets, and alerts remain
inline. Closing a persistent failure card hides only the floating card; the
typed failure and its `FailureDetailView` remain available. The batch card keeps
its native `List`, hides the short default separators, and draws an explicit
near-full-width divider after every complete item except the last.

## Technical Context

**Language/Version**: Swift 6.0 with complete concurrency checking

**Primary Dependencies**: SwiftUI, AppKit, Observation, Foundation,
Security.framework, UniformTypeIdentifiers; existing exact packages only:
KeyboardShortcuts 3.0.1, Sparkle 2.9.2, ZIPFoundation 0.9.19, swift-nio 2.86.0,
and swift-nio-ssl 2.35.0

**Storage**: No new durable storage. Notifications, queue order, dismissal
markers, action-in-flight state, and expiry tasks are window-scoped ephemeral
presentation state. Existing Keychain credentials, preferences, prepared
working copies, diagnostics, and bounded send history remain unchanged.

**Testing**: Swift Testing for configuration normalization, destination
partitioning, visible/queued transitions, replacement, deduplication, expiry
races, manual dismissal, persistent-state protection, command routing, and
divider derivation; XCTest/XCUITest for overlay position, layout invariance,
modal precedence, keyboard focus, accessibility announcements, action/close
controls, window separation, appearance settings, and divider geometry

**Target Platform**: macOS 26.0+

**Project Type**: Single native macOS application with one singleton main
`Window` scene and one native `Settings` scene

**Performance Goals**: Publish or update a notification without blocking the
main actor on I/O; keep no more than three cards visible per window; keep the
queue bounded by supported action-feedback scopes; complete stack
reconciliation synchronously within one main-actor turn; preserve the existing
responsive 20-item sequential batch; cause zero underlying layout displacement
when cards appear or disappear

**Constraints**: Exactly two primary screens; no notification center, persisted
notification history, remote transport, sound system, user-configurable
placement, third-party toast package, helper process, entitlement, database, or
new dependency; temporary durations normalized to 1...5 seconds with four
seconds as default; successful/informational results always absent by five
seconds; persistent failures never auto-evicted; at most one action per card;
typed commands only; no closure crosses an actor boundary

**Scale/Scope**: Two independent hosts (`main`, `settings`); maximum three
visible cards per host; at most one current lifecycle per
destination-and-feedback scope; temporary batches remain capped at 20 books;
per-item and per-delivery progress stays inline and does not create a toast per
book; send history remains capped at 500 records

## Constitution Check

### Pre-research gate

**Result: PASS**

- **Mission and surface**: Floating feedback improves setup, sending, repeated
  actions, diagnostics, shortcut settings, and history without adding a screen,
  route, window, Settings tab, or activity destination.
- **Native boundary**: The design uses the existing native application,
  SwiftUI/AppKit capabilities, and package set. It adds no Sonner/web runtime,
  toast dependency, helper, executable, download, service, or parallel product.
- **Minimal interaction**: Successful and informational acknowledgements remain
  temporary. Active, blocked, failed, cancelled, partial, and unknown results
  remain available. The overlay removes layout churn while retaining concise
  hierarchy and keyboard access.
- **Background pipeline**: EPUB safety, audit, deterministic repair, working
  copy, revalidation, PDF eligibility, confirmation, and SMTP behavior are
  untouched. Per-book progress and outcomes remain inline.
- **Original preservation**: The feature reads and presents existing action
  state only. It neither modifies originals nor changes prepared-copy cleanup.
- **Input safety**: Archive/XML processing, safety limits, and fixture contracts
  remain unchanged and outside notification presentation.
- **Batch reliability**: Stable confirmation, sequential work, cancellation,
  failure isolation, retry behavior, and `delivery_unknown` remain unchanged.
  Notifications cannot trigger automatic retry or outcome reclassification.
- **Delivery and privacy**: No book, credential, address, path, diagnostic
  evidence, or provider data is persisted or transmitted by notifications.
  SMTP remains explicit and credentials remain in the traditional Keychain.
- **History boundary**: History eligibility, 500-record retention, privacy,
  clearing, and non-management rules are unchanged. A notification is never
  evidence of Kindle receipt.
- **Architecture and tests**: Semantic feedback stays typed; application
  presentation owns queue and timing; views render passive cards and dispatch
  typed commands. Deterministic and UI/accessibility coverage is planned.
- **Migration and distribution**: No package, entitlement, signing, Sparkle,
  installer, release, or deployment behavior changes. Validation gates remain
  separate.

### Post-design gate

**Result: PASS**

The Phase 1 design places all mutable notification lifecycle state in a
main-actor presentation center, partitions entries by the existing singleton
main and Settings scenes, and keeps views free of timing and replacement rules.
Action closures are not stored in `Sendable` models or sent between actors;
cards carry a typed `RecoveryAction`, and each scene root resolves that command
on the main actor. Temporary timers are keyed by destination and feedback
identity and start only on visible promotion, so queued cards receive a full
interval and stale tasks cannot remove replacements.

The design explicitly retains contextual validation, progress, per-book state,
failure evidence, confirmation, uncertainty, and history semantics. It adds no
storage or dependency and does not change the processing or delivery pipeline.
No constitutional exception or complexity justification is required.

## Project Structure

### Documentation (this feature)

```text
specs/010-floating-feedback-system/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── batch-row-divider.md
│   ├── notification-action-accessibility.md
│   ├── notification-lifecycle.md
│   └── notification-presentation.md
├── checklists/
│   └── requirements.md
└── tasks.md                         # generated by speckit-tasks
```

### Source Code (repository root)

```text
BookSender/
├── App/
│   ├── AppModel.swift                    # publish typed feedback and commands
│   └── BookSenderApp.swift               # main root host composition
├── Application/
│   └── Presentation/
│       ├── ActionFeedbackService.swift   # semantic lifecycle construction
│       ├── FloatingNotificationCenter.swift
│       └── FloatingNotificationModels.swift
├── Domain/
│   └── Models/
│       └── FeedbackModels.swift          # existing typed feedback/recovery data
└── Features/
    ├── DeliverySetup/
    │   └── DeliverySetupView.swift       # remove inline acknowledgement card
    ├── SendBook/
    │   ├── SendBookView.swift            # remove inline card; explicit dividers
    │   └── SendHistoryView.swift          # remove inline acknowledgement card
    ├── Settings/
    │   ├── BookSenderSettingsView.swift  # settings root host composition
    │   └── ShortcutSettingsView.swift    # remove inline acknowledgement card
    └── Shared/
        ├── FailureDetailView.swift        # retain evidence; remove copy banner
        ├── FloatingNotificationCard.swift
        └── FloatingNotificationHost.swift

BookSenderTests/
├── Application/
│   ├── ActionFeedbackExpiryTests.swift
│   ├── ActionFeedbackServiceTests.swift
│   ├── FloatingNotificationCenterTests.swift
│   └── FloatingNotificationModelsTests.swift
└── Domain/
    └── FeedbackModelsTests.swift

BookSenderUITests/
├── AccessibilityUITests.swift
├── BatchSendUITests.swift
├── FloatingNotificationUITests.swift
├── SendHistoryUITests.swift
└── SettingsUITests.swift
```

**Structure Decision**: Add one presentation slice rather than embedding stack,
timer, and action rules in each screen. `ActionFeedbackService` continues to
construct semantic action lifecycles. `FloatingNotificationCenter` becomes the
single main-actor owner of current, visible, queued, hidden, and expiring
presentation entries. `FloatingNotificationHost` and
`FloatingNotificationCard` are passive shared SwiftUI components. Existing
feature views retain only their durable contextual evidence and actions.

## Design

### 1. Preserve typed semantic feedback as the source

Keep `ActionFeedback`, `FeedbackScope`, `FeedbackAction`, `FeedbackState`,
`FeedbackDismissalPolicy`, `FailurePresentation`, and `RecoveryAction` as the
semantic action-result contract. Extend presentation around these values rather
than converting outcomes into loose strings or view-local booleans.

Add `FeedbackScope.diagnosticCopy` as the dedicated current slot for copy
success/failure. This replaces `currentCopyFeedback` and
`copyFeedbackExpiryTask`, lets copy feedback coexist with the failure whose
details were copied, and participates in normal destination, queue, and expiry
rules.

`ActionFeedbackService` remains a pure lifecycle factory and reconciler. Its
default success duration remains four seconds. Delayed durations are normalized
to the constitutional 1...5-second range before a card can be published.
Persistent, explicit, and replace-on-next-action policies retain their current
meaning.

Move current feedback ownership from the raw `feedbackByScope` dictionary and
separate copy-feedback slot into `FloatingNotificationCenter`. `AppModel`
continues exposing compatibility queries such as `feedback(for:)`, but delegates
them to the center. This keeps existing application operations typed while
giving queue, visibility, dismissal, and timer rules one owner.

### 2. Partition presentation by owning window

Introduce `NotificationDestination.main` and `.settings`. Every publication
includes a destination, and the center keys current lifecycles by
`(destination, scope)`. Main-window operations—bootstrap completion, intake,
batch, history, update check, and main diagnostics—publish to `.main`.
Shortcut settings publish to `.settings`. Delivery setup publishes to `.main`
during onboarding and `.settings` when edited from Settings.

Wrap `MainWindowContent` in one `FloatingNotificationHost` for `.main`, and wrap
the root `TabView` in `BookSenderSettingsView` in a separate host for
`.settings`. The host uses an overlay aligned to the upper trailing content
edge with a bounded width and native scene padding. It does not use
`safeAreaInset`, a form section, list row, or other layout-participating
container.

Closing or recreating one scene clears its temporary/queued presentation tasks
for that destination only. Typed failure and workflow state remain in
`AppModel`; nothing is moved into the other scene.

### 3. Reconcile one bounded stack per destination

For each destination the center maintains:

- a current entry per supported feedback scope;
- up to three visible entry identifiers, newest closest to the anchor;
- a FIFO waiting order for still-relevant entries;
- hidden identifiers for manually dismissed persistent cards whose typed
  failure remains available;
- one expiry task per visible temporary entry.

Publishing the same lifecycle updates the entry in place. Equivalent repeated
feedback retains identity and increments the existing occurrence count.
Publishing a new lifecycle for the same destination and scope replaces the old
entry, cancels its task, removes its queued/hidden markers, and reconciles the
new state. Per-item progress never enters this stack; it remains in batch rows,
so the queue is bounded by high-level action scopes rather than batch size.

When three cards are visible, new relevant entries wait. Persistent visible
cards are never evicted. When a card leaves, the next still-current queued entry
is promoted. A queued entry replaced or resolved before promotion is removed
without ever appearing.

### 4. Start temporary lifetime only on visible promotion

`FloatingNotificationCenter` owns cancellation-aware tasks keyed by
`NotificationTaskKey(destination, feedbackID)`. A temporary task is created
only when an entry transitions from queued to visible. The injected
`FeedbackSleep` remains the deterministic clock boundary.

When the sleep finishes, the center removes the entry only if destination,
scope, identity, visible phase, and delayed policy still match. Replacement,
manual close, host disappearance, or state transition cancels the old task.
Application inactivity does not pause a temporary timer, so expired cards do
not return on reactivation.

Invalid duration input is normalized before scheduling: missing duration uses
four seconds, finite values below one become one, values above five become five,
and non-finite input uses four. Successful and informational feedback cannot
select a persistent lifetime.

### 5. Render one reusable adaptive notification card

`FloatingNotificationCard` receives one immutable presentation entry and
callbacks for close and typed action activation. It renders:

- an automatic semantic icon, a selected system icon, or no icon;
- optional title and supporting message;
- an optional occurrence count;
- an optional close button;
- at most one action button;
- semantic accessibility label/value independent of color.

Use a compact system-adaptive material, subtle border, restrained shadow, and
native text/button styles. Do not introduce decorative glass, custom color
themes, fixed light backgrounds, or a third-party toast aesthetic. Cap the card
width and supporting lines so the stack stays outside the central workflow.

The stack uses opacity plus a short trailing transition. With Reduce Motion,
remove spatial movement and use identity/opacity only. Reduce Transparency and
Increase Contrast continue using system-adaptive surfaces and semantic
foreground styles.

### 6. Route optional actions as typed commands

`NotificationActionDescriptor` stores only a stable identifier, English label,
typed `RecoveryAction`, and dismissal-on-activation policy. It is
`Equatable`/`Sendable`; it stores no closure.

Each scene root supplies a main-actor dispatcher to its host. The card sends the
typed command to that dispatcher. Main commands call existing `AppModel`
recovery methods or environment actions such as opening Settings. Settings
commands select the appropriate tab and issue a typed focus request that the
relevant settings view consumes. No action handler crosses an actor boundary or
enters a persisted/domain value.

The center marks the action in flight before dispatch so a double click or
repeated keyboard activation cannot execute it twice. The result either
replaces the lifecycle, hides the card when configured, or re-enables the action
after a failed no-state-change dispatch. Temporary cards may expose only a
nonessential action whose expiry does not remove the required recovery path.

### 7. Remove inline acknowledgements but retain contextual state

Remove `ActionFeedbackView` from `DeliverySetupView`, `SendBookView`,
`SendHistoryView`, `ShortcutSettingsView`, and the expanded copy-feedback area
of `FailureDetailView`. Delete `ActionFeedbackView.swift` only after every
consumer and accessibility identifier has migrated.

Keep:

- `setupErrors` and `setupMessage` adjacent to delivery fields/form context;
- setup and batch progress controls;
- `BatchItemRow` preparation and delivery states;
- aggregate and delivery-unknown guidance;
- `FailureDetailView` and sanitized diagnostics;
- history loading, unavailable, empty, and list states;
- confirmation sheets and destructive/uncertainty alerts.

Views query the latest typed feedback failure for their own destination and
scope to render `FailureDetailView`; manually closing a card does not clear that
failure. Copy success/failure publishes a new destination-scoped floating card
instead of nesting another feedback view inside the details disclosure.

### 8. Draw deterministic near-full-width batch dividers

Keep the existing `GroupBox` and `List`. Hide the list's default row separator,
which currently inherits platform insets and produces the short trailing line.
Enumerate the stable item collection and append an explicit `Divider` after the
complete item content only when the item is not last.

Apply balanced leading/trailing row insets so the explicit divider spans at
least 90% of usable card width without touching the GroupBox boundary. Place the
divider after `ItemDetailDisclosure`, so expanding details never splits one
book's content. Give each divider a deterministic accessibility identifier for
geometry checks while keeping it hidden from the semantic reading order.

### 9. Preserve deterministic test seams

Reuse `FeedbackSleep` for lifetime tests and add a center factory that accepts
the sleeper. Unit tests publish directly into an isolated center and inspect
immutable destination snapshots. No unit test waits real seconds.

Add coverage for:

- duration normalization and constitutional state/lifetime combinations;
- main/Settings isolation;
- three-visible ordering and queued promotion;
- persistent-card protection and stale queued removal;
- timer start on promotion, replacement cancellation, and stale-task safety;
- equivalent feedback deduplication and occurrence counts;
- close shown/hidden rules and persistent hidden state;
- typed action single activation and result replacement;
- host disappearance and application inactivity;
- removal of copy-feedback special scheduling.

UI tests retain deterministic launch fixtures, update selectors from
`feedback.*` to `notification.*`, and compare element frames to prove overlay
layout invariance and divider width. They also cover keyboard focus, one
announcement, Reduce Motion, Reduce Transparency, Increase Contrast, modal
precedence, and cross-window isolation.

### 10. Migration sequence

1. Add notification presentation models and pure normalization.
2. Add the main-actor center with destination snapshots, reconciliation, queue,
   hidden state, and injected timing.
3. Add unit tests for models and center before view migration.
4. Add passive card and host views with accessibility identifiers.
5. Compose independent hosts at main and Settings roots.
6. Route current `AppModel` publications into destination-scoped entries and
   migrate copy feedback.
7. Remove inline `ActionFeedbackView` consumers while retaining failure detail.
8. Add explicit batch dividers and geometry identifiers.
9. Update UI/accessibility tests and static migration checks.
10. Remove the obsolete shared inline feedback view and special expiry slots
    only after zero consumers remain.

## Requirement Traceability

| Requirement group | Design owner | Primary verification |
|---|---|---|
| FR-001–FR-007: shared overlay, destination, bounds, modal priority, no layout shift | root hosts, `NotificationDestination`, `FloatingNotificationHost` | destination unit tests and overlay/layout UI tests |
| FR-008–FR-019: content, icon, close, action, wrapping | presentation models, normalization service, card | configuration matrix unit tests and card accessibility UI tests |
| FR-020–FR-029: temporary/persistent lifetime and normalization | center, dismissal policy, injected sleeper | deterministic lifetime, inactivity, replacement, and invalid-duration tests |
| FR-030–FR-038: stack, queue, deduplication, replacement, host close | center destination snapshot and task keys | max-three, queue promotion, stale entry, persistent protection, and scene-close tests |
| FR-039–FR-048: migration and durable contextual evidence | feature views, `FailureDetailView`, `AppModel` | source scans, failure/recovery tests, delivery-unknown journeys |
| FR-049–FR-055: focus, reading order, appearance settings | card, host, typed scene dispatcher | keyboard, announcement, Reduce Motion/Transparency, and contrast UI tests |
| FR-056–FR-061: near-full-width dividers | `SendBookView` explicit divider row | geometry UI tests at multiple sizes and expanded-detail states |
| CC-001–CC-010 | all design owners | constitution review plus static/runtime gate separation |

## Validation Strategy

1. **Static source gate**: Confirm both hosts exist only at scene roots, inline
   `ActionFeedbackView` consumers are gone, no new package/storage exists,
   contextual state remains, destination routing is exhaustive, dividers are
   explicit and omit the final row, and documentation diffs are clean.
2. **Compilation gate**: Compile the Swift 6 macOS target with complete
   concurrency checking and verify the main-actor center, task captures,
   Observation boundaries, and typed dispatcher.
3. **Deterministic unit gate**: Run model, center, feedback, AppModel, and
   existing workflow tests with controlled sleepers and no real time delays.
4. **UI/accessibility gate**: Run overlay position, layout invariance,
   main/Settings isolation, action/close, keyboard focus, announcement,
   modal-precedence, appearance, and divider-geometry journeys.
5. **Manual runtime gate**: Inspect the built application with window
   activation changes, main/Settings open together, minimum sizing, long text,
   three persistent cards, overflow, sheets/alerts, VoiceOver, and appearance
   accessibility options.
6. **Authenticated provider gate**: No new live SMTP behavior is introduced.
   Existing authenticated delivery validation remains separate and is required
   only to prove no outcome or retry regression.
7. **Release gate**: Signing, clean-runner installation, Sparkle, appcast,
   publication, and public endpoint checks remain separate from feature
   acceptance.

Build, test, app launch, UI automation, authenticated SMTP, signing, and release
commands are not executed during planning.

## Agent Context Update

The active feature pointer remains
`.specify/feature.json -> specs/010-floating-feedback-system`. The installed
Spec Kit 0.12.9 Codex integration has no `update-agent-context.sh` script; its
read-only integration status reports the Codex integration installed and
aligned. Planning therefore changes no managed agent instruction file and uses
the feature pointer plus these artifacts as the downstream context.

## Complexity Tracking

No constitution violations require justification.
