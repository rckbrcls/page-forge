<!--
Sync Impact Report
- Version change: 3.0.0 -> 4.0.0
- Bump rationale: the product surface, runtime, interaction model, architecture,
  credential storage, distribution, and migration direction are redefined
  incompatibly from a Raycast extension to a native macOS application.
- Modified principles:
  - Single-Purpose Book Delivery -> Two-Surface Product
  - Self-Contained Raycast Extension -> Lightweight Native macOS Application
  - Original Files Are Immutable -> Original Files Are Immutable
  - Safe, Deterministic Repairs Only -> Safe Cleanup and Restoration Only
  - Untrusted-Archive Safety -> Untrusted-Book Safety
  - Local Processing and Explicit Delivery -> Background Preparation, Explicit Delivery
  - Transparent, Evidence-Based Health Reports -> Minimal Feedback, Retained Evidence
  - Validate Before and After Repair -> Validate Before and After Preparation
  - Domain-First, Typed Architecture -> Domain-First, Typed Architecture
  - Fixture-Backed Repair Assurance -> Fixture-Backed Pipeline Assurance
  - Native Raycast Interaction -> Sequential Batch Reliability
  - Privacy and Credentials -> Local Privacy and Protected Credentials
  - Simple, Reviewable Distribution -> Simple, Reviewable Distribution
- Added sections:
  - Product Surface and Interaction Contract
  - Background Ebook Preparation Policy
  - Architecture, Quality, and Distribution
- Removed sections:
  - Raycast command, runtime, component, preference, and Store requirements
  - Raycast-specific source layout and interaction rules
- Templates updated:
  - ✅ .specify/templates/plan-template.md
  - ✅ .specify/templates/spec-template.md
  - ✅ .specify/templates/tasks-template.md
  - ✅ .specify/templates/checklist-template.md
- Runtime guidance updated:
  - ✅ AGENTS.md
  - ✅ README.md
  - ✅ docs/desktop-migration.md
- Active specification updated:
  - ✅ specs/005-lightweight-macos-sender/spec.md
  - ✅ specs/005-lightweight-macos-sender/checklists/requirements.md
- Reviewed without changes:
  - .specify/templates/constitution-template.md
  - .specify/templates/commands/ (directory not present)
- Follow-up TODOs: implementation and obsolete Raycast removal remain future
  planning and task work; no constitution placeholders are deferred.
-->

# Book Sender Constitution

## Core Principles

### I. Two-Surface Product

Book Sender exists only to configure SMTP delivery and send local EPUB or PDF
books to Kindle. The product MUST expose exactly two primary screens:
`Delivery Setup` and `Send Book`.

The complete user-visible journey MUST remain:

`Configure Delivery -> Select Books -> Wait for Readiness -> Confirm -> Send`

System file pickers, confirmations, alerts, progress presentation, and inline
disclosures do not count as additional primary screens. The product MUST NOT add
a library, persistent queue, delivery history, reader, editor, account, cloud
sync, analytics dashboard, or general ebook-management surface.

Rationale: Book Sender earns complexity in preparation quality, not in navigation.

### II. Lightweight Native macOS Application

Book Sender MUST be one self-contained native macOS application implemented with
Swift and SwiftUI. It MUST remain fast to launch, small in surface area,
keyboard-accessible, and visually calm. A configurable global shortcut MAY reveal
the existing primary window while the application is active.

The final repository MUST contain one macOS application product and its tests,
fixtures, documentation, and distribution assets. Raycast, Electron, Tauri,
Python, Java, Docker, helper processes, local services, executable downloads,
Calibre, installed EPUBCheck, and user-installed processing tools MUST NOT be
runtime requirements or parallel products.

Dependencies MUST use macOS system capabilities or narrowly justified source
packages. Native or package dependencies MUST NOT introduce a second process,
download executable code, or weaken archive, credential, or privacy guarantees.

Rationale: the app must feel immediate and self-contained without outsourcing its
core behavior to installed tools.

### III. Minimal Interface, Minimal Feedback

The interface MUST use concise labels, strong hierarchy, opaque surfaces, subtle
borders, restrained motion, and no decorative complexity. Advanced preparation
MUST NOT create advanced navigation.

During normal work, each book MUST expose only a concise state equivalent to
`Checking`, `Preparing`, `Ready`, `Needs Attention`, `Sending`, and a terminal
result. Healthy or successfully prepared books MUST NOT require the user to read
technical findings. Detailed evidence MAY appear through inline progressive
disclosure only when it helps explain a blocked item, a failure, an applied
repair, or a user decision.

Progress feedback MUST remain honest. The app MUST NOT show invented percentages
for work whose completion cannot be measured. Accessibility labels, keyboard
focus, cancellation, errors, and terminal outcomes MUST remain clear even when
the visual presentation is minimal.

Rationale: quiet feedback reduces cognitive load without hiding actionable risk.

### IV. Advanced Background Preparation

Selecting an EPUB MUST begin a local background pipeline without requiring the
user to navigate through inspection or repair controls:

`Safety Check -> Structural Audit -> Cleanup/Restore -> Write Working Copy -> Revalidate -> Ready`

The pipeline MUST finish before an EPUB becomes eligible for delivery. PDF files
MUST receive bounded eligibility and delivery checks but MUST NOT be converted or
have their content modified.

Preparation MUST keep the interface responsive, publish concise state changes,
support cooperative cancellation, and retain detailed internal evidence for
tests and actionable failure disclosure. Background execution MUST NOT imply
background delivery: no selected or prepared book may be transmitted before an
explicit confirmation.

Rationale: advanced capability belongs in the pipeline; delivery intent remains
with the user.

### V. Original Files Are Immutable

Book Sender MUST NOT modify, overwrite, rename, move, or remove a selected
original. Any EPUB cleanup or restoration MUST operate on a separate,
collision-safe working copy. Existing files MUST never be overwritten silently.

Temporary and prepared files MUST have explicit lifecycle rules. Failure or
cancellation MUST preserve every original and pre-existing file, clean incomplete
temporary output when safe, and never present a partial output as valid.

Rationale: a convenience utility must never make the user's source library less
trustworthy.

### VI. Safe Cleanup and Restoration Only

Automatic cleanup or restoration is permitted only when the fault and correction
are deterministic, supported by concrete evidence, preserve the book's intended
meaning, and can be verified after writing.

Permitted categories MAY include:

- rebuilding and normalizing the EPUB `mimetype` entry;
- restoring `META-INF/container.xml` when exactly one unambiguous package exists;
- correcting media types that are unequivocally determined by resource content
  or extension;
- normalizing equivalent internal paths and fixing references with exactly one
  matching target;
- rebuilding the archive while preserving book resources and required ordering;
- normalizing XML encoding and structurally equivalent markup without editorial
  change;
- restoring missing structural declarations only when the remaining book
  provides one unambiguous source of truth.

The pipeline MUST NOT invent or rewrite prose, delete chapters, choose among
ambiguous packages, covers, or navigation structures, alter title, author,
language, styling, or layout for preference, remove DRM, or perform destructive
content cleanup. Ambiguous cases MUST remain unchanged and become
`Needs Attention`, `Unsupported`, or `Unsafe`.

Rationale: restoration recovers evidenced structure; it does not reinterpret the
book.

### VII. Untrusted-Book Safety

Every EPUB MUST be treated as an untrusted archive. Archive and XML handling MUST
defend against traversal, absolute or escaping paths, ZIP bombs, excessive size
or entry count, duplicate entries, invalid filenames, symlinks or equivalent
links, malicious XML, external entities, remote references, excessive nesting,
memory pressure, time exhaustion, and active content.

Limits and rejection behavior MUST be explicit, deterministic, typed, and tested
at their boundaries. No book content may be executed, and preparation MUST NOT
read local or remote resources referenced from inside the book.

Rationale: automatic background work increases the need for strict input
boundaries.

### VIII. Validate Before and After Preparation

The pipeline MUST inspect the original, derive a typed preparation plan, create a
separate working copy, inspect the written copy again, and compare both results.
A prepared EPUB becomes `Ready` only when the output introduces no new critical
finding and satisfies every delivery eligibility rule.

Every finding MUST retain a stable code, severity, location when applicable,
repairability, applied action when any, and revalidation result. The default UI
MAY hide this evidence, but the domain model and tests MUST NOT replace it with an
unexplained score or loose string.

Rationale: minimal presentation is safe only when supported by complete evidence.

### IX. Sequential Batch Reliability

The sending screen MUST accept one or more EPUB and PDF books. Confirmation MUST
capture a stable batch snapshot. Preparation, archive entry work, and delivery
MUST be sequential, with at most one active item in each constrained stage.

Failures MUST be isolated per book. One unsupported, unsafe, failed, or
delivery-unknown item MUST NOT determine another item's outcome. Cancellation
MUST stop pending scheduling, cooperatively interrupt active streams where safe,
and preserve completed results.

SMTP cancellation after message data begins MAY produce `delivery_unknown`.
Neither failed nor delivery-unknown items may be retried automatically.

Rationale: bounded sequential work keeps resource use predictable and outcomes
understandable.

### X. Local Processing and Explicit SMTP Delivery

Inspection, cleanup, restoration, and revalidation MUST run locally. Book content,
metadata, diagnostics, filenames, source paths, and credentials MUST NOT be sent
to analytics, AI models, remote processors, or hidden services.

The only permitted book transmission is an explicit, user-confirmed SMTP delivery
to the configured Kindle address. Each eligible book MUST have an independent
delivery attempt. The application MUST NOT automate Amazon login, browser upload,
or the official Send to Kindle website, and MUST NOT promise provider or Amazon
acceptance.

Rationale: selecting and preparing books is reversible local work; transmission
is a separate external side effect.

### XI. Domain-First, Typed Architecture

The required dependency direction is:

`SwiftUI Screens -> Application Pipeline -> Ebook Audit and Repair Domain -> Archive, XML, Filesystem, SMTP, and Credential Adapters`

SwiftUI views MUST compose the two screens and present state; they MUST NOT contain
archive, audit, repair, restoration, filesystem, credential, or SMTP rules.
Expected states and failures MUST use explicit models, including selected batch,
finding, health, preparation plan, applied action, comparison, cancellation, and
delivery result. Raw adapter exceptions MUST NOT reach the interface.

Rationale: the minimal UI must remain replaceable and the advanced pipeline must
remain independently testable.

### XII. Fixture-Backed Pipeline Assurance

Every audit rule and every automatic cleanup or restoration rule MUST have a
focused, deterministic fixture-backed test. Tests MUST cover valid EPUB 2 and
EPUB 3 books, malformed and ambiguous structures, every permitted repair,
malicious archives, every safety boundary, cancellation, batch isolation, working
copy collisions, revalidation regressions, SMTP sanitization, and
delivery-unknown behavior.

An automatic preparation rule without focused acceptance evidence MUST NOT ship.
UI tests MUST verify the two-screen boundary, minimal default feedback, keyboard
operation, accessibility labels, batch progress, failure disclosure, and explicit
delivery confirmation.

Rationale: invisible background sophistication requires unusually visible test
evidence.

### XIII. Local Privacy and Protected Credentials

SMTP passwords and equivalent secrets MUST use macOS protected credential
storage. Secrets MUST NOT be committed, stored in ordinary preference files,
logged, included in reports, shown after entry, or transmitted anywhere except to
the explicitly configured SMTP service during a confirmed delivery.

Non-secret preferences MAY remain local. The application MUST collect no hidden
usage data or telemetry. Diagnostic output MUST redact credentials, book
excerpts, full source paths, and other unnecessary personal data.

Rationale: an email-delivery utility handles both personal documents and powerful
credentials.

### XIV. Simple, Reviewable Distribution

The project MUST remain one macOS application target unless a test target or
distribution helper generated by the standard toolchain has a concrete need.
Plans MUST reject speculative layers, unused abstractions, duplicated pipelines,
parallel legacy products, and dependencies without measured value.

Public distribution requires clean compilation, tests, static analysis,
accessibility review, signing, notarization, privacy documentation, license
review, and a verified update or release process. Obsolete Raycast, legacy
desktop, Calibre, conversion, and conflicting documentation MUST be removed as
explicit migration work, not retained as fallbacks.

Rationale: operational simplicity is part of the product's lightweight promise.

## Product Surface and Interaction Contract

### Required Capabilities

- Configure sender address, SMTP host, port, security mode, username, protected
  app password, Kindle address, and the optional global shortcut.
- Select one or more local EPUB and PDF books through drag and drop or Finder.
- Prepare books automatically in the background and show only concise default
  state.
- Reveal actionable detail inline when a book cannot safely become ready.
- Confirm one stable eligible batch before sequential independent SMTP delivery.
- Show per-book terminal results and allow explicit retry of failed items only.

### Prohibited Expansion

No feature may introduce a third primary screen; library, persistent queue,
history, reader, editor, cloud, account, analytics, AI, conversion, DRM removal,
generic-document, mobile, web, Windows, Linux, or parallel legacy product scope
without a constitutional amendment.

## Background Ebook Preparation Policy

Health states MUST be `healthy`, `repairable`, `needs_review`, `unsupported`, or
`unsafe`. Finding severities MUST be `info`, `warning`, `error`, or `critical`.
Repairability MUST remain separate from severity.

The user-facing pipeline state MUST be derived from typed domain evidence.
`Ready` means the original PDF is eligible or the EPUB working copy passed
revalidation. `Needs Attention` means the pipeline cannot proceed without a user
decision or replacement file. `Failed`, `Cancelled`, and `Delivery Unknown` are
terminal outcomes and MUST remain distinct.

Prepared copies MUST preserve the original display name for Kindle attachment
unless a provider constraint requires a safe transformation. Detailed reports
MUST remain available to tests and diagnostics but MUST stay collapsed during
normal successful use.

## Architecture, Quality, and Distribution

### Planned Source Layout

Plans MUST use one native macOS application with a structure equivalent to:

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

Equivalent names are permitted when the dependency direction and two-screen
boundary remain explicit.

### Quality Gates

- Feature specifications MUST state the two-screen surface, background pipeline,
  minimal feedback, batch behavior, safety, original preservation, and explicit
  delivery boundaries.
- Plans MUST pass the Constitution Check before research and after design.
- Tasks MUST include fixture-backed tests for every audit, cleanup, restoration,
  and revalidation rule.
- Reviews MUST reject UI-embedded domain rules, raw expected failures, invented
  progress, unbounded archive work, automatic delivery, insecure credential
  storage, untested preparation, and parallel product surfaces.
- Static validation, compilation, automated tests, runtime inspection, signing,
  and production distribution are distinct claims and MUST be reported
  separately.

## Governance

This constitution supersedes conflicting product guidance, specifications, plans,
tasks, documentation, and code until amended. Every `spec.md`, `plan.md`,
`tasks.md`, implementation review, and release review MUST explicitly verify
compliance.

### Amendments

1. State the motivation, affected clauses, product and security impact, and
   required migration or removal work.
2. Record the approved replacement in this file before conflicting implementation.
3. Update dependent Spec Kit templates and runtime guidance in the same change.
4. Bump the version using semantic versioning: MAJOR for incompatible principle
   or product-boundary changes, MINOR for new or materially expanded obligations,
   and PATCH for clarifications that do not change obligations.
5. Preserve the original ratification date and update the amendment date in ISO
   `YYYY-MM-DD` format.

No exception is implicit. A plan or implementation that cannot cite an approved
constitutional rule or written amendment MUST be rejected. Compliance evidence
MUST distinguish static checks, compilation, automated tests, runtime behavior,
authenticated delivery, and production distribution.

**Version**: 4.0.0 | **Ratified**: 2026-07-17 | **Last Amended**: 2026-07-28
