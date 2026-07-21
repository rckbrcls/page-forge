<!--
Sync Impact Report
- Version change: 2.0.0 -> 3.0.0
- Bump rationale: the product surface, supported inputs, runtime, dependencies,
  architecture, safety model, and delivery constraints are redefined incompatibly.
- Modified principles: all prior desktop-app, Calibre, queue, conversion, and
  Settings principles are replaced by the principles below.
- Added sections: Product Boundary; EPUB Health and Repair Policy; Architecture,
  Quality, and Distribution.
- Removed sections: desktop queue baseline, Calibre engine boundary, conversion
  contracts, native Settings guidance, legacy Python compatibility, and Keychain
  requirements.
- Templates updated:
  - .specify/templates/plan-template.md
  - .specify/templates/spec-template.md
  - .specify/templates/tasks-template.md
  - .specify/templates/checklist-template.md
- Reviewed without changes: .specify/templates/constitution-template.md
- Follow-up TODOs: none
-->

# Page Forge Constitution

## Core Principles

### I. Minimum, EPUB-Only Scope
Page Forge exists only to inspect EPUB health, apply safe repairs, create a new
Kindle-ready EPUB copy, and explicitly send or prepare that copy for Kindle.
Every feature MUST directly serve this pipeline:

`Select EPUB -> Inspect Health -> Apply Safe Repairs -> Generate Repaired Copy -> Send to Kindle`

The product MUST NOT add PDF, MOBI, AZW, AZW3, or KFX conversion; DRM removal;
an EPUB editor or reader; library management; cloud sync; accounts; remote
backend; mobile or separate desktop apps; AI, chat, agents; or generic document
support. Adjacent functionality is out of scope even when it appears useful.

### II. Self-Contained Raycast Extension
Page Forge MUST be one public Raycast extension that works immediately after
installation through Raycast. It MUST use TypeScript, React, `@raycast/api`, and
`@raycast/utils` only when it provides a concrete benefit. Dependencies MUST be
JavaScript or TypeScript npm packages, or local Node.js APIs available in the
Raycast runtime.

Swift, SwiftUI, Electron, Tauri, Rust, Python, Java, Docker, helper processes,
local services, native binaries, executable downloads, Calibre, machine-installed
EPUBCheck, and user-installed dependencies are FORBIDDEN.

### III. Original Files Are Immutable
Page Forge MUST NOT modify, overwrite, rename, or remove a selected EPUB. A repair
MUST create a separate output, normally named `book-kindle-ready.epub`. If that
path exists, the extension MUST choose a safe unused path and report it; it MUST
never overwrite an existing file silently.

### IV. Safe, Deterministic Repairs Only
An automatic repair is permitted only when the fault and its correction are
unambiguous, no content is invented, the book's intended meaning is not changed,
the operation is testable, and the outcome can be explained to the user.

Initially permitted repairs, when implemented and tested, are rebuilding and
normalizing the `mimetype` entry; rebuilding `META-INF/container.xml` only with
one unambiguous OPF; correcting evident MIME types from extensions; normalizing
unequivocally equivalent internal paths; rebuilding the ZIP while preserving
content; fixing references with exactly one matching target; and normalizing XML
encoding without changing meaning.

The extension MUST NOT automatically delete chapters, rewrite content, summarize
text, choose among multiple OPFs or covers, remove scripts or fonts, delete orphan
resources, reconstruct substantial manifest sections, infer navigation, modify
title, author, or language, alter CSS for appearance, or destructively repair
XHTML. Ambiguous cases MUST produce a diagnosis without an automatic change.

### V. Untrusted-Archive Safety
Every EPUB MUST be treated as untrusted input. Archive and XML handling MUST
defend against ZIP traversal, absolute or escaping paths, ZIP bombs, excessive
file size or entry count, duplicate entries, malicious XML and external entities,
unexpected remote references, invalid filenames, symlinks or equivalent entries,
excessive memory consumption, and interface blocking. No internal EPUB content
may be executed.

Limits and rejection behavior MUST be explicit, deterministic, and reported as
typed processing failures. Inspection and repair work MUST keep the Raycast
interface responsive.

### VI. Local Processing and Explicit Delivery
Inspection and repair MUST run locally. Book content, diagnostics, and metadata
MUST NOT be sent to servers, APIs, analytics services, or AI models. The only
permitted external transmission is a user-initiated Kindle delivery action.

Inspection, repair, and sending MUST be distinct actions or visibly distinct
steps. Selecting or repairing a file MUST NOT send it automatically. Sending may
prepare the corrected file for a user-controlled Kindle flow when direct delivery
is not configured.

### VII. Transparent, Evidence-Based Health Reports
Health classification MAY use `Healthy`, `Repairable`, `Needs Review`,
`Unsupported`, or `Unsafe`, but it MUST be derived from concrete findings and
MUST NOT replace them. Every finding MUST include a stable code, severity, title,
description, location when applicable, repairability, applied repair when any,
and the result of revalidation.

The extension MUST NOT present an unexplained generic health score as the primary
diagnosis.

### VIII. Validate Before and After Repair
The repair pipeline MUST inspect the original EPUB, derive a repair plan, create a
new copy, inspect that copy again, and compare both reports. It MUST report success
only when the output introduces no new critical errors. A failed or unsafe repair
MUST preserve the original and clearly report the failure and any output path.

### IX. Domain-First, Typed Architecture
The EPUB engine MUST remain independent of Raycast UI components and testable
without rendering React. The required dependency direction is:

`Raycast Commands -> Application Services -> EPUB Audit and Repair Engine -> Archive, XML, and Filesystem Adapters`

React components MUST NOT contain audit or repair rules. Expected outcomes MUST
use explicit types, including loaded document, finding, severity, repair plan,
applied repair, report, processing failure, and delivery result. Expected failures
MUST NOT be represented by unstructured strings or generic exceptions.

### X. Fixture-Backed Repair Assurance
Every audit rule and every automatic repair MUST have focused tests and small,
specific fixtures. The test corpus MUST cover valid EPUBs; invalid ZIPs; absent,
compressed, or misordered `mimetype`; absent `container.xml`; absent or ambiguous
OPFs; invalid manifests and spines; missing resources; incorrect MIME types;
broken references; malicious paths; duplicate entries; and oversized files.

An automatic repair without a corresponding test MUST NOT be accepted.

### XI. Native Raycast Interaction
The user interface MUST use Raycast components and remain command-first, fast,
and keyboard usable. It MUST NOT imitate a traditional desktop application inside
Raycast. The initial command set SHOULD stay small and cover inspection,
preparation, and explicit Kindle sending for selected EPUBs.

### XII. Privacy and Credentials
Credentials MUST NOT be committed, stored in repository files, logged, shown in
errors or reports, or sent to telemetry. If email delivery is implemented,
credentials MUST use Raycast secure preferences and the extension README MUST
describe their handling. The extension MUST NOT collect hidden data.

### XIII. Simple, Reviewable Distribution
The project MUST remain a single npm package and a single Raycast extension; it
MUST NOT introduce a monorepo, speculative abstraction, unused layer, dependency
without a concrete need, or optimization without measurements. Raycast Store
distribution requires clean build, lint, and typecheck; justified dependencies;
no downloaded executables; a sufficient README; a publication-compatible license;
and readable, reviewable code.

## Product Boundary

### Required Capabilities
- Select one or more EPUBs through Finder-selected files or a Raycast file picker.
- Inspect EPUB structural health and show clear findings.
- Apply only permitted safe repairs and create a new corrected copy.
- Show the final report and generated output path.
- Explicitly send the corrected EPUB to Kindle or prepare it for user-controlled
  Kindle delivery.

### Prohibited Expansion
No feature may introduce external engines, remote processing, conversion between
formats, content authoring or reading, library features, or a product surface
outside Raycast without a constitutional amendment.

## EPUB Health and Repair Policy

Health findings MUST use stable, documented identifiers and a defined severity.
Repair planning MUST preserve enough evidence to explain why each repair is safe,
which archive entries changed, and why unaddressed findings remain.

Archive reconstruction MUST preserve original content except for the explicitly
planned repairs. A revalidation report MUST identify resolved, remaining, and newly
introduced findings.

## Architecture, Quality, and Distribution

### Source Layout
Plans MUST use one npm package with a structure equivalent to:

```text
src/
├── commands/
├── application/
├── domain/
│   ├── audit/
│   ├── repair/
│   └── models/
└── adapters/
    ├── archive/
    ├── xml/
    └── filesystem/
tests/
└── fixtures/
```

### Quality Gates
- Feature specifications MUST state scope boundaries, processing safety, report
  semantics, output behavior, and explicit delivery intent where relevant.
- Plans MUST pass the Constitution Check before research and after design.
- Tasks MUST include fixture-backed tests for every audit rule and auto-repair.
- Reviews MUST reject untyped expected failures, UI-embedded engine rules,
  untested repair behavior, unsafe archive handling, and prohibited dependencies.
- A feature requiring a constitutional exception MUST identify the violated rule,
  justify the exception, define its limits, and receive an amendment before work.

## Governance

This constitution supersedes conflicting product guidance, specifications, plans,
tasks, and code until it is amended. `spec.md`, `plan.md`, `tasks.md`, and code
reviews MUST explicitly verify compliance with it.

### Amendments
1. State the motivation, affected clauses, product and security impact, and any
   required migration or removal work.
2. Record the approved exception or replacement in this file before implementation.
3. Update dependent Spec Kit templates when they conflict with the amendment.
4. Bump the version using semantic versioning: MAJOR for incompatible principle or
   product-boundary changes, MINOR for new or materially expanded obligations, and
   PATCH for clarifications that do not change obligations.
5. Keep ratification and amendment dates in ISO `YYYY-MM-DD` format.

No exception is implicit. A plan or implementation that cannot cite an approved
constitutional exception MUST be rejected.

**Version**: 3.0.0 | **Ratified**: 2026-07-17 | **Last Amended**: 2026-07-20
