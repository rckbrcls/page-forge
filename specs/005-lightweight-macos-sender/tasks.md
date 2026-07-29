# Tasks: Lightweight macOS Book Sender

**Input**: Design documents from `/specs/005-lightweight-macos-sender/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`,
`contracts/`, and `quickstart.md`

**Tests**: Required by the specification and constitution. Every EPUB audit,
automatic cleanup/restoration, archive/XML safety boundary, batch transition,
credential boundary, SMTP state, and delivery-uncertainty rule must have focused
evidence before it is accepted.

**Organization**: Shared native foundations come first. User-story phases then
produce independently testable increments. Legacy deletion is a final gated
cutover, never a prerequisite for porting behavior or fixtures.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: May run in parallel because it touches independent files and has no
  incomplete dependency.
- **[Story]**: Maps work to `US1`, `US2`, `US3`, or `US4`.
- Every task names the primary file or directory it changes.

## Phase 1: Setup — Native Project and Migration Boundary

**Purpose**: Establish the clean native product beside the current behavioral
references without deleting or rewriting unrelated worktree changes.

- [X] T001 Record the current TypeScript rules, fixtures, Swift reusable patterns, release inputs, and unrelated dirty-tree exclusions in specs/005-lightweight-macos-sender/migration-baseline.md
- [X] T002 Create BookSender.xcodeproj with BookSender, BookSenderTests, and BookSenderUITests targets while leaving PageForge.xcodeproj intact
- [X] T003 Configure macOS 14.0, Swift 6 language mode, complete concurrency checking, Book Sender product naming, and com.rckbrcls.BookSender identity in BookSender.xcodeproj/project.pbxproj
- [X] T004 Add exact compatible KeyboardShortcuts, ZIPFoundation, swift-nio, and swift-nio-ssl source-package requirements and test product links in BookSender.xcodeproj/project.pbxproj
- [X] T005 [P] Add user-selected read-only and outgoing-network sandbox entitlements in BookSender/BookSender.entitlements
- [X] T006 [P] Create the final App, Features, Application, Domain, Adapters, Resources, unit-test, UI-test, and fixture directory groups in BookSender.xcodeproj/project.pbxproj
- [ ] T007 [P] Port only the approved semantic colors and app icon inputs into BookSender/Resources/Assets.xcassets and record asset provenance in BookSender/Resources/ASSET_NOTICES.md
- [X] T008 Add deterministic fixture resource-copy configuration for BookSenderTests/Fixtures in BookSender.xcodeproj/project.pbxproj

**Checkpoint**: A clean native project skeleton exists beside the legacy
references; nothing obsolete has been deleted.

---

## Phase 2: Foundational — Typed Local Pipeline

**Purpose**: Build the domain, safety, and adapter boundaries that every user
story depends on.

**Critical**: No user-story UI integration begins until this phase is complete.

- [X] T009 [P] Define DeliverySetup, DeliverySetupDraft, EmailAddress, SMTPHost, SecurityMode, CredentialReference, and validation error models in BookSender/Domain/Models/DeliveryModels.swift
- [X] T010 [P] Define CurrentBatch, BatchItem, BookFormat, SourceIdentity, ConfirmedBatchSnapshot, preparation states, and delivery states in BookSender/Domain/Models/BatchModels.swift
- [X] T011 [P] Define HealthFinding, FindingSeverity, Repairability, BookHealth, AuditReport, and stable finding codes in BookSender/Domain/Models/AuditModels.swift
- [X] T012 [P] Define PreparationPlan, RepairAction, AppliedRepairAction, PreparedBook, and RevalidationComparison in BookSender/Domain/Models/RepairModels.swift
- [X] T013 [P] Define PipelineEvent, DeliveryAttempt, delivery stages, terminal outcomes, and sanitized failure families in BookSender/Domain/Models/PipelineModels.swift
- [X] T014 Centralize archive, XML, PDF, batch, SMTP line, attachment, time, and memory bounds in BookSender/Domain/Models/SafetyLimits.swift
- [X] T015 [P] Define cancellation-aware archive, XML, filesystem, credential, preference, and SMTP protocols in BookSender/Domain/Ports/AdapterProtocols.swift
- [X] T016 [P] Define audit rule, repair planner, repair writer, report comparison, and readiness protocols in BookSender/Domain/Ports/PipelineProtocols.swift
- [ ] T017 [P] Translate valid EPUB 2/3, PDF, malformed container, package, mimetype, content, and repair fixtures from tests/fixtures into BookSenderTests/Fixtures/Books
- [ ] T018 [P] Translate traversal, absolute-path, duplicate, symlink, encrypted, ZIP-bomb, external-entity, deep-XML, and remote-reference fixtures from tests/fixtures into BookSenderTests/Fixtures/Malicious
- [ ] T019 [P] Add fixture manifest with source mapping, expected finding codes, expected repair actions, and original digests in BookSenderTests/Fixtures/fixture-manifest.json
- [X] T020 Add safety-limit boundary tests for limit minus one, exact limit, and limit plus one in BookSenderTests/Domain/SafetyLimitsTests.swift
- [ ] T021 Add original-preservation, UUID-path, partial-promotion, marker-bounded cleanup, and orphan-sweep tests in BookSenderTests/Adapters/WorkspaceStoreTests.swift
- [X] T022 Implement security-scoped streaming snapshots, UUID workspaces, partial promotion, and safe cleanup in BookSender/Adapters/Filesystem/WorkspaceStore.swift
- [ ] T023 Add archive preflight tests for paths, duplicates, links, methods, counts, sizes, ratios, cancellation, and EPUB mimetype ordering in BookSenderTests/Adapters/EPUBArchiveAdapterTests.swift
- [ ] T024 Implement bounded ZIPFoundation central-directory preflight and chunked entry reads in BookSender/Adapters/Archive/ZIPFoundationEPUBArchive.swift
- [ ] T025 Implement collision-safe streaming EPUB writing with first uncompressed mimetype and partial output in BookSender/Adapters/Archive/EPUBArchiveWriter.swift
- [ ] T026 Add XML parser tests for namespaces, DTD/entities, remote references, depth, elements, attributes, text, time, and cancellation in BookSenderTests/Adapters/BoundedXMLParserTests.swift
- [ ] T027 Implement bounded namespace-aware XMLParser handling with external resolution disabled in BookSender/Adapters/XML/BoundedXMLParser.swift
- [ ] T028 Add fixture-backed audit tests for every stable finding code and health derivation in BookSenderTests/Domain/EPUBAuditEngineTests.swift
- [ ] T029 Implement OCF container, package, manifest, reference, encryption, and media-type audit rules in BookSender/Domain/Audit/EPUBAuditEngine.swift
- [ ] T030 Add fixture-backed tests for every deterministic action, ambiguous non-action, write, reopen, comparison, and regression in BookSenderTests/Domain/EPUBRepairEngineTests.swift
- [ ] T031 Implement deterministic repair planning, EPUB writing, post-write audit comparison, and readiness decisions in BookSender/Domain/Repair/EPUBRepairEngine.swift
- [ ] T032 Implement the actor-owned sequential stage runner and minimal AsyncStream events in BookSender/Application/Pipeline/PipelineActor.swift

**Checkpoint**: The complete EPUB/PDF preparation foundation is testable without
SwiftUI, credentials, or real network access.

---

## Phase 3: User Story 1 — Set Up and Send the First Book (Priority: P1) MVP

**Goal**: A first-time user can save valid SMTP settings securely, select a
supported book, wait for background readiness, explicitly confirm, and receive
one independent delivery result using only the two primary screens.

**Independent Test**: Start without preferences, complete `Delivery Setup`, add
one healthy EPUB or PDF in `Send Book`, confirm the destination, exercise a
controlled accepted SMTP response, and verify the correct result with no third
screen or exposed credential.

### Tests for User Story 1

- [ ] T033 [P] [US1] Add field normalization, invalid setup, setup revision, and secret-redaction tests in BookSenderTests/Domain/DeliverySetupTests.swift
- [ ] T034 [P] [US1] Add Data Protection Keychain create, read, update, delete, local-only, and sanitized-error tests in BookSenderTests/Adapters/KeychainCredentialStoreTests.swift
- [ ] T035 [P] [US1] Add non-secret persistence tests proving credentials and batch data never enter preferences in BookSenderTests/Adapters/DeliveryPreferencesStoreTests.swift
- [ ] T036 [P] [US1] Add implicit TLS, STARTTLS upgrade, second EHLO, TLS verification, authentication, multiline reply, timeout, and rejection tests in BookSenderTests/Adapters/SMTPStateMachineTests.swift
- [ ] T037 [P] [US1] Add MIME header-injection, encoded-filename, base64 boundary, line-ending, dot-stuffing, and streaming tests in BookSenderTests/Adapters/MIMEMessageEncoderTests.swift
- [ ] T038 [P] [US1] Add first-book pipeline integration tests for EPUB preparation, unchanged PDF snapshot, explicit confirmation, independent attempt, and submitted result in BookSenderTests/Application/FirstBookJourneyTests.swift
- [ ] T039 [P] [US1] Add first-launch routing, setup validation, keyboard access, credential masking, confirmation, and two-screen UI tests in BookSenderUITests/FirstBookJourneyUITests.swift

### Implementation for User Story 1

- [X] T040 [P] [US1] Implement field-level setup validation and immutable validated setup creation in BookSender/Domain/Delivery/DeliverySetupValidator.swift
- [X] T041 [P] [US1] Implement Data Protection Keychain CRUD outside the main actor in BookSender/Adapters/Credentials/KeychainCredentialStore.swift
- [X] T042 [P] [US1] Implement non-secret setup revisions and local preference persistence in BookSender/Adapters/Credentials/DeliveryPreferencesStore.swift
- [X] T043 [US1] Implement atomic save orchestration across validated preferences and Keychain credentials in BookSender/Application/Delivery/DeliverySetupService.swift
- [X] T044 [P] [US1] Implement streaming sanitized MIME attachment generation in BookSender/Adapters/SMTP/MIMEMessageEncoder.swift
- [ ] T045 [US1] Implement the SwiftNIO/NIOSSL SMTP state machine for implicit TLS, STARTTLS, TLS-only AUTH, DATA, timeouts, and sanitized failures in BookSender/Adapters/SMTP/NIOSMTPClient.swift
- [ ] T046 [US1] Implement one independent confirmed SMTP attempt per prepared book in BookSender/Application/Delivery/BookDeliveryService.swift
- [X] T047 [P] [US1] Implement the minimal accessible reusable SMTP form in BookSender/Features/DeliverySetup/DeliverySetupView.swift
- [X] T048 [P] [US1] Implement the minimal drop/picker area, one-item readiness row, explicit confirmation, and terminal result presentation in BookSender/Features/SendBook/SendBookView.swift
- [ ] T049 [US1] Implement @MainActor @Observable setup routing, pipeline event projection, and sanitized UI state in BookSender/App/AppModel.swift
- [X] T050 [US1] Compose the single WindowGroup root with only DeliverySetupView and SendBookView as primary screens plus the constrained native Settings scene in BookSender/App/BookSenderApp.swift

**Checkpoint**: User Story 1 is an independently functional end-to-end MVP for
one book.

---

## Phase 4: User Story 2 — Send One or More Books with Minimal Interaction (Priority: P1)

**Goal**: A returning user can drop or choose a mixed temporary batch, observe
concise per-book readiness, confirm a stable eligible snapshot, send sequentially,
and retry only failed items from `Send Book`.

**Independent Test**: Launch with valid setup, add a mixed 20-item EPUB/PDF batch
through both intake paths, verify duplicates/exclusions, confirm once, observe
stable sequential independent outcomes after an injected failure, retry only the
failed item, and clear the batch.

### Tests for User Story 2

- [ ] T051 [P] [US2] Add shared Finder/drop intake, security-scope balance, stable-copy, unsupported input, file-change, and duplicate tests in BookSenderTests/Application/BookIntakeServiceTests.swift
- [ ] T052 [P] [US2] Add stable snapshot, ordered 20-item scheduling, one-active-item, failure isolation, later additions, and no-automatic-retry tests in BookSenderTests/Application/BatchPipelineTests.swift
- [ ] T053 [P] [US2] Add batch-list, disabled send, mixed eligibility, confirmation counts, per-item results, failed-only retry, remove, clear, keyboard, and accessibility UI tests in BookSenderUITests/BatchSendUITests.swift

### Implementation for User Story 2

- [X] T054 [P] [US2] Implement source identity, type/size/readability checks, duplicate detection, and shared security-scoped staging in BookSender/Application/Intake/BookIntakeService.swift
- [X] T055 [P] [US2] Implement drag-and-drop URL normalization through BookIntakeService in BookSender/Features/SendBook/BookDropTarget.swift
- [X] T056 [P] [US2] Implement multi-selection fileImporter normalization through BookIntakeService in BookSender/Features/SendBook/BookFileImporter.swift
- [ ] T057 [US2] Extend PipelineActor with immutable confirmation snapshots, ordered iteration, failure isolation, aggregate progress, and completed-result preservation in BookSender/Application/Pipeline/PipelineActor.swift
- [ ] T058 [US2] Implement failed-only retry, individual removal, clear, and append-after-completion commands in BookSender/Application/Pipeline/BatchCommandService.swift
- [X] T059 [P] [US2] Implement compact derived-state batch rows and collapsed actionable detail in BookSender/Features/SendBook/BatchItemRow.swift
- [X] T060 [P] [US2] Implement destination, eligible-count, and excluded-count confirmation without network side effects in BookSender/Features/SendBook/BatchConfirmationView.swift
- [ ] T061 [US2] Extend SendBookView with batch list, aggregate state, cancel/retry/remove/clear actions, and no invented percentages in BookSender/Features/SendBook/SendBookView.swift
- [ ] T062 [US2] Extend AppModel with ordered batch commands and minimal per-item event projection in BookSender/App/AppModel.swift

**Checkpoint**: User Stories 1 and 2 provide the complete primary setup and batch
delivery product without shortcut-specific or advanced recovery polish.

---

## Phase 5: User Story 3 — Open the Sender with a Global Shortcut (Priority: P2)

**Goal**: A configurable system-wide shortcut reveals and focuses the existing
primary window without creating another window, clearing the batch, or sending.

**Independent Test**: Configure, change, disable, and conflict the shortcut;
close the primary window; invoke it from another application with complete and
incomplete setup; verify the same window and state return within one second.

### Tests for User Story 3

- [ ] T063 [P] [US3] Add shortcut registration, change, disable, conflict, and no-delivery behavior tests in BookSenderTests/Application/ShortcutServiceTests.swift
- [ ] T064 [P] [US3] Add closed-window restore, setup/send routing, duplicate-window prevention, batch preservation, keyboard, and accessibility UI tests in BookSenderUITests/GlobalShortcutUITests.swift

### Implementation for User Story 3

- [X] T065 [P] [US3] Define shortcut preference and registration state models in BookSender/Domain/Models/ShortcutModels.swift
- [ ] T066 [US3] Implement KeyboardShortcuts registration, conflict projection, change, and disable behavior in BookSender/Application/Shortcut/ShortcutService.swift
- [X] T067 [US3] Implement weak-window capture, NSApp activation, existing-window reuse, and state-preserving reveal in BookSender/App/WindowCoordinator.swift
- [ ] T068 [US3] Integrate the recorder, conflict explanation, and disable action into the auxiliary Settings Shortcut tab in BookSender/Features/Settings/ShortcutSettingsView.swift
- [X] T069 [US3] Remove new-window commands and route shortcut callbacks through WindowCoordinator in BookSender/App/BookSenderApp.swift

**Checkpoint**: User Story 3 adds lightweight invocation without expanding beyond
the same two screens.

---

## Phase 6: User Story 4 — Recover from Setup, Book, and Delivery Problems (Priority: P2)

**Goal**: Unsupported, unsafe, repairable, rejected, cancelled, and uncertain
items remain understandable and recoverable in context while every original and
completed result remains intact.

**Independent Test**: Exercise invalid saved setup, repairable/ambiguous/unsafe
EPUBs, provider rejection, cancellation before DATA, interruption after DATA,
and a mixed batch; verify concise actions, collapsed evidence, preserved
originals/results, and no automatic retry or third screen.

### Tests for User Story 4

- [ ] T070 [P] [US4] Add typed recovery-action and raw-error sanitization tests across every adapter family in BookSenderTests/Domain/FailurePresentationTests.swift
- [ ] T071 [P] [US4] Add cancellation-between-stages, cancellation-during-stream, partial cleanup, completed-result preservation, and pending-item cancellation tests in BookSenderTests/Application/PipelineCancellationTests.swift
- [ ] T072 [P] [US4] Add cancellation before DATA, channel loss/cancellation after DATA, final 250, definitive rejection, and no automatic unknown retry tests in BookSenderTests/Adapters/SMTPDeliveryUncertaintyTests.swift
- [ ] T073 [P] [US4] Add byte-for-byte original preservation tests for success, repair, failure, cancellation, unsafe, and delivery-unknown outcomes in BookSenderTests/Application/OriginalPreservationTests.swift
- [ ] T074 [P] [US4] Add inline failure, collapsed repair evidence, setup recovery, cancellation, unknown-delivery, focus, and accessibility UI tests in BookSenderUITests/RecoveryJourneyUITests.swift

### Implementation for User Story 4

- [ ] T075 [US4] Add cooperative cancellation checks and cancellation handlers to archive, XML, filesystem, pipeline, and SMTP streams in BookSender/Application/Pipeline/PipelineActor.swift
- [ ] T076 [US4] Implement DATA-start tracking and cancelled-versus-deliveryUnknown terminal mapping in BookSender/Adapters/SMTP/NIOSMTPClient.swift
- [X] T077 [US4] Implement stable sanitized recovery actions for setup, intake, preparation, and delivery failures in BookSender/Application/Presentation/FailurePresentationService.swift
- [X] T078 [P] [US4] Implement collapsed applied-repair and blocked-item evidence disclosure in BookSender/Features/SendBook/ItemDetailDisclosure.swift
- [ ] T079 [US4] Integrate cancellation, setup recovery, explicit failed retry, and delivery-unknown handling into SendBookView in BookSender/Features/SendBook/SendBookView.swift

**Checkpoint**: All four user stories are independently covered and the two-screen
product is functionally complete.

---

## Phase 7: Polish, Verification, and Atomic Legacy Cutover

**Purpose**: Prove the native replacement, switch every product/release reference,
then remove obsolete implementations and verify their absence.

- [ ] T080 [P] Add launch, shortcut, 20-item memory, responsiveness, and UI-hitch metrics in BookSenderTests/Performance/BookSenderPerformanceTests.swift
- [ ] T081 [P] Add a credential, path, filename, SMTP payload, analytics, and telemetry privacy audit with expected redactions in BookSenderTests/Privacy/PrivacyBoundaryTests.swift
- [ ] T082 [P] Complete keyboard order, focus visibility, VoiceOver labels, reduced motion, contrast, and two-primary-screen review in BookSenderUITests/AccessibilityAuditUITests.swift
- [ ] T083 [P] Review exact package versions, transitive products, licenses, source-only status, and absence of helpers/telemetry in BookSender/Resources/THIRD_PARTY_NOTICES.md
- [ ] T084 Run the authorized static, build, Swift Testing, XCTest, and XCUITest gates from quickstart.md and record distinct evidence in specs/005-lightweight-macos-sender/validation/native-gates.md
- [ ] T085 Run the authorized manual setup, mixed-batch, shortcut, cancellation, recovery, accessibility, and original-digest scenarios and record results in specs/005-lightweight-macos-sender/validation/manual-acceptance.md
- [X] T086 Update product scope, installation, SMTP security, batch behavior, privacy, and two-screen usage documentation in README.md, docs/desktop-migration.md, and docs/deployment.md
- [X] T087 Add the approved Book Sender ad-hoc GitHub Release workflow, exact Sparkle dependency, EdDSA appcast, GitHub Pages artifact, and reviewable installer
- [X] T088 Make BookSender.xcodeproj the sole application project and remove all old target, bundle, scheme, signing, icon, and package references from BookSender.xcodeproj/project.pbxproj
- [X] T089 Delete obsolete Raycast and Node production/tests/configuration only after T084-T088 pass: src/, tests/, package.json, package-lock.json, pnpm-lock.yaml, tsconfig.json, vitest.config.ts, eslint.config.js, .prettierrc, raycast-env.d.ts, and Raycast assets
- [X] T090 Delete obsolete PageForge native sources and tests only after behavior and fixtures are represented in BookSender: PageForge/, PageForgeTests/, and PageForge.xcodeproj/
- [X] T091 Delete historical runtime/update surfaces after cutover: legacy/, old PageForge installer/appcast inputs, Calibre/conversion/MOBI/AZW code, and subprocess EPUB code
- [X] T092 Remove generated local artifacts without touching unrelated worktree changes: node_modules/, dist/, .raycast/, coverage/, xcuserdata/, .DS_Store files, duplicate generated images, and obsolete release assets
- [ ] T093 Run final forbidden-reference, single-product, package-content, entitlement, original-preservation, and two-screen absence scans and record results in specs/005-lightweight-macos-sender/validation/final-absence-scan.md
- [ ] T094 Separately verify archive signing, sandbox entitlements, Sparkle EdDSA, clean-account installation, public artifact identity, and downloaded-app behavior in specs/005-lightweight-macos-sender/validation/distribution.md
- [X] T095 Raise every app, unit-test, UI-test, and project configuration deployment target to macOS 26.0 in BookSender.xcodeproj/project.pbxproj
- [X] T096 Implement one adaptive behind-window material across the content and titlebar areas while preserving native window controls in BookSender/App/BookSenderApp.swift
- [X] T097 Apply Liquid Glass only to the drop target and primary actions, and remove opaque Form and List backgrounds in BookSender/Features
- [X] T098 Amend the constitution to 5.0.0 and align the active specification, research, plan, quickstart, checklist, and runtime guidance with macOS 26 and adaptive-material requirements
- [X] T099 Run the permitted plist, diff, deployment-target, opaque-background, and Liquid Glass placement static checks
- [ ] T100 Run authorized build, tests, and visual acceptance across wallpapers, appearances, window activation states, Reduce Transparency, Increase Contrast, keyboard, and VoiceOver

**Final checkpoint**: The repository contains exactly one Book Sender macOS
application plus its tests, fixtures, documentation, and distribution assets.

---

## Dependencies and Execution Order

### Phase dependencies

- **Phase 1 — Setup**: Starts first and preserves all legacy references.
- **Phase 2 — Foundational**: Depends on Phase 1 and blocks every user story.
- **US1 — First Book**: Depends on Phase 2 and is the MVP.
- **US2 — Batch Sending**: Depends on the US1 delivery path and extends it to the
  complete batch contract.
- **US3 — Shortcut**: Depends on the US1 single-window root; after that point it
  can proceed in parallel with US2 or US4 when shared app files are coordinated.
- **US4 — Recovery**: Depends on US1 and the US2 batch scheduler.
- **Phase 7 — Cutover**: Verification and documentation follow all user stories.
  Deletion tasks T089-T092 additionally depend on T084-T088.

### User story dependency graph

```text
Setup -> Foundation -> US1 (MVP) -> US2 -> US4 -> Cutover
                             \-> US3 -----------/
```

### Within each story

1. Write focused contract and fixture tests.
2. Implement or extend typed domain behavior.
3. Implement adapters and application orchestration.
4. Integrate into an existing primary screen.
5. Pass the independent story test before advancing.

No automatic EPUB rule is accepted without its focused fixture. No SMTP
transition is accepted without deterministic protocol evidence. Static success
does not imply compilation, tests, runtime, ad-hoc signing, update installation,
or release.

## Parallel Execution Examples

### Setup

After T002, T005 entitlements, T007 assets, and T008 fixture resources can proceed
in parallel. T003 and T004 remain coordinated because both modify the Xcode
project.

### Foundation

T009-T013 models can proceed in parallel. T017-T019 fixture translation can
proceed beside protocol work T015-T016. After the models and limits exist,
workspace tests, archive tests, XML tests, and audit tests can be prepared in
parallel; each implementation follows its corresponding failing tests.

### User Story 1

T033-T039 are independent test files. After model contracts exist, Keychain
T041, preferences T042, MIME T044, and the two view files T047-T048 can progress
in parallel. SMTP T045 follows its tests and MIME boundary; AppModel/root
integration T049-T050 remains ordered.

### User Story 2

T051-T053 can be authored in parallel. Drop handling T055, Finder import T056,
batch rows T059, and confirmation T060 touch independent files after intake and
batch interfaces stabilize.

### User Story 3

T063-T065 can proceed in parallel. Window activation T067 and the Settings
shortcut tab T068 can proceed together after ShortcutService's interface is fixed.

### User Story 4

T070-T074 can proceed in parallel. Failure presentation T077 and detail
disclosure T078 can progress independently while the pipeline/SMTP cancellation
paths T075-T076 remain coordinated.

### Final phase

Performance T080, privacy T081, accessibility T082, license review T083, and
documentation T086 can proceed in parallel. Release cutover and deletion remain
strictly sequential and gated.

## Implementation Strategy

### MVP first

1. Complete Phases 1 and 2.
2. Complete US1 through T050.
3. Run the US1 independent test with controlled SMTP fixtures.
4. Review the two-screen boundary and credential handling before adding batch
   convenience.

This produces the smallest end-to-end native value: secure setup plus one
explicitly confirmed book send.

### Incremental delivery

1. Native shell, typed domain, safe EPUB/PDF pipeline, and fixtures.
2. Secure setup and first-book delivery.
3. Multi-book intake, stable sequential batch, and failed-only retry.
4. Global shortcut without another window or screen.
5. Recovery, cancellation, and delivery uncertainty.
6. Full verification, atomic cutover, legacy deletion, and distribution proof.

### Worktree and git discipline

- Continue on `main`; do not create a branch, stage, or commit unless Erick asks.
- Inspect current diffs before every migration or deletion task.
- Preserve unrelated `.pi`, `.pi-subagents`, TypeScript, test, and documentation
  changes until their own gated task explicitly owns them.
- Use `apply_patch` for manual edits and never use destructive cleanup against a
  broad or unresolved path.
