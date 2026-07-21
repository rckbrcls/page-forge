# Quickstart Validation Guide: Desktop App Migration

**Feature**: `001-desktop-app-migration`  
**Purpose**: Prove the desktop migration works end-to-end after implementation slices land  
**Date**: 2026-07-17

## Prerequisites

- macOS machine
- Calibre installed with `ebook-convert`, `ebook-meta`, and `ebook-polish` discoverable
- Sample files:
  - one valid EPUB
  - one EPUB with known structural issues (optional but recommended)
  - one MOBI
  - one text-based PDF
  - one small folder mixing supported/unsupported files
- For send validation only:
  - Amazon-authorized sender email
  - Kindle target email
  - SMTP app password/token

## Repository shape checks (migration mechanics)

1. Confirm product code lives under `PageForge/` (desktop app).
2. Confirm old Python TUI/CLI lives under `legacy/python-tui-cli/`.
3. Confirm `legacy/README.md` states reference-only status.
4. Confirm the primary launchable product is the desktop app, not the old TUI.

Expected:

- No contributor needs the legacy TUI to perform baseline workflows.

## Slice A — Readiness audit (P1)

1. Launch desktop app.
2. Confirm default surface is Readiness.
3. Drop a valid EPUB.
4. Run audit/diagnose.

Expected:

- Status is one of `ready` / `needs_fixes` / `blocked`
- Issues use allowed severities
- No output file is written for audit-only

Negative check:

- With Calibre quit/uninstalled, structural audit may still run; any Calibre-backed action shows recovery guidance.

## Slice B — Prepare Kindle-ready (P2)

1. From an EPUB that needs fixes, run Prepare/Fix.
2. Confirm output path.

Expected:

- Creates `*-kindle-ready.epub`
- Original source remains intact
- Report refreshes after prepare

MOBI path:

1. Drop MOBI
2. Prepare/Fix

Expected:

- MOBI treated as legacy input
- Kindle-ready EPUB produced when conversion/preparation succeeds

## Slice C — Convert and repair (P3)

1. Convert MOBI → EPUB
2. Convert PDF → EPUB
3. Convert EPUB → MOBI
4. Safe-repair an EPUB
5. Only if needed, run aggressive repair with explicit confirmation

Expected:

- Successful operations produce outputs and clear success states
- Safe repair default output is `*-repaired.epub`
- Aggressive repair is not the default action
- PDF path does not advertise OCR

## Slice D — Send and handoff (P4)

1. Open Settings
2. Create/edit a delivery profile
3. Save SMTP secret to Keychain
4. Send a ready EPUB through SMTP profile
5. Trigger Send to Kindle handoff action

Expected:

- Secret not present in config file
- Incomplete profile blocks send with guidance
- Successful send returns visible success result
- Handoff opens external Amazon path without automated login/upload

## Slice E — Batch (P5)

1. Open Batch
2. Choose a folder with mixed files
3. Run batch readiness prepare
4. Run batch convert and/or repair as available

Expected:

- Progress remains visible
- UI stays navigable
- Summary includes completed/skipped/failed style information
- Counts for readiness statuses are available after readiness batch

## Slice F — Metadata (P6)

1. Inspect an EPUB
2. Update title and/or author
3. Re-inspect

Expected:

- Fields display when available
- Update persists
- Missing metadata tool yields clear dependency error

## Slice G — Settings and logs (P7)

1. Open Settings and verify Calibre status
2. Open Logs during/after an operation
3. Confirm app update and Calibre update guidance are separate

Expected:

- Missing tools are named
- Recent log messages appear
- Update concerns are not conflated

## Parity oracle (optional, developer)

While porting domain rules, compare desktop outputs against legacy reference behavior on the same fixtures using archived code under `legacy/python-tui-cli` only as an oracle.

Do not require legacy runtime for normal product use.

## Exit criteria for migration MVP program

Migration planning is validated when:

- Desktop app covers baseline workflows from the spec
- Legacy TUI is archived and non-primary
- Filename/status/safety contracts hold
- Long operations remain non-blocking
- Quickstart slices A–D pass on a developer machine; E–G pass before calling full parity done
