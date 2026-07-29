# Implementation Plan: [FEATURE]

**Branch**: `[###-feature-name]` | **Date**: [DATE] | **Spec**: [link]

**Input**: Feature specification from `/specs/[###-feature-name]/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See
`.specify/templates/plan-template.md` for the execution workflow.

## Summary

[Extract from feature spec: primary requirement + technical approach from research]

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with concrete technical
  details. Keep the selected approach within the native, single-app boundary.
-->

**Language/Version**: [Swift version supported by the selected Xcode toolchain]

**Primary Dependencies**: [SwiftUI, macOS system frameworks, and narrowly justified source packages]

**Storage**: [protected credentials, local preferences, selected inputs, and collision-safe temporary/prepared copies]

**Testing**: [Swift Testing or XCTest; deterministic EPUB, malicious-archive, pipeline, UI, and SMTP fixtures]

**Target Platform**: [supported macOS version]

**Project Type**: [single native macOS application]

**Performance Goals**: [fast launch, responsive minimal UI, bounded background preparation, responsive shortcut]

**Constraints**: [two primary screens; local processing; immutable originals; no external engine, helper process, or executable download]

**Scale/Scope**: [temporary batches up to the specified acceptance capacity; sequential preparation and delivery]

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

Verify against `.specify/memory/constitution.md`:

- **Mission and surface**: Feature directly supports SMTP setup, book intake,
  background preparation, or explicit Kindle delivery and introduces no third
  primary screen.
- **Native boundary**: Use one Swift and SwiftUI macOS application. Reject
  Raycast, parallel products, helper processes, executable downloads, Calibre,
  installed EPUBCheck, and user-installed processing tools.
- **Minimal interaction**: Default UI exposes concise derived states, honest
  progress, keyboard access, and actionable inline detail only when needed.
- **Background pipeline**: EPUB work follows safety check, structural audit,
  deterministic cleanup/restoration, separate-copy writing, and revalidation
  before readiness. PDF content remains unchanged.
- **Original preservation**: Originals and existing files remain immutable;
  temporary output has explicit cleanup and collision behavior.
- **Input safety**: Archive and XML limits cover traversal, absolute paths, ZIP
  bombs, duplicates, entities, links, remote references, memory, and time.
- **Batch reliability**: Confirm a stable snapshot, process sequentially, isolate
  per-book failures, preserve completed results, and define cancellation and
  `delivery_unknown`.
- **Delivery and privacy**: SMTP transmission is explicit; processing stays local;
  credentials use protected macOS storage and remain redacted.
- **Architecture and tests**: Keep SwiftUI separate from application, domain, and
  adapters. Use typed outcomes and fixture-backed tests for every automatic rule.
- **Migration and distribution**: Plan removal of obsolete Raycast and legacy
  surfaces. Keep compilation, tests, runtime validation, signing, notarization,
  and release verification as distinct gates.

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
└── tasks.md
```

### Source Code (repository root)

<!--
  ACTION REQUIRED: Replace this example with the concrete Xcode layout selected
  for the feature. Preserve the dependency direction and two-screen boundary.
-->

```text
BookSender/
├── App/
├── Features/
│   ├── DeliverySetup/
│   └── SendBook/
├── Application/
│   └── Pipeline/
├── Domain/
│   ├── Audit/
│   ├── Repair/
│   └── Models/
├── Adapters/
│   ├── Archive/
│   ├── XML/
│   ├── Filesystem/
│   ├── SMTP/
│   └── Credentials/
└── Resources/
BookSenderTests/
└── Fixtures/
```

**Structure Decision**: [Document the selected structure and reference the real directories captured above]

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation           | Why Needed         | Simpler Alternative Rejected Because |
| ------------------- | ------------------ | ------------------------------------ |
| [specific conflict] | [concrete need]    | [evidence against simpler approach]  |
