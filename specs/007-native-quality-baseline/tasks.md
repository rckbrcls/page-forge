# Tasks: Native Quality Baseline

**Input**: Design documents from `/specs/007-native-quality-baseline/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md),
[research.md](./research.md), [data-model.md](./data-model.md),
[contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: Required for timeout/cancellation ownership, intake outcomes,
confirmation state, accessibility, traditional Keychain behavior, privacy,
release signing, installer identity, and credential continuity.

**Organization**: Tasks are dependency-ordered and grouped by independently
testable user story. Security amendment work may complete independently of the
pre-existing reliability and interface work when files do not overlap.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: May run in parallel because it touches independent files and has no
  unmet dependency.
- **[Story]**: Maps to US1, US2, US3, or US4 in [spec.md](./spec.md).
- Every task names its concrete file or directory.

## Phase 1: Setup and Governance

**Purpose**: Establish the constitution 7.0.0 security contract and the active
quality evidence boundary.

- [X] T001 Amend the credential and distribution law to constitution 7.0.0 in .specify/memory/constitution.md
- [X] T002 [P] Record mandatory credential and release rules in AGENTS.md
- [X] T003 [P] Add the credential and release continuity contract in specs/007-native-quality-baseline/contracts/credential-and-release-continuity.md
- [X] T004 Update the 005, 006, and 007 normative security artifacts without rewriting historical validation records in specs/005-lightweight-macos-sender/, specs/006-replace-mock-workflows/, and specs/007-native-quality-baseline/

**Checkpoint**: Current implementation and distribution work is governed by one
non-conflicting security contract.

---

## Phase 2: Foundational Quality Ownership

**Purpose**: Establish the transient ownership models shared by reliability,
intake, and native interface corrections.

- [ ] T005 [P] Add deterministic timeout and cancellation test support in BookSenderTests/Support/
- [ ] T006 [P] Add ordered intake-attempt and sanitized transfer-failure models in BookSender/Application/Intake/
- [ ] T007 [P] Make ConfirmedBatchSummary optional presence the sole confirmation source in BookSender/Application/Presentation/
- [ ] T008 [P] Add lifecycle-owned main-window attachment support in BookSender/App/

**Checkpoint**: Reliability and interface stories have independently testable
foundations without a new persistence surface or architectural layer.

---

## Phase 3: User Story 1 - Complete Every Operation Reliably (Priority: P1)

**Goal**: Every bounded operation reaches one honest terminal result under
success, timeout, cancellation, queue finish, or late reply.

**Independent Test**: Exercise controlled SMTP, archive, and XML races and verify
terminal typed outcomes plus release within one second after deadline or
cancellation.

### Tests for User Story 1

- [ ] T009 [P] [US1] Add tokenized waiter race and exactly-once tests in BookSenderTests/Adapters/SMTPReplyQueueTests.swift
- [ ] T010 [P] [US1] Add archive and XML losing-race release tests in BookSenderTests/Adapters/
- [ ] T011 [P] [US1] Add batch cancellation and delivery-unknown preservation tests in BookSenderTests/Application/

### Implementation for User Story 1

- [ ] T012 [US1] Implement tokenized cancellation-aware reply ownership in BookSender/Adapters/SMTP/
- [ ] T013 [US1] Correct bounded archive and XML timeout cleanup in BookSender/Adapters/Archive/ and BookSender/Adapters/XML/
- [ ] T014 [US1] Preserve typed pre-DATA cancellation and post-DATA delivery-unknown behavior in BookSender/Application/Delivery/

**Checkpoint**: User Story 1 is deterministic without a live SMTP provider.

---

## Phase 4: User Story 2 - Receive Complete Intake Feedback (Priority: P1)

**Goal**: Every Finder and drag-and-drop item receives an accepted or visible
sanitized failure outcome.

**Independent Test**: Feed supported, unsupported, inaccessible, malformed, and
mixed selections through both intake paths and account for every attempted item.

### Tests for User Story 2

- [ ] T015 [P] [US2] Add Finder cancellation and non-cancellation failure tests in BookSenderTests/Application/BookIntakeServiceTests.swift
- [ ] T016 [P] [US2] Add mixed provider, ordering, and sanitization tests in BookSenderTests/Application/DropIntakeTests.swift
- [ ] T017 [P] [US2] Add visible aggregate intake-failure UI tests in BookSenderUITests/SendBookUITests.swift

### Implementation for User Story 2

- [ ] T018 [US2] Handle fileImporter success, cancellation, and failure explicitly in BookSender/Features/SendBook/
- [ ] T019 [US2] Replace deprecated drop loading with per-provider loadTransferable accounting in BookSender/Features/SendBook/
- [ ] T020 [US2] Forward ordered accepted URLs and sanitized failures through the shared path in BookSender/Application/Intake/

**Checkpoint**: User Story 2 accounts for every attempted input without exposing
raw paths or provider exceptions.

---

## Phase 5: User Story 4 - Keep the Credential Across Normal Updates (Priority: P1)

**Goal**: Save the SMTP password once under the corrected contract and preserve
access across normal versions signed by the pinned identity.

**Independent Test**: Save and reread through a recreated store, verify
transactional replacement and deletion, then replace version N with N+1 signed
under the same policy and confirm no new password prompt.

### Tests for User Story 4

- [X] T021 [P] [US4] Add traditional Keychain create, recreated-store read, exists, replacement rollback, and delete coverage in BookSenderTests/Adapters/KeychainCredentialStoreTests.swift
- [X] T022 [P] [US4] Add source-policy and secret-absence assertions in BookSenderTests/Privacy/PrivacyAuditTests.swift
- [X] T023 [P] [US4] Add certificate, workflow, no-fallback, installer pin, and isolated signing contracts in scripts/tests/signing_contract_test.sh, scripts/tests/install_contract_test.sh, and scripts/tests/local_signing_smoke_test.sh
- [ ] T024 [US4] Execute first-corrected-version quit and relaunch acceptance and record evidence in specs/007-native-quality-baseline/validation/credential-first-save.md
- [ ] T025 [US4] Execute same-identity N-to-N+1 and Sparkle acceptance and record evidence in specs/007-native-quality-baseline/validation/credential-update.md

### Implementation for User Story 4

- [X] T026 [US4] Remove Data Protection, accessibility, and synchronization selectors while preserving the credential port and transactions in BookSender/Adapters/Credentials/KeychainCredentialStore.swift
- [X] T027 [P] [US4] Create and back up the ten-year Book Sender Release Signing identity, configure GitHub secrets, and version only scripts/signing/BookSenderReleaseSigning.cer
- [X] T028 [P] [US4] Pin the release identity name, certificate fingerprint, and bundle identifier in scripts/signing/release-signing-policy.sh
- [X] T029 [US4] Import the PKCS#12 into a temporary runner Keychain, verify the public certificate, sign inside out, enforce the designated requirement, and clean secrets in .github/workflows/release.yml
- [X] T030 [US4] Remove the Keychain test exclusion while retaining ad-hoc signing only for non-distributed test hosts in .github/workflows/release.yml
- [X] T031 [US4] Reject unsigned, ad-hoc, differently signed, or requirement-divergent apps before replacement in scripts/install.sh
- [X] T032 [P] [US4] Document bootstrap, backup, rotation, Gatekeeper, first-save, and update behavior in README.md and docs/deployment.md

**Checkpoint**: Source, local identity, repository secrets, workflow, installer,
tests, and documentation share one pinned release policy. Runtime update
acceptance remains a distinct pending gate.

---

## Phase 6: User Story 3 - Use a Native, Accessible Mac Interface (Priority: P2)

**Goal**: Preserve the two-screen product and two-tab Settings window with native
keyboard, accessibility, text, contrast, and lifecycle behavior.

**Independent Test**: Complete setup, send, confirmation, Settings, and shortcut
journeys using keyboard and accessibility inspection under supported preferences.

### Tests for User Story 3

- [ ] T033 [P] [US3] Add item-driven confirmation transition tests in BookSenderTests/Application/AppModelTests.swift
- [ ] T034 [P] [US3] Add Settings tab, keyboard outcome, and accessibility tests in BookSenderUITests/
- [ ] T035 [P] [US3] Add enlarged-text, increased-contrast, and reduced-transparency coverage in BookSenderUITests/

### Implementation for User Story 3

- [ ] T036 [US3] Present confirmation from one optional summary value in BookSender/Features/SendBook/
- [ ] T037 [P] [US3] Replace deprecated Settings tabs and fixed typography with native semantic APIs in BookSender/Features/Settings/
- [ ] T038 [P] [US3] Move window capture and Sparkle observation to explicit lifecycle and MainActor ownership in BookSender/App/
- [ ] T039 [US3] Audit labels, focus, disabled, loading, error, and status semantics across BookSender/Features/

**Checkpoint**: The native and accessible interface remains within exactly two
primary screens.

---

## Phase 7: Cross-Cutting Validation

- [ ] T040 Run authorized compilation and unit/UI suites from specs/007-native-quality-baseline/quickstart.md and record each gate separately
- [X] T041 [P] Run signing-policy, installer, appcast, and isolated temporary-signing contract checks from scripts/tests/signing_contract_test.sh, scripts/tests/install_contract_test.sh, scripts/tests/appcast_contract_test.py, and scripts/tests/local_signing_smoke_test.sh
- [X] T042 Run final static diff, forbidden-pattern, plist, workflow, and certificate checks and record results in specs/007-native-quality-baseline/validation/static-gate.md
- [X] T043 Review constitution 7.0.0 compliance and separate static, compilation, test, runtime, provider, signing, update, and production claims in specs/007-native-quality-baseline/validation/release-readiness.md

---

## Dependencies and Execution Order

- Phase 1 governs every later phase.
- Phase 2 blocks US1, US2, and US3.
- US1 and US2 may proceed independently after Phase 2.
- US4 depends only on Phase 1 and is independent of unfinished reliability/UI
  work except for final integrated validation.
- US3 follows its presentation foundations and may proceed after US1/US2 where
  files overlap.
- Runtime credential acceptance requires two corrected signed versions and is
  intentionally later than source and contract completion.

## Parallel Opportunities

- T005-T008 touch separate foundational surfaces.
- T009-T011, T015-T017, and T033-T035 are independent focused test files.
- T021-T023 can be reviewed independently across adapter, privacy, and scripts.
- T027, T028, and T032 touch separate signing/bootstrap/documentation surfaces
  after the release policy is fixed.

## Implementation Strategy

1. Establish constitution 7.0.0 and the release continuity contract.
2. Complete the independently releasable traditional-Keychain and stable-signing
   correction.
3. Complete cancellation and intake P1 reliability work.
4. Complete native UI and accessibility P2 work.
5. Execute authorized build/runtime/update gates without treating earlier static
   evidence as a stronger claim.
