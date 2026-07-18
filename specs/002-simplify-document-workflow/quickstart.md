# Quickstart Validation Guide: Simplified Document Workflow

**Feature**: `002-simplify-document-workflow`  
**Purpose**: Validate the single-screen document queue after implementation  
**Date**: 2026-07-18

## Important Execution Boundary

Project instructions forbid agents from building, testing, launching, previewing,
or running the app by default. Static checks may be performed by the agent. The
`xcodebuild` and app interaction steps below are commands and scenarios for Erick
to run locally after implementation.

## Prerequisites

- macOS 26+
- Xcode capable of building the existing `PageForge.xcodeproj`
- Calibre installed with `ebook-convert`, `ebook-meta`, and `ebook-polish`
  discoverable
- Test inputs:
  - one valid EPUB;
  - one EPUB with safe-fix issues;
  - one MOBI;
  - one text-based PDF;
  - one scanned/image-only PDF;
  - one unsupported file;
  - two paths resolving to the same file, if available.
- For delivery only:
  - an Amazon-authorized sender address;
  - Kindle recipient address;
  - SMTP app password/token stored through Settings.

## Static Repository Checks

Run from the repository root:

```sh
git diff --check
rg -n "NavigationSplitView|AppDestination" PageForge
rg -n "allowsMultipleSelection|providers\.first" PageForge/Features/Shared/FileDropIntakeView.swift
rg -n "Settings \{|SettingsLink|toolbar" PageForge/App PageForge/Features
rg -n "DocumentWorkflow|DocumentPreparation|DocumentIntake|PreparedOutputExporter" PageForge PageForgeTests
```

Expected after implementation:

- `git diff --check` reports no whitespace errors.
- The main app no longer depends on `NavigationSplitView` or `AppDestination`.
- File intake allows multiple selection and no longer processes only the first
  dropped provider.
- The native Settings scene and Settings toolbar link are present.
- New workflow files and tests are referenced by `PageForge.xcodeproj`.

## Local Build and Test Commands

Erick may run:

```sh
xcodebuild test \
  -project PageForge.xcodeproj \
  -scheme PageForge \
  -destination 'platform=macOS'
```

If a build-only check is needed:

```sh
xcodebuild build \
  -project PageForge.xcodeproj \
  -scheme PageForge \
  -destination 'platform=macOS'
```

Expected:

- Intake, preparation routing, exporter, and workflow view-model tests pass.
- No missing project-file reference or target-membership error appears.

## Scenario A: Empty State and Intake Paths

1. Launch PageForge with an empty queue.
2. Confirm the preserved large drag-and-drop component is visually dominant.
3. Add EPUB, MOBI, and PDF together using Add Files.
4. Add another file by dropping it on the toolbar Add Files target.
5. Add another file by dropping it on the large target.
6. Use the File menu/keyboard Add Files command.

Expected:

- All entry paths append to one queue.
- Toolbar target highlights only during a valid drag.
- No file starts preparation automatically.
- The toolbar contains Add Files and Settings without recreating navigation.
- Keyboard and VoiceOver users can identify and activate both commands.

## Scenario B: Partial Intake and Deduplication

1. In one intake, choose a valid EPUB, unsupported file, and duplicate path.
2. If available, add the same file through a symlink or alias.
3. Try dropping a folder and an unreadable/missing placeholder.

Expected:

- The valid EPUB remains accepted.
- Every rejected item has its own reason.
- Duplicate canonical identities appear only once.
- Existing queue selection and progress are unchanged.
- Removing a row does not delete any local file.

## Scenario C: Mixed Preparation Queue

1. Select one EPUB, one MOBI, and one text-based PDF.
2. Activate Prepare Files.
3. While work runs, inspect rows, change selection, add a new file, and open
   Settings.

Expected:

- Snapshot items run in stable order and one at a time.
- Interface remains responsive.
- New intake appends as queued and is not silently added to the active snapshot.
- EPUB, MOBI, and PDF each end with an independent result.
- Successful outputs are `<source-stem>-kindle-ready.epub`.
- Original files remain unchanged.
- Closing Settings does not change the queue.

## Scenario D: PDF and Failure Isolation

1. Prepare a text-based PDF and an image-only/scanned PDF alongside a valid EPUB.
2. Repeat with Calibre conversion unavailable.
3. Move or delete one queued source before its turn begins.

Expected:

- PDF follows conversion and then readiness preparation.
- The app never claims OCR and warns that scanned results may be poor.
- Temporary EPUB paths are not shown as final results and are cleaned up.
- Missing Calibre or a missing source affects only its item.
- Other eligible files continue.
- Dependency failure provides Open Settings recovery.

## Scenario E: Output Collision and Retry

1. Pre-create the expected `*-kindle-ready.epub` output.
2. Prepare the corresponding source with overwrite disabled.
3. Resolve the conflict and retry.

Expected:

- Existing output is not overwritten silently.
- Item reports attention/failure with a recovery path.
- Retry transitions the item back through queued/preparing to its final status.

## Scenario F: Save Files

1. Select several ready items.
2. Choose Save Files and select a writable folder.
3. Repeat with one destination filename already present.
4. Repeat with an unwritable destination or insufficient space fixture if safe.

Expected:

- Each non-conflicting file is copied and reports its destination.
- A conflict fails only that output unless replacement was explicitly confirmed.
- Prepared outputs and original sources remain in place.
- Preparation remains ready even when save fails.

## Scenario G: Send to Kindle

1. With an incomplete profile, select ready outputs and choose Send to Kindle.
2. Open Settings from the recovery action and complete the profile.
3. Send two small outputs.
4. Simulate or observe a network/auth failure for one attempt.

Expected:

- Incomplete preflight sends nothing.
- Settings opens as one window and focuses the same instance on repeat activation.
- Each attachment has a separate sent/failed result.
- A later failure does not erase an earlier success.
- No credential appears in config, logs, UI messages, or captured errors.

## Scenario H: Contextual Advanced Capabilities

1. Select an item and open its advanced actions.
2. Inspect/edit metadata where eligible.
3. On an appropriate failed EPUB, inspect the explicitly labeled aggressive
   repair action.
4. Open troubleshooting/logs and Amazon handoff from Settings.

Expected:

- These capabilities remain available without top-level destinations.
- Aggressive repair is never the default and requires explicit confirmation.
- Handoff does not automate Amazon login or upload.

## Scenario I: Cancellation and Quit Boundary

1. Start a multi-item preparation sequence.
2. Cancel while one external operation is active.
3. Observe queued and active rows.
4. Attempt to close/quit during active work.

Expected:

- No new queued item starts after cancellation.
- Pending snapshot items become cancelled consistently.
- The UI does not falsely claim that an already running external process stopped
  immediately.
- The active item reconciles to its actual terminal outcome.
- Close/quit behavior explains active work and does not silently corrupt outputs.

## Acceptance Exit Criteria

- One main screen replaces all top-level workflow destinations.
- 50-file intake remains responsive and reports every outcome.
- EPUB/MOBI/PDF preparation produces per-item results and preserves originals.
- Save and Send are directly available for selected ready outputs.
- Settings is native, separate, single-instance, and queue-safe.
- Existing readiness/status/output/security contracts remain intact.
- All static checks and local tests pass; visual and interactive scenarios are
  confirmed on macOS.

