# Tasks: Essential Notification Feedback

**Input**: Design documents from
`/specs/011-reduce-notification-noise/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md),
[research.md](./research.md), [data-model.md](./data-model.md),
[contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: Required by the feature specification. Author deterministic policy,
AppModel, workflow, UI, and accessibility tests before accepting the
implementation they govern. Do not run build, test, app, UI automation, SMTP,
signing, or release commands without Erick's separate explicit authorization.

**Organization**: Tasks are grouped by independently testable user story.
`ActionFeedback` remains semantic application truth; Feature 011 changes only
whether a terminal result is projected into the existing floating presentation.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can proceed in parallel because it touches a different file and has
  no unmet dependency within the phase
- **[Story]**: Maps to US1, US2, US3, or US4 from [spec.md](./spec.md)
- Every task names its exact implementation, test, documentation, or evidence
  path

## Phase 1: Setup (Shared Test Infrastructure)

**Purpose**: Establish deterministic policy fixtures and an executable inventory
of the current feedback catalogue without changing production behavior.

- [X] T001 [P] Extend deterministic builders with publication intents, approved reasons, terminal/contextual feedback, destination snapshots, and visible/queued assertions in `BookSenderTests/Support/NotificationTestFixtures.swift`
- [X] T002 [P] Create the exhaustive twenty-action classification table, duplicate/missing-case checks, and the four-current-producer inventory in `BookSenderTests/Application/NotificationEligibilityTests.swift`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Separate semantic feedback from optional floating presentation and
make contextual evidence independent from notification visibility.

**⚠️ CRITICAL**: Complete this phase before changing any production action's
notification eligibility.

### Foundational Tests

- [X] T003 [P] Add default-contextual, explicit-reason, terminal-only, reserved-reason, and Sendable value tests in `BookSenderTests/Application/NotificationEligibilityTests.swift`
- [X] T004 Add semantic-retention, zero-queue contextual publication, matching-scope stale-card removal, and independent-destination preservation tests in `BookSenderTests/Application/AppModelNotificationRoutingTests.swift`

### Foundational Implementation

- [X] T005 [P] Define `NotificationPublicationIntent` and the six bounded `NotificationReason` cases without persistence or user-facing raw reason text in `BookSender/Application/Presentation/FloatingNotificationModels.swift`
- [X] T006 Refactor `beginFeedback`, `updateProgressFeedback`, `finishFeedback`, and `publishNotification` so semantic state always updates, progress never floats, terminal publication defaults to contextual, explicit eligible outcomes require a reason, and newer actions remove only matching stale presentation in `BookSender/App/AppModel.swift`
- [X] T007 [P] Read delivery-setup failure content from `AppModel.feedback(for:)` while retaining field errors, setup guidance, diagnostic copy, and destination-scoped recovery in `BookSender/Features/DeliverySetup/DeliverySetupView.swift`
- [X] T008 [P] Read only batch semantic feedback from `AppModel.feedback(for:)`, remove application/setup success fallbacks, and retain per-book, aggregate, retry, and uncertainty context in `BookSender/Features/SendBook/SendBookView.swift`
- [X] T009 [P] Read history failure content from `AppModel.feedback(for:)` while retaining loading, unavailable, empty, list, count, clear, retry, and diagnostic states in `BookSender/Features/SendBook/SendHistoryView.swift`
- [X] T010 [P] Read shortcut failure content from `AppModel.feedback(for:)` while retaining recorder, switch, registration state, diagnostic copy, and focused recovery in `BookSender/Features/Settings/ShortcutSettingsView.swift`

**Checkpoint**: Semantic feedback remains queryable and actionable even when no
notification entry exists or a prior card is closed, expired, replaced, queued,
or detached.

---

## Phase 3: User Story 1 - Complete Normal Work Without Notification Noise (Priority: P1) 🎯

**Goal**: Complete intake, preparation, confirmation, delivery, editing, retry,
and reset with zero floating cards for states already visible in the send
workflow.

**Independent Test**: Complete a successful one-book send and a mixed multi-book
send, including remove, clear, confirmation dismissal, retry, cancellation, and
send-more reset; verify contextual state remains complete while both visible and
queued notification counts remain zero.

### Tests for User Story 1

- [X] T011 [P] [US1] Preserve semantic batch lifecycle assertions while adding zero-visible/zero-queued notification checks for add, prepare, confirm, send, remove, clear, and retry in `BookSenderTests/Application/FirstBookJourneyTests.swift`
- [X] T012 [P] [US1] Add silent reset, failed reset, cancelled reset, and delivery-unknown reset-confirmation assertions without losing durable batch outcomes in `BookSenderTests/Application/CompletedBatchResetTests.swift` and `BookSenderTests/Application/BatchRetryTests.swift`
- [X] T013 [P] [US1] Assert application restore, successful update-interface opening, shortcut change/conflict, history load/clear, and their semantic terminal states do not enqueue cards in `BookSenderTests/Application/AppModelSetupTests.swift`, `BookSenderTests/Application/ShortcutServiceTests.swift`, and `BookSenderTests/Application/AppModelHistoryNotificationTests.swift`
- [X] T014 [P] [US1] Replace batch/update expiry assumptions with proof that contextual events create no expiry task while semantic feedback remains available in `BookSenderTests/Application/ActionFeedbackExpiryTests.swift`
- [X] T015 [P] [US1] Replace normal send, mixed outcome, cancellation, retry, clear, and send-more card assertions with row, aggregate, modal, and list evidence plus zero-card checks in `BookSenderUITests/BatchSendUITests.swift`
- [X] T016 [P] [US1] Convert production batch and shortcut journeys to contextual silence while retaining matrix, stack, action, focus, destination, and appearance launch fixtures in `BookSenderUITests/FloatingNotificationUITests.swift`

### Implementation for User Story 1

- [X] T017 [US1] Remove direct production publication for bootstrap, application reveal, batch intake/progress/completion, confirmation, cancellation, retry, reset, history load/clear, shortcut, and update success while keeping direct center publication only inside explicit UI-test fixture branches in `BookSender/App/AppModel.swift`

**Checkpoint**: US1 is independently testable: the complete normal send journey
produces zero floating notifications and loses no visible or semantic state.

---

## Phase 4: User Story 2 - Confirm an Invisible Side Effect (Priority: P1)

**Goal**: Publish exactly one terminal notification for current invisible
clipboard, protected-credential, deletion, and post-acceptance history outcomes.

**Independent Test**: Exercise setup save success, setup deletion success and
partial Keychain failure, diagnostic-copy success and failure, and history-write
failure after definitive SMTP acceptance; verify one correctly routed card,
correct lifetime, no duplicate, and unchanged underlying state.

### Tests for User Story 2

- [X] T018 [P] [US2] Add setup-save success, validation/storage contextual failure, deletion success, deletion partial outcome, secret redaction, and exact notification-count assertions in `BookSenderTests/Application/AppModelSetupTests.swift` and `BookSenderTests/Application/SettingsDeliveryTests.swift`
- [X] T019 [P] [US2] Retain the original diagnostic event while asserting exactly one temporary clipboard-success card, one persistent clipboard-failure card, safe content, destination routing, and repeated-copy replacement in `BookSenderTests/Application/AppModelDiagnosticsTests.swift`
- [X] T020 [P] [US2] Extend AppModel-level history tests to prove SMTP acceptance remains submitted, no SMTP retry occurs, and one persistent history notification appears when record persistence fails in `BookSenderTests/Application/AppModelHistoryNotificationTests.swift`
- [X] T021 [P] [US2] Restrict AppModel expiry coverage to approved setup/copy successes, four-second default duration, five-second maximum, replacement safety, and persistent partial/failure outcomes in `BookSenderTests/Application/ActionFeedbackExpiryTests.swift`
- [X] T022 [P] [US2] Verify approved cards use their originating main/Settings destination, replace equivalent outcomes by scope, and never leak into the other window in `BookSenderTests/Application/AppModelNotificationRoutingTests.swift`
- [X] T023 [P] [US2] Update Settings journeys to expect one temporary setup-save card and one terminal setup-deletion/Keychain card without duplicating the reset form in `BookSenderUITests/SettingsUITests.swift`
- [X] T024 [P] [US2] Preserve expanded diagnostic evidence while validating clipboard success/failure cards, repeated-copy replacement, close behavior, and sanitized content in `BookSenderUITests/RecoveryJourneyUITests.swift`
- [X] T025 [P] [US2] Author a deterministic history-write-failure journey that expects one persistent history card with a still-submitted book and no automatic retry in `BookSenderUITests/SendHistoryUITests.swift`

### Implementation for User Story 2

- [X] T026 [US2] Pass explicit reasons only for setup-save success, setup-deletion success/partial, diagnostic-copy success/failure, and history-record failure after SMTP acceptance; add only the deterministic history-write-failure launch dependency required by T025 while leaving every validation and visible failure contextual in `BookSender/App/AppModel.swift` and `BookSender/App/AppDependencies.swift`

**Checkpoint**: US2 is independently testable: all four current invisible action
paths publish exactly once and contextual failures remain silent.

---

## Phase 5: User Story 3 - Recover From a Non-Visible Consequential Failure (Priority: P2)

**Goal**: Preserve an explicit, safe path for future consequential hidden or
auxiliary-system failures without promoting visible failures automatically.

**Independent Test**: Use policy-level and synthetic component fixtures to
compare an explicitly opted-in persistent hidden failure with an equivalent
failure that has durable contextual evidence; verify only the former appears and
its action reveals context without sending, retrying, deleting, or confirming.

### Tests for User Story 3

- [X] T027 [P] [US3] Prove reserved consequential/auxiliary reasons have no current production producer, never infer eligibility from failure severity, and accept only explicit terminal intent in `BookSenderTests/Application/NotificationEligibilityTests.swift`
- [X] T028 [P] [US3] Add typed recovery tests that reveal or focus durable context, reject unsupported destinations, and preserve modal confirmation for retry, uncertainty, and destructive decisions in `BookSenderTests/Application/AppModelNotificationRoutingTests.swift`
- [X] T029 [P] [US3] Replace batch-card recovery expectations with durable inline failure evidence and retain a synthetic persistent hidden-failure recovery journey in `BookSenderUITests/RecoveryJourneyUITests.swift`
- [X] T030 [P] [US3] Prove matrix/stack/action fixtures publish directly only under existing UI-test launch arguments and do not alter the production catalogue in `BookSenderUITests/FloatingNotificationUITests.swift`

### Implementation for User Story 3

- [X] T031 [US3] Audit every terminal producer so no fallback promotes success, failure, partial, cancelled, or unknown state automatically; keep reserved reasons explicit and add no Sparkle failure callback or invented producer in `BookSender/App/AppModel.swift`

**Checkpoint**: US3 is independently testable at the policy/component boundary
without adding a fake production failure path or expanding the approved
catalogue.

---

## Phase 6: User Story 4 - Preserve Accessible, Durable Meaning (Priority: P2)

**Goal**: Remove redundant announcements while keeping contextual status,
failure evidence, uncertainty, keyboard recovery, and eligible card interaction
accessible without focus theft.

**Independent Test**: Complete the normal send flow and every approved
notification journey using keyboard navigation and supported accessibility
settings; verify zero redundant cards/announcements, one announcement per
eligible outcome, stable focus, and durable evidence after close or expiry.

### Tests for User Story 4

- [X] T032 [P] [US4] Replace batch, update, and other contextual notification expectations with accessible row/control/status evidence and one-announcement checks for approved cards in `BookSenderUITests/AccessibilityUITests.swift`
- [X] T033 [P] [US4] Verify shortcut recorder, switch, registration/conflict state, keyboard focus, and inline recovery remain accessible with zero floating shortcut cards in `BookSenderUITests/SettingsUITests.swift`
- [X] T034 [P] [US4] Verify history loading, unavailable/retry, empty/list/count, clear confirmation/result, and contextual failure remain accessible with zero load/clear cards in `BookSenderUITests/SendHistoryUITests.swift`
- [X] T035 [P] [US4] Verify failed, partial, cancelled, mixed, and `Delivery Unknown` rows and aggregate guidance remain durable, keyboard reachable, and silent in `BookSenderUITests/BatchSendUITests.swift`
- [X] T036 [P] [US4] Verify closing or expiring an approved card never removes its original semantic failure detail, copy control, or safe recovery path in `BookSenderUITests/RecoveryJourneyUITests.swift`
- [X] T037 [P] [US4] Retain Reduce Motion, Reduce Transparency, Increase Contrast, focus visibility, hit-target, and Liquid Glass readability coverage for eligible/test-only cards in `BookSenderUITests/FloatingNotificationAppearanceUITests.swift`

### Implementation for User Story 4

- [X] T038 [US4] Preserve stable accessibility labels, values, identifiers, keyboard recovery, and focus-request consumption for semantic contextual evidence after notification suppression in `BookSender/Features/DeliverySetup/DeliverySetupView.swift`, `BookSender/Features/SendBook/SendBookView.swift`, `BookSender/Features/SendBook/SendHistoryView.swift`, and `BookSender/Features/Settings/ShortcutSettingsView.swift`

**Checkpoint**: US4 is independently testable: contextual meaning remains
accessible, eligible cards announce once, and notification lifecycle never owns
workflow truth.

---

## Phase 7: Polish & Cross-Cutting Verification

**Purpose**: Reconcile documentation, prove the exhaustive catalogue, and keep
static, compiled, runtime, provider, and release evidence separate.

- [X] T039 [P] Update the contextual-default policy, four current eligible paths, six bounded reasons, terminal lifetimes, and Feature 010/011 relationship in `README.md`, `docs/desktop-migration.md`, and `docs/troubleshooting.md`
- [X] T040 [P] Reconcile all twenty `FeedbackAction` cases, every `.floating` call site, every direct center publication, and every suppressed event's durable evidence against `specs/011-reduce-notification-noise/contracts/approved-notification-catalogue.md` and `specs/011-reduce-notification-noise/quickstart.md`
- [X] T041 Verify no production view consumes `notificationFeedback`, no contextual event creates visible/queued/expiry state, UI-test fixtures remain launch-gated, and presentation component, package, SMTP, history, credential, and release behavior is otherwise unchanged in `BookSender/App/AppModel.swift`, `BookSender/Application/Presentation/FloatingNotificationCenter.swift`, `BookSender/Features/Shared/FloatingNotificationCard.swift`, `BookSender/Features/Shared/FloatingNotificationHost.swift`, `BookSender/Adapters/SMTP/NIOSMTPClient.swift`, `BookSender/Application/History/SendHistoryService.swift`, `BookSender/Adapters/Credentials/KeychainCredentialStore.swift`, `BookSender.xcodeproj/project.pbxproj`, and `BookSender.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- [X] T042 Run `git diff --check`, Swift parse, notification-producer, semantic-view-consumer, UI-test-fixture, accessibility-identifier, package, persistence, and forbidden-surface static scans and record only static evidence in `specs/011-reduce-notification-noise/quickstart.md`
- [ ] T043 After separate explicit authorization, run compilation, deterministic unit tests, and focused UI/accessibility tests as distinct gates and record only completed evidence in `specs/011-reduce-notification-noise/quickstart.md`
- [ ] T044 After separate explicit authorization, complete the manual macOS normal-send, invisible-side-effect, window-isolation, keyboard, VoiceOver, Reduce Motion, Reduce Transparency, and Increase Contrast matrix and record runtime evidence separately in `specs/011-reduce-notification-noise/quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: Starts first and changes test support only.
- **Phase 2 (Foundational)**: Depends on Phase 1 and blocks all production
  eligibility changes.
- **US1 (Phase 3)**: Depends on Phase 2 and establishes contextual silence.
- **US2 (Phase 4)**: Depends on Phase 2, may be authored alongside US1 in
  different tests, and must join US1 before an MVP can ship so approved invisible
  outcomes are not over-suppressed.
- **US3 (Phase 5)**: Depends on the explicit intent/reason contract from Phase 2
  and the approved producer boundary from US2.
- **US4 (Phase 6)**: Depends on US1 contextual silence and US2 eligible-card
  behavior; accessibility tests may be authored earlier in separate files.
- **Phase 7 (Polish)**: Depends on all selected stories.

### User Story Dependency Graph

```text
Setup -> Foundational -> US1 -----------+
                         |              |
                         +----> US2 ----+----> MVP
                                |
                                +----> US3
                         US1 + US2 ----> US4
                         US3 + US4 ----> Polish
```

### Within Each User Story

- Author the listed deterministic and UI tests before accepting implementation.
- Keep semantic state and durable contextual evidence before notification
  suppression.
- Keep the default contextual and require an explicit reason at every approved
  terminal producer.
- Never infer eligibility from `FeedbackState`, severity, action completion, or
  current scroll/window geometry.
- Complete the story's independent checkpoint before treating it as delivered.
- Coordinate tasks that edit `AppModel.swift`,
  `AppModelNotificationRoutingTests.swift`, `ActionFeedbackExpiryTests.swift`,
  or shared UI-test files.

### Parallel Opportunities

- **Setup**: T001 and T002 touch separate test files.
- **Foundation**: T003 and T005 can start in parallel; T007 through T010 touch
  independent views after T006 establishes semantic/publication ownership.
- **US1 tests**: T011 through T016 can be authored in parallel before T017.
- **US2 tests**: T018 through T025 can be authored in parallel before T026.
- **US3 tests**: T027 through T030 can be authored in parallel before T031.
- **US4 tests**: T032 through T037 touch independent test concerns and can be
  authored in parallel before T038.
- **Polish**: T039 and T040 can proceed in parallel before T041 and T042.

## Parallel Execution Examples

### User Story 1

```text
T011: AppModel normal-send semantic and silence tests
T012: Reset, retry, and delivery-unknown tests
T013: Application, update, shortcut, and history silence tests
T014: Contextual-event timer absence tests
T015: Batch workflow UI tests
T016: Production-silence and component-fixture UI tests
```

Then execute T017 and verify the US1 checkpoint.

### User Story 2

```text
T018: Setup save/delete tests
T019: Diagnostic-copy tests
T020: Post-acceptance history-persistence tests
T021: Approved lifetime and replacement tests
T022: Approved destination and replacement tests
T023: Settings setup-card UI tests
T024: Diagnostic-copy UI tests
T025: History-write-failure UI test
```

Then execute T026 after the independently authored unit and UI tests.

### User Story 3

```text
T027: Reserved-reason and terminal-intent tests
T028: Safe typed recovery tests
T029: Contextual-versus-hidden recovery UI journey
T030: Synthetic fixture isolation tests
```

Then execute T031 and verify there is no implicit eligibility fallback.

### User Story 4

```text
T032: Announcement and accessible contextual-state tests
T033: Shortcut accessibility tests
T034: History accessibility tests
T035: Delivery outcome and uncertainty accessibility tests
T036: Durable evidence after notification dismissal tests
T037: Accessibility appearance tests
```

Then execute T038 and verify the US4 checkpoint.

## Implementation Strategy

### Safe MVP

1. Complete Phase 1 and Phase 2.
2. Implement US1 and prove the normal workflow produces zero cards.
3. Implement US2 before shipping so approved invisible side effects still
   receive confirmation.
4. Treat **US1 + US2** as the minimum safe product increment.

### Incremental Delivery

1. **Foundation**: Separate semantic feedback from floating presentation.
2. **US1**: Silence every normal visible workflow transition.
3. **US2**: Opt in only setup persistence/deletion, diagnostic copy, and
   post-acceptance history persistence failure.
4. **US3**: Lock the reserved hidden-failure path behind explicit typed reasons
   and safe recovery.
5. **US4**: Complete announcement, keyboard, focus, contextual evidence, and
   accessibility-setting regressions.
6. **Polish**: Update product guidance and record each authorized evidence gate
   separately.

## Notes

- Do not stage or commit unless Erick explicitly requests it.
- Do not run build, tests, app, UI automation, authenticated SMTP, signing, or
  release validation without separate explicit authorization.
- Do not add a dependency, screen, window, preference, notification history,
  system notification, telemetry, storage, or production test fixture.
- Do not change SMTP, preparation, cancellation, delivery uncertainty, history,
  credential, privacy, signing, or release semantics.
- Do not treat static checks as compilation, automated tests, runtime behavior,
  authenticated provider behavior, or production distribution evidence.
