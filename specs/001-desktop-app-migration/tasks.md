---
description: "Task list for Desktop App Migration"
---

# Tasks: Desktop App Migration

**Input**: Design documents from `/specs/001-desktop-app-migration/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Not requested in the feature specification; no TDD task block. Domain/parity verification tasks appear only in Polish where constitution quality gates require them.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **macOS desktop**: `PageForge/App/`, `PageForge/Domain/`, `PageForge/Features/`, `PageForge/Integrations/`, `PageForgeTests/`
- **Legacy reference**: `legacy/python-tui-cli/`, `legacy/README.md`, `legacy/notes/`

## Constitution Task Expectations

- Domain rules land in `PageForge/Domain/`, not Views
- Calibre calls include missing-tool handling
- UI stays Readiness-first with progressive disclosure
- Long work stays off the main thread
- No DRM removal, OCR pipelines, Amazon login automation, or multi-platform shells

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the desktop project skeleton and archive the old terminal product

- [x] T001 Create macOS SwiftUI app scaffold directories `PageForge/App/`, `PageForge/Features/`, `PageForge/Domain/`, `PageForge/Integrations/`, `PageForge/Resources/`, and `PageForgeTests/`
- [x] T002 Initialize the Xcode macOS app target and test target for PageForge with Swift 6 / macOS 14+ settings in `PageForge.xcodeproj` (or equivalent package/workspace entrypoint)
- [x] T003 [P] Add project dependency strategy notes and Package.swift/Xcode package refs for ZIP handling if needed in `PageForge/Integrations/FileSystem/`
- [x] T004 Move current Python product tree into legacy reference paths: `src/page_forge/` → `legacy/python-tui-cli/src/page_forge/`, `tests/` → `legacy/python-tui-cli/tests/`, `pyproject.toml` → `legacy/python-tui-cli/pyproject.toml`, `install.sh` → `legacy/python-tui-cli/install.sh`
- [x] T005 [P] Write `legacy/README.md` stating reference-only status and no primary product maintenance
- [x] T006 [P] Create `legacy/notes/behavior-parity.md` mapping legacy modules to future Swift services
- [x] T007 Update root `README.md` and `AGENTS.md` to mark desktop as target primary surface and legacy Python as archived reference

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared domain, integration, shell, and job infrastructure required by all stories

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T008 Create shared enums and error types in `PageForge/Domain/Models/DomainEnums.swift` and `PageForge/Domain/Models/DomainError.swift`
- [x] T009 [P] Implement core value models (`EbookSource`, `OperationJob`, `OperationLogEntry`, `DependencyStatus`) in `PageForge/Domain/Models/CoreModels.swift`
- [x] T010 [P] Implement filename/output path helpers for `*-repaired.epub` and `*-kindle-ready.epub` in `PageForge/Domain/Services/OutputPathBuilder.swift`
- [x] T011 Implement filesystem validation helpers (exists, suffix checks, overwrite guard) in `PageForge/Integrations/FileSystem/FilePathValidator.swift`
- [x] T012 Implement Calibre process runner with argument-array invocation and stdout/stderr capture in `PageForge/Integrations/Calibre/CalibreProcessRunner.swift`
- [x] T013 Implement tool discovery and `DependencyService` in `PageForge/Integrations/Calibre/CalibreToolLocator.swift` and `PageForge/Domain/Services/DependencyService.swift`
- [x] T014 Implement `LogService` and in-memory/session log store in `PageForge/Domain/Services/LogService.swift`
- [x] T015 Implement async `OperationJob` coordinator for queue/run/succeed/fail/cancel in `PageForge/Domain/Jobs/OperationJobCoordinator.swift`
- [x] T016 Implement app state and Readiness-first navigation model in `PageForge/App/AppState.swift`
- [x] T017 Implement desktop app entrypoint and root navigation shell with destinations Readiness/Convert/Batch/Send/Metadata/Settings/Logs in `PageForge/App/PageForgeApp.swift` and `PageForge/App/RootNavigationView.swift`
- [x] T018 Implement reusable drag-and-drop + file/folder picker intake component in `PageForge/Features/Shared/FileDropIntakeView.swift`
- [x] T019 Implement shared progress/error presentation components in `PageForge/Features/Shared/OperationStatusView.swift`

**Checkpoint**: App launches to Readiness shell, can select files, can detect Calibre tools, can log operations

---

## Phase 3: User Story 1 - Drop a book and see Kindle readiness (Priority: P1) 🎯 MVP

**Goal**: User drops one ebook and gets a readiness report with status and issues, without writing output

**Independent Test**: Drop a valid EPUB and see `ready`/`needs_fixes`/`blocked`; blocked/invalid cases explain failure without crash

### Implementation for User Story 1

- [x] T020 [P] [US1] Implement `ReadinessIssue` and `ReadinessReport` models in `PageForge/Domain/Models/ReadinessModels.swift`
- [x] T021 [US1] Port EPUB structural audit logic from legacy readiness/epub rules into `PageForge/Domain/Services/ReadinessService.swift`
- [x] T022 [US1] Add ZIP/container/OPF inspection helpers in `PageForge/Domain/Services/EPUBInspection.swift`
- [x] T023 [US1] Wire readiness audit use-case through job coordinator in `PageForge/Domain/Jobs/ReadinessAuditJob.swift`
- [x] T024 [US1] Build Readiness feature view model in `PageForge/Features/Readiness/ReadinessViewModel.swift`
- [x] T025 [US1] Build Readiness screen with drop intake, audit action, status chip, and issue list in `PageForge/Features/Readiness/ReadinessView.swift`
- [x] T026 [US1] Show clear dependency recovery messaging when later actions need missing Calibre tools in `PageForge/Features/Readiness/ReadinessDependencyBanner.swift`

**Checkpoint**: P1 MVP works — diagnose-only desktop flow is demoable

---

## Phase 4: User Story 2 - Prepare a Kindle-ready file (Priority: P2)

**Goal**: Apply safe preparation and write `*-kindle-ready.epub` while keeping source intact

**Independent Test**: Prepare a fixable EPUB and confirm kindle-ready output + refreshed report; audit-only still writes nothing

### Implementation for User Story 2

- [x] T027 [P] [US2] Implement `PreparationRequest` handling and default kindle-ready path rules in `PageForge/Domain/Services/OutputPathBuilder.swift`
- [x] T028 [US2] Extend `ReadinessService` with prepare/fix flow (including MOBI legacy conversion handoff points) in `PageForge/Domain/Services/ReadinessService.swift`
- [x] T029 [US2] Implement safe structural write/repair primitives needed by prepare in `PageForge/Domain/Services/EPUBRepair.swift`
- [x] T030 [US2] Add prepare job wrapper with progress/log events in `PageForge/Domain/Jobs/ReadinessPrepareJob.swift`
- [x] T031 [US2] Add Prepare/Fix action, output path display, and blocked-prepare messaging in `PageForge/Features/Readiness/ReadinessView.swift` and `PageForge/Features/Readiness/ReadinessViewModel.swift`
- [x] T032 [US2] Ensure audit-only path never writes files via guards in `PageForge/Domain/Services/ReadinessService.swift`

**Checkpoint**: diagnose → prepare works for single book

---

## Phase 5: User Story 3 - Convert and repair individual books (Priority: P3)

**Goal**: Convert MOBI/PDF/EPUB and repair EPUBs with safe default + explicit aggressive mode

**Independent Test**: Convert one MOBI/PDF to EPUB, safe-repair one EPUB, confirm outputs and messages

### Implementation for User Story 3

- [x] T033 [P] [US3] Implement conversion models/results in `PageForge/Domain/Models/ConversionModels.swift`
- [x] T034 [US3] Implement `ConversionService` (MOBI→EPUB, PDF→EPUB, EPUB→MOBI) in `PageForge/Domain/Services/ConversionService.swift`
- [x] T035 [US3] Implement `RepairService` with safe default and explicit aggressive mode in `PageForge/Domain/Services/RepairService.swift`
- [x] T036 [US3] Implement conversion/repair jobs in `PageForge/Domain/Jobs/ConversionJob.swift` and `PageForge/Domain/Jobs/RepairJob.swift`
- [x] T037 [US3] Build Convert view model in `PageForge/Features/Convert/ConvertViewModel.swift`
- [x] T038 [US3] Build Convert screen with operation picker, safe repair default, aggressive confirmation, and output status in `PageForge/Features/Convert/ConvertView.swift`
- [x] T039 [US3] Add PDF-no-OCR copy/disclaimer in `PageForge/Features/Convert/ConvertView.swift`

**Checkpoint**: single-book convert/repair surface works independently

---

## Phase 6: User Story 4 - Send to Kindle or hand off (Priority: P4)

**Goal**: SMTP send through local profiles + explicit Amazon handoff, secrets in Keychain

**Independent Test**: Configured profile can send or fail actionably; handoff opens without Amazon automation

### Implementation for User Story 4

- [x] T040 [P] [US4] Implement `DeliveryProfile`, `AppConfig`, and `SendResult` models in `PageForge/Domain/Models/ConfigModels.swift`
- [x] T041 [US4] Implement config load/save in Application Support via `PageForge/Integrations/FileSystem/ConfigStore.swift` and `PageForge/Domain/Services/ConfigService.swift`
- [x] T042 [US4] Implement Keychain secret service in `PageForge/Integrations/Keychain/KeychainSecretStore.swift` and `PageForge/Domain/Services/SecretService.swift`
- [x] T043 [US4] Implement SMTP send integration in `PageForge/Integrations/Mail/SMTPClient.swift`
- [x] T044 [US4] Implement `DeliveryService` (send + handoff open) in `PageForge/Domain/Services/DeliveryService.swift`
- [x] T045 [US4] Build Send view model in `PageForge/Features/Send/SendViewModel.swift`
- [x] T046 [US4] Build Send screen with profile selection, send action, handoff action, and incomplete-profile guidance in `PageForge/Features/Send/SendView.swift`
- [x] T047 [US4] Add deep-link/handoff from ready readiness output into Send surface in `PageForge/Features/Readiness/ReadinessViewModel.swift`

**Checkpoint**: delivery paths work without leaking secrets into config

---

## Phase 7: User Story 5 - Process a folder in batch (Priority: P5)

**Goal**: Folder batch readiness/repair/convert with progress and summary counts

**Independent Test**: Run one batch on mixed folder; get per-item outcomes and totals; UI stays usable

### Implementation for User Story 5

- [x] T048 [P] [US5] Implement batch result models and readiness count helpers in `PageForge/Domain/Models/BatchModels.swift`
- [x] T049 [US5] Implement folder enumeration and skip rules in `PageForge/Integrations/FileSystem/FolderEnumerator.swift`
- [x] T050 [US5] Extend readiness/conversion/repair services with folder batch APIs in `PageForge/Domain/Services/ReadinessService.swift`, `PageForge/Domain/Services/ConversionService.swift`, and `PageForge/Domain/Services/RepairService.swift`
- [x] T051 [US5] Implement batch job runner with progress events in `PageForge/Domain/Jobs/BatchJob.swift`
- [x] T052 [US5] Build Batch view model in `PageForge/Features/Batch/BatchViewModel.swift`
- [x] T053 [US5] Build Batch screen with folder intake, operation selection, progress, summary, and failure/skip access in `PageForge/Features/Batch/BatchView.swift`

**Checkpoint**: batch workflows usable without blocking navigation

---

## Phase 8: User Story 6 - Inspect and adjust metadata (Priority: P6)

**Goal**: Inspect title/author and apply light metadata updates

**Independent Test**: Inspect book, update title/author, re-inspect shows changes

### Implementation for User Story 6

- [x] T054 [P] [US6] Implement `BookMetadata` model in `PageForge/Domain/Models/MetadataModels.swift`
- [x] T055 [US6] Implement `MetadataService` inspect/update via Calibre meta tool in `PageForge/Domain/Services/MetadataService.swift`
- [x] T056 [US6] Implement metadata jobs in `PageForge/Domain/Jobs/MetadataJob.swift`
- [x] T057 [US6] Build Metadata view model in `PageForge/Features/Metadata/MetadataViewModel.swift`
- [x] T058 [US6] Build Metadata screen with inspect form and title/author edit actions in `PageForge/Features/Metadata/MetadataView.swift`

**Checkpoint**: metadata surface works independently when Calibre meta is available

---

## Phase 9: User Story 7 - Configure app health, profiles, and logs (Priority: P7)

**Goal**: Settings for Calibre status, profiles, update guidance; Logs for recent operations

**Independent Test**: View dependency status, create/edit profile, open logs, confirm app vs Calibre update guidance are separate

### Implementation for User Story 7

- [x] T059 [P] [US7] Implement setup/update guidance helpers (no silent Calibre upgrade) in `PageForge/Domain/Services/SetupGuidanceService.swift`
- [x] T060 [US7] Build Settings view model for dependencies/profiles/updates in `PageForge/Features/Settings/SettingsViewModel.swift`
- [x] T061 [US7] Build Settings screen sections for Calibre status, profile editor, secret presence, and separate update actions in `PageForge/Features/Settings/SettingsView.swift`
- [x] T062 [US7] Build profile editor form UI in `PageForge/Features/Settings/ProfileEditorView.swift`
- [x] T063 [US7] Build Logs view model and screen bound to `LogService` in `PageForge/Features/Logs/LogsViewModel.swift` and `PageForge/Features/Logs/LogsView.swift`
- [x] T064 [US7] Ensure all long-running jobs append useful log entries through `PageForge/Domain/Jobs/OperationJobCoordinator.swift`

**Checkpoint**: configuration and diagnostics are complete and secondary to Readiness

---

## Phase 10: User Story 8 - Retire old terminal UI to legacy reference (Priority: P8)

**Goal**: Ensure legacy is clearly archived and desktop is the only primary product surface

**Independent Test**: Repo inspection shows old TUI only under legacy; normal launch path is desktop

### Implementation for User Story 8

- [x] T065 [US8] Verify/adjust root package scripts so primary docs no longer instruct TUI as default product in `README.md`
- [x] T066 [US8] Finalize `legacy/README.md` with contribution rule: no new feature work in legacy
- [x] T067 [US8] Complete `legacy/notes/behavior-parity.md` checklist against implemented Swift services
- [x] T068 [US8] Remove or isolate obsolete root Python entry packaging left outside `legacy/` (if any remain) while keeping legacy tree intact
- [x] T069 [US8] Add desktop-focused development notes in `docs/desktop-migration.md`

**Checkpoint**: migration boundary is clean; legacy is inspiration only

---

## Phase 11: Polish & Cross-Cutting Concerns

**Purpose**: Quality, performance, security, and constitution compliance across stories

- [x] T070 [P] Add domain parity fixtures under `PageForgeTests/Fixtures/` for EPUB readiness/repair cases
- [x] T071 [P] Add domain tests for readiness status vocabulary and output filename contracts in `PageForgeTests/Domain/ReadinessServiceTests.swift`
- [x] T072 [P] Add domain tests for repair mode defaults and overwrite guards in `PageForgeTests/Domain/RepairServiceTests.swift`
- [x] T073 [P] Add config/secret tests ensuring passwords never serialize into config in `PageForgeTests/Domain/ConfigSecretTests.swift`
- [x] T074 Performance pass: ensure convert/repair/batch jobs never block UI updates in `PageForge/Domain/Jobs/` and feature view models
- [x] T075 UI polish pass for calm hierarchy, spacing, progressive disclosure, and accessibility labels across `PageForge/Features/**`
- [x] T076 Security hardening review for Keychain, SMTP, process arguments, and output path writes in `PageForge/Integrations/**`
- [x] T077 Constitution compliance review against `.specify/memory/constitution.md` and record residual gaps in `legacy/notes/behavior-parity.md`
- [x] T078 Run validation scenarios from `specs/001-desktop-app-migration/quickstart.md` and fix blocking gaps

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies
- **Foundational (Phase 2)**: depends on Setup; blocks all user stories
- **US1 (Phase 3)**: depends on Foundational; MVP slice
- **US2 (Phase 4)**: depends on US1 readiness models/service base
- **US3 (Phase 5)**: depends on Foundational; can start after Foundational in parallel with US1/US2 if staffed, but simplest path is after US2
- **US4 (Phase 6)**: depends on Foundational; benefits from US2 output handoff
- **US5 (Phase 7)**: depends on US1–US3 service methods
- **US6 (Phase 8)**: depends on Foundational + Calibre meta integration
- **US7 (Phase 9)**: depends on Foundational; profile pieces can reuse US4 config/secret services
- **US8 (Phase 10)**: can progress docs anytime after Setup, finalize after features land
- **Polish (Phase 11)**: after desired stories complete

### User Story Dependencies

- **US1**: foundation only
- **US2**: extends US1 readiness service/UI
- **US3**: mostly independent after foundation; shared intake/status components
- **US4**: independent after foundation; optional US2 handoff integration
- **US5**: needs service APIs from US1–US3
- **US6**: independent after foundation
- **US7**: independent after foundation; stronger after US4 secrets/config exist
- **US8**: migration hygiene; finalize late

### Parallel Opportunities

- Within Setup: T003, T005, T006 in parallel after move plan is clear
- Within Foundational: models/helpers (T008–T010) in parallel; then integrations
- Within a story: models marked [P] first, then services, then UI
- After Foundational, different developers can split US3 and US6 while one owner lands US1→US2

---

## Parallel Example: User Story 1

```bash
# Parallel model/helper work:
Task: "T020 [P] [US1] Implement ReadinessIssue/ReadinessReport in PageForge/Domain/Models/ReadinessModels.swift"

# Then sequential service/UI:
Task: "T021 [US1] Port audit logic into PageForge/Domain/Services/ReadinessService.swift"
Task: "T024 [US1] Build ReadinessViewModel"
Task: "T025 [US1] Build ReadinessView"
```

## Parallel Example: User Story 4

```bash
Task: "T040 [P] [US4] Config/send models"
Task: "T041 [US4] ConfigStore/ConfigService"
Task: "T042 [US4] KeychainSecretStore/SecretService"
Task: "T043 [US4] SMTPClient"
Task: "T044 [US4] DeliveryService"
Task: "T046 [US4] SendView"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 Setup
2. Complete Phase 2 Foundational
3. Complete Phase 3 US1
4. **STOP and VALIDATE** with quickstart Slice A
5. Demo: drop ebook → readiness report

### Incremental Delivery

1. US1 diagnose MVP
2. US2 prepare kindle-ready
3. US3 convert/repair
4. US4 send/handoff
5. US5 batch
6. US6 metadata
7. US7 settings/logs polish
8. US8 legacy retirement finalization
9. Phase 11 polish + quickstart A–G

### Suggested MVP Scope

**US1 only** (plus Setup + Foundational): desktop launch, drag-and-drop, readiness audit, status/issues.

---

## Notes

- [P] = different files, no dependency on incomplete sibling tasks
- [USn] maps to spec user stories
- Do not implement DRM removal, Amazon login automation, OCR, or multi-platform shells
- Legacy Python is reference only after T004–T006
- Commit after each task or cohesive task group during implementation
