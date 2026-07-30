# Tasks: App Feedback and Diagnostics

**Input**: Design documents from
`/specs/008-app-feedback-diagnostics/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`,
`contracts/`, `quickstart.md`

**Tests**: Required by FR-037 for every action lifecycle, expected failure
family, SMTP phase, redaction rule, copied field, recovery action, and
accessibility announcement. Test tasks appear before their corresponding
implementation tasks.

**Organization**: Tasks are grouped by independently testable user story.
Static, compiled, automated, runtime, authenticated-provider, and release
evidence remain separate gates.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can proceed in parallel after its phase prerequisites because it
  touches different files and does not depend on another unfinished task in the
  same parallel group
- **[Story]**: Maps the task to `US1` through `US5`
- Every task includes an exact repository file path

## Phase 1: Setup (Shared Inventory and Fixtures)

**Purpose**: Establish an exhaustive migration inventory and synthetic privacy
inputs before changing shared failure types.

- [X] T001 Inventory every accepted action, current `SanitizedFailure` construction site, stable failure code, owning layer, recovery action, and expected story mapping in specs/008-app-feedback-diagnostics/implementation-inventory.md
- [X] T002 [P] Add synthetic passwords, addresses, hosts, paths, filenames, provider prose, book text, message bytes, and raw-error canaries with safe expected values in BookSenderTests/Support/DiagnosticTestFixtures.swift

**Checkpoint**: The implementation has a reviewable coverage baseline with no
personal credentials or user data.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Add the typed feedback and diagnostic contracts shared by every
story without wiring a new UI or persistence surface.

**Critical**: Complete this phase before user-story implementation.

- [X] T003 Define exhaustive `DiagnosticCode`, `DiagnosticPhase`, `DiagnosticSeverity`, `RetryDisposition`, `ProviderStatus`, `EnhancedStatusCode`, `DiagnosticContext`, `DiagnosticEvent`, `DiagnosticOutcome`, and `DiagnosticCopy` models with validation in BookSender/Domain/Models/DiagnosticModels.swift
- [X] T004 [P] Define `ActionFeedback`, `FeedbackScope`, `FeedbackAction`, `FeedbackState`, `FeedbackDismissalPolicy`, and `FailurePresentation` with legal state transitions in BookSender/Domain/Models/FeedbackModels.swift
- [X] T005 Define typed `DiagnosticRecording` and main-actor `DiagnosticClipboard` ports that accept no raw strings, errors, addresses, paths, or arbitrary metadata in BookSender/Domain/Ports/DiagnosticProtocols.swift
- [X] T006 [P] Add exhaustive code, enhanced-status, safe-context, retry-disposition, and invalid-value tests in BookSenderTests/Domain/DiagnosticModelsTests.swift
- [X] T007 [P] Add lifecycle, terminal immutability, partial/unknown invariants, dismissal-policy, and retry-identity tests in BookSenderTests/Domain/FeedbackModelsTests.swift
- [X] T008 Add recorder, clipboard, clock, app-version, and feedback observer test doubles using typed values only in BookSenderTests/Support/TestDoubles.swift
- [X] T009 Implement sanitized event creation, event equality keys, occurrence consolidation, and record-once coordination in BookSender/Application/Diagnostics/DiagnosticService.swift
- [X] T010 [P] Implement action acknowledgement, honest progress, terminal replacement, dismissal, and unchanged-state deduplication in BookSender/Application/Presentation/ActionFeedbackService.swift
- [X] T011 [P] Add event construction, occurrence grouping, terminal-only recording, and recorder-failure isolation tests in BookSenderTests/Application/DiagnosticServiceTests.swift
- [X] T012 [P] Add action transition, quick-action, replacement, persistence-duration, and observer-deduplication tests in BookSenderTests/Application/ActionFeedbackServiceTests.swift

**Checkpoint**: Typed feedback and diagnostics are independently testable with
spies; no SwiftUI view, OSLog adapter, clipboard adapter, or app-owned storage is
required.

---

## Phase 3: User Story 1 - Know That Every Action Worked (Priority: P1) MVP

**Goal**: Every accepted action exposes a proportionate acknowledgement,
observable progress when applicable, and a visible terminal result, including
unambiguous secure setup-save success.

**Independent Test**: Exercise launch restoration, setup creation/edit/password
replacement, intake, remove, clear, confirmation, send, cancellation, retry,
shortcut changes, and update checking; verify one perceivable terminal result
per accepted action and no reliance on navigation or field clearing.

### Tests for User Story 1

- [X] T013 [P] [US1] Add setup-create, setup-edit, password-replacement, secure-field-clearing, repeated-save, and durable-success-feedback tests in BookSenderTests/Application/AppModelSetupTests.swift
- [X] T014 [P] [US1] Add launch, intake, remove, clear, confirm, dismiss, cancel, send, and failed-only retry lifecycle tests in BookSenderTests/Application/FirstBookJourneyTests.swift
- [X] T015 [P] [US1] Add shortcut save, clear, conflict, registration failure, and terminal feedback tests in BookSenderTests/Application/ShortcutServiceTests.swift
- [X] T016 [P] [US1] Add saved delivery edit, delete, unchanged-password, and preference rollback feedback tests in BookSenderTests/Application/SettingsDeliveryTests.swift
- [X] T017 [P] [US1] Verify the setup password field clears while `Setup saved. App password stored securely.` remains perceivable in BookSenderUITests/FirstBookJourneyUITests.swift
- [X] T018 [P] [US1] Verify intake, remove, clear, confirmation, send, cancellation, partial completion, and retry control feedback in BookSenderUITests/BatchSendUITests.swift
- [X] T019 [P] [US1] Verify Delivery and Shortcut Settings actions plus the global shortcut expose loading and terminal results in BookSenderUITests/SettingsUITests.swift and BookSenderUITests/GlobalShortcutUITests.swift

### Implementation for User Story 1

- [X] T020 [US1] Create the shared inline renderer for acknowledgement, progress, success, cancellation, partial, unknown, and failure states in BookSender/Features/Shared/ActionFeedbackView.swift
- [X] T021 [US1] Publish launch restoration and setup-save feedback, preserve success after clearing the secret draft, and reject duplicate active saves in BookSender/App/AppModel.swift
- [X] T022 [US1] Render setup create/edit/delete progress and terminal feedback without redisplaying secrets in BookSender/Features/DeliverySetup/DeliverySetupView.swift and BookSender/Features/Settings/BookSenderSettingsView.swift
- [X] T023 [US1] Add lifecycle feedback for intake, remove, clear, confirmation, dismissal, preparation, send, cancellation, and failed-only retry in BookSender/App/AppModel.swift
- [X] T024 [US1] Render aggregate action feedback and non-obvious disabled reasons around intake and sending in BookSender/Features/SendBook/SendBookView.swift, BookSender/Features/SendBook/BookFileImporter.swift, and BookSender/Features/SendBook/BookDropTarget.swift
- [X] T025 [US1] Render confirmation, cancellation, retry, and per-item terminal feedback without replacing existing batch outcomes in BookSender/Features/SendBook/BatchConfirmationView.swift and BookSender/Features/SendBook/BatchItemRow.swift
- [X] T026 [US1] Return typed shortcut save/clear/conflict outcomes and render them inline in BookSender/Application/Shortcut/ShortcutService.swift and BookSender/Features/Settings/ShortcutSettingsView.swift
- [X] T027 [US1] Compose action-feedback dependencies and preserve `SPUStandardUpdaterController` as the standard update-cycle UI in BookSender/App/AppDependencies.swift and BookSender/App/BookSenderApp.swift

**Checkpoint**: User Story 1 is independently demonstrable across all successful
and existing terminal paths without adding a primary screen or diagnostic
history.

---

## Phase 4: User Story 2 - Understand Every Failure (Priority: P1)

**Goal**: Every expected or unexpected failure identifies the affected action,
safe phase, specific cause, observed impact, stable code, and primary recovery
action through concise copy and progressive disclosure.

**Independent Test**: Trigger one controlled failure from intake, archive, XML,
audit, repair, filesystem, credential, preferences, shortcut, update, pipeline,
and delivery families; verify specific catalog output and consolidated repeated
failures without exposing raw technical text.

### Tests for User Story 2

- [X] T028 [P] [US2] Add exhaustive catalog coverage for every `DiagnosticCode`, specific family/phase/recovery mapping, unexpected-family fallback, and prohibited generic wording in BookSenderTests/Domain/FailurePresentationTests.swift
- [X] T029 [P] [US2] Add credential read/write/delete and preference read/write/revision failure-evidence tests in BookSenderTests/Adapters/KeychainCredentialStoreTests.swift and BookSenderTests/Adapters/DeliveryPreferencesStoreTests.swift
- [X] T030 [P] [US2] Add intake, PDF eligibility, workspace staging, collision, size, timeout, cleanup, and unexpected-boundary evidence tests in BookSenderTests/Application/BookIntakeServiceTests.swift, BookSenderTests/Application/PDFEligibilityServiceTests.swift, and BookSenderTests/Adapters/WorkspaceStoreTests.swift
- [X] T031 [P] [US2] Add archive safety, archive write, XML parsing, malformed input, boundary limit, and raw-input-discard evidence tests in BookSenderTests/Adapters/EPUBArchiveAdapterTests.swift, BookSenderTests/Adapters/EPUBArchiveWriterTests.swift, and BookSenderTests/Adapters/BoundedXMLParserTests.swift
- [X] T032 [P] [US2] Add audit, repair, revalidation, pipeline, shortcut, startup, and update-boundary evidence tests in BookSenderTests/Domain/EPUBAuditEngineTests.swift, BookSenderTests/Domain/EPUBRepairEngineTests.swift, BookSenderTests/Integration/EPUBPreparationJourneyTests.swift, BookSenderTests/Application/ShortcutServiceTests.swift, and BookSenderTests/Application/AppModelSetupTests.swift
- [X] T033 [P] [US2] Verify concise failure summaries, expandable code/subsystem/phase/retry details, one recovery action, unexpected failures, and repeated-failure grouping in BookSenderUITests/RecoveryJourneyUITests.swift

### Implementation for User Story 2

- [X] T034 [US2] Extend `SanitizedFailure` with closed `DiagnosticCode` and required `DiagnosticEvidence`, remove dynamic provider-code strings, and preserve typed recovery actions in BookSender/Domain/Models/PipelineModels.swift and BookSender/Domain/Models/DiagnosticModels.swift
- [X] T035 [US2] Replace broad family-only copy with the exhaustive code-to-title/summary/explanation/phase/impact/retry/recovery catalog in BookSender/Application/Presentation/FailurePresentationService.swift
- [X] T036 [US2] Create keyboard-reachable progressive disclosure for stable code, subsystem, phase, impact, retry classification, safe context, and primary recovery action in BookSender/Features/Shared/FailureDetailView.swift
- [X] T037 [US2] Translate Keychain and preferences errors into phase-specific evidence without raw `OSStatus`, credential data, or preference payloads in BookSender/Adapters/Credentials/KeychainCredentialStore.swift and BookSender/Adapters/Credentials/DeliveryPreferencesStore.swift
- [X] T038 [US2] Translate intake, PDF eligibility, and workspace failures into stable evidence without paths, filenames, or content in BookSender/Application/Intake/BookIntakeService.swift, BookSender/Application/Intake/PDFEligibilityService.swift, and BookSender/Adapters/Filesystem/WorkspaceStore.swift
- [X] T039 [US2] Translate archive and XML failures into stable rule codes, safe limit identifiers, and exact archive/XML phases while discarding input text in BookSender/Adapters/Archive/ZIPFoundationEPUBArchive.swift, BookSender/Adapters/Archive/EPUBArchiveWriter.swift, and BookSender/Adapters/XML/BoundedXMLParser.swift
- [X] T040 [US2] Translate audit, repair, write, revalidation, cancellation, and unexpected pipeline failures into typed evidence in BookSender/Domain/Audit/EPUBAuditEngine.swift, BookSender/Domain/Repair/EPUBRepairEngine.swift, and BookSender/Application/Pipeline/PipelineActor.swift
- [X] T041 [US2] Translate shortcut and app-owned startup/update-configuration failures while preserving Sparkle standard update UI in BookSender/Application/Shortcut/ShortcutService.swift and BookSender/App/BookSenderApp.swift
- [X] T042 [US2] Build one failure presentation per terminal operation, consolidate identical occurrences, and retain the latest safe state in BookSender/App/AppModel.swift
- [X] T043 [US2] Integrate concise failure summaries and progressive details into setup and both existing Settings tabs in BookSender/Features/DeliverySetup/DeliverySetupView.swift, BookSender/Features/Settings/BookSenderSettingsView.swift, and BookSender/Features/Settings/ShortcutSettingsView.swift
- [X] T044 [US2] Integrate per-item and aggregate failure details without conflicting messages in BookSender/Features/SendBook/ItemDetailDisclosure.swift, BookSender/Features/SendBook/BatchItemRow.swift, and BookSender/Features/SendBook/SendBookView.swift

**Checkpoint**: Every non-SMTP failure family is independently diagnosable, and
delivery has a safe catalog boundary ready for phase-specific refinement.

---

## Phase 5: User Story 3 - Diagnose Delivery Rejections Safely (Priority: P1)

**Goal**: Distinguish connection, secure channel, authentication, sender,
recipient, DATA, final acceptance, timeout, cancellation, and uncertain delivery
using only safe provider status and protocol state.

**Independent Test**: Run the controlled SMTP matrix, including 530, 534, 535,
4xx/5xx envelope and final replies, malformed enhanced codes, multi-line
replies, pre-data interruption, and post-data interruption; verify phase,
certainty, recovery, and complete raw-reply redaction.

### Tests for User Story 3

- [X] T045 [P] [US3] Add controlled SMTP reply, phase, interruption, and provider-prose scenarios to BookSenderTests/Support/TestDoubles.swift and BookSenderTests/Support/DiagnosticTestFixtures.swift
- [X] T046 [P] [US3] Add three-digit/enhanced-status parsing, absent/malformed enhanced code, multi-line framing, limits, and raw-line-discard tests in BookSenderTests/Adapters/SMTPReplyDecoderTests.swift
- [X] T047 [P] [US3] Add the complete phase matrix for connection, TLS, 530/534/535 authentication, sender, recipient, DATA, final acceptance, 4xx/5xx, timeout, and malformed replies in BookSenderTests/Adapters/SMTPStateMachineTests.swift
- [X] T048 [P] [US3] Add pre-data retry, post-data uncertainty, final-rejection, timeout, channel-close, and cancellation tests in BookSenderTests/Adapters/SMTPDeliveryUncertaintyTests.swift and BookSenderTests/Adapters/SMTPActiveCancellationTests.swift
- [X] T049 [P] [US3] Verify controlled delivery rows and expanded details distinguish every SMTP phase and never show raw replies, addresses, or credentials in BookSenderUITests/BatchSendUITests.swift

### Implementation for User Story 3

- [X] T050 [US3] Parse and validate `ProviderStatus` while keeping provider reply text transient and outside `SanitizedFailure` in BookSender/Adapters/SMTP/SMTPReplyDecoder.swift
- [X] T051 [US3] Interpret replies in the active SMTP state before failure mapping and emit stable cause codes plus phase-specific retry dispositions in BookSender/Adapters/SMTP/SMTPStateMachine.swift
- [X] T052 [US3] Preserve connection/TLS/authentication/envelope/data/final phases and `transmissionStarted` across transport errors, timeouts, and cancellation in BookSender/Adapters/SMTP/NIOSMTPClient.swift
- [X] T053 [US3] Preserve conclusive rejection versus `delivery_unknown`, prohibit automatic retry after data starts, and forward typed evidence through BookSender/Application/Delivery/BookDeliveryService.swift and BookSender/Application/Pipeline/PipelineActor.swift
- [X] T054 [US3] Add phase-specific SMTP explanations and `Edit Setup`, `Retry`, or `Check Kindle Before Retrying` recovery guidance in BookSender/Application/Presentation/FailurePresentationService.swift
- [X] T055 [US3] Present safe numeric/enhanced provider status, phase, and delivery certainty in BookSender/App/AppModel.swift and BookSender/Features/SendBook/BatchItemRow.swift
- [X] T056 [US3] Reconcile all migrated SMTP codes and controlled cases with the coverage matrix in specs/008-app-feedback-diagnostics/implementation-inventory.md

**Checkpoint**: The original vague provider rejection is replaced by a
phase-aware, privacy-safe result, while live Gmail/Kindle acceptance remains a
separate gate.

---

## Phase 6: User Story 4 - Share Useful Diagnostics Without Sharing Private Data (Priority: P2)

**Goal**: Record each failed or uncertain operation once in bounded local
unified logging and let the user explicitly copy the current sanitized
diagnostic block.

**Independent Test**: Feed the full canary matrix through presentation, recorder
spy, formatter, clipboard, startup, and fatal paths; verify required fields are
correlatable and every protected value is absent.

### Tests for User Story 4

- [X] T057 [P] [US4] Add deterministic field order, optional-field omission, ISO timestamp, occurrence count, and no-raw-error formatter tests in BookSenderTests/Application/DiagnosticFormatterTests.swift
- [X] T058 [P] [US4] Add fixed subsystem/category, error/fault level, validated-public-field, terminal-only, and recorder-failure isolation tests in BookSenderTests/Adapters/UnifiedDiagnosticRecorderTests.swift
- [X] T059 [P] [US4] Add explicit write-only, clear-before-write, plain-text, repeated-copy, and typed clipboard-failure tests in BookSenderTests/Adapters/AppKitDiagnosticClipboardTests.swift
- [X] T060 [P] [US4] Run every synthetic credential, address, host, path, filename, provider, content, message, and raw-error canary through presentation, recording, and copying in BookSenderTests/Privacy/DiagnosticRedactionTests.swift
- [X] T061 [P] [US4] Restrict `Logger` to the vetted adapter and reject `os_log`, telemetry, arbitrary diagnostic metadata, and secret-bearing interpolation elsewhere in BookSenderTests/Privacy/PrivacyAuditTests.swift
- [X] T062 [P] [US4] Add record-once, startup/fatal correlation, app-version/event-ID, copy success/failure, and original-failure-retention tests in BookSenderTests/Application/AppModelDiagnosticsTests.swift
- [X] T063 [P] [US4] Verify `Copy Error Details`, `Error details copied.`, clipboard failure recovery, selected-item session reference, and unchanged failure visibility in BookSenderUITests/RecoveryJourneyUITests.swift

### Implementation for User Story 4

- [X] T064 [US4] Implement deterministic compact English diagnostic text from `DiagnosticEvent` only in BookSender/Application/Diagnostics/DiagnosticFormatter.swift
- [X] T065 [US4] Implement the sole `OSLog.Logger` adapter with static templates, fixed categories, error/fault levels, and explicitly validated public fields in BookSender/Adapters/Diagnostics/UnifiedDiagnosticRecorder.swift
- [X] T066 [US4] Implement explicit main-actor pasteboard clearing and plain-text writing without clipboard reads in BookSender/Adapters/Diagnostics/AppKitDiagnosticClipboard.swift
- [X] T067 [US4] Compose recorder, formatter, clipboard, clock, and app-version dependencies without adding a persistence or telemetry sink in BookSender/App/AppDependencies.swift
- [X] T068 [US4] Record each failed or uncertain startup, setup, shortcut, pipeline, and delivery terminal boundary once while isolating recorder failures in BookSender/Application/Diagnostics/DiagnosticService.swift
- [X] T069 [US4] Retain the current `DiagnosticEvent`, route explicit copying, report copy success/failure, and keep the original failure visible in BookSender/App/AppModel.swift
- [X] T070 [US4] Create correlatable startup/fatal events before safe presentation and preserve standard Sparkle behavior in BookSender/App/BookSenderApp.swift
- [X] T071 [US4] Add `Copy Error Details` and copy feedback to expanded current-failure disclosure without introducing diagnostic-history or diagnostic-export UI in BookSender/Features/Shared/FailureDetailView.swift

**Checkpoint**: Current failures can be shared safely, and startup/fatal
failures leave bounded local evidence without app-owned storage.

---

## Phase 7: User Story 5 - Receive Calm and Accessible Feedback (Priority: P2)

**Goal**: Keep richer feedback inline, concise, keyboard-operable, semantic, and
announced once without relying on color or creating batch noise.

**Independent Test**: Complete success, failure, cancellation, partial, and
unknown journeys with keyboard and supported accessibility settings; verify one
meaningful announcement per transition, bounded batch announcements, visible
focus, and collapsed healthy detail.

### Tests for User Story 5

- [X] T072 [P] [US5] Add feedback-identity/state announcement deduplication, bounded batch policy, and unchanged-state suppression tests in BookSenderTests/Application/ActionFeedbackServiceTests.swift
- [X] T073 [P] [US5] Verify accessible names, values, hints, reading order, one announcement per important transition, and no color-only status in BookSenderUITests/AccessibilityUITests.swift
- [X] T074 [P] [US5] Verify setup and Settings focus, pressed, disabled, loading, success, and failure states through keyboard paths in BookSenderUITests/SettingsUITests.swift and BookSenderUITests/FirstBookJourneyUITests.swift
- [X] T075 [P] [US5] Verify a mixed 20-item batch exposes one non-conflicting aggregate result, every item outcome, bounded announcements, and collapsed healthy detail in BookSenderUITests/BatchSendUITests.swift
- [X] T076 [P] [US5] Preserve responsive sequential 20-item projection and occurrence consolidation under rapid updates in BookSenderTests/Performance/BatchCapacityTests.swift

### Implementation for User Story 5

- [X] T077 [US5] Add text/semantic status, visible focus behavior, reduced-motion-safe transitions, and one keyed macOS accessibility announcement per important state in BookSender/Features/Shared/ActionFeedbackView.swift
- [X] T078 [US5] Make expanded failure details keyboard reachable with meaningful labels, reading order, recovery focus, and no color-only severity in BookSender/Features/Shared/FailureDetailView.swift
- [X] T079 [US5] Add accessible loading, disabled-reason, focus, pressed, success, and error semantics to setup controls in BookSender/Features/DeliverySetup/DeliverySetupView.swift
- [X] T080 [US5] Add accessible intake/send controls and concise healthy-state disclosure behavior in BookSender/Features/SendBook/SendBookView.swift and BookSender/Features/SendBook/BookDropTarget.swift
- [X] T081 [US5] Add bounded aggregate/per-item semantics for progress, partial, cancellation, and uncertainty in BookSender/Features/SendBook/BatchConfirmationView.swift, BookSender/Features/SendBook/BatchItemRow.swift, and BookSender/Features/SendBook/ItemDetailDisclosure.swift
- [X] T082 [US5] Add accessible state and disabled-reason semantics to Delivery and Shortcut Settings without adding tabs in BookSender/Features/Settings/BookSenderSettingsView.swift and BookSender/Features/Settings/ShortcutSettingsView.swift
- [X] T083 [US5] Deduplicate announcement identity/state, prioritize aggregate batch announcements, and keep routine healthy detail collapsed in BookSender/App/AppModel.swift and BookSender/Application/Presentation/ActionFeedbackService.swift

**Checkpoint**: All five stories satisfy the two-screen, minimal-interface, and
accessibility contract together.

---

## Phase 8: Polish and Cross-Cutting Validation

**Purpose**: Close coverage, documentation, privacy, constitution, and separated
evidence gates without overstating runtime or provider behavior.

- [X] T084 [P] Document current-error copying, privacy guarantees, standard macOS diagnostic lookup, retention limits, and non-personal support evidence in docs/troubleshooting.md and link it from README.md
- [X] T085 Reconcile every implemented action, failure code, recovery action, SMTP phase, redaction rule, copied field, and announcement with tests and final status in specs/008-app-feedback-diagnostics/implementation-inventory.md
- [X] T086 Run the non-executing checks from specs/008-app-feedback-diagnostics/quickstart.md and record `git diff --check`, JSON/plist validation, logger-location, privacy, dependency, two-screen, and no-diagnostic-history results in specs/008-app-feedback-diagnostics/validation/static-validation.md
- [ ] T087 With Erick's explicit authorization, run the BookSender compile and unit-test gates from specs/008-app-feedback-diagnostics/quickstart.md and record compilation separately from deterministic test results in specs/008-app-feedback-diagnostics/validation/compiled-and-unit-tests.md
- [ ] T088 With Erick's explicit authorization, run the BookSender UI/accessibility suite from specs/008-app-feedback-diagnostics/quickstart.md and record keyboard, announcement, contrast, motion, and mixed-batch results in specs/008-app-feedback-diagnostics/validation/ui-accessibility.md
- [ ] T089 With Erick's explicit authorization, inspect a controlled post-restart event through standard macOS diagnostics and record only sanitized correlation fields in specs/008-app-feedback-diagnostics/validation/local-diagnostics-runtime.md
- [ ] T090 With Erick's explicit authorization and dedicated non-personal credentials, execute the controlled provider matrix without raw transcripts and record fixture versus Gmail/Kindle evidence separately in specs/008-app-feedback-diagnostics/validation/provider-acceptance.md
- [X] T091 Review constitution 7.2.0, exact dependencies, Keychain continuity, original preservation, sequential isolation, Sparkle ownership, signing/release boundaries, and evidence separation in specs/008-app-feedback-diagnostics/validation/constitution-and-release-regression.md

---

## Dependencies and Execution Order

### Phase dependencies

- **Phase 1** has no prerequisites.
- **Phase 2** depends on Phase 1 and blocks all story implementation.
- **US1** depends on Phase 2 and establishes the shared visible lifecycle.
- **US2** depends on Phase 2; following US1 avoids conflicts in `AppModel` and
  shared views.
- **US3** depends on US2's stable codes, evidence envelope, and presentation
  catalog.
- **US4** depends on US2 for the sanitized event and US3 for complete SMTP copy
  coverage.
- **US5** depends on the visible states from US1-US4 for final accessibility
  acceptance.
- **Polish** depends on all selected stories; executing build, UI, runtime, or
  provider gates additionally requires explicit authorization.

### User story dependency graph

```text
Setup -> Foundation -> US1 -> US2 -> US3 -> US4 -> US5 -> Polish
                       \------ all P1 diagnostic release ------/
```

The order is intentionally conservative because the stories share `AppModel`,
`FailurePresentationService`, `BatchItemRow`, and the two primary screens.
Tests and isolated adapters identified below can still proceed in parallel.

### Within each user story

- Write or extend focused tests before accepting implementation.
- Domain models precede application services.
- Adapters translate raw failures before application terminal recording.
- Application state precedes SwiftUI integration.
- Existing screen and Settings integration precedes UI/accessibility acceptance.
- A failed/uncertain provider outcome never triggers automatic retry.

## Parallel Opportunities

### User Story 1

- T013-T019 can be authored in parallel after Foundation because they touch
  separate test files.
- T024-T026 can proceed in parallel after T023 defines application lifecycle
  state.

### User Story 2

- T028-T033 can be authored in parallel.
- T037-T041 can proceed in parallel after T034 defines the failure envelope and
  T035 establishes catalog terminology.
- T043 and T044 can proceed in parallel after T036 and T042.

### User Story 3

- T045-T049 can be authored in parallel.
- T050 and the catalog portion of T054 can proceed in parallel before
  T051-T053 converge on transport behavior.

### User Story 4

- T057-T063 can be authored in parallel.
- T064-T066 can proceed in parallel before dependency composition in T067.
- T070 and T071 can proceed in parallel after T067-T069 expose the current
  event.

### User Story 5

- T072-T076 can be authored in parallel.
- T079-T082 can proceed in parallel after T077-T078 establish shared semantics.

## Implementation Strategy

### MVP first

1. Complete Setup and Foundation.
2. Deliver US1 so setup save, field clearing, batch actions, shortcut changes,
   cancellation, retry, and update entry points always communicate completion.
3. Validate US1 independently before expanding technical detail.

US1 is the suggested MVP, but it does not solve the original vague SMTP error
alone. The first diagnosis-capable P1 delivery is US1 + US2 + US3.

### Incremental delivery

1. **Visible trust**: US1 action lifecycle and setup-save confirmation.
2. **Specific failures**: US2 stable catalog and progressive disclosure.
3. **SMTP diagnosis**: US3 phase/provider/certainty mapping.
4. **Safe support**: US4 local recording and explicit copied details.
5. **Calm accessibility**: US5 announcements, semantics, focus, and batch
   consolidation.
6. **Evidence**: static first; compiled, automated, runtime, provider, and
   release gates only with their required authority and environment.

## Notes

- Do not create a branch, stage, commit, build, test, launch, inspect Console, or
  contact a provider unless the applicable repository rule or explicit
  authorization permits it.
- Preserve concurrent changes in `AppDependencies.swift`, `AppModel.swift`,
  `BookSenderApp.swift`, and existing tests; inspect their current diffs before
  each task.
- Keep all application UI strings, diagnostic text, identifiers, comments,
  tests, and technical documentation in English.
- Do not add a dependency, helper process, custom diagnostic log file,
  diagnostic database, diagnostic-history screen, telemetry sink, hidden upload,
  or third primary screen. Bounded send history remains owned by Feature 009.
- Static checks, compilation, tests, runtime accessibility, local log
  inspection, authenticated SMTP/Kindle behavior, signing, and publication are
  distinct claims.
