# Research: Desktop App Migration

**Feature**: `001-desktop-app-migration`  
**Date**: 2026-07-17

## 1. Primary product surface

**Decision**: Native macOS desktop app with SwiftUI as the primary UI framework.

**Rationale**:
- Constitution requires a fast, light, beautiful macOS utility.
- Drag-and-drop, Keychain, process orchestration, and system look-and-feel are first-class on Apple platforms.
- User explicitly requested desktop SwiftUI migration.

**Alternatives considered**:
- **Keep Python Textual TUI**: rejects the desktop/drag-drop product goal.
- **Tauri/web shell**: usable, but heavier and less native; weaker fit for a calm macOS utility.
- **Electron**: rejected by constitution and weight goals.

## 2. Runtime strategy for existing Python code

**Decision**: Archive the Python TUI/CLI under `legacy/` and reimplement domain behavior in Swift. Do not ship a Python sidecar.

**Rationale**:
- User asked to move the old TUI to legacy and use it only as inspiration.
- Sidecar packaging on macOS creates PATH, codesign, update, and support complexity.
- Domain size is manageable: readiness/repair/conversion orchestration, not a full conversion engine.

**Alternatives considered**:
- **Swift UI + Python backend process**: faster prototype, poor long-term product shape.
- **Maintain both surfaces indefinitely**: doubles cost and contradicts migration intent.

## 3. Calibre integration

**Decision**: Discover and invoke Calibre tools (`ebook-convert`, `ebook-meta`, `ebook-polish`) through external process execution, preserving current discovery order and env overrides as behavioral reference.

**Rationale**:
- Current product already depends on Calibre as the engine.
- Constitution forbids reimplementing full conversion pipelines.
- Clear missing-tool states are already part of the product promise.

**Alternatives considered**:
- **Bundle Calibre**: huge distribution cost and licensing/support burden.
- **Pure Swift conversion stack**: out of scope and high risk.

**Reference behavior**:
- `legacy` module equivalents of current `calibre.py` discovery paths:
  - env vars
  - `PATH`
  - `/Applications/calibre.app/Contents/MacOS`
  - Homebrew bin locations

## 4. EPUB readiness and repair ownership

**Decision**: Port PageForge-owned EPUB structural diagnosis and safe repair into Swift domain services. Keep aggressive repair as an explicit secondary path that may orchestrate Calibre roundtrips.

**Rationale**:
- Readiness Doctor and safe repair are product differentiators.
- Legacy logic already separates PageForge structure work from Calibre conversion/polish.
- Output contracts must stay stable.

**Alternatives considered**:
- **Always call Calibre polish only**: loses current structure-audit specificity.
- **Defer repair to later version**: regresses baseline capabilities.

## 5. Async job and UI architecture

**Decision**: Use a modular monolith with:
- SwiftUI feature views/view models
- Domain services with protocol boundaries
- Background jobs for long operations
- Central log/event stream for Settings/Logs and progress surfaces

**Rationale**:
- Keeps UI responsive.
- Allows unit testing domain rules without launching UI.
- Matches constitution architecture rules.

**Alternatives considered**:
- **Do work inline on main actor**: fails performance/UX gates.
- **Micro-apps or extensions per workflow**: overengineering for a single utility.

## 6. Config and secrets

**Decision**:
- Persist non-secret profile/config in Application Support.
- Store SMTP passwords/tokens in Keychain.
- Support named profiles and a default profile, matching current behavior.

**Rationale**:
- Direct continuity with current `config.py` + `keyring` model.
- Constitution requires Keychain and forbids secrets in plain config.

**Alternatives considered**:
- **Store secrets in config file**: rejected for security.
- **macOS Accounts framework multi-user sync**: unnecessary complexity.

## 7. Delivery paths

**Decision**: Keep two delivery paths only:
1. SMTP Send to Kindle via local profile
2. Explicit handoff to Amazon Send to Kindle

**Rationale**: Matches README/constitution safety boundary.

**Alternatives considered**:
- **Automate Amazon web upload**: forbidden.
- **Remove SMTP and keep handoff only**: simplifies security, but regresses current baseline; can be a later product decision, not the migration default.

## 8. Migration sequencing

**Decision**: Implement by user-story priority, but scaffold the full app shell early so later features plug into stable navigation and job infrastructure.

Recommended vertical slices:
1. App shell + legacy move + dependency status
2. Readiness audit
3. Prepare/fix
4. Convert/repair
5. Send/handoff/profiles
6. Batch
7. Metadata
8. Settings/logs/update polish

**Rationale**: Delivers value early without losing the full-parity plan.

**Alternatives considered**:
- **Big-bang rewrite of all services before UI**: slower feedback.
- **UI mock only first**: risks domain drift from legacy behavior.

## 9. Testing strategy

**Decision**:
- Port behavioral tests around readiness status determination, filename contracts, profile readiness, and calibre missing-tool handling first.
- Use fixture archives for EPUB structure cases.
- Treat legacy Python tests as oracles during port, not as runtime suite for the desktop app.

**Rationale**: Highest regression risk is domain parity, not view layout.

## 10. Packaging and updates

**Decision** (initial):
- Distribute as a standard macOS app target.
- Present app update guidance and Calibre update guidance as separate actions/states.
- Do not auto-upgrade Calibre by default.

**Rationale**: Matches current product policy and reduces surprise system changes.

**Alternatives considered**:
- **Auto-update everything**: too aggressive for an external native dependency.
- **Require Homebrew for daily use**: unnecessary if Calibre app tools are already present.

## Resolved clarifications

No open `NEEDS CLARIFICATION` items remain in Technical Context after research.
