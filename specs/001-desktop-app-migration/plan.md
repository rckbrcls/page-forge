# Implementation Plan: Desktop App Migration

**Branch**: `001-desktop-app-migration` | **Date**: 2026-07-17 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-desktop-app-migration/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Migrate PageForge from a Python Textual TUI/CLI product to a lightweight native
macOS desktop app while preserving the README workflow baseline: readiness,
conversion, repair, metadata, batch, Send to Kindle, settings, and logs.

Technical approach:

1. Archive the current Python app under `legacy/` as behavioral reference only.
2. Build a new Swift/SwiftUI modular monolith with testable domain services.
3. Port readiness/repair/conversion/delivery rules into Swift domain code,
   using the legacy Python modules as the source of truth for behavior.
4. Keep Calibre as an external engine invoked through process orchestration.
5. Ship a Readiness-first desktop UI with drag-and-drop intake and progressive
   disclosure for supporting surfaces.

## Technical Context

**Language/Version**: Swift 6, SwiftUI (macOS 14+ target baseline)

**Primary Dependencies**:

- SwiftUI / AppKit interop where needed for open panels and keychain-adjacent UX
- Foundation `Process` for Calibre CLI orchestration
- Security framework / Keychain Services for SMTP secrets
- ZIPFoundation or native Compression/ZIP handling for EPUB structure work
- Optional: Homebrew detection only for setup/update guidance, not runtime core

**Storage**:

- Local ebook files chosen by the user
- App config JSON/plist in Application Support
- Secrets in macOS Keychain
- No cloud database

**Testing**:

- Swift Testing / XCTest for domain and integration seams
- Fixture EPUBs/MOBIs under `PageForgeTests/Fixtures`
- Legacy Python tests remain frozen under `legacy/` for reference only

**Target Platform**: macOS desktop only

**Project Type**: native desktop utility app

**Performance Goals**:

- Drop/file selection feedback under 100ms perceived
- Readiness audit UI remains interactive; typical local EPUB audit feels
  near-instant to a few seconds depending on file size
- Conversion/repair/batch never block the main thread
- Low idle memory footprint suitable for a utility app

**Constraints**:

- Mission-only Kindle-ready workflow
- Local-first
- No DRM removal
- No Amazon login/upload automation
- No OCR promises for scanned PDFs
- Calibre remains external engine
- Output contracts: `*-repaired.epub` vs `*-kindle-ready.epub`
- Readiness vocabulary fixed
- Old TUI/CLI archived to legacy and not dual-maintained

**Scale/Scope**:

- Single-user local utility
- Seven primary surfaces: Readiness, Convert, Batch, Send, Metadata, Settings, Logs
- Full baseline parity with current README capabilities across phased delivery

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

### Pre-design gate

| Gate                 | Status                        | Notes                                                                               |
| -------------------- | ----------------------------- | ----------------------------------------------------------------------------------- |
| Mission fit          | PASS                          | Migrates existing ebook preparation mission; no library/cloud expansion             |
| Fast/light/beautiful | PASS                          | Native SwiftUI utility; no Electron/web shell                                       |
| Readiness-first      | PASS                          | Default route/home is Readiness                                                     |
| Calibre boundary     | PASS                          | Process orchestration only; no conversion engine rewrite                            |
| Safe local-first     | PASS                          | Local files, Keychain secrets, explicit aggressive repair, no DRM/Amazon automation |
| Status vocabulary    | PASS                          | Preserve `ready`/`needs_fixes`/`blocked` and issue severities                       |
| Output contracts     | PASS                          | Preserve repaired vs kindle-ready naming                                            |
| Architecture         | PASS                          | Domain services separate from SwiftUI views                                         |
| Complexity           | PASS with justified exception | See Complexity Tracking for legacy archival vs transitional CLI guidance            |

### Post-design gate

| Gate                    | Status | Notes                                                                     |
| ----------------------- | ------ | ------------------------------------------------------------------------- |
| Mission fit             | PASS   | Contracts and data model stay inside baseline workflows                   |
| Fast/light/beautiful    | PASS   | Async job model + restrained surface map                                  |
| Readiness-first         | PASS   | Navigation contract defaults to Readiness                                 |
| Calibre boundary        | PASS   | Integration contract isolates Calibre process I/O                         |
| Safe local-first        | PASS   | Delivery/security contracts require Keychain and handoff-only Amazon path |
| Status/output contracts | PASS   | Explicit domain enums and filename builders                               |
| Architecture            | PASS   | Modular monolith boundaries defined                                       |
| Complexity              | PASS   | Legacy archive is deliberate one-time migration cost                      |

## Project Structure

### Documentation (this feature)

```text
specs/001-desktop-app-migration/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── ui-navigation.md
│   ├── domain-services.md
│   ├── calibre-integration.md
│   └── delivery-and-config.md
├── checklists/
│   └── requirements.md
└── tasks.md                 # created later by /speckit.tasks
```

### Source Code (repository root)

```text
PageForge/
├── App/
│   ├── PageForgeApp.swift
│   └── AppState.swift
├── Features/
│   ├── Readiness/
│   ├── Convert/
│   ├── Batch/
│   ├── Send/
│   ├── Metadata/
│   ├── Settings/
│   └── Logs/
├── Domain/
│   ├── Models/
│   ├── Services/
│   │   ├── ReadinessService.swift
│   │   ├── ConversionService.swift
│   │   ├── RepairService.swift
│   │   ├── MetadataService.swift
│   │   ├── DeliveryService.swift
│   │   └── DependencyService.swift
│   └── Jobs/
│       └── OperationJob.swift
├── Integrations/
│   ├── Calibre/
│   ├── Keychain/
│   ├── Mail/
│   └── FileSystem/
└── Resources/

PageForgeTests/
├── Domain/
├── Integrations/
├── Features/
└── Fixtures/

legacy/
├── README.md                 # "reference only; not product surface"
├── python-tui-cli/           # moved from current src/page_forge + packaging
│   ├── src/page_forge/
│   ├── tests/
│   ├── pyproject.toml
│   └── install.sh
└── notes/
    └── behavior-parity.md    # mapping legacy modules -> Swift services

docs/
└── desktop-migration.md      # optional operator notes after implementation
```

**Structure Decision**: Use a single macOS SwiftUI app target plus test target as
the product. Move the entire current Python TUI/CLI tree into `legacy/python-tui-cli`
for inspiration and parity reference. Do not keep Python as a runtime sidecar.
Domain behavior is reimplemented in Swift services, guided by legacy modules:

- `legacy/.../readiness.py` → `Domain/Services/ReadinessService`
- `legacy/.../epub_repair.py` + conversion repair path → `RepairService`
- `legacy/.../conversion.py` → `ConversionService`
- `legacy/.../metadata.py` → `MetadataService`
- `legacy/.../kindle.py` + `config.py` → `DeliveryService` + config/keychain integrations
- `legacy/.../calibre.py` → `Integrations/Calibre`

## Complexity Tracking

| Violation / Tension                                                                            | Why Needed                                                                             | Simpler Alternative Rejected Because                                                                                                   |
| ---------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| Explicit archival of Python CLI/TUI instead of preserving it as a maintained secondary surface | User-approved full desktop refactor; legacy code is inspiration only                   | Keeping dual Python+Swift product surfaces doubles maintenance and delays a clean desktop architecture                                 |
| Full baseline parity in one migration program (phased delivery inside one feature)             | README defines the real product; readiness-only rewrite would regress current value    | Shipping only drop+audit first is fine as an implementation slice, but planning must cover full baseline so later slices stay coherent |
| Reimplement domain logic in Swift rather than wrapping Python                                  | Packaging, codesign, PATH, and UX reliability are worse with a Python sidecar on macOS | Sidecar is faster to prototype, but fails the light/native product bar and creates fragile distribution                                |

## Phase 0 Research Summary

See [research.md](./research.md).

Key decisions:

- SwiftUI native app, no Tauri/Electron
- Pure Swift domain port, no Python runtime dependency
- Legacy tree under `legacy/` for reference only
- EPUB ZIP/XML repair ported from `epub_repair.py` / readiness audits
- Calibre via `Process`
- Keychain for SMTP secrets
- Phased implementation order follows user-story priority P1→P8

## Phase 1 Design Summary

See:

- [data-model.md](./data-model.md)
- [contracts/](./contracts/)
- [quickstart.md](./quickstart.md)

Design centers on:

- immutable report/result values
- async operation jobs with progress/log events
- service protocols for UI testability
- stable filename and status contracts copied from legacy behavior

## Implementation Phasing (for later tasks)

Not a tasks breakdown, only planning order:

1. Repo bootstrap: Xcode/Swift package layout + move Python tree to `legacy/`
2. Domain skeleton + Calibre dependency detection
3. Readiness audit (P1)
4. Prepare/fix Kindle-ready (P2)
5. Convert + repair (P3)
6. Send + handoff + profiles/keychain (P4)
7. Batch (P5)
8. Metadata (P6)
9. Settings/logs/update guidance polish (P7)
10. Legacy cleanup verification and docs (P8)

## Agent Context Update

No project agent-context update script is present under `.specify/scripts`.
Runtime guidance was already aligned in `AGENTS.md` with constitution v1.1.0.
No additional generated agent context file was written by this plan command.
