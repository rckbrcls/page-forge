# Tasks: Floating Feedback System

**Input**: Design documents from
`/specs/010-floating-feedback-system/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md),
[research.md](./research.md), [data-model.md](./data-model.md),
[contracts/](./contracts/)

**Tests**: Required by the feature specification. Author deterministic model,
center, presentation, UI, accessibility, and divider-geometry tests before the
implementation task they govern. Do not run build, test, app, UI automation,
SMTP, signing, or release commands without Erick's separate explicit
authorization.

**Organization**: Tasks are grouped by independently testable user story.
`ActionFeedback` remains the typed semantic source; the new system changes
ephemeral presentation and batch-row separation without changing pipeline,
delivery, history, credential, or diagnostic truth.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel because it touches different files and has no
  unmet dependency within the phase
- **[Story]**: Maps to US1, US2, US3, US4, or US5 from [spec.md](./spec.md)
- Every task names its exact implementation, test, or evidence path

## Phase 1: Setup (Shared Test Infrastructure)

**Purpose**: Establish deterministic builders and launch fixtures for the
ephemeral notification system without changing production behavior.

- [X] T001 [P] Create fixed feedback identities, destinations, timestamps, configurations, entries, and destination-snapshot builders in `BookSenderTests/Support/NotificationTestFixtures.swift`
- [X] T002 [P] Extend the controlled feedback sleeper with visible-promotion observations, cancellation inspection, and an isolated notification-center factory in `BookSenderTests/Support/TestDoubles.swift`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Define the typed presentation boundary, pure normalization, and
main-actor ownership required by every notification story.

**⚠️ CRITICAL**: Complete this phase before integrating any notification UI.

### Foundational Tests

- [X] T003 [P] Add tests for destination/key identity, icon fallback, lifetime normalization, close-policy validity, action descriptors, entry invariants, and immutable snapshots in `BookSenderTests/Application/FloatingNotificationModelsTests.swift`
- [X] T004 [P] Extend feedback model tests for the independent `diagnosticCopy` scope and exhaustive accessibility identifiers in `BookSenderTests/Domain/FeedbackModelsTests.swift`
- [X] T005 Add isolated center contract tests for main/settings state separation, publish/snapshot behavior, and injected-time ownership in `BookSenderTests/Application/FloatingNotificationCenterTests.swift`

### Foundational Implementation

- [X] T006 Add `FeedbackScope.diagnosticCopy` while preserving existing semantic feedback, dismissal, and recovery contracts in `BookSender/Domain/Models/FeedbackModels.swift`
- [X] T007 Define `NotificationDestination`, `NotificationKey`, icon/lifetime/close/action configuration, phase, entry, snapshot, task-key, focus-request, and batch-row-position models with pure validation in `BookSender/Application/Presentation/FloatingNotificationModels.swift`
- [X] T008 Create the `@MainActor @Observable` center boundary, independent destination storage, immutable snapshots, injected `FeedbackSleep`, and explicit publish/close/action/attach/detach APIs in `BookSender/Application/Presentation/FloatingNotificationCenter.swift`

**Checkpoint**: Notification models and the isolated center can be tested without
SwiftUI, storage, network, or a running application.

---

## Phase 3: User Story 1 - Receive Feedback Without Moving the Workflow (Priority: P1) 🎯 MVP

**Goal**: Present supported action feedback in a top-trailing overlay owned by
the correct window, with no content insertion, layout movement, reserved space,
or modal obstruction.

**Independent Test**: Trigger success, informational, and failure feedback in
every supported scope across the main and Settings windows; verify the correct
host receives each card and underlying form, batch, history, and shortcut frames
are identical before, during, and after presentation.

### Tests for User Story 1

- [X] T009 [P] [US1] Add AppModel routing tests for setup, shortcut, intake, batch, delivery, history, diagnostics, and application feedback destinations in `BookSenderTests/Application/AppModelNotificationRoutingTests.swift`
- [X] T010 [P] [US1] Add main/settings host isolation, layout-invariance, no-reserved-space, window-bounds, and modal-precedence journeys in `BookSenderUITests/FloatingNotificationUITests.swift`
- [X] T011 [P] [US1] Update setup, shortcut, batch, history, and diagnostic journeys to expect `notification.*` overlays without losing durable inline context in `BookSenderUITests/SettingsUITests.swift`, `BookSenderUITests/BatchSendUITests.swift`, `BookSenderUITests/SendHistoryUITests.swift`, and `BookSenderUITests/RecoveryJourneyUITests.swift`

### Implementation for User Story 1

- [X] T012 [P] [US1] Implement the passive adaptive-material notification card shell, bounded text layout, and deterministic `notification.<destination>.<scope>` identifiers in `BookSender/Features/Shared/FloatingNotificationCard.swift`
- [X] T013 [P] [US1] Implement a top-trailing overlay host with safe-area bounds, three-card container geometry, non-blocking hit testing outside cards, and modal-safe layering in `BookSender/Features/Shared/FloatingNotificationHost.swift`
- [X] T014 [US1] Own and inject one shared notification center, map every current feedback scope to an explicit destination, and publish existing `ActionFeedback` without changing semantic state in `BookSender/App/AppDependencies.swift` and `BookSender/App/AppModel.swift`
- [X] T015 [US1] Compose the main host around `MainWindowContent` and the Settings host around `BookSenderSettingsView` without adding a scene, window, tab, or primary screen in `BookSender/App/BookSenderApp.swift` and `BookSender/Features/Settings/BookSenderSettingsView.swift`
- [X] T016 [US1] Remove inline acknowledgement placement while retaining field validation, progress, aggregate guidance, empty/unavailable states, and confirmations in `BookSender/Features/DeliverySetup/DeliverySetupView.swift`, `BookSender/Features/Settings/ShortcutSettingsView.swift`, `BookSender/Features/SendBook/SendBookView.swift`, and `BookSender/Features/SendBook/SendHistoryView.swift`
- [X] T017 [US1] Publish diagnostic copy success/failure through `diagnosticCopy` while retaining the expanded evidence and recovery controls in `BookSender/App/AppModel.swift`, `BookSender/Features/Shared/FailureDetailView.swift`, and `BookSender/Features/SendBook/ItemDetailDisclosure.swift`

**Checkpoint**: US1 is independently functional: supported feedback floats in
the owning window, contextual state remains, and the underlying workflow never
moves.

---

## Phase 4: User Story 2 - Configure a Reusable Notification (Priority: P1)

**Goal**: Let every supported producer use one normalized contract for lifetime,
duration, icon, title/message, close visibility, and at most one typed action.

**Independent Test**: Present the complete permitted configuration matrix,
including temporary bounds, persistent variants, derived/custom/absent icons,
short and wrapping content, every close/action combination, and invalid inputs;
verify deterministic normalization and one reusable visual component.

### Tests for User Story 2

- [X] T018 [P] [US2] Extend configuration matrix tests for missing, non-finite, below-minimum, valid, and above-maximum durations plus state/lifetime compatibility in `BookSenderTests/Application/FloatingNotificationModelsTests.swift`
- [X] T019 [P] [US2] Add projection tests for default and caller-selected icon, title/message, close policy, optional action, sanitized content, and persistent-resolution requirements in `BookSenderTests/Application/ActionFeedbackServiceTests.swift`
- [X] T020 [P] [US2] Add visual and accessibility journeys for icon-present/icon-absent, one-line/multi-line, close-only, action-only, both-control, and no-control cards at minimum window sizes in `BookSenderUITests/FloatingNotificationUITests.swift`

### Implementation for User Story 2

- [X] T021 [US2] Implement the pure `ActionFeedback`-to-notification projection, default four-second lifetime, inclusive one-to-five-second clamping, semantic icon map, and invalid-configuration fallback in `BookSender/Application/Presentation/ActionFeedbackService.swift` and `BookSender/Application/Presentation/FloatingNotificationModels.swift`
- [X] T022 [US2] Complete reusable card rendering for optional title, supporting message, occurrence count, automatic/custom/absent icon, close control, one action button, wrapping, and bounded width in `BookSender/Features/Shared/FloatingNotificationCard.swift`
- [X] T023 [US2] Assign explicit configuration overrides only where the product catalogue requires them while keeping all setup, shortcut, intake, batch, delivery, history, diagnostic-copy, and application feedback on the shared projection in `BookSender/App/AppModel.swift`
- [X] T024 [US2] Derive at most one `NotificationActionDescriptor` from existing `RecoveryAction`, reject destructive or multi-choice modal decisions, and guarantee a resolution path for non-closeable persistent cards in `BookSender/Application/Presentation/ActionFeedbackService.swift` and `BookSender/App/AppModel.swift`
- [X] T025 [US2] Render the declared action before close in deterministic keyboard order and remove absent icon/control placeholders from visual and accessibility layout in `BookSender/Features/Shared/FloatingNotificationCard.swift`
- [X] T026 [US2] Add test-only launch scenarios for the permitted configuration matrix without production demo state or personal data in `BookSender/App/AppDependencies.swift` and `BookSenderUITests/FloatingNotificationUITests.swift`

**Checkpoint**: US2 is independently functional: all supported configurations
normalize through one contract and render through one reusable card.

---

## Phase 5: User Story 3 - Manage Multiple Notifications Calmly (Priority: P1)

**Goal**: Maintain one independent, ordered stack per window with at most three
visible cards, a relevance queue, in-place deduplication/replacement, and
visible-only temporary lifetimes.

**Independent Test**: Publish 20 rapid events containing duplicates, state
transitions, persistent failures, queued temporary results, window lifecycle
changes, inactivity, and replacement races; verify no overlap, no more than
three visible cards, no lost persistent action, and no stale reappearance.

### Tests for User Story 3

- [X] T027 [P] [US3] Add max-three ordering, oldest-relevant promotion, persistent protection, independent destination queue, and 20-event burst tests in `BookSenderTests/Application/FloatingNotificationQueueTests.swift`
- [X] T028 [P] [US3] Add equivalent-feedback deduplication, occurrence-count, same-key transition, stack-position retention, queued obsolescence, and independent-dismissal tests in `BookSenderTests/Application/FloatingNotificationReconciliationTests.swift`
- [X] T029 [P] [US3] Add visible-only timer, promotion full-duration, replacement cancellation, stale-task rejection, inactive expiry, and host-detach lifecycle tests using controlled time in `BookSenderTests/Application/FloatingNotificationTimingTests.swift`
- [X] T030 [P] [US3] Update expiry regression tests to prove the center replaces per-scope and diagnostic-copy schedulers without changing semantic feedback policy in `BookSenderTests/Application/ActionFeedbackExpiryTests.swift` and `BookSenderTests/Application/AppModelDiagnosticsTests.swift`
- [X] T031 [P] [US3] Add three-card stack, fourth-card promotion, duplicate burst, cross-window isolation, navigation, deactivation/reactivation, and close/reopen journeys in `BookSenderUITests/FloatingNotificationUITests.swift`

### Implementation for User Story 3

- [X] T032 [US3] Implement per-destination reconciliation, maximum-three visible ordering, oldest-relevant queued promotion, hidden persistent presentation, and persistent-card protection in `BookSender/Application/Presentation/FloatingNotificationCenter.swift`
- [X] T033 [US3] Implement key-based equivalent deduplication, occurrence updates, lifecycle replacement, state-transition updates, queued-obsolete removal, and independent entry dismissal in `BookSender/Application/Presentation/FloatingNotificationCenter.swift`
- [X] T034 [US3] Start expiry only on visible promotion, key tasks by destination and exact feedback identity, cancel replacements, reject stale completion, and reconcile elapsed time across application inactivity in `BookSender/Application/Presentation/FloatingNotificationCenter.swift`
- [X] T035 [US3] Attach/detach hosts explicitly, remove detached temporary presentation, cancel its tasks, retain relevant persistent state for later promotion, and keep main/settings lifecycles isolated in `BookSender/Application/Presentation/FloatingNotificationCenter.swift` and `BookSender/Features/Shared/FloatingNotificationHost.swift`
- [X] T036 [US3] Remove AppModel-owned per-scope and diagnostic-copy expiry scheduling so the center is the sole presentation timer while `feedbackByScope` remains semantic workflow state in `BookSender/App/AppModel.swift`

**Checkpoint**: US3 is independently functional: bursts remain calm and
bounded, timers are race-safe, and persistent actionable feedback is never
discarded to make room.

---

## Phase 6: User Story 4 - Act On or Dismiss Feedback Accessibly (Priority: P2)

**Goal**: Make notification meaning, action, and close operation accessible by
keyboard, pointer, and assistive technology without stealing or losing workflow
focus.

**Independent Test**: Operate every interactive variant by keyboard and
assistive technology under Reduce Motion, Reduce Transparency, and Increase
Contrast; verify one announcement, deterministic control order, single action
dispatch, stable workflow focus, preserved failure evidence, and unchanged
delivery uncertainty.

### Tests for User Story 4

- [X] T037 [P] [US4] Add single-activation, in-flight suppression, dismissal-after-activation, replacement result, and destination-scoped focus-request tests in `BookSenderTests/Application/FloatingNotificationCenterTests.swift` and `BookSenderTests/Application/AppModelNotificationRoutingTests.swift`
- [X] T038 [P] [US4] Add keyboard order, labels, hints, visible focus, no redundant focus stop, focus preservation, and one-announcement journeys in `BookSenderUITests/AccessibilityUITests.swift` and `BookSenderUITests/FloatingNotificationUITests.swift`
- [X] T039 [P] [US4] Add Reduce Motion, Reduce Transparency, Increase Contrast, pointer hit-target, long-description, and minimum-size accessibility journeys in `BookSenderUITests/FloatingNotificationAppearanceUITests.swift`
- [X] T040 [P] [US4] Add persistent-failure recovery, diagnostic-detail retention, modal precedence, and `Delivery Unknown` no-retry/no-reclassification journeys in `BookSenderUITests/RecoveryJourneyUITests.swift` and `BookSenderUITests/BatchSendUITests.swift`

### Implementation for User Story 4

- [X] T041 [US4] Dispatch each typed notification command at most once while in flight, apply `keep`/`hide`/`awaitReplacement`, and emit destination-scoped `NotificationFocusRequest` values without storing escaping handlers in `BookSender/Application/Presentation/FloatingNotificationCenter.swift` and `BookSender/App/AppModel.swift`
- [X] T042 [US4] Add semantic grouping, one outcome announcement, deterministic action-then-close order, meaningful labels/hints, visible focus, and no focus target for passive cards in `BookSender/Features/Shared/FloatingNotificationCard.swift`
- [X] T043 [US4] Preserve underlying workflow focus during publish, replace, reorder, expire, and close; reduce or remove spatial animation under Reduce Motion in `BookSender/Features/Shared/FloatingNotificationHost.swift`
- [X] T044 [US4] Adapt card material, border, icon, controls, and focus treatment for Reduce Transparency and Increase Contrast without converting notifications into decorative Liquid Glass controls in `BookSender/Features/Shared/FloatingNotificationCard.swift`
- [X] T045 [US4] Consume typed focus/recovery requests only in the matching scene and retain existing field, item, retry, detail, history, and shortcut recovery paths in `BookSender/App/BookSenderApp.swift`, `BookSender/Features/DeliverySetup/DeliverySetupView.swift`, `BookSender/Features/Settings/ShortcutSettingsView.swift`, `BookSender/Features/SendBook/SendBookView.swift`, and `BookSender/Features/SendBook/SendHistoryView.swift`

**Checkpoint**: US4 is independently functional: every permitted notification
is understandable and operable without focus theft or mutation of durable
workflow truth.

---

## Phase 7: User Story 5 - Scan Batch Rows With Near-Full Dividers (Priority: P2)

**Goal**: Separate complete adjacent book rows with calm, balanced dividers
spanning at least 90% of usable width and omit the final divider.

**Independent Test**: Measure batches of 1, 2, 3, and 20 items across supported
window sizes, scrolling, long names, state changes, expanded details, and
Increase Contrast; verify exactly `n - 1` dividers and a minimum 0.90 usable
width ratio.

### Tests for User Story 5

- [X] T046 [P] [US5] Add deterministic `BatchRowPosition` tests for empty, single, multi-item, reordered, removed, and stable-snapshot batches in `BookSenderTests/Application/FloatingNotificationModelsTests.swift`
- [X] T047 [P] [US5] Add divider count, identifier, width-ratio, balanced-inset, final-row omission, expanded-detail, resize, scroll-reuse, and Increase Contrast geometry journeys in `BookSenderUITests/BatchSendUITests.swift`

### Implementation for User Story 5

- [X] T048 [US5] Enumerate the stable batch snapshot, hide native row separators, and append an explicit divider only after each complete non-final row in `BookSender/Features/SendBook/SendBookView.swift`
- [X] T049 [US5] Apply balanced row/divider insets that remain inside the batch card and span at least 90% of usable width after `ItemDetailDisclosure` in `BookSender/Features/SendBook/SendBookView.swift`
- [X] T050 [US5] Give each divider a deterministic `sendBook.item.divider.<itemID>` test identifier while keeping it decorative, non-interactive, semantically subordinate, and compatible with Increase Contrast in `BookSender/Features/SendBook/SendBookView.swift`

**Checkpoint**: US5 is independently functional: every complete adjacent row
pair is visually connected by one near-full-width divider.

---

## Phase 8: Polish & Cross-Cutting Verification

**Purpose**: Remove obsolete presentation code, prove scope coverage, and keep
static, compiled, runtime, provider, and release evidence separate.

- [X] T051 Remove `BookSender/Features/Shared/ActionFeedbackView.swift` only after a zero-consumer scan and remove obsolete inline feedback parameters/selectors from `BookSender/Features/Shared/FailureDetailView.swift`, `BookSender/Features/SendBook/ItemDetailDisclosure.swift`, `BookSenderTests/Application/AppModelDiagnosticsTests.swift`, and `BookSenderUITests/AccessibilityUITests.swift`
- [X] T052 [P] Reconcile all catalogued feedback producers against the shared center, classify any newly discovered presentation as floating or durable contextual state, and record traceability in `specs/010-floating-feedback-system/quickstart.md`
- [X] T053 [P] Update reusable notification, accessibility, non-persistence, no-notification-history, and divider behavior documentation in `README.md`, `docs/desktop-migration.md`, and `docs/troubleshooting.md`
- [X] T054 Run `git diff --check`, Swift parse, host/destination, zero-inline-consumer, accessibility-identifier, divider, persistence, package, and forbidden-surface static scans and record only static evidence in `specs/010-floating-feedback-system/quickstart.md`
- [ ] T055 After separate explicit authorization, run compilation, deterministic unit tests, focused UI/accessibility tests, and performance/regression tests as distinct gates and record only completed evidence in `specs/010-floating-feedback-system/quickstart.md`
- [ ] T056 After separate explicit authorization, complete manual macOS appearance/focus/window lifecycle inspection, optional authenticated SMTP regression, and release validation as independent gates in `specs/010-floating-feedback-system/quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: Starts first and changes test support only.
- **Phase 2 (Foundational)**: Depends on Phase 1 and blocks all story UI.
- **US1 (Phase 3)**: Depends on Phase 2 and is the recommended MVP.
- **US2 (Phase 4)**: Depends on US1's host/card path and completes its reusable
  configuration contract.
- **US3 (Phase 5)**: Depends on US2 normalization and extends the center with
  bounded stack, queue, replacement, and timing behavior.
- **US4 (Phase 6)**: Depends on US2's controls and US3's lifecycle/action state.
- **US5 (Phase 7)**: Its tests may be authored after Phase 2, but implementation
  follows US1 to avoid concurrent edits in `SendBookView.swift`.
- **Phase 8 (Polish)**: Depends on all selected stories.

### User Story Dependency Graph

```text
Setup -> Foundational -> US1 (MVP) -> US2 -> US3 -> US4 -> Polish
                          |
                          +-------------> US5 -----------+
```

### Within Each User Story

- Author the listed deterministic and UI tests before accepting implementation.
- Keep typed models and pure normalization before center behavior.
- Keep center behavior before host/card integration that consumes it.
- Keep semantic `ActionFeedback` and durable contextual state independent from
  ephemeral visibility.
- Complete the story's independent test checkpoint before beginning the next
  dependent story.
- Coordinate tasks that edit `AppModel.swift`, `FloatingNotificationCenter.swift`,
  `FloatingNotificationCard.swift`, `SendBookView.swift`, or shared UI tests.

### Parallel Opportunities

- **Setup**: T001 and T002 touch separate support files.
- **Foundation**: T003 and T004 can be authored in parallel; T005 follows the
  model contract, then T006 through T008 proceed in order.
- **US1 tests**: T009, T010, and T011 can be authored in parallel.
- **US1 views**: T012 and T013 can proceed in parallel before T015.
- **US2 tests**: T018, T019, and T020 can be authored in parallel.
- **US3 tests**: T027 through T031 can be authored in parallel after US2.
- **US4 tests**: T037 through T040 can be authored in parallel after US3.
- **US5 tests**: T046 and T047 can be authored in parallel after Phase 2.
- **Polish**: T052 and T053 can proceed in parallel before T054.

## Parallel Execution Examples

### User Story 1

```text
T009: AppModel destination-routing tests
T010: Host isolation and layout-invariance UI tests
T011: Existing workflow selector and durable-context regressions
T012: Passive notification card
T013: Root overlay host
```

After those independent files are ready, execute T014 -> T015 -> T016 -> T017.

### User Story 2

```text
T018: Duration and state compatibility matrix
T019: Projection and configuration policy tests
T020: Card variant UI/accessibility matrix
```

Then execute T021 -> T022 -> T023 -> T024 -> T025 -> T026.

### User Story 3

```text
T027: Maximum-three, order, queue, and burst tests
T028: Deduplication, replacement, and dismissal tests
T029: Timer, inactivity, and detach race tests
T030: Existing expiry/copy scheduler regression tests
T031: Stack, promotion, cross-window, and lifecycle UI journeys
```

Then execute T032 -> T033 -> T034 -> T035 -> T036.

### User Story 4

```text
T037: Typed action and focus-request tests
T038: Keyboard, focus, and announcement journeys
T039: Appearance accessibility journeys
T040: Recovery, uncertainty, and modal regressions
```

Then execute T041 -> T042 -> T043 -> T044 -> T045.

### User Story 5

```text
T046: Batch row position model tests
T047: Divider geometry and appearance journeys
```

Then execute T048 -> T049 -> T050.

## Implementation Strategy

### MVP First

1. Complete Phase 1 and Phase 2.
2. Deliver US1 only.
3. Verify main/settings isolation, complete feedback-scope coverage, layout
   invariance, no reserved space, contextual-state retention, and modal
   precedence before adding configuration or queue complexity.

### Incremental Delivery

1. **US1**: Move feedback out of workflow layout into the correct scene overlay.
2. **US2**: Complete the reusable configuration and typed optional action
   contract.
3. **US3**: Add the maximum-three stack, relevance queue, deduplication,
   replacement, and race-safe visible lifetime.
4. **US4**: Complete keyboard, focus, announcement, recovery, and appearance
   accessibility.
5. **US5**: Replace short native row separators with explicit near-full dividers.
6. **Polish**: Delete obsolete inline presentation and record each authorized
   evidence gate separately.

### Product P1 Completion

US1, US2, and US3 are Priority P1. The smallest demonstrable MVP is US1; the
complete P1 notification system requires Phases 1 through 5.

## Notes

- Work on the current branch; do not create a branch, stage, or commit unless
  Erick explicitly requests it.
- Do not build, test, launch, automate the UI, contact a real SMTP provider,
  sign, package, or publish without separate explicit authorization.
- Do not add a dependency, helper process, storage, notification history,
  telemetry, analytics, network transport, third screen, window, or Settings
  tab.
- Do not move field validation, active progress, per-item terminal results,
  failure evidence, empty/unavailable state, or confirmations into ephemeral
  notifications.
- Notification close and action behavior must never retry delivery silently,
  change `Delivery Unknown`, create send-history evidence, or imply Kindle
  receipt or processing.
- Preserve unrelated and concurrent worktree changes.
- Static source evidence, compilation, automated tests, runtime accessibility,
  authenticated SMTP, signing, and release publication are separate claims.
