<!--
Sync Impact Report
- Version change: 1.0.0 → 1.1.0
- Bump rationale: README-grounded rewrite; expanded product baseline, workflow
  surface, operational contracts, and explicit current-vs-target UI direction
- Modified principles:
  - I. Mission-First Minimalism → I. Kindle-Ready Ebook Workflow Mission
  - II. Lightweight Native Performance → II. Fast, Light, Beautiful Surface
  - III. Calibre Engine Boundary → III. Calibre-Powered Engine Boundary
  - IV. Safe Local-First Operations → IV. Safe Local-First Operations (expanded)
  - V. Calm Premium Interface → V. Readiness-First Progressive UI
- Added sections:
  - Product Baseline (from README)
  - Capability Map
  - Operational Contracts
- Removed sections: none
- Templates requiring updates:
  - .specify/templates/plan-template.md → ✅ updated
  - .specify/templates/spec-template.md → ✅ updated
  - .specify/templates/tasks-template.md → ✅ updated
  - .specify/templates/checklist-template.md → ✅ updated
  - .specify/templates/commands/*.md → ⚠ pending (directory absent)
  - AGENTS.md → ✅ updated
  - README.md → ⚠ pending (still documents current Python TUI as primary surface)
- Source of truth used for this amendment:
  - README.md (full)
  - AGENTS.md
  - User direction: desktop app that remains fast, light, minimal, and beautiful
- Follow-up TODOs:
  - Update README product story when desktop surface becomes primary
  - Keep Python CLI contracts stable during desktop migration unless a breaking
    change is explicitly approved
-->

# PageForge Constitution

## Core Principles

### I. Kindle-Ready Ebook Workflow Mission
PageForge is a macOS product for preparing and managing ebook workflows. Its
mission is to turn scattered ebook files into clean, ready-to-use books through
conversion, repair, metadata cleanup, batch processing, and Kindle delivery.

The non-negotiable primary flow is:

`intake → readiness diagnose → safe fix/prepare → convert when needed → send or hand off`

Every feature MUST strengthen that mission. PageForge MUST NOT become a Calibre
replacement, generic digital library, reader social app, storefront, cloud sync
service, or plugin platform.

Rationale: The README already defines PageForge as a focused preparation utility.
Breadth without that spine dilutes quality, speed, and trust.

### II. Fast, Light, Beautiful Surface
PageForge MUST stay fast, lightweight, and visually calm. Local interactions
MUST feel immediate. Long-running conversion, repair, batch, setup, and update
work MUST run without freezing the interface and MUST expose progress or clear
status.

Target product surface:

- Primary: native macOS desktop app (Swift/SwiftUI)
- Secondary during transition: existing Python TUI/CLI documented in README

The desktop surface MUST prioritize drag-and-drop intake, low overhead, and a
premium but restrained macOS aesthetic. Electron, generic web-shell runtimes, and
unjustified heavy dependencies are FORBIDDEN. Beauty MUST come from hierarchy,
spacing, clarity, and progressive disclosure, not ornament or dashboard clutter.

Rationale: The product is a personal utility. Speed and beauty are part of the
job, not polish afterthoughts.

### III. Calibre-Powered Engine Boundary
PageForge has two layers:

1. PageForge experience and workflow orchestration
2. Calibre as the native ebook engine for `ebook-convert`, `ebook-meta`, and
   `ebook-polish`

PageForge MUST orchestrate Calibre for conversion, metadata mutation, and polish.
PageForge-owned logic covers readiness diagnosis, safe structural repair
workflow, delivery/handoff UX, setup/doctor guidance, and focused batch
orchestration. The product MUST NOT claim to replace Calibre.

Missing or custom Calibre installs MUST be handled explicitly:

- doctor/setup guidance
- Homebrew-oriented install/update paths on macOS
- support for custom tool paths when provided

Rationale: Format edge cases are hard. Reusing Calibre keeps PageForge small and
useful while the product owns the Kindle-ready workflow.

### IV. Safe Local-First Operations
All primary work MUST operate on local user-provided files. Secrets for SMTP or
app tokens MUST live in macOS Keychain and MUST NOT be written to config files.

Safety rules:

- Prefer safe repairs and explicit user-initiated transforms
- Aggressive repair (`EPUB -> MOBI -> EPUB`) is allowed only as a clearly labeled
  secondary mode when safe repair is insufficient
- DRM removal is FORBIDDEN
- Amazon login automation and direct Amazon upload automation are FORBIDDEN
- Delivery is limited to:
  - SMTP Send to Kindle through configured local profiles
  - explicit handoff to Amazon Send to Kindle web/app/USB flows
- PDF conversion MUST remain direct Calibre conversion without OCR promises;
  scanned PDFs may produce poor or empty output

Readiness vocabulary is mandatory:

- statuses: `ready`, `needs_fixes`, `blocked`
- severities: `info`, `warning`, `error`, `fixable`

Rationale: Trust depends on local control, explicit actions, and honest limits.

### V. Readiness-First Progressive UI
Readiness is the main workflow. The default entry experience MUST open on
Readiness, not on settings or secondary tools.

Core surfaces derived from the README:

- Readiness
- Convert
- Batch
- Send to Kindle
- Metadata
- Settings
- Logs

UI rules:

- Readiness and intake come first
- Convert, Batch, Metadata, Settings, and Logs are supporting surfaces
- Settings holds profile configuration, Calibre status, Kindle profile status,
  update actions, and log access
- Advanced or destructive controls use progressive disclosure
- The UI MUST NOT present every internal engine concept as equal primary
  navigation

Rationale: The README already centers Kindle preparation. The interface should
make that order obvious.

## Product Baseline

This constitution treats the current README capability set as the product
baseline that desktop work MUST preserve unless an explicit breaking change is
approved.

### Capability Map
- Interactive primary app experience (today: Textual TUI; target: SwiftUI desktop)
- Readiness Doctor for Kindle-focused EPUB/MOBI audit and safe fixes
- Safe EPUB repair plus optional aggressive MOBI roundtrip mode
- Direct conversion: `MOBI -> EPUB`, `PDF -> EPUB`, `EPUB -> MOBI`
- Folder batch repair and conversion
- Metadata inspection and title/author updates
- Send to Kindle through SMTP profiles or Send to Kindle handoff
- Calibre setup checks with visible feedback
- App and Calibre update actions
- Command-line shortcuts for automation and one-off tasks during transition

### Operational Contracts
- Readiness audit without write: inspect only
- Readiness with fix: write `*-kindle-ready.epub`
- Structural repair command/output remains distinct: `*-repaired.epub`
- MOBI is legacy input: convert to EPUB before full readiness preparation
- Folder readiness/conversion/repair remain supported workflows
- `doctor` checks local dependencies
- `setup` can guide or install Calibre on macOS via Homebrew-oriented flow
- `update` updates PageForge by default; Calibre updates only when explicitly
  requested because Calibre is a separate native macOS app
- Custom Calibre binary locations may be provided through configured paths/env
- SMTP sender email authorization on Amazon remains a user responsibility
- Named local profiles are supported for delivery configuration

### In Scope
- macOS-only ebook preparation utility
- Kindle-ready diagnosis, repair, conversion, light metadata edits, batch ops
- SMTP delivery and Send to Kindle handoff
- Local config, Keychain secrets, setup/doctor/update guidance

### Out of Scope
- Multi-platform product shells unless this constitution is amended
- Cloud library sync, accounts, collaboration, marketplace, or social features
- Full library-manager identity as the product center
- Reader features beyond what preparation requires
- OCR pipeline for scanned PDFs
- DRM circumvention
- Amazon login or upload automation
- Rebuilding Calibre conversion internals inside PageForge

## Architecture & Quality

### Architecture Rules
- Use a modular monolith with clear boundaries:
  - UI surface
  - domain/workflow services
  - Calibre integration
  - config and secrets
  - delivery
- Domain rules for readiness, repair, conversion orchestration, and delivery
  preconditions MUST live in shared services/models
- UI and CLI entrypoints MUST NOT duplicate business rules
- During desktop migration, preserve existing public CLI behavior unless a
  breaking change is explicitly requested
- New mission-critical behavior SHOULD be implemented in a form reusable by the
  primary UI and any secondary automation surface

### Quality Gates
- Every feature plan MUST pass a Constitution Check before design acceptance
- Performance-sensitive paths MUST keep the UI responsive during convert/repair/
  batch/update work
- Security-sensitive changes (Keychain, SMTP, file writes, process execution)
  MUST use safe defaults and explicit user intent
- Tests are required for:
  - readiness status/severity rules
  - repair safety invariants
  - conversion orchestration contracts
  - delivery preconditions
- UI work MUST preserve accessibility basics: readable contrast, keyboard access
  to primary actions, and clear status text

### Complexity Policy
- Choose the simplest design that satisfies the README mission
- New abstractions require a written reason and a rejected simpler alternative
- Do not invent platform features, plugin systems, or cloud infrastructure for
  speculative future use

## Governance

This constitution supersedes conflicting convenience decisions and aspirational
scope. When docs, plans, or code conflict with this file, this file wins until
amended.

Primary references:

- Product baseline: `README.md`
- Runtime agent guidance: `AGENTS.md`
- Governance source: `.specify/memory/constitution.md`

### Amendments
1. State motivation, affected principles, and product impact.
2. Update this file with explicit normative language (`MUST` / `FORBIDDEN`).
3. Bump version with semantic versioning:
   - MAJOR: incompatible principle removals or redefinitions
   - MINOR: new principles/sections or materially expanded guidance
   - PATCH: clarifications and non-semantic refinements
4. Propagate changes to Speckit templates and `AGENTS.md`.
5. Record dates in ISO format (`YYYY-MM-DD`).

### Compliance Review
- Specs, plans, tasks, and checklists MUST include constitution review
- Reject work that violates mission, safety, Calibre boundary, or UI order
- Temporary exceptions require Complexity Tracking with a simpler rejected
  alternative
- Desktop migration work MUST preserve README workflow contracts unless an
  explicit product change is approved

**Version**: 1.1.0 | **Ratified**: 2026-07-17 | **Last Amended**: 2026-07-17
