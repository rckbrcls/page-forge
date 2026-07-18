<!--
Sync Impact Report
- Version change: 1.1.0 → 2.0.0
- Bump rationale: replace the mode-based and folder-first baseline with one
  files-first queue while retaining advanced capabilities contextually
- Product impact: one main queue and one Settings window replace peer workflow
  destinations; Calibre, local-file safety, and delivery boundaries are unchanged
- Modified principles:
  - I. Kindle-Ready Ebook Workflow Mission: queue-first primary flow
  - II. Fast, Light, Beautiful Surface: desktop app is the sole primary surface
  - V. Readiness-First Progressive UI → V. Files-First Progressive UI
- Added sections: none
- Removed sections: none
- Templates and guidance updated:
  - .specify/templates/tasks-template.md
  - AGENTS.md
  - README.md
  - docs/desktop-migration.md
- Reviewed without changes: plan-template.md, spec-template.md, and
  checklist-template.md
- Source of truth: specs/002-simplify-document-workflow/ and the delivered native
  desktop workflow
- Follow-up TODOs: none
-->

# PageForge Constitution

## Core Principles

### I. Kindle-Ready Ebook Workflow Mission
PageForge is a macOS product for preparing ebook files for Kindle. Its mission is
to turn a user-selected collection of local EPUB, MOBI, and PDF files into
Kindle-ready EPUB outputs that can be saved or sent.

The non-negotiable primary flow is:

`add files → prepare sequentially → save or send`

Every feature MUST strengthen that mission. PageForge MUST NOT become a Calibre
replacement, generic digital library, reader social app, storefront, cloud sync
service, or plugin platform.

Rationale: The README already defines PageForge as a focused preparation utility.
Breadth without that spine dilutes quality, speed, and trust.

### II. Fast, Light, Beautiful Surface
PageForge MUST stay fast, lightweight, and visually calm. Local interactions
MUST feel immediate. Long-running preparation, conversion, export, and delivery
work MUST run without freezing the interface and MUST expose progress or clear
status.

The native macOS desktop app is the primary product surface. The archived Python
TUI/CLI is reference material only and MUST NOT constrain the desktop workflow.

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
workflow, delivery/handoff UX, setup/doctor guidance, and focused queue
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

### V. Files-First Progressive UI
The default experience MUST be one files-first document queue, not a mode picker,
sidebar, dashboard, settings screen, or collection of peer workflow destinations.

UI rules:

- Drag-and-drop, picker, toolbar, and File menu MUST feed one shared intake path
- EPUB, MOBI, and PDF items MUST coexist in one stable queue
- Prepare, Save Files, and Send to Kindle MUST be the obvious primary actions
- Settings MUST open in the native separate Settings window
- Readiness details, metadata, advanced repair, logs, and troubleshooting MUST be
  contextual or progressively disclosed rather than top-level destinations
- Advanced or destructive controls use progressive disclosure
- The UI MUST NOT present every internal engine concept as equal primary
  navigation

Rationale: A single queue keeps the common task obvious while preserving expert
capabilities without turning engine concepts into navigation.

## Product Baseline

This constitution treats the files-first desktop workflow as the product
baseline. Capability preservation does not require preserving legacy navigation,
folder-oriented entrypoints, or one screen per engine operation.

### Capability Map
- One native macOS queue for multi-file EPUB, MOBI, and PDF intake
- Sequential preparation with independent per-file progress and results
- Readiness diagnosis and safe preparation inside the primary workflow
- Safe EPUB repair plus optional aggressive MOBI roundtrip mode
- Required conversion: `MOBI -> EPUB` and `PDF -> EPUB` before preparation
- Metadata inspection and repair as contextual advanced capabilities
- Local output export plus SMTP Send to Kindle or explicit handoff
- Calibre setup checks with visible feedback
- App and Calibre guidance in Settings

### Operational Contracts
- Readiness audit without write: inspect only
- Readiness with fix: write `*-kindle-ready.epub`
- Structural repair command/output remains distinct: `*-repaired.epub`
- MOBI is legacy input: convert to EPUB before full readiness preparation
- Multi-file queue processing replaces folder-first batch as the primary model
- Settings reports local dependency status and provides setup guidance
- PageForge and Calibre update guidance remain separate because Calibre is a
  separate native macOS app
- Custom Calibre binary locations may be provided through configured paths/env
- SMTP sender email authorization on Amazon remains a user responsibility
- Named local profiles are supported for delivery configuration

### In Scope
- macOS-only ebook preparation utility
- Kindle-ready diagnosis, repair, conversion, light metadata edits, and queued processing
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
- UI and legacy entrypoints MUST NOT duplicate business rules
- New mission-critical behavior SHOULD be implemented in a form reusable by the
  primary UI and any secondary automation surface

### Quality Gates
- Every feature plan MUST pass a Constitution Check before design acceptance
- Performance-sensitive paths MUST keep the UI responsive during preparation,
  conversion, export, and delivery work
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
- Product work MUST preserve the single-queue files-first workflow unless an
  explicit constitution amendment approves a different primary model

**Version**: 2.0.0 | **Ratified**: 2026-07-17 | **Last Amended**: 2026-07-18
