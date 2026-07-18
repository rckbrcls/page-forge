# Tasks: Simplified Document Workflow

**Input**: Design documents from `/specs/002-simplify-document-workflow/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md),
[research.md](./research.md), [data-model.md](./data-model.md),
[contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: Tests are included because the constitution requires coverage for
readiness, conversion orchestration, repair safety, and delivery preconditions,
and the plan requires deterministic intake/workflow/export tests. Write each test
task first and confirm it would fail against the pre-feature behavior. Agents must
not run `xcodebuild` under the repository rules; Erick performs runnable validation
from `quickstart.md`.

**Organization**: Tasks are grouped by user story so each story can be developed
and evaluated as an incremental slice.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel because it changes different files and does not
  depend on another incomplete task in the same group.
- **[Story]**: Maps the task to a user story from `spec.md`.
- Every task names the exact file or files it changes.

## Phase 1: Setup (Shared Test Infrastructure)

**Purpose**: Establish deterministic local-file fixtures without introducing an
external package or executable test dependency.

- [ ] T001 Create reusable temporary EPUB, MOBI, PDF, unsupported-file, duplicate-path, and unreadable-file fixtures in `PageForgeTests/Support/TemporaryDocumentFactory.swift`
- [ ] T002 Register `PageForgeTests/Support/TemporaryDocumentFactory.swift` in the PageForgeTests group and Sources build phase in `PageForge.xcodeproj/project.pbxproj`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Add shared workflow state, cancellation-safe job semantics, and one
composition root before any user-facing story work.

**⚠️ CRITICAL**: User-story implementation begins only after this phase is complete.

- [ ] T003 [P] Write failing state-transition, selection-eligibility, independent save/delivery state, and derived queue-state tests in `PageForgeTests/Domain/DocumentWorkflowModelsTests.swift`
- [ ] T004 Implement `DocumentFormat`, `PreparationState`, `OutputActionState`, `QueueState`, intake outcomes, `DocumentItem`, `DocumentQueue`, `PreparedOutput`, issues, export results, and delivery results in `PageForge/Domain/Models/DocumentWorkflowModels.swift`
- [ ] T005 [P] Write failing queued-job and cancel-pending consistency tests in `PageForgeTests/Domain/OperationJobCoordinatorTests.swift`
- [ ] T006 Add explicit queued creation, pending cancellation, and terminal reconciliation APIs without claiming hard subprocess cancellation in `PageForge/Domain/Jobs/OperationJobCoordinator.swift`
- [ ] T007 [P] Construct and reuse single `ConfigService`, `SecretService`, `ConversionService`, `RepairService`, `ReadinessService`, and `DeliveryService` instances in `PageForge/App/AppState.swift`
- [ ] T008 Register `PageForge/Domain/Models/DocumentWorkflowModels.swift`, `PageForgeTests/Domain/DocumentWorkflowModelsTests.swift`, and `PageForgeTests/Domain/OperationJobCoordinatorTests.swift` in the correct groups and Sources phases in `PageForge.xcodeproj/project.pbxproj`

**Checkpoint**: Shared models compile conceptually, queue invariants are specified,
and app-wide services no longer drift through duplicate instances.

---

## Phase 3: User Story 1 — Import a Document Collection (Priority: P1) 🎯 MVP

**Goal**: Replace mode-based navigation with one queue and allow multiple files to
enter through the preserved large drop area, chooser, toolbar, or File menu.

**Independent Test**: Add a mixed EPUB/MOBI/PDF/unsupported/duplicate selection
through each intake channel and confirm accepted files append in stable order,
each rejection has a reason, and removing rows never deletes local files.

### Tests for User Story 1

- [ ] T009 [P] [US1] Write failing local-file validation, EPUB/MOBI/PDF filtering, canonical dedupe, partial acceptance, stable ordering, and rejection-reason tests in `PageForgeTests/Domain/DocumentIntakeServiceTests.swift`
- [ ] T010 [P] [US1] Write failing add/select/select-all/remove/intake-summary and add-while-existing-queue tests in `PageForgeTests/Features/DocumentWorkflowViewModelTests.swift`

### Implementation for User Story 1

- [ ] T011 [US1] Implement canonical identity, readability/type validation, duplicate detection, stable partial outcomes, and security-scoped access metadata in `PageForge/Domain/Services/DocumentIntakeService.swift`
- [ ] T012 [P] [US1] Refactor chooser and drop handling to accept `[URL]`, enable multiple selection, resolve every provider in input order, and balance security-scoped access in `PageForge/Features/Shared/FileDropIntakeView.swift`
- [ ] T013 [US1] Implement queue ownership, shared intake entry, selection, Select All, removal-only semantics, and intake feedback in `PageForge/Features/Workflow/DocumentWorkflowViewModel.swift`
- [ ] T014 [P] [US1] Implement the selectable filename/format/status row with accessible remove action in `PageForge/Features/Workflow/DocumentQueueRow.swift`
- [ ] T015 [US1] Implement the empty large drop state and non-empty queue state with calm hierarchy and no nested-card/dashboard layout in `PageForge/Features/Workflow/DocumentWorkflowView.swift`
- [ ] T016 [US1] Replace `RootNavigationView` and the `NavigationSplitView` shell with `MainWorkflowView` and remove `AppDestination`/destination routing in `PageForge/App/RootNavigationView.swift`, `PageForge/App/MainWorkflowView.swift`, `PageForge/App/AppState.swift`, and `PageForge/App/PageForgeApp.swift`
- [ ] T017 [US1] Add the drop-capable `Add Files` toolbar control, `File > Add Files…` command, keyboard shortcut, targeted highlight, help, and overflow-safe labeling in `PageForge/App/MainWorkflowView.swift` and `PageForge/App/PageForgeApp.swift`
- [ ] T018 [US1] Add Workflow, intake service, view-model, row, view, and US1 test references to the app/test Sources phases and remove the obsolete `RootNavigationView.swift` reference in `PageForge.xcodeproj/project.pbxproj`

**Checkpoint**: US1 is independently demonstrable as one simple multi-file intake
screen even before preparation is connected.

---

## Phase 4: User Story 2 — Prepare Every Eligible File (Priority: P2)

**Goal**: Turn selected EPUB, MOBI, and PDF items into independently reported
Kindle-ready EPUB outputs through one explicit Prepare Files action.

**Independent Test**: Seed a queue with EPUB/MOBI/PDF plus one failure, run
preparation, and confirm stable sequential processing, original-file immutability,
PDF conversion-before-readiness, correct output names, and continuation after the
failure.

### Tests for User Story 2

- [ ] T019 [P] [US2] Write failing EPUB/MOBI/PDF routing, PDF temporary cleanup, original immutability, `*-kindle-ready.epub`, no-OCR warning, output collision, and missing-dependency tests in `PageForgeTests/Domain/DocumentPreparationServiceTests.swift`
- [ ] T020 [P] [US2] Write failing preparation snapshot, sequential progression, per-item failure isolation, retry, new-intake exclusion, cancel-pending, and active-result reconciliation tests in `PageForgeTests/Features/DocumentWorkflowViewModelTests.swift`

### Implementation for User Story 2

- [ ] T021 [US2] Define the narrow `DocumentPreparing` contract and implement EPUB/MOBI delegation plus PDF conversion-then-readiness orchestration in `PageForge/Domain/Services/DocumentPreparationService.swift`
- [ ] T022 [US2] Add unique PDF working directories, `defer`-style best-effort cleanup, final report source remapping, final output verification, and no-OCR issue propagation in `PageForge/Domain/Services/DocumentPreparationService.swift`
- [ ] T023 [US2] Implement stable selected-item snapshots, sequential detached work, main-actor reconciliation, independent failures, and operation logging in `PageForge/Features/Workflow/DocumentWorkflowViewModel.swift`
- [ ] T024 [US2] Add retry and cancel-pending transitions while allowing an active external process to reconcile honestly in `PageForge/Features/Workflow/DocumentWorkflowViewModel.swift` and `PageForge/Domain/Jobs/OperationJobCoordinator.swift`
- [ ] T025 [US2] Render Prepare Files, per-row determinate/indeterminate progress, readiness status text, output location, retry, and cancel feedback in `PageForge/Features/Workflow/DocumentWorkflowView.swift` and `PageForge/Features/Workflow/DocumentQueueRow.swift`
- [ ] T026 [US2] Surface missing-tool, moved-source, blocked-readiness, output-conflict, and scanned-PDF guidance with contextual recovery actions in `PageForge/Features/Workflow/DocumentWorkflowView.swift` and `PageForge/Features/Workflow/DocumentWorkflowViewModel.swift`
- [ ] T027 [US2] Register `DocumentPreparationService.swift` and `DocumentPreparationServiceTests.swift` in the app/test groups and Sources phases in `PageForge.xcodeproj/project.pbxproj`

**Checkpoint**: US1 + US2 form the first useful product increment: import N files
and leave with independently prepared Kindle-ready outputs.

---

## Phase 5: User Story 3 — Send or Save Prepared Files (Priority: P3)

**Goal**: Let users select ready outputs and either copy them to a local folder or
send them through a configured profile, with a result for every file.

**Independent Test**: Inject ready outputs into the queue, save them with one
collision, then send them with complete and incomplete profiles; verify preflight,
copy semantics, independent results, and preservation of previous successes.

### Tests for User Story 3

- [ ] T028 [P] [US3] Write failing copy-only export, writable destination, partial success, no-silent-overwrite, confirmed replacement, and source/output preservation tests in `PageForgeTests/Domain/PreparedOutputExporterTests.swift`
- [ ] T029 [P] [US3] Write failing complete-profile preflight, attachment existence/size, secret-safe failure, stable send order, partial SMTP failure, and prior-success preservation tests in `PageForgeTests/Domain/DocumentDeliveryWorkflowTests.swift`
- [ ] T030 [P] [US3] Write failing ready-item eligibility, selected-only save/send, independent save/delivery axes, conflict retry, and remove-without-delete tests in `PageForgeTests/Features/DocumentWorkflowOutputTests.swift`

### Implementation for User Story 3

- [ ] T031 [P] [US3] Define `PreparedOutputExporting` and implement per-file copy results, writable-directory validation, `failIfExists`, and explicit replacement in `PageForge/Integrations/FileSystem/PreparedOutputExporter.swift`
- [ ] T032 [P] [US3] Add reusable profile preflight, readable attachment and delivery-size validation, and secret-free result/error mapping in `PageForge/Domain/Services/DeliveryService.swift`
- [ ] T033 [US3] Implement Save Files destination selection, selected-ready filtering, per-file exporter results, conflict recovery, and Reveal File behavior in `PageForge/Features/Workflow/DocumentWorkflowViewModel.swift`
- [ ] T034 [US3] Implement explicit profile selection, preflight-before-first-send, sequential per-output delivery, cancel-pending, and partial result preservation in `PageForge/Features/Workflow/DocumentWorkflowViewModel.swift`
- [ ] T035 [US3] Add primary Save Files and Send to Kindle controls with accurate disabled/loading/error/partial-success states in `PageForge/Features/Workflow/DocumentWorkflowView.swift`
- [ ] T036 [US3] Render per-item saved/sent/failed destinations and explicit replace/retry confirmation without changing readiness state in `PageForge/Features/Workflow/DocumentQueueRow.swift` and `PageForge/Features/Workflow/DocumentWorkflowView.swift`
- [ ] T037 [US3] Register the exporter and US3 test files in the app/test groups and Sources phases in `PageForge.xcodeproj/project.pbxproj`

**Checkpoint**: US3 is independently testable with seeded ready outputs and
completes both requested outcomes from the same screen.

---

## Phase 6: User Story 4 — Configure Without Leaving the Workflow (Priority: P4)

**Goal**: Move configuration into the native single-instance Settings window and
preserve main queue state and active work when Settings opens or closes.

**Independent Test**: Open Settings repeatedly, update a delivery profile and
secret, close the window during queue work, and confirm one Settings instance,
unchanged queue state, persistent non-secret config, and Keychain-only secrets.

### Tests for User Story 4

- [ ] T038 [P] [US4] Extend profile persistence, default-profile, Keychain-only secret, missing-secret, and secret-redaction coverage in `PageForgeTests/Domain/ConfigSecretTests.swift`
- [ ] T039 [P] [US4] Write failing dependency refresh, profile save/select, output preference, log access, and shared-service Settings tests in `PageForgeTests/Features/SettingsViewModelTests.swift`

### Implementation for User Story 4

- [ ] T040 [P] [US4] Declare the native `Settings` scene, inject shared `AppState`/`ThemeManager`, and place `SettingsLink` in the main toolbar in `PageForge/App/PageForgeApp.swift` and `PageForge/App/MainWorkflowView.swift`
- [ ] T041 [P] [US4] Refactor Settings state to use shared config/dependency/secret/log services and persist relevant output preference without queue ownership in `PageForge/Features/Settings/SettingsViewModel.swift` and `PageForge/Domain/Models/ConfigModels.swift`
- [ ] T042 [US4] Organize appearance, Calibre status/recovery, delivery profiles, output preference, updates, logs/troubleshooting, and Amazon handoff in the dedicated window in `PageForge/Features/Settings/SettingsView.swift` and `PageForge/Features/Settings/ProfileEditorView.swift`
- [ ] T043 [US4] Connect preparation and delivery recovery actions to the native Settings window without resetting selection, progress, or results in `PageForge/Features/Workflow/DocumentWorkflowView.swift` and `PageForge/App/MainWorkflowView.swift`
- [ ] T044 [US4] Remove remaining Settings destination, pending-send navigation, and obsolete route state while retaining shared job/log lifecycle in `PageForge/App/AppState.swift`
- [ ] T045 [US4] Register `SettingsViewModelTests.swift`, verify Settings files remain in the app target, and remove obsolete navigation references in `PageForge.xcodeproj/project.pbxproj`

**Checkpoint**: All four user stories are functional, with Settings separated from
the single-screen workflow and secrets still protected by Keychain.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Preserve advanced baseline capabilities contextually, remove dead UI,
align governance, and complete static validation without reintroducing complexity.

- [ ] T046 [P] Write failing contextual metadata, explicit aggressive-repair confirmation, and no-default-advanced-action tests in `PageForgeTests/Features/DocumentWorkflowAdvancedActionsTests.swift`
- [ ] T047 Implement per-item progressive disclosure for metadata inspect/update and explicitly confirmed aggressive repair using existing services in `PageForge/Features/Workflow/DocumentQueueRow.swift`, `PageForge/Features/Workflow/DocumentWorkflowViewModel.swift`, and `PageForge/Domain/Services/MetadataService.swift`
- [ ] T048 Add keyboard shortcuts, visible focus, VoiceOver labels/values, non-color status text, compact-toolbar behavior, empty/error/partial-completion polish, and reduced-motion-safe feedback in `PageForge/App/MainWorkflowView.swift`, `PageForge/Features/Workflow/DocumentWorkflowView.swift`, `PageForge/Features/Workflow/DocumentQueueRow.swift`, and `PageForge/Features/Shared/FileDropIntakeView.swift`
- [ ] T049 [P] Add a 50-item intake and mixed-outcome performance regression test with no real Calibre/network work in `PageForgeTests/Domain/DocumentIntakeServiceTests.swift`
- [ ] T050 Audit output paths, security-scoped access balancing, Keychain/SMTP redaction, logs, and user-facing errors for secret or destructive behavior in `PageForge/Domain/Services/DeliveryService.swift`, `PageForge/Integrations/FileSystem/PreparedOutputExporter.swift`, `PageForge/Features/Workflow/DocumentWorkflowViewModel.swift`, and `PageForge/Domain/Services/LogService.swift`
- [ ] T051 Remove obsolete top-level view/view-model files under `PageForge/Features/Batch/`, `PageForge/Features/Convert/`, `PageForge/Features/Readiness/`, `PageForge/Features/Send/`, `PageForge/Features/Metadata/`, and `PageForge/Features/Logs/` only after their required behavior is relocated, and remove their references from `PageForge.xcodeproj/project.pbxproj`
- [ ] T052 Align the delivered single-workflow product and explicit files-first scope in `README.md`, `docs/desktop-migration.md`, `AGENTS.md`, `.specify/memory/constitution.md`, and `.specify/templates/tasks-template.md`
- [ ] T053 Perform `git diff --check` and all targeted static searches from `specs/002-simplify-document-workflow/quickstart.md`, resolve findings in affected source/docs, and leave the documented `xcodebuild`/interactive scenarios for Erick to run locally

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 — Setup**: Starts immediately.
- **Phase 2 — Foundational**: Depends on Phase 1 and blocks all stories.
- **Phase 3 — US1**: Depends on Foundation and creates the visible queue shell.
- **Phase 4 — US2**: Domain preparation work can begin after Foundation; full UI
  integration depends on US1.
- **Phase 5 — US3**: Export/delivery services and tests can begin after Foundation;
  visible integration depends on US1 and normal end-to-end use depends on US2.
- **Phase 6 — US4**: Settings domain/view-model work can begin after Foundation;
  toolbar integration depends on US1.
- **Phase 7 — Polish**: Depends on all stories selected for delivery. Obsolete
  screens are removed only after contextual capabilities have moved.

### User Story Dependencies

```text
Setup → Foundation → US1 ─┬→ US2 ─┬→ Polish
                          ├→ US3 ─┤
                          └→ US4 ─┘

Foundation ─→ US2 domain tests/service
Foundation ─→ US3 exporter/delivery tests/services
Foundation ─→ US4 Settings tests/view-model
```

- **US1 (P1)**: No story dependency; this is the strict UI MVP.
- **US2 (P2)**: Independently testable at the domain level after Foundation; uses
  the US1 queue for the complete user journey.
- **US3 (P3)**: Independently testable with seeded/fake ready outputs; uses US2
  outputs for the real user journey.
- **US4 (P4)**: Independently testable through Settings/config services; integrates
  with US1 toolbar and US2/US3 recovery actions.

### Within Each Story

1. Write tests first and confirm the assertions describe behavior absent from the
   pre-feature code.
2. Implement domain models/services and filesystem/delivery seams.
3. Implement or extend the main-actor view model.
4. Implement views and app-shell integration.
5. Update explicit Xcode target membership.
6. Perform static validation; Erick runs build/test/app scenarios locally.

## Parallel Opportunities

### User Story 1

```text
T009 DocumentIntakeService tests
T010 DocumentWorkflowViewModel intake tests
T012 FileDropIntakeView multi-URL refactor
T014 DocumentQueueRow presentation
```

After T011, T012 and T013 converge through the shared `[URL]` intake contract.

### User Story 2

```text
T019 DocumentPreparationService tests
T020 DocumentWorkflowViewModel preparation tests
```

T021–T022 complete the domain path while UI work waits for the US1 queue shell.

### User Story 3

```text
T028 PreparedOutputExporter tests
T029 Delivery workflow tests
T030 Workflow output-state tests
T031 PreparedOutputExporter implementation
T032 DeliveryService preflight implementation
```

Save and delivery use different files until they converge in the workflow view
model at T033–T034.

### User Story 4

```text
T038 Config/Keychain tests
T039 SettingsViewModel tests
T040 Settings scene and SettingsLink
T041 SettingsViewModel/config refactor
```

T042 integrates the independently prepared Settings scene and state.

## Implementation Strategy

### Strict MVP: User Story 1

1. Complete Setup and Foundation.
2. Complete US1.
3. Stop and validate the single-screen multi-file intake independently.

This proves the simplified interaction model but does not yet prepare books.

### First Useful Product Increment: User Stories 1 + 2

1. Complete the strict MVP.
2. Add US2 preparation orchestration.
3. Validate EPUB/MOBI/PDF outputs, failure isolation, and responsiveness.

This is the recommended first handoff because users can import N documents and
leave with Kindle-ready files.

### Incremental Delivery

1. US1: one queue and all intake paths.
2. US2: one preparation action and independent results.
3. US3: Save Files and Send to Kindle outcomes.
4. US4: native separate Settings window.
5. Polish: contextual advanced capabilities, dead-screen removal, accessibility,
   security, documentation, and governance alignment.

## Notes

- `[P]` means different files and no incomplete prerequisite conflict.
- Story labels map directly to `spec.md` priorities.
- Do not implement new behavior under `legacy/`.
- Do not run build, test, launch, preview, or browser commands in-agent.
- Preserve unrelated worktree changes and use `apply_patch` for manual edits.
- Do not delete old views until their required capabilities have moved and
  `project.pbxproj` references are resolved explicitly.
- Do not add DRM removal, OCR, cloud accounts, Amazon automation, or parallel
  Calibre scheduling.
