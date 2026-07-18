# AGENTS.md

## Language And Communication

- Always respond to the user in Portuguese.
- Always write application UI strings, CLI output, code, comments, identifiers, docs intended for the app, and tests in English unless the user explicitly asks for another language.
- Keep explanations direct and grounded in the repository. Prefer file paths, entrypoints, and actual contracts over generic advice.

## Hard Workflow Rules

- Never run build or run commands in this environment.
- Do not start the app, TUI, dev servers, browser previews, or commands that execute the app unless the user explicitly allows it.
- Do not create branches unless the user explicitly asks. Work on the current branch by default.
- Do not revert or overwrite user changes. If the worktree is dirty, inspect the relevant diff and work with it.
- Use `apply_patch` for manual file edits.
- Prefer `rg` / `rg --files` for search.

## Web Project Rule

- Whenever creating a web project, disable browser automatic translation features where applicable because they can mutate the DOM.

## Project Context

- Governance source: `.specify/memory/constitution.md`.
- Product baseline + workflow docs: `README.md`, `docs/desktop-migration.md`, `specs/002-simplify-document-workflow/`.
- PageForge is a macOS-only ebook preparation utility.
- **Primary surface**: native SwiftUI desktop app in `PageForge/` via `PageForge.xcodeproj`.
- **Legacy surface**: Python TUI/CLI archived under `legacy/python-tui-cli/` for reference only.
- Main desktop areas:
  - `PageForge/App/`: app entry, commands, and main window composition
  - `PageForge/Features/Workflow/`: the single document queue and primary actions
  - `PageForge/Features/Settings/`: the separate native Settings window
  - `PageForge/Features/Shared/`: shared intake and presentation components
  - `PageForge/Domain/`: models, services, jobs
  - `PageForge/Integrations/`: Calibre, Keychain, Mail, FileSystem
  - `PageForgeTests/`: domain tests

## Product Positioning

- Do not frame PageForge as a Calibre replacement.
- Treat Calibre as the underlying ebook engine.
- PageForge adds value through one focused Kindle-ready workflow: add local files, diagnose and safely prepare them, then save or send the results.
- The default experience is files-first and queue-first, with no mode sidebar.
- Readiness, conversion, and delivery are steps in the main workflow rather than peer destinations.
- Metadata, advanced repair, and troubleshooting remain contextual capabilities.
- Configuration belongs in the separate native Settings window.
- For Kindle delivery, keep two paths clear:
  - SMTP email delivery through configured profiles.
  - Handoff to Amazon Send to Kindle web/app/USB flow.
- Do not promise direct Amazon upload automation or Amazon login automation.
- Do not implement DRM removal.
- Do not promise OCR for scanned PDFs.
- Keep the product fast, light, minimal, and visually calm.

## Implementation Conventions

- Keep one shared intake path for drag-and-drop, picker, toolbar, and File menu.
- Process a stable selected snapshot sequentially and isolate failures per file.
- New files added during processing remain queued for a later run.
- Cancellation stops pending scheduling; do not claim hard cancellation of an active Calibre process.
- Keep `repair` behavior separate from Readiness prepare behavior:
  - Repair output remains `*-repaired.epub`.
  - Readiness prepare output uses `*-kindle-ready.epub`.
- Keep shared logic in domain services. Avoid embedding readiness/repair/conversion rules in SwiftUI views.
- Do not restore separate top-level Readiness, Convert, Batch, Send, Metadata, or Logs navigation without an approved product change.
- For user-facing statuses, use:
  - `ready`
  - `needs_fixes`
  - `blocked`
- For Readiness issues, use:
  - `info`
  - `warning`
  - `error`
  - `fixable`
- Do not develop new features in `legacy/`.

## Dependencies And Platform

- Desktop: Swift / SwiftUI, macOS 26+
- External: Calibre tools (`ebook-convert`, `ebook-meta`, `ebook-polish`)
- Secrets: macOS Keychain
- Optional discovery overrides: `EBOOK_CONVERT_PATH`, `EBOOK_META_PATH`, `EBOOK_POLISH_PATH`
- Legacy Python tree remains only as reference under `legacy/python-tui-cli/`

## Verification

- Because build/run commands are forbidden by default, do not run app execution commands for verification.
- Use static checks that do not build or run the app when useful, such as:
  - `git diff --check`
  - targeted `rg`
  - focused file reads
- If tests or app execution are needed, ask the user first and be explicit about the exact command.

## Git And Delivery

- Do not create a commit unless the user asks.
- Do not stage files unless the user asks.
- When summarizing work, mention files changed and explicitly state which verifications were not run because of the no build/run rule.
