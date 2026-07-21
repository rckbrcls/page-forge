# Implementation Plan: [FEATURE]

**Branch**: `[###-feature-name]` | **Date**: [DATE] | **Spec**: [link]

**Input**: Feature specification from `/specs/[###-feature-name]/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

[Extract from feature spec: primary requirement + technical approach from research]

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: [TypeScript version or NEEDS CLARIFICATION]

**Primary Dependencies**: [e.g., @raycast/api, a justified pure JS/TS archive or XML package]

**Storage**: [local EPUB input and explicitly selected output paths; Raycast preferences only when needed]

**Testing**: [TypeScript test runner; small EPUB and malicious-archive fixtures]

**Target Platform**: [Raycast extension runtime]

**Project Type**: [single-package public Raycast extension]

**Performance Goals**: [responsive Raycast UI; bounded archive processing and memory use]

**Constraints**: [EPUB-only; local processing; safe deterministic repairs; no external executable, service, or engine]

**Scale/Scope**: [small command set; inspect, prepare, and explicitly send Kindle-ready EPUBs]

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Verify against `.specify/memory/constitution.md`:

- **Mission fit**: Feature directly supports EPUB selection, health inspection,
  safe repair, corrected-copy generation, or explicit Kindle delivery.
- **Boundary**: Accept EPUB only. Reject conversion, editing, reading, library,
  cloud, account, desktop-app, AI, and generic-document scope.
- **Runtime**: Use TypeScript, React, `@raycast/api`, justified pure JS/TS npm
  packages, and Node.js APIs available in Raycast. Reject binaries, processes,
  Calibre, machine-installed EPUBCheck, and user-installed dependencies.
- **Archive safety**: Define limits and safe handling for traversal, absolute or
  escaping paths, ZIP bombs, duplicate entries, XML entities, symlinks, remote
  references, memory pressure, and UI responsiveness.
- **Repair safety**: Auto-repair only unambiguous, explainable, testable changes
  that preserve meaning. Ambiguity remains diagnostic-only.
- **Output and validation**: Never mutate an original. Create a collision-safe new
  output, revalidate it, compare reports, and reject new critical errors.
- **Architecture and types**: Keep UI separate from application, EPUB engine, and
  adapters. Use typed expected results and failures, not loose strings.
- **Tests and privacy**: Plan fixtures for every audit and repair; process locally;
  require explicit external delivery intent; protect credentials in Raycast secure
  preferences if email delivery is included.
- **Complexity**: Keep one package and one extension. Any exception has a written,
  approved constitutional amendment.

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)
<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
   for this feature. Keep a single TypeScript package and separate Raycast commands
   from application, EPUB-engine, and adapter code.
  The delivered plan must not include Option labels.
-->

```text
src/
├── commands/
├── application/
├── domain/
│   ├── audit/
│   ├── repair/
│   └── models/
└── adapters/
    ├── archive/
    ├── xml/
    └── filesystem/
tests/
└── fixtures/
```

**Structure Decision**: [Document the selected structure and reference the real
directories captured above]

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
