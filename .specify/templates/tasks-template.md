---
description: "Task list template for feature implementation"
---

# Tasks: [FEATURE NAME]

**Input**: Design documents from `/specs/[###-feature-name]/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Tests are REQUIRED for every EPUB audit rule and automatic repair. Include
fixture-backed tests for archive safety and revalidation behavior where relevant.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Raycast extension**: `src/commands/`, `src/application/`, `src/domain/`, `src/adapters/`, `tests/fixtures/`
- **Single package**: do not introduce a monorepo, companion app, local service, or helper process
- Paths shown below are examples - adjust based on plan.md structure

## Constitution Task Expectations

- Foundational work MUST establish typed application and EPUB-engine services before Raycast UI work
- Audit and repair rules MUST live outside React commands and have focused fixtures and tests
- Archive tasks MUST include safe limits for traversal, escaping paths, ZIP bombs, duplicates, XML entities, symlinks, remote references, memory, and responsiveness
- Repair tasks MUST preserve originals, generate collision-safe outputs, revalidate copies, and reject newly introduced critical errors
- Delivery tasks MUST require explicit user intent and must not expose credentials in files, logs, errors, or reports
- Do not schedule Calibre, EPUBCheck, format conversion, executables, services, desktop/mobile apps, AI, DRM removal, editing, reading, library, cloud, or account work

<!--
  ============================================================================
  IMPORTANT: The tasks below are SAMPLE TASKS for illustration purposes only.

  The /speckit.tasks command MUST replace these with actual tasks based on:
  - User stories from spec.md (with their priorities P1, P2, P3...)
  - Feature requirements from plan.md
  - Entities from data-model.md
  - Interfaces and workflows from contracts/

  Tasks MUST be organized by user story so each story can be:
  - Implemented independently
  - Tested independently
  - Delivered as an MVP increment

  DO NOT keep these sample tasks in the generated tasks.md file.
  ============================================================================
-->

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [ ] T001 Create project structure per implementation plan
- [ ] T002 Initialize [language] project with [framework] dependencies
- [ ] T003 [P] Configure linting and formatting tools

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

Examples of foundational tasks (adjust based on your project):

- [ ] T004 Create typed EPUB health and repair models in src/domain/models/[Models].ts
- [ ] T005 [P] Define audit and repair service contracts in src/application/[Service].ts
- [ ] T006 [P] Define bounded archive, XML, and filesystem adapter contracts in src/adapters/[Adapter].ts
- [ ] T007 Create deterministic EPUB and malicious-archive fixtures in tests/fixtures/[Fixture].epub
- [ ] T008 Add fixture-backed audit and repair tests in tests/[Feature].test.ts

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - [Title] (Priority: P1) 🎯 MVP

**Goal**: [Brief description of what this story delivers]

**Independent Test**: [How to verify this story works on its own]

### Tests for User Story 1 (REQUIRED for audit or repair behavior)

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T010 [P] [US1] Add domain tests and focused fixtures in tests/[Feature].test.ts
- [ ] T011 [P] [US1] Add Raycast command behavior tests where applicable in tests/[Command].test.tsx

### Implementation for User Story 1

- [ ] T012 [P] [US1] Create [Entity1] model in src/domain/models/[Entity1].ts
- [ ] T013 [P] [US1] Create [Entity2] model in src/domain/models/[Entity2].ts
- [ ] T014 [US1] Implement [Service] in src/application/[Service].ts (depends on T012, T013)
- [ ] T015 [US1] Implement command behavior in src/commands/[Feature].tsx
- [ ] T016 [US1] Add typed validation and failure handling in src/application/[Service].ts
- [ ] T017 [US1] Add Raycast result feedback in src/commands/[Feature].tsx

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently

---

## Phase 4: User Story 2 - [Title] (Priority: P2)

**Goal**: [Brief description of what this story delivers]

**Independent Test**: [How to verify this story works on its own]

### Tests for User Story 2 (REQUIRED for audit or repair behavior)

- [ ] T018 [P] [US2] Add domain tests and focused fixtures in tests/[Feature].test.ts
- [ ] T019 [P] [US2] Add command tests where applicable in tests/[Command].test.tsx

### Implementation for User Story 2

- [ ] T020 [P] [US2] Create [Entity] model in src/domain/models/[Entity].ts
- [ ] T021 [US2] Implement [Service] in src/application/[Service].ts
- [ ] T022 [US2] Implement command behavior in src/commands/[Feature].tsx
- [ ] T023 [US2] Integrate typed result presentation in src/commands/[Feature].tsx

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently

---

## Phase 5: User Story 3 - [Title] (Priority: P3)

**Goal**: [Brief description of what this story delivers]

**Independent Test**: [How to verify this story works on its own]

### Tests for User Story 3 (REQUIRED for audit or repair behavior)

- [ ] T024 [P] [US3] Add domain tests and focused fixtures in tests/[Feature].test.ts
- [ ] T025 [P] [US3] Add command tests where applicable in tests/[Command].test.tsx

### Implementation for User Story 3

- [ ] T026 [P] [US3] Create [Entity] model in src/domain/models/[Entity].ts
- [ ] T027 [US3] Implement [Service] in src/application/[Service].ts
- [ ] T028 [US3] Implement command behavior in src/commands/[Feature].tsx

**Checkpoint**: All user stories should now be independently functional

---

[Add more user story phases as needed, following the same pattern]

---

## Phase N: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] TXXX [P] Documentation updates in docs/
- [ ] TXXX Code cleanup and refactoring
- [ ] TXXX Performance pass: bounded archive processing, memory use, and responsive Raycast feedback
- [ ] TXXX UI polish pass: keyboard-first Raycast interaction and clear finding/result presentation
- [ ] TXXX [P] Additional fixture-backed tests for audit, repair, revalidation, and delivery intent invariants
- [ ] TXXX Security hardening for archive paths, XML parsing, output paths, and credential handling
- [ ] TXXX Constitution compliance review against `.specify/memory/constitution.md`
- [ ] TXXX Run quickstart.md validation

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User stories can then proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P2 → P3)
- **Polish (Final Phase)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - May integrate with US1 but should be independently testable
- **User Story 3 (P3)**: Can start after Foundational (Phase 2) - May integrate with US1/US2 but should be independently testable

### Within Each User Story

- Required audit and repair tests MUST be written and FAIL before implementation
- Models before services
- Services before workflow UI
- Core implementation before integration
- Story complete before moving to next priority

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel
- All Foundational tasks marked [P] can run in parallel (within Phase 2)
- Once Foundational phase completes, all user stories can start in parallel (if team capacity allows)
- All tests for a user story marked [P] can run in parallel
- Models within a story marked [P] can run in parallel
- Different user stories can be worked on in parallel by different team members

---

## Parallel Example: User Story 1

```bash
# Launch required audit and repair tests for User Story 1 together:
Task: "Domain contract tests and fixtures in tests/[Feature].test.ts"
Task: "Raycast command behavior tests in tests/[Command].test.tsx"

# Launch all models for User Story 1 together:
Task: "Create [Entity1] model in src/domain/models/[Entity1].ts"
Task: "Create [Entity2] model in src/domain/models/[Entity2].ts"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Test User Story 1 independently
5. Demo locally if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP!)
3. Add User Story 2 → Test independently → Deploy/Demo
4. Add User Story 3 → Test independently → Deploy/Demo
5. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1
   - Developer B: User Story 2
   - Developer C: User Story 3
3. Stories complete and integrate independently

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Do not stage or commit unless the user explicitly requests it
- Stop at any checkpoint to validate story independently
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence
