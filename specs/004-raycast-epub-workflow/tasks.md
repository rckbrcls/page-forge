---
description: "Implementation tasks for the self-contained Raycast EPUB workflow"
---

# Tasks: Self-Contained Raycast EPUB Workflow

**Input**: Design documents from `/specs/004-raycast-epub-workflow/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md`

**Tests**: Tests are REQUIRED for every EPUB audit rule and automatic repair. Write the listed tests first and confirm they fail before implementing the corresponding behavior.

**Organization**: Tasks are grouped by user story so each story can be implemented and tested as an explicit increment.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel after its phase prerequisites because it changes different files and does not depend on another incomplete task in the same parallel group.
- **[Story]**: Maps a task to its user story from `spec.md`.
- Every checklist task includes an exact file path.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish the single-package Raycast extension and validation toolchain without implementing product behavior.

- [x] T001 Create the root Raycast package manifest with exactly three macOS view commands, optional send-command SMTP preferences, Node `>=22.22.2 <23`, scripts, and the approved runtime/dev dependencies in `package.json`
- [x] T002 After explicit execution approval, install the dependencies declared by T001 and generate the deterministic npm dependency graph in `package-lock.json`
- [x] T003 [P] Configure strict TypeScript 6.0 and Raycast ambient types in `tsconfig.json` and `raycast-env.d.ts`
- [x] T004 [P] Configure Raycast ESLint and repository-wide Prettier checks in `eslint.config.js`, `prettier.config.js`, and `.prettierignore`
- [x] T005 [P] Configure Vitest's Node environment, V8 coverage, test globs, and domain coverage thresholds in `vitest.config.ts`
- [x] T006 [P] Replace obsolete generated-file ignores with Node, Raycast, coverage, temporary EPUB, and macOS ignores in `.gitignore`

**Checkpoint**: The repository has one npm package definition and static tool configuration, but no user story is implemented.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Define typed boundaries, operation state, safety constants, and deterministic test support required by every story.

**CRITICAL**: Complete this phase before any user-story implementation.

- [x] T007 [P] Define `Result`, exhaustive helpers, and typed processing-failure unions without raw exception leakage in `src/domain/models/result.ts` and `src/domain/models/processing-failure.ts`
- [x] T008 [P] Define selected-file snapshots, verified descriptors, internal paths, archive entries, loaded projections, and source fingerprints in `src/domain/models/epub-document.ts` and `src/domain/models/archive.ts`
- [x] T009 [P] Define severities, findings, rule outcomes, health states, health reports, stable finding identity, and revalidation enrichment in `src/domain/models/finding.ts` and `src/domain/models/health-report.ts`
- [x] T010 [P] Define repair plans, allowlisted operations, applied repairs, preparation results, prepared outputs, and revalidation comparisons in `src/domain/models/repair.ts`
- [x] T011 [P] Define processing phases, batch item/results, progress events, delivery configuration, and delivery outcomes including `delivery_unknown` in `src/domain/models/operation.ts` and `src/domain/models/delivery.ts`
- [x] T012 [P] Encode the closed v1 finding codes and all numeric archive/XML/time limits from the contracts in `src/domain/audit/finding-codes.ts` and `src/domain/audit/limits.ts`
- [x] T013 [P] Implement combined user/deadline cancellation, cooperative checkpoints, and event-loop yield helpers in `src/application/cancellation.ts` and `src/application/progress.ts`
- [x] T014 Define typed archive, XML, filesystem, selection, delivery, and clock ports used by application services in `src/application/ports.ts`
- [x] T015 Implement host-independent POSIX internal-path parsing, directory marker handling, canonical Unicode folding, and reference identity helpers in `src/domain/audit/internal-path.ts`
- [x] T016 [P] Build a deterministic raw ZIP fixture generator supporting headers, central-directory records, CRCs, flags, methods, attributes, duplicate names, and inconsistent sizes in `tests/support/fixture-builder.ts`
- [x] T017 [P] Build minimal EPUB 2/3 package, container, XHTML, navigation, CSS, image, font, and encryption fixture factories in `tests/support/epub-fixture-factory.ts`
- [x] T018 [P] Add source/output hashing, temporary filesystem, fake clock, progress recorder, and abort test utilities in `tests/support/hashes.ts`, `tests/support/test-filesystem.ts`, and `tests/support/operation-harness.ts`
- [x] T019 Add contract tests for model invariants, health-state discriminants, operation transitions, safety constants, and forbidden domain imports in `tests/domain/models/model-contracts.test.ts` and `tests/architecture/dependency-direction.test.ts`

**Checkpoint**: Typed contracts and deterministic test infrastructure are ready; user stories can now be implemented against stable boundaries.

---

## Phase 3: User Story 1 - Inspect EPUB Health (Priority: P1) MVP

**Goal**: Inspect Finder-selected or manually selected EPUBs locally, preserve originals, and present complete structured health reports.

**Independent Test**: Select valid EPUB 2/3 and malformed fixtures, run `Page Forge: Inspect EPUB`, and verify individual structured reports, picker fallback, no network use, and byte-identical originals.

### Tests for User Story 1

- [x] T020 [P] [US1] Add Finder/picker intake tests for mixed extensions, Unicode names, duplicate identities, directories, missing files, unreadable files, and changed snapshots in `tests/application/select-epubs.test.ts` and `tests/fixtures/input/fixture-definitions.ts`
- [x] T021 [P] [US1] Add valid EPUB 2, valid EPUB 3, fixed-layout Info, invalid ZIP, empty ZIP, and non-EPUB ZIP fixtures and report assertions in `tests/domain/audit/valid-and-zip.test.ts` and `tests/fixtures/valid/fixture-definitions.ts`
- [x] T022 [P] [US1] Add focused tests for `MIMETYPE_MISSING`, `MIMETYPE_NOT_FIRST`, `MIMETYPE_COMPRESSED`, `MIMETYPE_VALUE_INVALID`, and `MIMETYPE_EXTRA_FIELD` in `tests/domain/audit/mimetype-rules.test.ts` and `tests/fixtures/mimetype/fixture-definitions.ts`
- [x] T023 [P] [US1] Add focused tests for missing/malformed container XML, rootfile absence/multiplicity, missing referenced package, no package, ambiguous package, invalid package XML, and unsupported version in `tests/domain/audit/container-package-discovery.test.ts` and `tests/fixtures/container/fixture-definitions.ts`
- [x] T024 [P] [US1] Add metadata, unique-identifier, manifest, duplicate ID/href, missing resource, and media-type fixtures for every package finding in `tests/domain/audit/package-manifest-rules.test.ts` and `tests/fixtures/package/manifest-fixtures.ts`
- [x] T025 [P] [US1] Add spine, reading-order, navigation, and cover fixtures for every corresponding v1 finding in `tests/domain/audit/spine-navigation-cover-rules.test.ts` and `tests/fixtures/package/reading-order-fixtures.ts`
- [x] T026 [P] [US1] Add malformed XHTML, broken links, missing image/stylesheet/font, case mismatch, remote resource, empty file/chapter, and fixed-layout content tests in `tests/domain/audit/content-rules.test.ts` and `tests/fixtures/content/fixture-definitions.ts`
- [x] T027 [P] [US1] Add inspection orchestration and Raycast view contract tests for stable result order, complete rule accounting, report fields/actions, no writes, and no network port in `tests/application/inspect-epubs.test.ts` and `tests/commands/inspect-command.test.tsx`

### Implementation for User Story 1

- [x] T028 [P] [US1] Implement Finder selection and picker-source adapters without duplicating intake rules in `src/adapters/raycast/selected-finder-items.ts` and `src/adapters/raycast/file-picker-source.ts`
- [x] T029 [US1] Implement extension filtering, filesystem-identity deduplication, item-level rejection, and stable selection snapshots in `src/application/select-epubs.ts`
- [x] T030 [US1] Implement read-only descriptor verification, source hashing, archive open, lazy central-directory enumeration, one-entry streaming, and basic ZIP validity outcomes in `src/adapters/filesystem/local-epub-files.ts` and `src/adapters/archive/archive-reader.ts`
- [x] T031 [P] [US1] Implement bounded fatal UTF-8/UTF-16 decoding and namespace-aware SAX projection parsing in `src/adapters/xml/safe-xml-parser.ts`
- [x] T032 [US1] Implement container rootfile, OPF metadata, manifest, spine, navigation, and cover projections in `src/adapters/xml/epub-projections.ts`
- [x] T033 [P] [US1] Implement owner-relative internal URL/reference resolution with fragment handling and exact/unique-equivalent target evidence in `src/domain/audit/resolve-reference.ts`
- [x] T034 [P] [US1] Implement stable finding definitions, severities, categories, titles, descriptions, impacts, and conditional repairability from the catalog in `src/domain/audit/finding-catalog.ts`
- [x] T035 [P] [US1] Implement deterministic finding ordering and `unsafe > unsupported > needs_review > repairable > healthy` derivation in `src/domain/audit/derive-health.ts`
- [x] T036 [P] [US1] Implement ZIP identity, mimetype, container, and package-discovery audit rules in `src/domain/audit/rules/archive-identity.ts`, `src/domain/audit/rules/mimetype.ts`, and `src/domain/audit/rules/container.ts`
- [x] T037 [P] [US1] Implement metadata, unique identifier, manifest, media type, spine, reading order, navigation, and cover rules in `src/domain/audit/rules/package.ts`
- [x] T038 [P] [US1] Implement XHTML/XML structure, internal references, resource existence, relevant-empty-content, and fixed-layout compatibility rules in `src/domain/audit/rules/content.ts`
- [x] T039 [US1] Implement the closed rule registry, terminal rule accounting, report fingerprints, and full local audit orchestration in `src/domain/audit/rule-catalog.ts` and `src/domain/audit/audit-epub.ts`
- [x] T040 [US1] Implement sequential single-file inspection orchestration with isolated typed outcomes and progress callbacks in `src/application/inspect-epubs.ts`
- [x] T041 [P] [US1] Implement reusable health badges, finding groups, metadata, and full report actions in `src/commands/components/health-report-detail.tsx` and `src/commands/components/epub-picker.tsx`
- [x] T042 [US1] Implement the Inspect EPUB list/detail workflow and thin Raycast entrypoint in `src/commands/inspect-command.tsx` and `src/inspect-epub.tsx`

**Checkpoint**: User Story 1 independently inspects ordinary valid and malformed EPUBs without modification or network access.

---

## Phase 4: User Story 2 - Prepare a Safe Repaired Copy (Priority: P1)

**Goal**: Present a deterministic plan, apply only confirmed safe repairs, create a collision-safe copy, revalidate it, and expose a final Healthy result.

**Independent Test**: Prepare fixtures containing only allowlisted deterministic faults and verify reviewed operations, preserved unrelated bytes, unchanged originals, no-clobber naming, full revalidation, and failure without final promotion for new findings.

### Tests for User Story 2

- [x] T043 [P] [US2] Add repair-plan allowlist, finding linkage, exact-target, changed-entry, unresolved-reason, stale-source, and predicted-path tests in `tests/domain/repair/create-repair-plan.test.ts`
- [x] T044 [P] [US2] Add canonical mimetype and unique-OPF container reconstruction tests with focused repair fixtures in `tests/domain/repair/mimetype-container-repairs.test.ts` and `tests/fixtures/repair/mimetype-container-fixtures.ts`
- [x] T045 [P] [US2] Add media-type, unique reference, equivalent path, case, and meaning-preserving XML encoding repair tests in `tests/domain/repair/reference-xml-repairs.test.ts` and `tests/fixtures/repair/reference-xml-fixtures.ts`
- [x] T046 [P] [US2] Add streaming archive reconstruction tests for mimetype ordering/STORE/extras, original relative order, CRC, bounded memory, and byte preservation of unplanned resources in `tests/adapters/archive/archive-writer.test.ts`
- [x] T047 [P] [US2] Add output prediction, `-2`/`-3` suffixes, race-time `EEXIST`, same-directory temp, no-clobber hard-link promotion, unsupported-volume failure, and cleanup tests in `tests/adapters/filesystem/atomic-output.test.ts`
- [x] T048 [P] [US2] Add comparison tests for resolved/remaining/introduced findings, finding enrichment, failed operations, final non-Healthy state, repair/revalidation timeout, and retained unsuccessful evidence in `tests/domain/repair/revalidation-comparison.test.ts`
- [x] T049 [P] [US2] Add Prepare command tests for plan-before-write confirmation, non-repairable states, progress/cancel actions, final five actions, and zero network calls in `tests/commands/prepare-command.test.tsx`

### Implementation for User Story 2

- [x] T050 [P] [US2] Implement conditional repair eligibility, allowlisted operation generation, unresolved reasons, and predicted output paths in `src/domain/repair/create-repair-plan.ts`
- [x] T051 [P] [US2] Implement bounded canonical container/XML and reference transformations without editorial changes in `src/domain/repair/xml-transformations.ts`
- [x] T052 [US2] Implement ordered streaming reconstruction with canonical first `mimetype`, unchanged-resource streaming, actual-byte/CRC checks, and output caps in `src/adapters/archive/archive-writer.ts`
- [x] T053 [US2] Implement plan-exact operation dispatch and applied/already-satisfied/failed evidence in `src/domain/repair/apply-repair-plan.ts`
- [x] T054 [P] [US2] Implement output prediction, random same-directory mode-safe temporaries, no-clobber hard-link promotion, suffix retry, and owned-temp cleanup in `src/adapters/filesystem/atomic-output-writer.ts`
- [x] T055 [P] [US2] Implement finding identity comparison, applied-repair/revalidation enrichment, final Healthy gate, and unsuccessful evidence in `src/domain/repair/compare-revalidation.ts`
- [x] T056 [US2] Implement inspect-plan-confirm-reconstruct-close-reopen-revalidate-compare-promote orchestration with source rechecks and no network port in `src/application/prepare-epubs.ts`
- [x] T057 [P] [US2] Implement reviewable repair-plan and unsuccessful-comparison details in `src/commands/components/repair-plan-detail.tsx` and `src/commands/components/revalidation-detail.tsx`
- [x] T058 [P] [US2] Implement Finder reveal, copy path, open folder, final report, and send-next-step actions in `src/commands/components/preparation-actions.tsx`
- [x] T059 [US2] Implement the Prepare EPUB for Kindle workflow and thin Raycast entrypoint in `src/commands/prepare-command.tsx` and `src/prepare-epub-for-kindle.tsx`
- [x] T060 [US2] Add an end-to-end preparation acceptance test covering original hashes, canonical output, on-disk reinspection, final Healthy state, and all result actions in `tests/application/prepare-epubs.test.ts`

**Checkpoint**: User Story 2 independently turns deterministic repairable fixtures into separate revalidated Healthy copies and never overwrites or exposes a failed artifact.

---

## Phase 5: User Story 3 - Refuse Unsafe or Ambiguous Changes (Priority: P1)

**Goal**: Stop dangerous inputs within fixed bounds and diagnose ambiguous/editorial cases without executing content or creating repaired files.

**Independent Test**: Inspect every malicious, excessive, encrypted, active-content, and ambiguous fixture and verify the exact Unsafe/Needs Review findings, bounded work, no external access, and no output.

### Tests for User Story 3

- [x] T061 [P] [US3] Add focused fixtures/tests for absolute, traversal, noncanonical, NUL, backslash, invalid-encoding, exact duplicate, Unicode-folded collision, and file/directory conflict codes in `tests/domain/audit/archive-path-safety.test.ts` and `tests/fixtures/malicious/path-fixtures.ts`
- [x] T062 [P] [US3] Add focused fixtures/tests for multidisk, invalid ZIP64, unsupported method, CRC/size mismatch, symlink, special file, and encrypted ZIP entry codes in `tests/domain/audit/archive-structure-safety.test.ts` and `tests/fixtures/malicious/zip-structure-fixtures.ts`
- [x] T063 [P] [US3] Add below/at/above boundary tests for source bytes, entry count, entry bytes, expanded total, zero/nonzero denominator, per-entry/aggregate 100:1 ratio, and 120-second inspection timeout in `tests/domain/audit/archive-limits.test.ts` and `tests/fixtures/malicious/limit-fixtures.ts`
- [x] T064 [P] [US3] Add XML 1.1, DOCTYPE, entity, invalid encoding, 10 MB, depth-64, malformed recursion, cancellation, and no-resolution tests in `tests/adapters/xml/xml-safety.test.ts` and `tests/fixtures/malicious/xml-fixtures.ts`
- [x] T065 [P] [US3] Add external-file, executable, scripted, interactive, remote-resource, and DRM/encryption detection tests proving zero execution/fetch/decryption in `tests/domain/audit/active-protected-content.test.ts` and `tests/fixtures/encrypted/fixture-definitions.ts`
- [x] T066 [P] [US3] Add ambiguous OPF, cover, navigation, reference, metadata, manifest reconstruction, chapter deletion, XHTML rewrite, script/font removal, and CSS/editorial refusal tests in `tests/domain/repair/ambiguous-repair-refusal.test.ts` and `tests/fixtures/ambiguous/fixture-definitions.ts`
- [x] T067 [P] [US3] Add terminal-preflight and command tests proving later rules are accounted but not run, no repair action/output exists, and reports stay actionable in `tests/application/unsafe-inspection.test.ts` and `tests/commands/unsafe-results.test.tsx`

### Implementation for User Story 3

- [x] T068 [P] [US3] Harden archive name/type validation for all path, duplicate, collision, ancestry, symlink, and special-file findings in `src/adapters/archive/archive-path-safety.ts`
- [x] T069 [P] [US3] Implement multidisk, ZIP64, method, encryption, declared-size, CRC, and actual-stream integrity checks in `src/adapters/archive/archive-integrity.ts`
- [x] T070 [US3] Implement integer-safe source/count/entry/aggregate/ratio limits, streamed counters, one-active-entry enforcement, deadline abort, and terminal Unsafe outcomes in `src/adapters/archive/archive-limits.ts`
- [x] T071 [P] [US3] Enforce XML 1.0 encoding, DTD/entity prohibition, byte/depth limits, chunk cancellation, and zero resolver access in `src/adapters/xml/xml-safety.ts`
- [x] T072 [P] [US3] Implement protected-content, local/remote reference, executable, script, and interactive compatibility rules in `src/domain/audit/rules/active-content.ts`
- [x] T073 [P] [US3] Implement ambiguity/refusal policy for OPFs, covers, navigation, references, editorial metadata, content deletion/rewrite, fonts/scripts, and CSS in `src/domain/repair/permitted-repairs.ts`
- [x] T074 [US3] Integrate terminal safety findings and `not_run_after_terminal_finding` accounting into the closed audit pipeline in `src/domain/audit/audit-epub.ts`
- [x] T075 [P] [US3] Implement Unsafe and Needs Review explanations with no automatic action in `src/commands/components/safety-result-detail.tsx`
- [x] T076 [US3] Add the full malicious/ambiguous acceptance matrix and verify every v1 finding code maps to a focused fixture in `tests/acceptance/audit-rule-matrix.test.ts`

**Checkpoint**: User Story 3 independently proves hostile and ambiguous EPUBs are bounded, diagnosed, and never altered or executed.

---

## Phase 6: User Story 4 - Send Explicitly to Kindle (Priority: P2)

**Goal**: Explicitly submit eligible EPUBs through secure user-configured SMTP or hand off to the official Send to Kindle page without exposing credentials.

**Independent Test**: Exercise healthy, prepared, repairable, blocked, configured, unconfigured, success, sanitized failure, cancellation, and unknown-delivery cases while asserting one attachment and no pre-confirmation network use.

### Tests for User Story 4

- [x] T077 [P] [US4] Add configuration tests for optional preferences, exact `@kindle.com` validation, CR/LF rejection, port bounds, implicit TLS, required STARTTLS, TLS 1.2, and prohibited plaintext/downgrade options in `tests/adapters/delivery/delivery-preferences.test.ts`
- [x] T078 [P] [US4] Add private mode-0600 delivery snapshot tests for same-descriptor copying, digest match/mismatch, close/reopen streaming, and cleanup before/after failures in `tests/adapters/filesystem/delivery-snapshot.test.ts`
- [x] T079 [P] [US4] Add SMTP contract tests for reviewed confirmation, envelope, fixed headers/body, basename-only metadata, disabled file/URL access, and exactly one streamed EPUB attachment in `tests/adapters/delivery/smtp-client.test.ts`
- [x] T080 [P] [US4] Add DNS, connection, TLS, authentication, envelope, message/size, stream, and unknown-error sanitization tests proving no raw response, path, filename, host, username, or secret escapes in `tests/adapters/delivery/smtp-errors.test.ts`
- [x] T081 [P] [US4] Add before-connect cancellation, best-effort active interruption, post-DATA `delivery_unknown`, 2xx `submitted`, and no-automatic-retry tests in `tests/adapters/delivery/smtp-cancellation.test.ts`
- [x] T082 [P] [US4] Add send-service eligibility tests for Healthy/prepared, prepare-first, blocked states, sequential one-message items, changed digest, and explicit confirmation in `tests/application/send-epubs.test.ts`
- [x] T083 [P] [US4] Add Send command tests for optional settings, preference action, manual handoff, confirmation detail, progress, sanitized outcomes, and duplicate warning on Send Again in `tests/commands/send-command.test.tsx`

### Implementation for User Story 4

- [x] T084 [P] [US4] Implement optional Raycast password/text/dropdown preference loading and validated delivery configuration in `src/adapters/raycast/delivery-preferences.ts`
- [x] T085 [P] [US4] Implement private delivery snapshots, digest binding, verified reopen, and guaranteed owned-temp cleanup in `src/adapters/filesystem/delivery-snapshot.ts`
- [x] T086 [US4] Implement non-pooled Nodemailer submission with implicit TLS/required STARTTLS, certificate checks, timeouts, disabled debug/file/URL access, and one attachment in `src/adapters/delivery/smtp-client.ts`
- [x] T087 [P] [US4] Implement allowlisted SMTP failure mapping, redaction, phase-aware cancellation, and `delivery_unknown` decisions in `src/adapters/delivery/smtp-result.ts`
- [x] T088 [P] [US4] Implement explicit official Send to Kindle browser handoff without upload automation in `src/adapters/delivery/kindle-handoff.ts`
- [x] T089 [US4] Implement eligibility inspection, reviewed-set confirmation, sequential submission, no automatic retry, and truthful result orchestration in `src/application/send-epubs.ts`
- [x] T090 [P] [US4] Implement delivery confirmation, settings guidance, progress, sanitized results, manual handoff, and Send Again warning UI in `src/commands/components/delivery-confirmation.tsx` and `src/commands/components/delivery-result.tsx`
- [x] T091 [US4] Implement the Send EPUB to Kindle workflow and thin Raycast entrypoint in `src/commands/send-command.tsx` and `src/send-epub-to-kindle.tsx`

**Checkpoint**: User Story 4 independently performs explicit secure SMTP submission or a manual official handoff while preserving truthful and secret-free outcomes.

---

## Phase 7: User Story 5 - Process and Recover a Batch (Priority: P2)

**Goal**: Process stable multi-file snapshots sequentially, isolate failures, support cooperative cancellation, preserve completed results, and retry only failed items.

**Independent Test**: Run a 20-file mixed batch through inspect, prepare, and send harnesses; cancel active phases and verify ordered independent results, cleanup, pending-stop behavior, and failed-only retry.

### Tests for User Story 5

- [ ] T092 [P] [US5] Add mixed-batch tests for stable order, duplicate collapse, one active file/entry, isolated Healthy/Repairable/Needs Review/Unsupported/Unsafe/failure results, and continued scheduling in `tests/application/process-batch.test.ts`
- [ ] T093 [P] [US5] Add cancellation tests for inspection, reconstruction, revalidation, pre-DATA delivery, post-DATA unknown delivery, pending-stop behavior, prior-result preservation, and owned-temp cleanup in `tests/application/batch-cancellation.test.ts`
- [ ] T094 [P] [US5] Add retry tests proving only failed items are rescheduled, cancelled items require a new operation, and unknown delivery uses separately confirmed Send Again in `tests/application/batch-retry.test.ts`
- [ ] T095 [P] [US5] Add 20-file capacity, honest per-phase/entry progress, at-least-once-per-second yield, and failure-isolation acceptance tests in `tests/acceptance/batch-capacity.test.ts`

### Implementation for User Story 5

- [ ] T096 [US5] Implement generic sequential snapshot scheduling, item-level result capture, pending cancellation, and progress emission in `src/application/process-batch.ts`
- [ ] T097 [P] [US5] Implement operation-scoped AbortController ownership and typed phase transitions in `src/application/operation-controller.ts`
- [ ] T098 [P] [US5] Implement conservative cleanup of only recognizable Page Forge temporary outputs and delivery snapshots in `src/adapters/filesystem/orphan-cleanup.ts`
- [ ] T099 [P] [US5] Implement reusable honest file/phase/entry progress presentation and cancel action in `src/commands/components/operation-progress.tsx`
- [ ] T100 [P] [US5] Implement ordered batch result lists, per-item details, preserved completed states, and failed-only retry actions in `src/commands/components/batch-results.tsx`
- [ ] T101 [US5] Integrate the shared batch runner and operation controller into `src/application/inspect-epubs.ts`, `src/application/prepare-epubs.ts`, and `src/application/send-epubs.ts`
- [ ] T102 [US5] Integrate shared progress, cancellation, batch results, and retry behavior into `src/commands/inspect-command.tsx`, `src/commands/prepare-command.tsx`, and `src/commands/send-command.tsx`

**Checkpoint**: User Story 5 independently demonstrates bounded, cancellable, failure-isolated batch behavior across all three intents.

---

## Phase 8: User Story 6 - Install One Focused Product (Priority: P3)

**Goal**: Leave one documented, self-contained, Store-ready Raycast extension and remove every conflicting desktop, Calibre, conversion, and legacy product surface.

**Independent Test**: Install the package with only Raycast available, verify exactly three commands and core fixtures, and run static repository checks proving no legacy product or forbidden dependency remains.

### Tests for User Story 6

- [ ] T103 [P] [US6] Add package-manifest contract tests for one macOS extension, exactly three view commands, optional send preferences, approved dependency types, and no npm publication path in `tests/repository/package-manifest.test.ts`
- [ ] T104 [P] [US6] Add repository-boundary tests forbidding Swift/Xcode/Python/Calibre/Sparkle/conversion/native-binary/helper-service production surfaces while preserving current Spec Kit artifacts in `tests/repository/product-boundary.test.ts`

### Implementation for User Story 6

- [ ] T105 [P] [US6] Add an owned publication-compatible 512x512 PNG extension icon in `assets/extension-icon.png`
- [ ] T106 [P] [US6] Add the publication-compatible project license in `LICENSE`
- [ ] T107 [P] [US6] Rewrite installation, three commands, EPUB scope, privacy, limits, repair policy, SMTP app-password setup, approved sender, truthful submission, and manual fallback documentation in `README.md`
- [ ] T108 [P] [US6] Publish the stable v1 finding definitions and fixture expectations from the contract in `docs/finding-catalog.md`
- [ ] T109 [P] [US6] Document automatic-repair boundaries, original immutability, local processing, temporary-copy handling, credentials, and zero telemetry in `docs/repair-policy.md` and `docs/privacy.md`
- [ ] T110 [P] [US6] Document Store metadata, icon/license checks, dependency review, validation gates, and operational desktop deprecation follow-up in `docs/publication.md`
- [ ] T111 [P] [US6] Replace the desktop release pipeline with npm lockfile install, format, lint, tests, coverage, and Raycast build validation in `.github/workflows/ci.yml`
- [ ] T112 [US6] Remove the obsolete Sparkle release workflow, appcast, desktop installer, and update scripts from `.github/workflows/release.yml`, `appcast.xml`, `scripts/install.sh`, and `scripts/update_appcast.py`
- [ ] T113 [US6] Remove the obsolete SwiftUI app, Xcode project, Swift tests, and Python product trees from `PageForge/`, `PageForge.xcodeproj/`, `PageForgeTests/`, and `legacy/`
- [ ] T114 [US6] Remove obsolete desktop specs/docs/assets, tracked exploration artifacts, generated images, and `.DS_Store` files from `specs/001-desktop-app-migration/`, `specs/002-simplify-document-workflow/`, `docs/desktop-migration.md`, `docs/assets/`, `.pi-subagents/artifacts/`, `Generated image 1.png`, and repository `.DS_Store` paths
- [ ] T115 [US6] Finalize Raycast-only agent guidance and remove any remaining conflicting product instructions in `AGENTS.md`
- [ ] T116 [US6] Add a self-containment acceptance test that imports the built dependency graph metadata and confirms core fixtures require no installed external tool in `tests/acceptance/self-contained-install.test.ts`

**Checkpoint**: User Story 6 leaves exactly one public Raycast extension product with no parallel legacy implementation or distribution surface.

---

## Phase 9: Polish and Cross-Cutting Verification

**Purpose**: Prove full-rule coverage, performance, privacy, accessibility, documentation consistency, and publication gates across the completed product.

- [ ] T117 [P] Cross-check every code in `src/domain/audit/finding-codes.ts` and every operation in `src/domain/models/repair.ts` against at least one focused fixture/test and fail on unmapped entries in `tests/acceptance/rule-repair-coverage.test.ts`
- [ ] T118 [P] Add deterministic performance measurements for healthy EPUBs up to 50 MB/2,000 entries and bounded stream memory in `tests/performance/inspection-performance.test.ts`
- [ ] T119 [P] Add keyboard-action, meaningful-label, status, confirmation, progress, cancellation, and recovery accessibility assertions for all commands in `tests/commands/accessibility.test.tsx`
- [ ] T120 [P] Add privacy/redaction tests that fail on book excerpts, full paths, filenames in telemetry/logs, raw adapter errors, SMTP responses, or credential values in `tests/security/privacy-redaction.test.ts`
- [ ] T121 [P] Add dependency/license/binary inspection that rejects native addons, executables, postinstall downloads, forbidden runtimes, and unjustified packages in `tests/repository/dependency-policy.test.ts`
- [ ] T122 [P] Add documentation drift checks for command names, safety limits, finding codes, repair allowlist, SMTP states, and removed-scope references in `tests/repository/documentation-contract.test.ts`
- [ ] T123 Review and remove unused exports, dependencies, speculative abstractions, and duplicate UI/application logic across `src/`, `tests/`, and `package.json`
- [ ] T124 Validate README, repair policy, finding catalog, privacy, publication guidance, Store metadata, icon dimensions/ownership, and license against `specs/004-raycast-epub-workflow/quickstart.md`
- [ ] T125 Run the static repository replacement searches and whitespace validation from Scenario 11 of `specs/004-raycast-epub-workflow/quickstart.md`
- [ ] T126 After explicit execution approval, run install, format check, lint, typecheck/build, tests, coverage, and distribution build commands documented in `specs/004-raycast-epub-workflow/quickstart.md`
- [ ] T127 After explicit Raycast execution approval, run the Finder, picker, prepare, collision, ambiguity, hostile, cancellation, batch, SMTP, fallback, and Store-readiness manual scenarios in `specs/004-raycast-epub-workflow/quickstart.md`
- [ ] T128 Perform the final constitution and specification audit, recording any approved deviations or confirming none in `specs/004-raycast-epub-workflow/checklists/implementation.md`

---

## Dependencies and Execution Order

### Phase Dependencies

- **Phase 1 Setup**: Starts immediately.
- **Phase 2 Foundation**: Depends on Phase 1 and blocks every user story.
- **US1 Inspection**: Starts after Foundation and establishes the primary audit pipeline and MVP.
- **US2 Preparation**: Depends on Foundation and US1's audit/report pipeline.
- **US3 Safety/Refusal**: Depends on Foundation and US1's preflight/audit pipeline; it can proceed in parallel with US2 after US1.
- **US4 Delivery**: Depends on Foundation and US1 eligibility reports; prepared-output delivery additionally integrates with US2.
- **US5 Batch**: Depends on the single-item application services from US1, US2, and US4.
- **US6 Focused Product**: Package/docs tasks can begin after Foundation, but destructive legacy removal waits until US1-US5 behavior and fixtures preserve required knowledge.
- **Phase 9 Polish**: Depends on all selected user stories; publication requires all six.

### User Story Dependency Graph

```text
Setup -> Foundation -> US1 Inspect
                         |-> US2 Prepare --|
                         |-> US3 Safety    |-> US5 Batch -> US6 Final Removal -> Polish
                         |-> US4 Send -----|

US2 Prepared Output -> US4 Prepared-File Delivery
```

### Within Each User Story

- Write the story's fixture-backed tests first and confirm they fail for the intended reason.
- Implement models/contracts before adapters and services that consume them.
- Implement adapters/domain rules before application orchestration.
- Implement application orchestration before command UI integration.
- Pass the independent story checkpoint before treating the story as complete.

## Parallel Opportunities

- Setup configuration tasks T003-T006 can run in parallel after T001.
- Foundational model tasks T007-T013 and test-support tasks T016-T018 can run in parallel before T014/T019 integration.
- Within US1, fixture/test groups T020-T027 and independent rule groups T034-T038 can run in parallel.
- US2 and US3 can run in parallel after US1 because they modify repair and safety-specific modules.
- US4 delivery adapters can run in parallel with US2/US3 after US1 eligibility reports stabilize.
- US5 test groups T092-T095 and component tasks T097-T100 can run in parallel around the central batch runner.
- US6 docs/assets/tests T103-T111 can run in parallel; deletion tasks T112-T114 must wait for preserved fixture coverage.
- Cross-cutting tests T117-T122 can run in parallel before the final cleanup and execution gates.

## Parallel Execution Examples

### User Story 1

```text
Task T022: Mimetype fixtures/tests in tests/domain/audit/mimetype-rules.test.ts
Task T024: Manifest fixtures/tests in tests/domain/audit/package-manifest-rules.test.ts
Task T026: Content fixtures/tests in tests/domain/audit/content-rules.test.ts
```

### User Story 2

```text
Task T044: Mimetype/container repair fixtures in tests/domain/repair/mimetype-container-repairs.test.ts
Task T045: Reference/XML repair fixtures in tests/domain/repair/reference-xml-repairs.test.ts
Task T047: Atomic output tests in tests/adapters/filesystem/atomic-output.test.ts
```

### User Story 3

```text
Task T061: Path safety fixtures in tests/fixtures/malicious/path-fixtures.ts
Task T063: Limit boundary fixtures in tests/fixtures/malicious/limit-fixtures.ts
Task T064: XML safety fixtures in tests/fixtures/malicious/xml-fixtures.ts
```

### User Story 4

```text
Task T077: Preference validation tests in tests/adapters/delivery/delivery-preferences.test.ts
Task T078: Delivery snapshot tests in tests/adapters/filesystem/delivery-snapshot.test.ts
Task T080: Sanitized SMTP error tests in tests/adapters/delivery/smtp-errors.test.ts
```

### User Story 5

```text
Task T092: Mixed batch tests in tests/application/process-batch.test.ts
Task T093: Cancellation tests in tests/application/batch-cancellation.test.ts
Task T095: Capacity/progress tests in tests/acceptance/batch-capacity.test.ts
```

### User Story 6

```text
Task T103: Package manifest contract in tests/repository/package-manifest.test.ts
Task T107: Raycast product README in README.md
Task T109: Repair/privacy docs in docs/repair-policy.md and docs/privacy.md
```

## Implementation Strategy

### MVP First

1. Complete Setup and Foundation.
2. Complete US1 Inspection.
3. Validate US1 independently against valid and ordinary malformed fixtures.
4. Treat this as an internal MVP only; do not publish until US3 hostile-input protections are complete.

### Safe Core Increment

1. Add US3 Safety immediately after or in parallel with US2.
2. Complete US2 Preparation and revalidation.
3. Validate that only final Healthy copies are promoted.
4. This establishes the complete local inspect-and-prepare product core.

### Full V1 Increment

1. Add US4 explicit delivery and manual handoff.
2. Add US5 sequential batch/cancellation/retry behavior.
3. Complete US6 replacement, docs, CI, assets, and legacy removal.
4. Complete all Polish gates before Store submission.

## Notes

- `[P]` means different files and no unresolved same-group dependency, not permission to ignore phase prerequisites.
- Tests for an audit rule or automatic repair must fail before its implementation and pass before the task is complete.
- Never use giant or executable malicious fixtures; encode hostile metadata deterministically with the fixture builder.
- Never modify, overwrite, rename, or remove a selected original EPUB.
- Do not stage, commit, publish, or run the app/build/test commands without the permissions required by `AGENTS.md`.
