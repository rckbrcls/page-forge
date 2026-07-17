# AGENTS.md

## Language And Communication

- Always respond to the user in Portuguese.
- Always write application UI strings, CLI output, code, comments, identifiers, docs intended for the app, and tests in English unless the user explicitly asks for another language.
- Keep explanations direct and grounded in the repository. Prefer file paths, entrypoints, and actual contracts over generic advice.

## Hard Workflow Rules

- Never run build or run commands in this environment.
- Do not start the TUI, app, dev servers, browser previews, or commands that execute the app unless the user explicitly allows it.
- Do not create branches unless the user explicitly asks. Work on the current branch by default.
- Do not revert or overwrite user changes. If the worktree is dirty, inspect the relevant diff and work with it.
- Use `apply_patch` for manual file edits.
- Prefer `rg` / `rg --files` for search.

## Web Project Rule

- Whenever creating a web project, disable browser automatic translation features where applicable because they can mutate the DOM.

## Project Context

- Governance source: `.specify/memory/constitution.md` (currently v1.1.0).
- Product baseline source: `README.md`.
- PageForge is a macOS-only ebook preparation utility.
- Current shipped surface: Python terminal app (Textual TUI + Typer CLI).
- Target primary surface under the constitution: lightweight native macOS desktop app (Swift/SwiftUI), preserving the README workflow contracts.
- The console script is `page-forge = page_forge.cli:app`.
- Main entrypoints today:
  - `src/page_forge/cli.py`: Typer CLI and default TUI launch.
  - `src/page_forge/tui_app.py`: Textual TUI.
  - `src/page_forge/conversion.py`: EPUB/MOBI/PDF conversion and EPUB repair orchestration.
  - `src/page_forge/epub_repair.py`: safe EPUB ZIP/container/OPF structure repair.
  - `src/page_forge/readiness.py`: Kindle Readiness Doctor audit/fix/send handoff flow.
  - `src/page_forge/kindle.py`: SMTP Send to Kindle delivery.
  - `src/page_forge/config.py`: local config and macOS Keychain password storage.

## Product Positioning

- Do not frame PageForge as a Calibre replacement.
- Treat Calibre as the underlying ebook engine.
- PageForge should add value through a focused Kindle-ready workflow: diagnose, safely fix, prepare, optionally send, and provide Send to Kindle handoff.
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

- Preserve existing public behavior unless the user explicitly asks for a breaking change.
- Keep `repair-epub` behavior separate from Readiness Doctor behavior:
  - Existing repair output remains `*-repaired.epub`.
  - Readiness Doctor output uses `*-kindle-ready.epub`.
- Keep shared logic in services that can be used by both CLI and TUI. Avoid duplicating rules between `cli.py` and `tui_app.py`.
- For user-facing statuses, use the existing Readiness model vocabulary:
  - `ready`
  - `needs_fixes`
  - `blocked`
- For Readiness issues, use the existing severity vocabulary:
  - `info`
  - `warning`
  - `error`
  - `fixable`

## Dependencies And Platform

- Python version: `>=3.11`.
- Package manager/tooling: `uv`.
- Runtime dependencies: `typer`, `rich`, `textual`, `keyring`.
- Dev dependency: `pytest`.
- Calibre is external and required for conversion, metadata, and polish operations.
- macOS assumptions are intentional:
  - Homebrew for Calibre setup/update.
  - Calibre macOS app paths for `ebook-convert`, `ebook-meta`, and `ebook-polish`.
  - macOS Keychain via `keyring`.

## Verification

- Because build/run commands are forbidden by default, do not run app execution commands for verification.
- Use static checks that do not build or run the app when useful, such as:
  - `git diff --check`
  - targeted `rg`
  - focused file reads with `sed`
- If tests or app execution are needed, ask the user first and be explicit about the exact command.

## Git And Delivery

- Do not create a commit unless the user asks.
- Do not stage files unless the user asks.
- When summarizing work, mention files changed and explicitly state which verifications were not run because of the no build/run rule.
