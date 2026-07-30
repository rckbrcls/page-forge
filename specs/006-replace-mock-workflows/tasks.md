# Tasks: Replace Mock Workflows

**Input**: Design documents from `/specs/006-replace-mock-workflows/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md),
[research.md](./research.md), [data-model.md](./data-model.md),
[contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: Tests are required because the specification and constitution require
fixture-backed evidence for every EPUB audit, cleanup, restoration, and
revalidation rule, plus focused setup, batch, cancellation, privacy, SMTP, UI,
accessibility, and performance coverage.

**Organization**: Tasks are dependency-ordered and grouped by independently
testable user story. Tests precede the implementation they accept.

**Security amendment (2026-07-30)**: Completed task wording that names Data
Protection Keychain or ad-hoc distribution is historical evidence of the former
6.0.0 contract. Constitution 7.0.0 and
`specs/007-native-quality-baseline/tasks.md` supersede those requirements with
traditional Keychain storage and the pinned self-signed release identity.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: May run in parallel after its listed prerequisites because it touches
  different files and does not depend on another incomplete task in the group.
- **[Story]**: Maps the task to US1, US2, US3, or US4 from the feature
  specification.
- Every task names the exact file or directory it changes or produces.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Preserve the current checkout, establish deterministic test support,
and remove stale fixture provenance before changing production behavior.

- [X] T001 Record the current tracked/untracked Swift changes, preview references, missing production services, and validation boundary in specs/006-replace-mock-workflows/validation/implementation-baseline.md
- [X] T002 [P] Record the existing exact package versions, target products, licenses, sandbox implications, and no-new-dependency decision in specs/006-replace-mock-workflows/validation/dependency-baseline.md
- [X] T003 Replace removed TypeScript fixture provenance with a native manifest schema, expected digests, finding codes, actions, and readiness fields in BookSenderTests/Fixtures/fixture-manifest.json and BookSenderTests/Fixtures/Books/README.md and BookSenderTests/Fixtures/Malicious/README.md
- [X] T004 [P] Create deterministic ZIP, XML, EPUB, PDF, certificate, and SMTP transcript builders in BookSenderTests/Support/FixtureFactory.swift
- [X] T005 [P] Create isolated UserDefaults, Keychain namespace, workspace root, and cleanup helpers in BookSenderTests/Support/TestStores.swift
- [X] T006 [P] Create reusable credential, preference, archive, delivery, clock, and pipeline test doubles in BookSenderTests/Support/TestDoubles.swift

**Checkpoint**: Tests can create deterministic private inputs without production
preview state or residual user data.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Establish the typed models, ports, actor ownership, and safety
support required by every user story.

**⚠️ CRITICAL**: No user-story UI integration begins until this phase is complete.

- [X] T007 Add `SetupLoadResult`, revision-safe `CredentialReference`, explicit `BookHealth` raw values including `needs_review`, and validation invariants in BookSender/Domain/Models/DeliveryModels.swift and BookSender/Domain/Models/AuditModels.swift
- [X] T008 [P] Add ordered `IntakeOutcome`, excluded/cancelled item representation, optional pre-staging evidence, and authoritative batch phases in BookSender/Domain/Models/BatchModels.swift
- [X] T009 [P] Add `PreparationResult`, executable plan postconditions, `ConfirmedBatchItem`, value-based `ConfirmedBatchSnapshot`, and complete delivery-attempt fields in BookSender/Domain/Models/RepairModels.swift and BookSender/Domain/Models/PipelineModels.swift
- [X] T010 [P] Complete registered, disabled, and conflict shortcut preference states in BookSender/Domain/Models/ShortcutModels.swift
- [X] T011 Extend credential existence checks, archive opening/writing, preparation, SMTP transport progress, and transient delivery ports in BookSender/Domain/Ports/AdapterProtocols.swift
- [X] T012 Define actor-owned intake, preparation, confirmation, cancellation, retry, and snapshot command contracts in BookSender/Domain/Ports/PipelineProtocols.swift
- [X] T013 [P] Add limit-minus-one, limit, and limit-plus-one coverage for batch, book, archive, XML, attachment, SMTP reply, timeout, and orphan thresholds in BookSenderTests/Domain/SafetyLimitsTests.swift
- [X] T014 [P] Add manifest schema, fixture digest, expected-code, expected-action, and bundle/resource-access contract tests in BookSenderTests/Support/FixtureManifestTests.swift
- [X] T015 [P] Add digest, containment, partial cleanup, marker validation, clear, quit, and orphan-sweep tests in BookSenderTests/Adapters/WorkspaceStoreTests.swift
- [X] T016 Implement staged-byte digests, collision-safe cleanup, exact-root clear, and marker/age-bounded orphan sweep in BookSender/Adapters/Filesystem/WorkspaceStore.swift
- [X] T017 Refactor PipelineActor into the sole mutable `CurrentBatch` owner with guarded phases, retained active tasks, value snapshots, and complete typed event emission in BookSender/Application/Pipeline/PipelineActor.swift
- [X] T018 Create injectable production and isolated-test dependency composition without a second product path in BookSender/App/AppDependencies.swift
- [X] T019 Complete stable sanitized failure codes, recovery actions, and redacted user presentations across every failure family in BookSender/Application/Presentation/FailurePresentationService.swift and BookSenderTests/Domain/FailurePresentationTests.swift

**Checkpoint**: The actor, models, ports, fixtures, and storage safety contracts
are testable without SwiftUI.

---

## Phase 3: User Story 1 - Complete Real Delivery Setup (Priority: P1) 🎯 First Deliverable

**Goal**: A user can save a consistent protected delivery setup and reach
`Send Book` only from actual complete state, with no preview or bypass path.

**Independent Test**: Launch with isolated empty storage, confirm no preview
control exists, exercise invalid field feedback, save valid setup, relaunch into
`Send Book`, and verify the credential is neither visible nor stored in
preferences.

### Tests for User Story 1

- [X] T020 [P] [US1] Extend normalization, field mapping, Kindle destination, blank-password edit, revision, and secret-redaction tests in BookSenderTests/Domain/DeliverySetupTests.swift
- [X] T021 [P] [US1] Add Data Protection attributes, create, read, exists, replace, delete, device-only, non-synchronizing, and sanitized-error tests in BookSenderTests/Adapters/KeychainCredentialStoreTests.swift
- [X] T022 [P] [US1] Add non-secret round-trip, invalid decode, clear, and absence-of-credential/batch/path tests in BookSenderTests/Adapters/DeliveryPreferencesStoreTests.swift
- [X] T023 [P] [US1] Add initial save, blank-password reuse, revision-scoped replacement, preference rollback, credential failure, missing credential on load, and old-reference preservation tests in BookSenderTests/Application/DeliverySetupServiceTests.swift
- [X] T024 [P] [US1] Add complete/incomplete load, failed/successful save, preserved draft, and presentation-only route tests in BookSenderTests/Application/AppModelSetupTests.swift
- [X] T025 [P] [US1] Replace first-launch appearance-only coverage with no-bypass, invalid save, real isolated save, relaunch, credential masking, keyboard, and accessibility scenarios in BookSenderUITests/FirstBookJourneyUITests.swift

### Implementation for User Story 1

- [X] T026 [US1] Implement credential existence checks, revision-scoped reference creation, Data Protection attributes, and sanitized Security.framework failures in BookSender/Adapters/Credentials/KeychainCredentialStore.swift
- [X] T027 [US1] Make preference decoding explicit and preserve only validated non-secret setup revisions in BookSender/Adapters/Credentials/DeliveryPreferencesStore.swift
- [X] T028 [US1] Implement transactional setup load/save/rollback and old-credential cleanup without network validation in BookSender/Application/Delivery/DeliverySetupService.swift
- [X] T029 [US1] Route only from `SetupLoadResult`, preserve safe drafts, block concurrent saves, and keep credential bytes out of presentation state in BookSender/App/AppModel.swift
- [X] T030 [US1] Remove `isPreviewingSendBook`, preview items/actions/branches/row initialization/identifiers and delete BookSender/Features/SendBook/PreviewBookItem.swift and BookSenderTests/Application/PreviewBookIntakeTests.swift while updating BookSender/App/AppModel.swift and BookSender/Features/SendBook/BatchItemRow.swift and BookSender/Features/SendBook/SendBookView.swift
- [X] T031 [US1] Remove `Preview Send Book`, retain field-specific safe feedback, and allow transition only after successful setup persistence in BookSender/Features/DeliverySetup/DeliverySetupView.swift
- [X] T032 [US1] Consume explicit UI-test storage arguments through isolated dependency composition without weakening release behavior in BookSender/App/BookSenderApp.swift and BookSender/App/AppDependencies.swift
- [ ] T033 [US1] Execute the authorized focused setup/unit/UI checks and record static, compilation, automated, and runtime results separately in specs/006-replace-mock-workflows/validation/us1-real-setup.md

**Checkpoint**: US1 works independently and the setup screen has no route that can
simulate completion.

---

## Phase 4: User Story 2 - Prepare and Send Real Books (Priority: P1) 🎯 Minimum Usable Product

**Goal**: A configured user can add real EPUB/PDF files, receive genuine local
readiness, confirm an immutable batch, and obtain observed independent SMTP
outcomes.

**Independent Test**: Add one valid EPUB and one valid PDF through both intake
paths, verify genuine preparation and unchanged originals, confirm the displayed
destination/counts, and complete two controlled independent SMTP attempts without
placeholder messages.

### Test Fixtures for User Story 2

- [X] T034 [US2] Implement all valid EPUB 2/3, PDF, malformed, repairable, ambiguous, malicious, certificate, reply, and SMTP transcript families required by contracts/intake-and-preparation.md and contracts/batch-and-smtp-delivery.md in BookSenderTests/Support/FixtureFactory.swift and BookSenderTests/Fixtures/fixture-manifest.json

### Tests for User Story 2

- [X] T035 [P] [US2] Add ordered outcomes, shared intake, security-scope balance, duplicate, changed-file, unsupported, size, capacity, snapshot, and staged-digest tests in BookSenderTests/Application/BookIntakeServiceTests.swift
- [X] T036 [P] [US2] Add PDF signature, attachment limit, immutable snapshot, digest, malformed PDF, and no-conversion tests in BookSenderTests/Application/PDFEligibilityServiceTests.swift
- [X] T037 [P] [US2] Add archive open-state reset, paths, directories, normalization collisions, links, encryption, compression, sizes, ratios, counts, timeout, cancellation, and mimetype-order tests in BookSenderTests/Adapters/EPUBArchiveAdapterTests.swift
- [X] T038 [P] [US2] Expand namespace, nested projection, DTD/entity, remote reference, depth, elements, attributes, total text, time, and cancellation tests in BookSenderTests/Adapters/BoundedXMLParserTests.swift
- [X] T039 [P] [US2] Add fixture-backed tests for every shipped finding code, repairability, severity, `needs_review` serialization, and health derivation in BookSenderTests/Domain/EPUBAuditEngineTests.swift
- [X] T040 [P] [US2] Add positive, ambiguous-negative, precondition, postcondition, and ordering tests for every executable repair action in BookSenderTests/Domain/EPUBRepairEngineTests.swift
- [X] T041 [P] [US2] Add bounded entry streaming, first uncompressed mimetype, plan-only mutation, resource preservation, write cancellation, and partial cleanup tests in BookSenderTests/Adapters/EPUBArchiveWriterTests.swift
- [X] T042 [P] [US2] Add reopen, before/after comparison, regression rejection, promoted digest, partial removal, and byte-for-byte original preservation tests in BookSenderTests/Integration/EPUBPreparationJourneyTests.swift
- [X] T043 [P] [US2] Expand CR/LF injection, RFC filename encoding, base64 boundaries, line endings, attachment streaming, and message-size tests in BookSenderTests/Adapters/MIMEMessageEncoderTests.swift
- [X] T044 [P] [US2] Add bounded reply parsing, implicit TLS, STARTTLS upgrade, second EHLO, TLS verification, AUTH PLAIN/LOGIN, envelope, DATA, and final `250` transcript tests in BookSenderTests/Adapters/SMTPStateMachineTests.swift
- [X] T045 [P] [US2] Add missing STARTTLS, certificate, hostname, TLS-version, authentication, timeout, provider rejection, channel-loss, DATA-boundary, and sanitized-error tests in BookSenderTests/Adapters/SMTPDeliveryUncertaintyTests.swift
- [X] T046 [P] [US2] Add one-active-stage, ordered preparation, value snapshot, independent attempts, setup revision, exact outcome count, and complete event projection tests in BookSenderTests/Application/FirstBookJourneyTests.swift
- [X] T047 [P] [US2] Add real fixture intake, concise states, disabled/enabled send, immutable confirmation counts, controlled outcomes, keyboard, and accessibility scenarios in BookSenderUITests/BatchSendUITests.swift

### Implementation for User Story 2

- [X] T048 [US2] Return one accepted/excluded/cancelled outcome per selected URL, enforce batch/file limits, fingerprint staged bytes, and surface safe failures in BookSender/Application/Intake/BookIntakeService.swift
- [X] T049 [P] [US2] Implement bounded PDF signature, staged stability, attachment limit, digest, and immutable prepared-book eligibility in BookSender/Application/Intake/PDFEligibilityService.swift
- [X] T050 [P] [US2] Complete per-open preflight state, directory/path handling, collisions, links, encryption, compression, aggregate bounds, cancellation, and timeout in BookSender/Adapters/Archive/ZIPFoundationEPUBArchive.swift
- [X] T051 [P] [US2] Preserve nested XML projection and enforce external-resource, structure, total-text, cancellation, and timeout boundaries in BookSender/Adapters/XML/BoundedXMLParser.swift
- [X] T052 [US2] Implement every fixture-backed mimetype, container, package, manifest, media type, reference, encryption, active-content, and remote-reference audit rule in BookSender/Domain/Audit/EPUBAuditEngine.swift
- [X] T053 [US2] Execute only planned repair actions with bounded per-entry streaming, required ordering, safe path handling, and universal partial cleanup in BookSender/Adapters/Archive/EPUBArchiveWriter.swift
- [X] T054 [US2] Produce complete preparation evidence, always write/reopen/revalidate EPUB copies, verify action postconditions, compare reports, compute digests, and promote only ready output in BookSender/Domain/Repair/EPUBRepairEngine.swift
- [X] T055 [P] [US2] Implement bounded SMTP reply decoding and explicit command/state transitions in BookSender/Adapters/SMTP/SMTPReplyDecoder.swift and BookSender/Adapters/SMTP/SMTPStateMachine.swift
- [X] T056 [US2] Implement one-connection-per-book implicit TLS, STARTTLS, second EHLO, TLS-only authentication, timeouts, DATA tracking, and sanitized outcomes in BookSender/Adapters/SMTP/NIOSMTPClient.swift
- [X] T057 [P] [US2] Complete standards-compliant filename encoding, bounded MIME/base64 streaming, and SMTP dot-stuffing integration in BookSender/Adapters/SMTP/MIMEMessageEncoder.swift
- [X] T058 [US2] Read credentials transiently after confirmation, create independent attempts, publish stages, and discard secrets in BookSender/Application/Delivery/BookDeliveryService.swift
- [X] T059 [US2] Orchestrate sequential intake/preparation, freeze value-based confirmations, invoke independent delivery, and guarantee an outcome for every confirmed item in BookSender/Application/Pipeline/PipelineActor.swift
- [X] T060 [US2] Project every actor snapshot/event, derive honest counts and command availability, and remove the SMTP-unavailable placeholder in BookSender/App/AppModel.swift
- [X] T061 [P] [US2] Bind confirmation to the actor-frozen destination, eligible items, excluded items, and explicit consent in BookSender/Features/SendBook/BatchConfirmationView.swift
- [X] T062 [US2] Connect shared Finder/drop intake, real confirmation, aggregate progress, and actor-derived send state without invented percentages in BookSender/Features/SendBook/SendBookView.swift
- [X] T063 [P] [US2] Present real row states and collapsed findings/applied actions for actionable detail in BookSender/Features/SendBook/BatchItemRow.swift and BookSender/Features/SendBook/ItemDetailDisclosure.swift
- [X] T064 [US2] Compose production intake, preparation, workspace, credential, delivery, and pipeline services once at launch in BookSender/App/AppDependencies.swift and BookSender/App/BookSenderApp.swift
- [X] T065 [US2] Extend isolated UI-test composition with deterministic fixture URLs and controlled SMTP outcomes in BookSender/App/AppDependencies.swift and BookSenderUITests/BatchSendUITests.swift
- [ ] T066 [US2] Execute the authorized focused preparation/SMTP/integration/UI checks and record static, compilation, fixture, controlled-runtime, and original-digest evidence in specs/006-replace-mock-workflows/validation/us2-real-send.md

**Checkpoint**: US1 and US2 form the minimum usable Book Sender: no mock state,
real local readiness, explicit confirmation, and controlled real protocol
outcomes.

---

## Phase 5: User Story 3 - Recover a Mixed Batch (Priority: P2)

**Goal**: A mixed batch isolates failures, cancels cooperatively, preserves
completed work, and retries only definitive failures.

**Independent Test**: Process eligible, repairable, unsafe, unsupported,
duplicate, failed, and uncertain items; cancel before and after SMTP DATA; then
confirm that completed outcomes remain and `Retry Failed` excludes uncertain
delivery.

### Tests for User Story 3

- [X] T067 [P] [US3] Add cancellation between stages, pending-item cancellation, completed-result preservation, phase guards, and no-silent-skip tests in BookSenderTests/Application/PipelineCancellationTests.swift
- [X] T068 [P] [US3] Add intake/archive/XML/write/workspace cancellation, timeout, stream interruption, partial cleanup, and orphan safety tests in BookSenderTests/Adapters/AdapterCancellationTests.swift
- [X] T069 [P] [US3] Add active-channel cancellation before DATA, after DATA, after final acceptance, and repeated-cancel idempotency tests in BookSenderTests/Adapters/SMTPActiveCancellationTests.swift
- [X] T070 [P] [US3] Add failed-only snapshot, no automatic retry, excluded unknown/cancelled/submitted items, ordering, and new-attempt identity tests in BookSenderTests/Application/BatchRetryTests.swift
- [X] T071 [P] [US3] Extend byte-for-byte preservation coverage across success, repair, exclusion, failure, cancellation, retry, and delivery unknown in BookSenderTests/Integration/OriginalPreservationTests.swift
- [X] T072 [P] [US3] Add mixed-batch detail, cancel availability, completed preservation, failed-only retry, unknown guidance, focus, keyboard, and accessibility scenarios in BookSenderUITests/RecoveryJourneyUITests.swift

### Implementation for User Story 3

- [X] T073 [US3] Retain and cancel active preparation/delivery tasks, stop pending scheduling, preserve completed items, and finish every confirmed item visibly in BookSender/Application/Pipeline/PipelineActor.swift
- [X] T074 [P] [US3] Add cooperative cancellation and timeout checks plus safe partial cleanup to BookSender/Application/Intake/BookIntakeService.swift and BookSender/Adapters/Archive/ZIPFoundationEPUBArchive.swift and BookSender/Adapters/Archive/EPUBArchiveWriter.swift and BookSender/Adapters/XML/BoundedXMLParser.swift and BookSender/Adapters/Filesystem/WorkspaceStore.swift
- [X] T075 [P] [US3] Close the active channel cooperatively and map pre-DATA versus post-DATA cancellation/loss to `Cancelled` or `Delivery Unknown` in BookSender/Adapters/SMTP/NIOSMTPClient.swift
- [X] T076 [US3] Implement phase-guarded remove/clear and fresh failed-only retry snapshots with no unknown retry in BookSender/Application/Pipeline/BatchCommandService.swift
- [X] T077 [US3] Expose cancel, failed-only retry, remove, clear, and sanitized recovery commands from actor-derived state in BookSender/App/AppModel.swift
- [X] T078 [US3] Add phase-correct cancel, retry, remove, and clear controls with honest aggregate state in BookSender/Features/SendBook/SendBookView.swift
- [X] T079 [P] [US3] Present applied restoration, blocked evidence, definitive failure, and delivery-unknown guidance without raw errors in BookSender/Features/SendBook/ItemDetailDisclosure.swift
- [ ] T080 [US3] Execute the authorized mixed-batch/cancellation/retry checks and record static, automated, controlled-runtime, cleanup, and original-digest evidence in specs/006-replace-mock-workflows/validation/us3-recovery.md

**Checkpoint**: US3 is independently recoverable without automatic or ambiguous
retry.

---

## Phase 6: User Story 4 - Edit Settings and Use the Shortcut (Priority: P3)

**Goal**: A returning user can edit setup safely and configure a real shortcut
that restores the one correct primary window without changing active work.

**Independent Test**: Edit non-secret setup without replacing the credential,
configure/disable/conflict the shortcut, close the main window, and verify an
accepted shortcut restores the correct setup-derived route and intact batch.

### Tests for User Story 4

- [X] T081 [P] [US4] Add idle-batch preservation, blank-password reuse, replacement revision, active-send save guard, and Settings error tests in BookSenderTests/Application/SettingsDeliveryTests.swift
- [X] T082 [P] [US4] Add register, change, disable, restore, conflict, repeated invocation, and no-delivery tests in BookSenderTests/Application/ShortcutServiceTests.swift
- [X] T083 [P] [US4] Add captured-window reuse, absent-window reopen request, Settings-window exclusion, activation, and duplicate prevention tests in BookSenderTests/Application/WindowCoordinatorTests.swift
- [X] T084 [P] [US4] Add Delivery/Shortcut-only tabs, preserved batch, recorder state, conflict feedback, close/reopen, correct route, keyboard, and accessibility scenarios in BookSenderUITests/SettingsUITests.swift and BookSenderUITests/GlobalShortcutUITests.swift

### Implementation for User Story 4

- [X] T085 [US4] Publish enabled, disabled, registered, and sanitized conflict state while retaining the existing configurable shortcut in BookSender/Application/Shortcut/ShortcutService.swift
- [X] T086 [P] [US4] Reuse only the captured main window or request deterministic main-window reopening without falling back to an arbitrary Settings window in BookSender/App/WindowCoordinator.swift
- [X] T087 [US4] Register one main-window reopen action, remove duplicate-window paths, and keep Settings auxiliary in BookSender/App/BookSenderApp.swift
- [X] T088 [US4] Reconcile shortcut routing from validated setup, preserve batch/operation state, and block shortcut-triggered confirmation or delivery in BookSender/App/AppModel.swift
- [X] T089 [P] [US4] Reuse transactional delivery validation, preserve blank credentials, and disable save during confirmed delivery in BookSender/Features/Settings/BookSenderSettingsView.swift and BookSender/Features/DeliverySetup/DeliverySetupView.swift
- [X] T090 [P] [US4] Bind recorder, enable switch, and inline registered/disabled/conflict feedback to `ShortcutPreference` in BookSender/Features/Settings/ShortcutSettingsView.swift
- [X] T091 [US4] Extend isolated UI-test composition for main-window close/reopen and shortcut conflict scenarios in BookSender/App/AppDependencies.swift and BookSenderUITests/GlobalShortcutUITests.swift
- [ ] T092 [US4] Execute the authorized Settings/shortcut/window checks and record static, automated, runtime, keyboard, accessibility, and responsiveness evidence in specs/006-replace-mock-workflows/validation/us4-settings-shortcut.md

**Checkpoint**: All four stories are independently functional within the
two-screen product and auxiliary two-tab Settings contract.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Prove the complete lightweight product, privacy boundary, and
distribution claims without conflating validation layers.

- [X] T093 [P] Add launch, first interaction, shortcut focus, UI hitch, preparation responsiveness, and cancellation-latency metrics in BookSenderTests/Performance/BookSenderPerformanceTests.swift
- [X] T094 [P] Add full keyboard, VoiceOver label/order, focus restoration, state-not-by-color, Reduce Transparency, and Increase Contrast coverage in BookSenderUITests/AccessibilityUITests.swift
- [X] T095 [P] Add credential, preferences, path, filename, payload, logs, analytics, telemetry, and hidden-egress privacy assertions in BookSenderTests/Privacy/PrivacyAuditTests.swift
- [X] T096 [P] Add mixed 20-item capacity, centralized hard-limit, one-active-stage, failure-isolation, memory-bound, and exact-outcome performance coverage in BookSenderTests/Performance/BatchCapacityTests.swift
- [X] T097 Record a zero-result production scan for preview/demo state, placeholder outcomes, stale identifiers, unconsumed UI-test paths, and forbidden runtimes in specs/006-replace-mock-workflows/validation/mock-and-forbidden-absence.md
- [ ] T098 [P] Reconcile actual linked products, exact resolved versions, binary contents, licenses, third-party notices, and sandbox entitlements in BookSender/Resources/THIRD_PARTY_NOTICES.md and specs/006-replace-mock-workflows/validation/dependency-review.md
- [X] T099 Update README.md and docs/deployment.md to claim real delivery only after the corresponding controlled and authenticated gates pass, while preserving ad-hoc/non-notarized disclosure
- [X] T100 Require the approved unit/UI suite before release publication and remove experimental SMTP release notes only after readiness evidence in .github/workflows/release.yml
- [X] T101 [P] Add installer identity, appcast fields, EdDSA, ZIP contents, endpoint, and no-preview/no-fixture packaging contract checks in scripts/tests/install_contract_test.sh and scripts/tests/appcast_contract_test.py
- [X] T102 Execute the static commands from specs/006-replace-mock-workflows/quickstart.md and record diff, JSON/plist/project, dependency, mock-absence, and forbidden-reference results in specs/006-replace-mock-workflows/validation/static-gate.md
- [ ] T103 Execute explicitly authorized Swift 6 compilation and complete unit/integration suites and record commands, toolchain, counts, failures, and boundaries in specs/006-replace-mock-workflows/validation/build-and-tests.md
- [ ] T104 Execute explicitly authorized UI, accessibility, performance, mixed-batch, cleanup, and original-preservation runtime acceptance and record evidence in specs/006-replace-mock-workflows/validation/runtime-acceptance.md
- [ ] T105 Execute separately authorized controlled and real-provider implicit TLS/STARTTLS delivery without secrets or raw personal transcripts and record redacted outcomes in specs/006-replace-mock-workflows/validation/smtp-acceptance.md
- [X] T106 Re-run the post-implementation constitution check and separate code, compilation, tests, runtime, authenticated delivery, signing, Sparkle update, clean-account installation, and public-release readiness in specs/006-replace-mock-workflows/validation/release-readiness.md

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 — Setup**: Starts first and preserves the current dirty worktree.
- **Phase 2 — Foundational**: Depends on Phase 1 and blocks every user-story
  integration.
- **US1 — Real Delivery Setup**: Depends on Phase 2 and removes the only setup
  bypass.
- **US2 — Real Prepare and Send**: Depends on US1 because explicit delivery
  requires complete protected setup.
- **US3 — Mixed-Batch Recovery**: Depends on US2's real preparation and SMTP DATA
  boundaries.
- **US4 — Settings and Shortcut**: Depends on US1. Its shortcut/window work may
  proceed alongside later US2/US3 adapter work, but final integration must use
  the authoritative actor state.
- **Phase 7 — Polish**: Depends on all selected stories.

### User Story Dependency Graph

```text
Phase 1 Setup
    -> Phase 2 Foundation
        -> US1 Real Setup
            -> US2 Real Prepare and Send
                -> US3 Mixed-Batch Recovery
            -> US4 Settings and Shortcut
        -> Phase 7 Polish after US2 + US3 + US4
```

### Within Each User Story

- Fixture/test-support tasks precede focused tests.
- Focused tests precede the production rule or transition they accept.
- Models and ports precede adapters and application services.
- Adapters precede actor orchestration.
- Actor behavior precedes `AppModel` projection.
- `AppModel` projection precedes SwiftUI integration.
- Automated evidence precedes manual, provider, and release claims.

## Parallel Opportunities

### Setup and Foundation

- T002, T004, T005, and T006 can proceed in parallel after T001.
- T007, T008, T009, and T010 touch separate model files.
- T013, T014, and T015 can proceed in parallel after their models/support exist.

### User Story 1

```text
After Phase 2:
  T020 + T021 + T022 + T023 + T024 + T025
  T026 + T027
  T028 -> T029 -> T030 -> T031 -> T032 -> T033
```

### User Story 2

```text
T034 first, then:
  Intake/PDF tests:     T035 + T036
  EPUB tests:           T037 + T038 + T039 + T040 + T041 + T042
  SMTP tests:           T043 + T044 + T045
  Pipeline/UI tests:    T046 + T047

Implementation lanes:
  Intake:               T048 -> T049
  EPUB:                 T050 + T051 -> T052 -> T053 -> T054
  SMTP:                 T055 + T057 -> T056 -> T058
  Integration:          T059 -> T060 -> T061 + T063 -> T062 -> T064 -> T065 -> T066
```

### User Story 3

```text
Tests:                  T067 + T068 + T069 + T070 + T071 + T072
Adapters/actor:         T073 + T074 + T075
Commands/UI:            T076 -> T077 -> T078 + T079 -> T080
```

### User Story 4

```text
Tests:                  T081 + T082 + T083 + T084
Services:               T085 + T086
Integration:            T087 -> T088 -> T089 + T090 -> T091 -> T092
```

## Implementation Strategy

### First Deliverable: US1

1. Complete Setup and Foundation.
2. Make setup transactional and credential-aware.
3. Remove preview source, UI, identifiers, and tests.
4. Prove the first-launch and relaunch route independently.

US1 is a safe independently testable checkpoint, but it does not yet deliver the
product's core sending value.

### Minimum Usable Product: US1 + US2

1. Add real typed intake and immutable PDF readiness.
2. Complete fixture-backed EPUB preparation and revalidation.
3. Implement the explicit TLS SMTP state machine.
4. Freeze confirmation and project real outcomes into `Send Book`.
5. Pass controlled preparation, SMTP, original-preservation, and UI gates.

Do not release a "real delivery" claim until both P1 stories and their controlled
and authenticated acceptance gates pass.

### Incremental Completion

1. Add US3 cancellation and failed-only recovery.
2. Add US4 Settings/shortcut conflict and one-window behavior.
3. Complete cross-cutting accessibility, performance, privacy, packaging, update,
   and release gates.

## Notes

- Preserve unrelated Swift and untracked changes until task ownership is
  established by T001.
- Do not stage, commit, branch, discard, or rewrite unrelated work unless the
  user explicitly requests it.
- T103, T104, and T105 require explicit authorization because they build, test,
  launch, or perform external SMTP behavior.
- Static checks, compilation, automated tests, controlled runtime, authenticated
  delivery, signing, update installation, and public release are separate claims.
- No task may add a third primary screen, conversion, DRM removal, an external
  ebook engine, helper process, executable download, persistent queue, history,
  account, cloud, AI, browser automation, or a preview fallback.
