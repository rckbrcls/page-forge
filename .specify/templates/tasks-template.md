---
description: "Task list template for feature implementation"
---

# Tasks: [FEATURE NAME]

**Input**: Design documents from `/specs/[###-feature-name]/`

**Prerequisites**: plan.md (required), spec.md (required), research.md,
data-model.md, contracts/

**Tests**: Tests are REQUIRED for every EPUB audit, cleanup, restoration, and
revalidation rule. Include focused tests for archive safety, batch isolation,
cancellation, credential redaction, delivery uncertainty, and bounded local
send-history behavior where relevant.

**Organization**: Group tasks by independently testable user story while keeping
shared pipeline foundations explicit.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel because it touches different files and has no unmet dependency
- **[Story]**: User story mapping such as US1, US2, or US3
- Include exact file paths in every task

## Path Conventions

- **Native app**: `BookSender/App/`, `BookSender/Features/`,
  `BookSender/Application/`, `BookSender/Domain/`, `BookSender/Adapters/`
- **Tests**: `BookSenderTests/` with deterministic fixtures under
  `BookSenderTests/Fixtures/`
- Keep one macOS application product; do not add a companion app, helper process,
  local service, or parallel legacy product
- Paths are examples and MUST be replaced with the concrete plan layout

## Constitution Task Expectations

- Foundational work MUST establish typed domain, pipeline, and adapter contracts
  before SwiftUI screen integration
- UI tasks MUST preserve exactly `Delivery Setup` and `Send Book`, keep `Send`
  and `History` as local tabs within `Send Book` when history is in scope, and
  retain concise states, progressive disclosure, keyboard use, and accessibility
- Pipeline tasks MUST cover safety check, audit, deterministic
  cleanup/restoration, separate working copy, revalidation, and readiness
- Archive tasks MUST bound traversal, paths, ZIP bombs, entries, expansion,
  duplicates, XML entities, links, remote references, time, and memory
- Batch tasks MUST use a stable snapshot, sequential scheduling, isolated
  outcomes, cooperative cancellation, and no automatic retry after failure or
  `delivery_unknown`
- Delivery tasks MUST require explicit confirmation, use independent SMTP
  attempts, protect credentials, and sanitize all errors and diagnostics
- History tasks MUST record only definitive SMTP acceptance, retain at most 500
  local identifier/name/timestamp records, provide confirmed clearing, and test
  record-once, ordering, relaunch persistence, retention, and privacy
- Migration tasks MUST remove obsolete Raycast code and documentation rather than
  preserve a fallback
- Do not schedule conversion, DRM removal, external engines, executable
  downloads, library, persistent queue, unbounded or remote history,
  history-driven resend, cloud, account, AI, reader, editor, or third-screen work

<!--
  The sample tasks below MUST be replaced with tasks derived from the active spec,
  plan, data model, and contracts. Do not retain placeholders in generated tasks.
-->

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish the native project, test targets, and migration boundary

- [ ] T001 Create the native macOS project structure from plan.md
- [ ] T002 Configure the application and test targets with the selected Swift toolchain
- [ ] T003 [P] Configure formatting, static analysis, and fixture resources
- [ ] T004 Document and schedule removal of obsolete Raycast and legacy product surfaces

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Build the typed pipeline contracts before user-facing work

**⚠️ CRITICAL**: No user-story UI work begins until this phase is complete

- [ ] T005 Create typed batch, finding, health, preparation, cancellation, delivery, and applicable submission-record models in BookSender/Domain/Models/
- [ ] T006 [P] Define audit, repair, restoration, and comparison contracts in BookSender/Domain/
- [ ] T007 [P] Define bounded archive, XML, filesystem, SMTP, credential, and applicable local-history adapters in BookSender/Adapters/
- [ ] T008 Define the sequential application pipeline in BookSender/Application/Pipeline/
- [ ] T009 Create deterministic valid, malformed, ambiguous, and malicious fixtures in BookSenderTests/Fixtures/
- [ ] T010 Add contract tests for original preservation, typed failures, limits, and revalidation in BookSenderTests/

**Checkpoint**: Pipeline foundation is testable without SwiftUI

---

## Phase 3: User Story 1 - [Title] (Priority: P1) 🎯 MVP

**Goal**: [User-visible outcome]

**Independent Test**: [Acceptance path]

### Tests for User Story 1

- [ ] T011 [P] [US1] Add focused domain and fixture tests in BookSenderTests/[Feature]Tests.swift
- [ ] T012 [P] [US1] Add screen and accessibility tests in BookSenderTests/[Screen]Tests.swift

### Implementation for User Story 1

- [ ] T013 [P] [US1] Create required domain models in BookSender/Domain/Models/
- [ ] T014 [US1] Implement pipeline behavior in BookSender/Application/Pipeline/
- [ ] T015 [US1] Implement only the applicable primary screen in BookSender/Features/
- [ ] T016 [US1] Add concise derived feedback and actionable inline failure disclosure

**Checkpoint**: User Story 1 is independently functional and tested

---

## Phase 4: User Story 2 - [Title] (Priority: P2)

**Goal**: [User-visible outcome]

**Independent Test**: [Acceptance path]

### Tests for User Story 2

- [ ] T017 [P] [US2] Add focused domain and fixture tests in BookSenderTests/[Feature]Tests.swift
- [ ] T018 [P] [US2] Add interaction and accessibility tests in BookSenderTests/[Screen]Tests.swift

### Implementation for User Story 2

- [ ] T019 [P] [US2] Extend typed models in BookSender/Domain/Models/
- [ ] T020 [US2] Implement application behavior in BookSender/Application/
- [ ] T021 [US2] Integrate the behavior into an existing primary screen
- [ ] T022 [US2] Add cancellation, recovery, and terminal result handling

**Checkpoint**: User Stories 1 and 2 are independently functional

---

## Phase 5: User Story 3 - [Title] (Priority: P3)

**Goal**: [User-visible outcome]

**Independent Test**: [Acceptance path]

### Tests for User Story 3

- [ ] T023 [P] [US3] Add focused behavior tests in BookSenderTests/[Feature]Tests.swift
- [ ] T024 [P] [US3] Add screen, keyboard, and accessibility tests in BookSenderTests/[Screen]Tests.swift

### Implementation for User Story 3

- [ ] T025 [P] [US3] Extend typed models in BookSender/Domain/Models/
- [ ] T026 [US3] Implement application behavior in BookSender/Application/
- [ ] T027 [US3] Integrate behavior without adding a primary screen

**Checkpoint**: All selected user stories are independently functional

---

## Phase N: Polish & Cross-Cutting Concerns

**Purpose**: Verify the lightweight experience and advanced pipeline together

- [ ] TXXX [P] Update documentation in README.md and docs/
- [ ] TXXX Remove obsolete Raycast implementation, metadata, tests, and assets
- [ ] TXXX Verify launch and shortcut responsiveness against the spec
- [ ] TXXX Verify concise default states and no invented progress
- [ ] TXXX [P] Complete fixture coverage for audit, cleanup, restoration, revalidation, and malicious inputs
- [ ] TXXX Verify batch capacity, failure isolation, cancellation, and `delivery_unknown`
- [ ] TXXX Verify history record-once behavior, retention, persistence, clearing, and privacy when applicable
- [ ] TXXX Review protected credentials and redacted diagnostics
- [ ] TXXX Review keyboard operation, focus, and accessibility
- [ ] TXXX Run constitution compliance review against `.specify/memory/constitution.md`
- [ ] TXXX Separate compilation, automated tests, runtime inspection, signing, notarization, and release evidence

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup**: Starts first
- **Foundational**: Depends on Setup and blocks user-story UI work
- **User Stories**: Depend on Foundational and proceed in priority order unless
  the plan proves independent parallel work
- **Polish**: Depends on all selected stories

### Within Each User Story

- Focused tests and fixtures before accepting an automatic pipeline rule
- Domain models before application pipeline behavior
- Application pipeline before SwiftUI integration
- Core behavior before recovery and polish
- Story validation before moving to the next priority

### Parallel Opportunities

- Different adapter contracts and fixtures may proceed in parallel
- Independent domain and screen tests may proceed in parallel
- Work touching the same pipeline scheduler, batch state, or primary screen MUST
  remain coordinated

## Implementation Strategy

### MVP First

1. Complete native setup and typed pipeline foundations
2. Deliver SMTP setup and protected credentials
3. Deliver batch intake and background readiness
4. Deliver explicit sequential SMTP sending
5. Validate the two-screen experience before expansion

### Incremental Delivery

1. Typed foundation and fixtures
2. `Delivery Setup`
3. `Send Book` intake and concise background preparation
4. Batch confirmation, delivery, cancellation, and per-item results
5. Bounded local submission history when required by the active specification
6. Shortcut, accessibility, performance, and distribution readiness

## Notes

- Do not stage or commit unless the user explicitly requests it
- Do not treat static checks as compilation, tests, runtime behavior, or release evidence
- Avoid vague tasks, cross-story file conflicts, and abstractions without a concrete rule
