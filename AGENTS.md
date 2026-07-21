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
- Active product specification and plan: `specs/004-raycast-epub-workflow/`.
- Book Sender is a macOS-only, public, self-contained Raycast extension that checks, safely repairs when possible, and sends EPUB or PDF books to Kindle through one command.
- The final repository contains one npm package and one Raycast extension. Swift, SwiftUI, Xcode, Python, Calibre, and the previous desktop distribution are obsolete and must not be retained as a parallel product.
- Required dependency direction: `Raycast Commands -> Application Services -> EPUB Audit and Repair Engine -> Archive, XML, Filesystem, and Delivery Adapters`.
- Planned source areas:
  - `src/commands/`: Raycast view composition only
  - `src/application/`: intake, batch, inspect, prepare, and send orchestration
  - `src/domain/audit/`: EPUB rules and health derivation
  - `src/domain/repair/`: repair planning, application, and comparison
  - `src/domain/models/`: typed reports, failures, plans, results, and state
  - `src/adapters/`: archive, XML, filesystem, SMTP, and Raycast boundaries
  - `tests/fixtures/`: small valid, malformed, ambiguous, and malicious EPUB fixtures

## Product Positioning

- Book Sender is not a Calibre replacement and must not depend on Calibre or any installed ebook engine.
- Keep one focused pipeline: `Select Book -> Check -> Apply Safe EPUB Repairs -> Validate -> Confirm -> Send to Kindle`.
- Support EPUB inspection/repair and direct PDF delivery. Do not add conversion or MOBI, AZW, AZW3, or KFX handling.
- Expose exactly one command: Send Book to Kindle. Inspection and repair are internal stages of that command.
- Keep SMTP delivery and the official Send to Kindle web handoff distinct and explicit.
- Do not promise direct Amazon upload automation or Amazon login automation.
- Do not implement DRM removal.
- Keep the product fast, light, minimal, and visually calm.

## Implementation Conventions

- Keep one shared intake path for Finder-selected files and the Raycast file picker.
- Process a stable selected snapshot sequentially, one EPUB and one archive entry at a time, and isolate failures per file.
- Cancellation stops pending scheduling and cooperatively interrupts active streams; SMTP may become `delivery_unknown` after message data begins.
- Never modify or overwrite an original. EPUB repair uses a separate copy and preserves the original display name for Kindle delivery.
- Apply only deterministic permitted repairs and revalidate the written copy before delivery.
- Keep audit and repair rules out of React components.
- Use health states:
  - `healthy`
  - `repairable`
  - `needs_review`
  - `unsupported`
  - `unsafe`
- Use finding severities:
  - `info`
  - `warning`
  - `error`
  - `critical`
- Represent repairability separately from severity.
- Use typed expected failures; never expose raw archive, XML, filesystem, or SMTP exceptions.
- Every audit and automatic repair rule requires a focused fixture-backed test.
- Do not develop or preserve production features in obsolete `PageForge/` or `legacy/` trees.

## Dependencies And Platform

- Product surface: TypeScript, React, `@raycast/api`, and Node.js APIs available in Raycast.
- Planned archive/XML/delivery dependencies: `yauzl`, `yazl`, `saxes`, and `nodemailer`, plus narrowly justified integrity/path helpers.
- Tests: Vitest with small deterministic EPUB fixtures.
- Secrets: Raycast password preferences; never direct Keychain access, project files, logs, or remote storage.
- Forbidden: native binaries, helper processes, executable downloads, Calibre, installed EPUBCheck, Python, Java, Docker, local services, and user-installed processing tools.

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
