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

**Language/Version**: [e.g., Swift 6 / SwiftUI, Python 3.11 transitional CLI or NEEDS CLARIFICATION]

**Primary Dependencies**: [e.g., SwiftUI, Calibre CLI tools, Security/Keychain or NEEDS CLARIFICATION]

**Storage**: [local files + app config; Keychain for secrets; no cloud DB by default]

**Testing**: [e.g., XCTest/Swift Testing for domain; pytest only for transitional Python surfaces]

**Target Platform**: [macOS desktop only]

**Project Type**: [native desktop utility app]

**Performance Goals**: [e.g., instant drop feedback, non-blocking UI during convert/repair, low idle memory]

**Constraints**: [mission-only scope; local-first; no DRM removal; no Amazon login automation; Calibre remains external engine]

**Scale/Scope**: [single-user local utility; small screen count; focused Kindle-ready workflow]

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Verify against `.specify/memory/constitution.md` and README baseline:

- **Mission fit**: Feature improves intake, readiness, conversion, repair,
  metadata cleanup, batch preparation, or Kindle send/handoff. Reject generic
  library-manager, cloud sync, or platform scope.
- **Fast/light/beautiful**: Design keeps the UI responsive and restrained. No
  Electron/web-shell runtime or unjustified heavy dependency.
- **Readiness-first**: Default user journey still centers Readiness; supporting
  surfaces stay secondary (Convert, Batch, Metadata, Settings, Logs).
- **Calibre boundary**: Conversion/metadata/polish remain Calibre-orchestrated.
  PageForge owns workflow, diagnosis, safe repair, setup/doctor, and delivery UX.
- **Safe local-first**: Local files, Keychain secrets, explicit transforms. No DRM
  removal. No Amazon login/upload automation. Aggressive repair only as labeled
  secondary mode. No OCR promises for scanned PDFs.
- **Status vocabulary**: Readiness uses `ready` / `needs_fixes` / `blocked`.
  Issues use `info` / `warning` / `error` / `fixable`.
- **Output contracts**: Keep `*-repaired.epub` distinct from
  `*-kindle-ready.epub`. Preserve CLI behavior during desktop migration unless a
  breaking change is explicit.
- **Architecture**: Domain logic lives in testable services; UI/CLI do not
  duplicate readiness/repair/conversion rules.
- **Complexity**: Any extra abstraction or surface has a written justification in
  Complexity Tracking.

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
  for this feature. Prefer the macOS desktop structure. Keep transitional Python
  paths only when the feature still touches the legacy CLI/TUI surface.
  The delivered plan must not include Option labels.
-->

```text
# Preferred: macOS SwiftUI desktop utility
PageForge/
├── App/
├── Features/
│   ├── DropIntake/
│   ├── Readiness/
│   ├── Prepare/
│   └── Delivery/
├── Domain/
│   ├── Models/
│   ├── Services/
│   └── Readiness/
├── Integrations/
│   ├── Calibre/
│   ├── Keychain/
│   └── Mail/
└── Resources/

PageForgeTests/
├── Domain/
├── Integrations/
└── Features/

# Transitional only: legacy Python CLI/TUI surface
src/page_forge/
tests/
```

**Structure Decision**: [Document the selected structure and reference the real
directories captured above]

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
