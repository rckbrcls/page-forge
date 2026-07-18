# Implementation Plan: Simplified Document Workflow

**Branch**: `002-simplify-document-workflow` (Spec Kit feature identifier; the
worktree remains on `main`) | **Date**: 2026-07-18 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from
`/specs/002-simplify-document-workflow/spec.md`

## Summary

Replace the seven-destination sidebar with one document queue that accepts many
EPUB, MOBI, and PDF files, prepares each item through the existing readiness and
conversion services, and exposes Save Files and Send to Kindle as the two primary
outcomes. Preserve the existing large drop component, add a secondary drop-capable
Add Files control to the standard toolbar, and move configuration into the native
single-instance Settings window.

The implementation remains a small native modular monolith. It adds only two
domain seams—intake validation and preparation orchestration—plus a local output
exporter. Existing Calibre, readiness, repair, config, Keychain, SMTP, logging,
and dependency services remain authoritative. The queue processes selected items
sequentially off the main actor so one failure is isolated without launching many
Calibre processes at once.

## Technical Context

**Language/Version**: Swift 5 language mode (`SWIFT_VERSION = 5.0`) with SwiftUI
and targeted AppKit interop

**Primary Dependencies**: SwiftUI, AppKit, Foundation,
UniformTypeIdentifiers, Security/Keychain, existing external Calibre tools
(`ebook-convert`, `ebook-meta`, `ebook-polish`); no new package dependency

**Storage**: User-selected local files; prepared outputs beside their sources by
the existing naming rules; explicit copies to a selected local folder; app config
in Application Support; SMTP secrets in Keychain; no database or cloud storage

**Testing**: XCTest domain/service tests and focused view-model tests with narrow
fakes for preparation, export, and delivery side effects

**Target Platform**: macOS 26+

**Project Type**: Native macOS desktop utility with one app target and one test
target

**Performance Goals**: Intake outcomes visible within two seconds for 50 files;
all conversion, preparation, export, and delivery work off the main actor; queue
selection, inspection, Settings, and new intake remain responsive during work

**Constraints**: One main workflow; local-first and explicit transforms; original
sources immutable; no DRM removal, OCR promise, Amazon login, or direct Amazon
upload; existing readiness vocabulary and output naming preserved; no app/build
execution during this planning task

**Scale/Scope**: Single-user local utility; up to 50 files in the acceptance
queue; EPUB/MOBI/PDF intake; sequential preparation and per-item save/send
outcomes; existing advanced metadata, repair, handoff, logs, and diagnostics
remain contextual rather than top-level navigation

## Constitution Check

*GATE: Evaluated before research and re-evaluated after design.*

### Pre-design gate

| Gate | Status | Notes |
|------|--------|-------|
| Mission fit | PASS | The feature narrows the app to intake, readiness, safe preparation, and Kindle outcomes |
| Fast/light/beautiful | PASS | One native screen, no new runtime or third-party dependency |
| Readiness-first | PASS | Readiness becomes an automatic part of Prepare Files rather than a removed capability |
| Calibre boundary | PASS | Existing services continue to orchestrate the external ebook engine |
| Safe local-first | PASS | Sources remain immutable; save/send require explicit intent; Keychain remains mandatory |
| Status vocabulary | PASS | Existing readiness statuses and severities remain unchanged |
| Output contracts | PASS | `*-kindle-ready.epub` and `*-repaired.epub` stay distinct |
| Architecture | PASS | Intake and preparation rules stay in domain services, not views |
| Complexity | PASS | Two focused services and one exporter replace multiple screen-specific coordinators |
| Baseline surface change | PASS with explicit product decision | The user explicitly requested one N-file workflow; folder batch is no longer a primary surface, while multi-item batch semantics remain |

### Post-design gate

| Gate | Status | Notes |
|------|--------|-------|
| Mission fit | PASS | Contracts contain only import, preparation, save, send, Settings, and contextual support |
| Fast/light/beautiful | PASS | Sequential background work and a two-control toolbar minimize resource and visual load |
| Readiness-first | PASS | Every EPUB/MOBI/PDF preparation ends with a readiness result |
| Calibre boundary | PASS | PDF/MOBI routing composes `ConversionService` and `ReadinessService`; it does not duplicate conversion |
| Safe local-first | PASS | Export uses copies, conflicts never overwrite silently, and delivery is profile-gated |
| Status/output contracts | PASS | Data model and contracts retain mandatory vocabularies and filenames |
| Architecture | PASS | Queue state belongs to one main-actor view model; side effects remain behind focused services |
| Accessibility | PASS | Drag operations have chooser, menu, keyboard, text status, focus, and progress alternatives |
| Complexity | PASS | No generic workflow framework, repository layer, or parallel execution system is introduced |

### Governance scope decision

The constitution's capability map still names Readiness, Convert, Batch, Send,
Metadata, Settings, and Logs as surfaces and preserves folder batch contracts. The
user has explicitly approved a simpler files-first product shape. This plan treats
those names as capabilities, not mandatory sidebar destinations:

- Readiness, conversion, safe repair, and multi-item processing become one
  preparation flow.
- Send moves to the main queue; Settings and Logs move to the Settings scene.
- Metadata and aggressive repair remain contextual advanced actions, not primary
  destinations.
- Folder batch intake is replaced by selecting or dropping N files. Domain folder
  services may remain for compatibility but are not surfaced by this feature.

A later constitution amendment is recommended to remove the stale surface list,
but this plan is not blocked because the feature request is the explicit product
change approval required by the current governance text.

## Project Structure

### Documentation (this feature)

```text
specs/002-simplify-document-workflow/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── intake-and-toolbar.md
│   ├── preparation-workflow.md
│   └── output-settings-and-delivery.md
├── checklists/
│   └── requirements.md
└── tasks.md                         # generated later by speckit-tasks
```

### Source Code (repository root)

```text
PageForge/
├── App/
│   ├── PageForgeApp.swift           # WindowGroup + Settings scene
│   ├── AppState.swift               # shared composition root, no destination routing
│   └── MainWorkflowView.swift       # replaces RootNavigationView/sidebar
├── Features/
│   ├── Workflow/
│   │   ├── DocumentWorkflowView.swift
│   │   ├── DocumentWorkflowViewModel.swift
│   │   └── DocumentQueueRow.swift
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   ├── SettingsViewModel.swift
│   │   └── ProfileEditorView.swift
│   └── Shared/
│       ├── FileDropIntakeView.swift
│       └── OperationStatusView.swift
├── Domain/
│   ├── Models/
│   │   └── DocumentWorkflowModels.swift
│   ├── Services/
│   │   ├── DocumentIntakeService.swift
│   │   ├── DocumentPreparationService.swift
│   │   ├── ReadinessService.swift
│   │   ├── ConversionService.swift
│   │   ├── RepairService.swift
│   │   └── DeliveryService.swift
│   └── Jobs/
│       └── OperationJobCoordinator.swift
├── Integrations/
│   ├── FileSystem/
│   │   └── PreparedOutputExporter.swift
│   ├── Calibre/
│   ├── Keychain/
│   └── Mail/
└── DesignSystem/

PageForgeTests/
├── Domain/
│   ├── DocumentIntakeServiceTests.swift
│   ├── DocumentPreparationServiceTests.swift
│   └── PreparedOutputExporterTests.swift
└── Features/
    └── DocumentWorkflowViewModelTests.swift

PageForge.xcodeproj/
└── project.pbxproj                # manual references and Sources membership
```

**Structure Decision**: Keep one app/test target and the current modular monolith.
The new Workflow feature owns presentation and ephemeral queue state. Domain
services own intake and format-routing rules. The existing Settings feature is
reused in a native Settings scene. Old top-level feature views/view models are
removed from the target after their remaining behavior is relocated; their domain
services remain when still used by the unified workflow.

The Xcode project uses explicit file references rather than filesystem-synchronized
groups. Every add, rename, removal, and test file therefore requires a small,
verified `project.pbxproj` update.

## Design Decisions

### One queue owner

`DocumentWorkflowViewModel` is the sole owner of the session queue and selected
rows. It lives on the main actor and derives aggregate UI state from item state.
It does not own conversion rules or mutate the filesystem directly.

### One intake path

The large drop zone, toolbar control, file importer, and File menu command all
produce `[URL]` and call the same intake service. Partial acceptance is normal:
valid documents append in stable order while every rejection has a reason.

### Sequential preparation

Selected queued items are prepared in order on background work. EPUB and MOBI
delegate to `ReadinessService.prepare`. PDF converts to a temporary EPUB, then
passes through readiness preparation with a final output named from the original
PDF. Temporary artifacts are cleaned on success and best-effort on failure.

Parallel Calibre jobs are rejected because the feature does not require them and
they increase resource contention, cancellation complexity, and ordering risk.

### Independent output actions

Preparation state is separate from save/send state. Saving copies prepared files
to one selected directory and never silently overwrites. Sending validates the
profile before starting and then reports each attachment independently. A later
failure never removes prior success.

### Native Settings scene

`PageForgeApp` declares `Settings { SettingsView() }`. A toolbar `SettingsLink`
opens or focuses that system-managed single window, also preserving the standard
Settings menu command. Queue state stays in the main scene owner and is not copied
into Settings.

### Cancellation boundary

The first implementation cancels queued items and stops scheduling new work. An
already running external conversion is allowed to finish, after which its item is
reconciled to a terminal state. Terminating child process trees is deferred until
`CalibreProcessRunner` has an explicit cancellation contract; the UI must not
claim immediate hard cancellation.

## Complexity Tracking

No constitution-violating architecture is required. The files-only intake is an
explicit product scope change, not additional technical complexity.

Rejected additions:

- A generic workflow engine: unnecessary for one linear queue.
- Parallel conversion scheduling: unnecessary for the acceptance scale.
- A repository layer or database: queue state is session-only and files remain
  authoritative.
- Custom `NSToolbar` or window registry: native SwiftUI toolbar and Settings
  scene satisfy the requirements.

## Phase 0 Research Summary

See [research.md](./research.md). All technical unknowns are resolved for design.
The exact drop modifier overload must be selected against the installed macOS 26
SDK during implementation; the contract does not depend on a newer SDK API.

## Phase 1 Design Summary

- [data-model.md](./data-model.md) defines queue, item, intake, preparation,
  export, and delivery states.
- [contracts/intake-and-toolbar.md](./contracts/intake-and-toolbar.md) defines the
  shared multi-file entry contract.
- [contracts/preparation-workflow.md](./contracts/preparation-workflow.md) defines
  format routing, progress, failure isolation, and cancellation.
- [contracts/output-settings-and-delivery.md](./contracts/output-settings-and-delivery.md)
  defines save, send, Settings, secrets, and conflict behavior.
- [quickstart.md](./quickstart.md) defines static and runnable acceptance checks.

## Implementation Phasing

1. Add workflow models, intake normalization, preparation orchestration, exporter,
   and deterministic domain tests.
2. Add the unified queue view model and focused state-transition tests.
3. Convert file intake to multi-URL behavior and create the single main workflow.
4. Add native toolbar/menu commands and the Settings scene.
5. Integrate save and per-file delivery outcomes.
6. Relocate contextual metadata/repair/log/handoff access and remove obsolete
   top-level views from the target.
7. Align README, migration documentation, AGENTS guidance, and constitution
   wording with the delivered single-workflow product.
8. Run static checks in-agent; Erick performs the forbidden build/test/app checks
   locally using the quickstart commands.

## Agent Context Update

No agent-context update script exists under `.specify/scripts`, so the required
automation could not be run. `AGENTS.md` remains the current runtime context. Its
surface map should be updated during implementation after the new workflow exists,
so documentation does not claim an undelivered UI.

