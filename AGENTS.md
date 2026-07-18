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
- Product baseline + migration docs: `README.md`, `docs/desktop-migration.md`, `specs/001-desktop-app-migration/`.
- PageForge is a macOS-only ebook preparation utility.
- **Primary surface**: native SwiftUI desktop app in `PageForge/` via `PageForge.xcodeproj`.
- **Legacy surface**: Python TUI/CLI archived under `legacy/python-tui-cli/` for reference only.
- Main desktop areas:
  - `PageForge/App/`: app entry and navigation
  - `PageForge/Features/`: Readiness, Convert, Batch, Send, Metadata, Settings, Logs
  - `PageForge/Domain/`: models, services, jobs
  - `PageForge/Integrations/`: Calibre, Keychain, Mail, FileSystem
  - `PageForgeTests/`: domain tests

## Product Positioning

- Do not frame PageForge as a Calibre replacement.
- Treat Calibre as the underlying ebook engine.
- PageForge adds value through a focused Kindle-ready workflow: diagnose, safely fix, prepare, optionally send, and provide Send to Kindle handoff.
- Default experience is Readiness-first.
- Supporting surfaces: Convert, Batch, Send to Kindle, Metadata, Settings, Logs.
- For Kindle delivery, keep two paths clear:
  - SMTP email delivery through configured profiles.
  - Handoff to Amazon Send to Kindle web/app/USB flow.
- Do not promise direct Amazon upload automation or Amazon login automation.
- Do not implement DRM removal.
- Do not promise OCR for scanned PDFs.
- Keep the product fast, light, minimal, and visually calm.

## Implementation Conventions

- Keep `repair` behavior separate from Readiness prepare behavior:
  - Repair output remains `*-repaired.epub`.
  - Readiness prepare output uses `*-kindle-ready.epub`.
- Keep shared logic in domain services. Avoid embedding readiness/repair/conversion rules in SwiftUI views.
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

- Desktop: Swift / SwiftUI, macOS 14+
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
