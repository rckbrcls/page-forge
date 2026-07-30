# Tasks: Transient Feedback and Send History

**Input**: Design documents from
`/specs/009-transient-feedback-history/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md),
[research.md](./research.md), [data-model.md](./data-model.md),
[contracts/](./contracts/)

**Tests**: Required by the feature specification and Constitution 8.0.0.
Implement deterministic unit, adapter, pipeline, privacy, performance, UI, and
accessibility coverage for transient feedback, completed-batch reset, and
bounded local send history.

**Organization**: Tasks are grouped by independently testable user story.
Feature 008 feedback and diagnostic changes already present in the worktree are
dependencies to extend, not unrelated changes to replace.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel because it touches different files and has no
  unmet dependency within the phase
- **[Story]**: Maps to US1, US2, or US3 from [spec.md](./spec.md)
- Every task names its exact implementation or evidence path

## Phase 1: Setup (Shared Test Infrastructure)

**Purpose**: Prepare isolated, deterministic test support without changing app
behavior.

- [X] T001 Extend isolated test storage with a dedicated history root and containment-safe cleanup in `BookSenderTests/Support/TestStores.swift`
- [X] T002 [P] Create fixed identifiers, timestamps, display names, records, and envelope builders for history tests in `BookSenderTests/Support/HistoryTestFixtures.swift`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Establish shared event, feedback, and timing seams before
user-story implementation.

**⚠️ CRITICAL**: Complete this phase before integrating any user-story UI.

- [X] T003 Extend `FeedbackScope` and `FeedbackAction` with history loading, recording, clearing, and completed-batch reset cases in `BookSender/Domain/Models/FeedbackModels.swift`
- [X] T004 Add a batch-scoped pipeline event envelope that exposes the originating batch identifier for every mutation-capable event in `BookSender/Domain/Models/PipelineModels.swift`
- [X] T005 Adapt pipeline event emission and presentation projection to the batch-scoped envelope without changing existing outcomes in `BookSender/Application/Pipeline/PipelineActor.swift` and `BookSender/App/AppModel.swift`
- [X] T006 Add a cancellation-aware injectable feedback sleeper to production dependencies and deterministic test doubles in `BookSender/App/AppDependencies.swift` and `BookSenderTests/Support/TestDoubles.swift`

**Checkpoint**: Existing setup, intake, preparation, delivery, cancellation, and
diagnostic behavior is represented through batch-scoped events and a testable
time seam.

---

## Phase 3: User Story 1 - See Timely Feedback Without Stale Notices (Priority: P1) 🎯 MVP

**Goal**: Successful and informational acknowledgements disappear after a full
four-second interval while active, blocked, failed, cancelled, partial, and
uncertain states remain.

**Independent Test**: Exercise setup save, shortcut changes, intake, removal,
batch clear, send completion, replacement feedback, and application
inactive/reactivated timing; verify success appears once and is absent by five
seconds without removing actionable feedback or leaving layout space.

### Tests for User Story 1

- [X] T007 [P] [US1] Update feedback policy, transition, replacement, and announcement expectations in `BookSenderTests/Application/ActionFeedbackServiceTests.swift`
- [X] T008 [P] [US1] Add controllable-sleeper tests for four-second expiry, five-second maximum, replacement restart, stale-task rejection, independent scopes, and persistent actionable states in `BookSenderTests/Application/ActionFeedbackExpiryTests.swift`
- [X] T009 [P] [US1] Add setup, shortcut, intake, batch-summary, navigation, and one-announcement expiry journeys in `BookSenderUITests/AccessibilityUITests.swift`, `BookSenderUITests/SettingsUITests.swift`, and `BookSenderUITests/BatchSendUITests.swift`

### Implementation for User Story 1

- [X] T010 [US1] Derive delayed four-second dismissal for successful and informational terminal feedback while preserving persistent actionable classifications in `BookSender/Application/Presentation/ActionFeedbackService.swift`
- [X] T011 [US1] Own one identity-guarded expiry task per feedback scope, cancel replaced tasks, remove only matching delayed feedback, and cancel all tasks on teardown in `BookSender/App/AppModel.swift`
- [X] T012 [US1] Classify every existing terminal feedback call site and change copy-success timing from two to four seconds in `BookSender/App/AppModel.swift`
- [X] T013 [US1] Key accessibility announcements by feedback identity and state while allowing removed feedback to collapse its complete layout in `BookSender/Features/Shared/ActionFeedbackView.swift`

**Checkpoint**: User Story 1 is independently functional and deterministically
tested without real-time sleeps in unit tests.

---

## Phase 4: User Story 2 - Start Another Send From a Completed Batch (Priority: P1)

**Goal**: A terminal batch exposes `Send More Books`, clears all temporary batch
state through one deliberate reset, preserves durable values, and confirms
before discarding visible uncertainty.

**Independent Test**: Complete submitted-only, failed-only, cancelled, mixed,
and `Delivery Unknown` batches; verify action availability, failed-item retry,
unknown confirmation cancel/confirm behavior, empty re-intake, durable-state
preservation, and rejection of late old-batch events.

### Tests for User Story 2

- [X] T014 [P] [US2] Add AppModel reset tests for cleared presentation state, preserved setup/preferences/history boundary, unknown confirmation, clear failure, and stale-event rejection in `BookSenderTests/Application/CompletedBatchResetTests.swift`
- [X] T015 [P] [US2] Extend definitive-failure retry coverage so `Retry Failed` remains available until reset and uncertain items remain excluded in `BookSenderTests/Application/BatchRetryTests.swift`
- [X] T016 [P] [US2] Add submitted, failed, cancelled, mixed, uncertain, second-intake, and active-batch UI journeys for `Send More Books` in `BookSenderUITests/BatchSendUITests.swift`
- [X] T017 [P] [US2] Add keyboard focus, labels, hints, default-action, and unknown-confirmation coverage for completed reset in `BookSenderUITests/AccessibilityUITests.swift`

### Implementation for User Story 2

- [X] T018 [US2] Make completed batches read-only for intake and expose terminal, retryable-failure, uncertainty, and reset eligibility derivations in `BookSender/Domain/Models/BatchModels.swift`
- [X] T019 [US2] Reject additions to completed batches, preserve failed retry snapshots, and make clear create one new batch identity after workspace cleanup in `BookSender/Application/Pipeline/PipelineActor.swift`
- [X] T020 [US2] Implement `Send More Books` state, uncertainty confirmation, complete batch-scoped presentation cleanup, clear-failure recovery, and old-batch event filtering in `BookSender/App/AppModel.swift`
- [X] T021 [US2] Replace the completed primary action, retain `Retry Failed`, disable completed intake, and add the native uncertainty confirmation in `BookSender/Features/SendBook/SendBookView.swift` and `BookSender/Features/SendBook/BookDropTarget.swift`

**Checkpoint**: User Story 2 is independently functional; reset never mutates
setup, credentials, shortcut preferences, application preferences, or any
history implementation.

---

## Phase 5: User Story 3 - Review a Simple Local Send History (Priority: P2)

**Goal**: `History` lists exactly one newest-first local record per definitive
SMTP acceptance, persists at most 500 privacy-minimized records, survives
relaunch, and clears independently after confirmation.

**Independent Test**: Submit repeated names and a 20-item mixed batch across
relaunches; verify accepted-only record-once behavior, acceptance timestamps,
ordering, current locale/time-zone formatting, 500-record retention, storage
failure isolation, active-batch tab switching, empty state, and confirmed clear.

### Tests for User Story 3

- [X] T022 [P] [US3] Add model validation, record projection, deterministic ordering, tie-breaker, and exact three-field Codable tests in `BookSenderTests/Domain/HistoryModelsTests.swift`
- [X] T023 [P] [US3] Add service tests for idempotent insertion, repeated display names, newest-first ordering, 500-record retention, multi-insert boundaries, snapshots, and clear in `BookSenderTests/Application/SendHistoryServiceTests.swift`
- [X] T024 [P] [US3] Add adapter tests for missing and empty stores, version-1 round trips, atomic replacement, owner-only permissions, 1 MiB rejection, malformed/unsupported envelopes, unavailable storage, and clear preservation in `BookSenderTests/Adapters/FileSendHistoryStoreTests.swift`
- [X] T025 [P] [US3] Add pipeline tests for record-before-advance, accepted-only inclusion, per-attempt timestamps, duplicate-event idempotency, repeat submissions, mixed batches, write-failure isolation, and quit-after-acceptance persistence in `BookSenderTests/Application/PipelineHistoryTests.swift`
- [X] T026 [P] [US3] Add allow-list and encoded-payload privacy checks rejecting paths, content, addresses, credentials, SMTP data, batch/item identifiers, diagnostics, and remote identifiers in `BookSenderTests/Privacy/SendHistoryPrivacyTests.swift`
- [X] T027 [P] [US3] Add complete history diagnostic-code catalog and safe recovery presentation coverage in `BookSenderTests/Domain/FailurePresentationTests.swift`
- [X] T028 [P] [US3] Add tab, active-send switching, newest-first rows, repeated names, locale/time-zone display, empty/unavailable distinction, relaunch, clear cancel/success/failure, keyboard, and accessibility journeys in `BookSenderUITests/SendHistoryUITests.swift`
- [X] T029 [P] [US3] Add a 500-record load and presentation performance check against the one-second acceptance target in `BookSenderTests/Performance/SendHistoryPerformanceTests.swift`

### Implementation for User Story 3

- [X] T030 [US3] Define `SendBookTab`, `SubmissionReceipt`, `SubmissionRecord`, `SendHistoryEnvelope`, `SendHistorySnapshot`, and typed history failures with validation and privacy-minimized projection in `BookSender/Domain/Models/HistoryModels.swift`
- [X] T031 [US3] Define the async history storage boundary for load, atomic replacement, and clear in `BookSender/Domain/Ports/HistoryProtocols.swift`
- [X] T032 [P] [US3] Implement the actor-owned version-1 JSON store with a 1 MiB predecode limit, owner-only permissions, same-directory atomic replacement, typed failures, and no silent repair in `BookSender/Adapters/History/FileSendHistoryStore.swift`
- [X] T033 [P] [US3] Implement record projection, idempotency, deterministic newest-first ordering, 500-record retention, immutable snapshots, and clear semantics in `BookSender/Application/History/SendHistoryService.swift`
- [X] T034 [P] [US3] Add history diagnostic codes, phases, recovery actions, dispositions, and safe presentation wording that never changes delivery truth in `BookSender/Domain/Models/DiagnosticModels.swift`, `BookSender/Domain/Models/PipelineModels.swift`, and `BookSender/Application/Presentation/FailurePresentationService.swift`
- [X] T035 [US3] Persist a receipt immediately after definitive SMTP acceptance, exclude failed/cancelled/unattempted/unknown outcomes, emit separate history failures, and never retry delivery in `BookSender/Application/Pipeline/PipelineActor.swift` and `BookSender/Domain/Models/PipelineModels.swift`
- [X] T036 [US3] Compose one shared history store/service for production, isolated UI testing, and unit tests; inject it into the pipeline and presentation model in `BookSender/App/AppDependencies.swift`, `BookSenderTests/Support/TestDoubles.swift`, and `BookSenderTests/Support/TestStores.swift`
- [X] T037 [US3] Own tab selection, history loading/snapshots, accepted-record refresh, unavailable state, confirmed clear, and history-scoped feedback in `BookSender/App/AppModel.swift`
- [X] T038 [US3] Implement the simple native newest-first list, current locale/time-zone formatting, exact empty state, loading/unavailable states, secondary clear action, and clear confirmation in `BookSender/Features/SendBook/SendHistoryView.swift`
- [X] T039 [US3] Add exact local `Send` and `History` tabs while keeping `Send` default and preserving current batch state during switches in `BookSender/Features/SendBook/SendBookView.swift`
- [X] T040 [US3] Add isolated history reset/seed/failure launch arguments without production demo behavior in `BookSender/App/AppDependencies.swift`

**Checkpoint**: User Story 3 is independently functional; history remains local,
bounded, privacy-minimized, clearable, and incapable of resending or managing a
book.

---

## Phase 6: Polish & Cross-Cutting Verification

**Purpose**: Reconcile all stories, documentation, privacy boundaries, and
separate evidence gates.

- [X] T041 [P] Update the bounded-history, repeated-send, feedback-timing, privacy, and non-Kindle-claim guidance in `README.md`, `docs/desktop-migration.md`, and `docs/troubleshooting.md`
- [X] T042 [P] Reconcile Feature 009 requirement traceability, commands, expected outcomes, and explicit pending runtime/provider/release gates in `specs/009-transient-feedback-history/quickstart.md`
- [X] T043 Run `git diff --check` and targeted route, UI-string, package, prohibited-field, process/helper, and history-management scans; record static evidence in `specs/009-transient-feedback-history/quickstart.md`
- [ ] T044 After explicit authorization, run the Book Sender compile, deterministic test, UI/accessibility, performance, manual runtime, and authenticated SMTP gates separately and record only completed evidence in `specs/009-transient-feedback-history/quickstart.md`

---

## Dependencies & Execution Order

### Phase dependencies

- **Phase 1 (Setup)**: Starts first and changes test support only.
- **Phase 2 (Foundational)**: Depends on Phase 1 and blocks story integration.
- **US1 (Phase 3)**: Depends on Phase 2 and is the recommended MVP.
- **US2 (Phase 4)**: Depends on Phase 2. Its domain/pipeline work is logically
  independent of US1, but complete it after US1 to avoid concurrent edits in
  `AppModel`, `SendBookView`, and UI tests.
- **US3 (Phase 5)**: History models, ports, store, service, and their focused
  tests depend only on Phase 2. Final feedback and `SendBookView` integration
  depends on US1 and should follow US2 to avoid mixed-file conflicts.
- **Phase 6 (Polish)**: Depends on all selected user stories.

### User story dependency graph

```text
Setup -> Foundational -> US1 (MVP)
                       ├-> US2
                       └-> US3 Core

US1 + US2 + US3 Core -> US3 UI Integration -> Polish
```

### Within each user story

- Write the listed deterministic and UI tests before accepting implementation.
- Update typed models before services, pipeline behavior, and SwiftUI.
- Keep adapter failures typed and raw errors below the adapter boundary.
- Complete application behavior before UI integration.
- Preserve current Feature 008 changes when touching shared feedback and
  diagnostic files.
- Pass the independent story checkpoint before starting the next integration
  phase.

### Parallel opportunities

- **Setup**: T001 and T002 touch separate test-support files.
- **US1**: T007, T008, and T009 can be authored in parallel after T006.
- **US2**: T014, T015, T016, and T017 can be authored in parallel after Phase 2.
- **US3 tests**: T022 through T029 can be authored in parallel from the
  contracts.
- **US3 core**: After T030 and T031, T032, T033, and T034 can proceed in
  parallel; integrate them through T035 through T040 in order.
- **Polish**: T041 and T042 can proceed in parallel before static evidence is
  captured in T043.
- Tasks that edit `AppModel.swift`, `PipelineActor.swift`,
  `AppDependencies.swift`, `SendBookView.swift`, or shared UI test files must
  remain coordinated even when their surrounding stories are logically
  independent.

## Parallel Execution Examples

### User Story 1

```text
T007: ActionFeedbackService policy tests
T008: AppModel expiry scheduler tests
T009: UI and accessibility expiry journeys
```

After those tests are authored, execute T010 -> T011 -> T012 -> T013.

### User Story 2

```text
T014: AppModel reset and stale-event tests
T015: Failed-item retry preservation tests
T016: Completed-batch UI journeys
T017: Keyboard and accessibility reset journeys
```

After those tests are authored, execute T018 -> T019 -> T020 -> T021.

### User Story 3

```text
T022: History model contract tests
T023: History service semantic tests
T024: JSON adapter boundary tests
T025: Pipeline acceptance integration tests
T026: Persisted-field privacy tests
T027: Failure-presentation catalog tests
T028: History UI/accessibility journeys
T029: 500-record performance check
```

After T030 and T031 establish models and ports, execute T032, T033, and T034 in
parallel, then integrate in order through T035 -> T036 -> T037 -> T038 -> T039
-> T040.

## Implementation Strategy

### MVP first

1. Complete Phase 1 and Phase 2.
2. Deliver User Story 1 only.
3. Verify deterministic timing, replacement safety, actionable persistence, and
   accessibility behavior before changing completed-batch or history UI.

### Incremental delivery

1. **US1**: Remove stale acknowledgements without changing pipeline truth.
2. **US2**: Add deliberate completed-batch reset and stale-event isolation.
3. **US3 Core**: Add typed records, local persistence, retention, and accepted-
   only pipeline integration.
4. **US3 UI**: Add local tabs, history list, empty/unavailable states, and clear.
5. **Polish**: Reconcile documentation and record each authorized evidence gate
   separately.

### Product P1 completion

Both US1 and US2 are Priority P1. The smallest demonstrable MVP is US1, while
the complete P1 product increment requires Phases 1 through 4.

## Notes

- Work on the current branch; do not create a branch, stage, or commit unless
  Erick explicitly requests it.
- Do not build, test, launch, automate the UI, or contact a real SMTP provider
  without explicit authorization.
- Do not add a package, helper process, database, library, queue, resend action,
  remote history, analytics, search, filters, export, file-management action, or
  third primary screen.
- Do not treat SMTP submission as Kindle receipt, processing, or library
  availability.
- Preserve unrelated and concurrent worktree changes.
- Static source evidence, compilation, automated tests, runtime behavior,
  authenticated SMTP, signing, and release publication are separate claims.
