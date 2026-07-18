# UI Navigation Contract

**Feature**: `001-desktop-app-migration`  
**Audience**: desktop app shell and feature surfaces

## Primary surfaces

The app exposes exactly these primary destinations:

1. `Readiness` (default)
2. `Convert`
3. `Batch`
4. `Send`
5. `Metadata`
6. `Settings`
7. `Logs`

No additional top-level product destinations are allowed without a constitution amendment.

## Default route

- On cold launch, selected destination MUST be `Readiness`.
- Settings and Logs MUST NOT be the default home.

## Intake contract

### Single-file surfaces (`Readiness`, `Convert`, `Send`, `Metadata`)
- Accept drag-and-drop of one supported file.
- Provide an explicit file picker action.
- If multiple files are dropped:
  - keep the first supported file, or
  - show a clear choice/error
  - do not silently process an arbitrary hidden subset without feedback

### Folder surfaces (`Batch`)
- Accept folder drop or folder picker.
- Show discovered eligible files before or during processing summary.

## Readiness surface contract

Required actions:
- Audit / Diagnose
- Prepare / Fix (safe Kindle-ready preparation)
- Open Send to Kindle handoff (when useful)
- Navigate or deep-link to Send with current output when ready

Required visible data:
- source file name/path
- status chip/text: `ready` | `needs_fixes` | `blocked`
- issue list with severity labels
- output path after prepare

## Convert surface contract

Required actions:
- Convert MOBI → EPUB
- Convert PDF → EPUB
- Convert EPUB → MOBI
- Safe repair EPUB
- Aggressive repair EPUB (explicit secondary confirmation)

Required visible data:
- source
- selected operation
- output path
- success/failure message

## Batch surface contract

Required actions:
- Batch readiness prepare/fix
- Batch repair
- Batch convert to EPUB

Required visible data:
- folder path
- progress
- summary counts
- per-item failures/skips access

## Send surface contract

Required actions:
- Send via selected profile
- Open handoff
- Jump to profile setup if incomplete

Required visible data:
- selected file
- selected profile
- profile readiness state
- last send result

## Metadata surface contract

Required actions:
- Inspect
- Update title
- Update author

## Settings surface contract

Required content:
- Calibre/dependency status
- recovery guidance when tools missing
- delivery profile management
- app update guidance
- Calibre update guidance as a separate action
- access path to logs

## Logs surface contract

- Show recent operation log entries newest-first or clearly ordered
- Entries include timestamp + message; level when available
- Long-running jobs should append progress-relevant messages

## Progress and responsiveness contract

- Any operation expected to take noticeable time MUST:
  - run off the main interaction path
  - expose running state
  - allow navigation among surfaces while running, unless a modal confirmation is active
- Failures MUST surface actionable text, not only generic “Error”.

## Visual restraint contract

- Prefer calm hierarchy over dense control grids
- Advanced/destructive options use confirmation or disclosure
- Aggressive repair never appears as the default repair action
