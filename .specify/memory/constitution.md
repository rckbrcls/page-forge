<!--
Sync Impact Report
- Version change: 7.1.0 -> 7.2.0
- Bump rationale: a launch check on the runner that imported the private signing
  identity does not prove that a clean consumer Mac can resolve the self-signed
  certificate chain.
- Modified principles:
  - Simple, Reviewable Distribution
- Added obligations:
  - The installer verifies the GitHub asset digest and pinned public certificate
    before registering only that public certificate in the user Keychain.
  - Registration is idempotent and must not import a private key or install an
    explicit Always Trust override.
  - A separate clean macOS runner receives only the packaged release candidate,
    executes the installer bootstrap, verifies that no private identity exists,
    and launches the installed app before publication.
- Runtime guidance updated:
  - ✅ AGENTS.md
- Specifications and distribution guidance updated:
  - ✅ specs/005-lightweight-macos-sender/
  - ✅ specs/006-replace-mock-workflows/
  - ✅ specs/007-native-quality-baseline/
  - ✅ README.md
  - ✅ docs/deployment.md
- Follow-up TODOs: v0.2.4 clean-consumer and installed-app acceptance, first
  corrected-version credential acceptance, and the first
  same-identity N-to-N+1 Sparkle update remain separate runtime gates.
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

A native auxiliary Settings window MAY expose exactly two tabs: `Delivery` for
editing saved SMTP configuration and `Shortcut` for changing or disabling the
global shortcut. Settings MUST NOT host book intake, preparation, confirmation,
delivery, queue, history, or another primary workflow.

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
Sparkle is the sole exception: its embedded installer services MAY update the
application itself, but MUST NOT inspect, prepare, convert, or transmit books.
Repository-only release scripts MAY run in GitHub Actions and MUST NOT be bundled
as application runtime dependencies.

Rationale: the app must feel immediate and self-contained without outsourcing its
core behavior to installed tools.

### III. Minimal Interface, Adaptive Materials

The interface MUST use concise labels, strong hierarchy, an adaptive system
behind-window material across the primary window, subtle borders, restrained
motion, and no decorative complexity. The window material MUST extend through
the titlebar area without replacing the standard close, minimize, or full-screen
controls.

Liquid Glass MUST remain a distinct functional layer for important interactive
controls and MUST NOT replace the content-layer window material. Standard fields,
lists, sheets, and secondary controls MUST retain their native adaptive behavior
rather than receive bespoke glass decoration. The interface MUST remain legible
and operable when Reduce Transparency or Increase Contrast is enabled.

Advanced preparation MUST NOT create advanced navigation.

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

SMTP passwords and equivalent secrets MUST use a generic-password item in the
traditional file-based macOS Keychain. Credential queries MUST NOT opt into the
Data Protection Keychain, synchronization, or custom accessibility attributes.
The Keychain access contract MUST be governed by the application's stable
designated requirement across normal updates.

Secrets MUST NOT be committed, stored in ordinary preference files, written to
files, protected by application-embedded encryption keys, logged, included in
reports, shown after entry, or transmitted anywhere except to the explicitly
configured SMTP service during a confirmed delivery. No file, `UserDefaults`,
remote-storage, or in-memory persistence fallback is permitted.

If a credential created under an obsolete or inaccessible security contract
cannot be read, the application MAY prefill only non-secret values and MUST ask
for the secret again once. It MUST NOT attempt an unsafe extraction or migration.

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

The approved public channel is a GitHub Release containing a universal ZIP
signed with the stable self-signed `Book Sender Release Signing` identity,
Sparkle EdDSA archive signatures, an HTTPS appcast, GitHub Pages publication,
and a reviewable installer. Every distributed version and nested executable MUST
use the same pinned certificate. The main application MUST carry the explicit
designated requirement anchored to that certificate and the identifier
`com.rckbrcls.BookSender`.

Ad-hoc or unsigned distributed artifacts are forbidden. Missing private signing
material, an invalid PKCS#12, a divergent certificate, a changed designated
requirement, or an invalid nested signature MUST fail the release before
packaging or publication; no fallback identity is permitted. The installer MUST
verify the GitHub Release asset SHA-256 digest, the pinned public certificate,
and the exact main-app designated requirement before replacing an installed
application. If the public certificate is absent, the installer MUST register
only the versioned DER certificate in the user's default Keychain before strict
signature verification and MUST request explicit terminal confirmation before
the first registration. Registration MUST be idempotent and MUST NOT import a
private key, install an explicit trust override, or weaken the pinned
fingerprint. Sparkle EdDSA verification remains an independent mandatory
protection.

The self-signed identity has no Apple-issued Team ID. Distributed builds MUST
retain the hardened runtime and MAY disable only library validation on the main
executable so that its pinned Sparkle framework can load. This exception MUST
NOT authorize unsigned or differently signed distributed components: CI and the
installer MUST continue verifying every bundled Sparkle executable against the
pinned certificate. A signed-app launch smoke test MUST keep the executable
alive for a bounded interval so static signature checks cannot mask a dyld
rejection. Publication MUST additionally depend on a separate clean macOS runner
that never receives the PKCS#12 or private signing identity, installs the
packaged candidate through the real certificate bootstrap into an isolated
Keychain and application directory, proves that no private identity was
imported, and passes strict signing plus launch verification.

The private identity MUST remain outside the repository, with an encrypted
backup and release-automation secrets; only its public DER certificate may be
versioned. Rotation requires explicit authorization, a migration plan, and
clear notice that one-time credential re-entry may be required.

Developer ID and notarization are not provided by this channel. Documentation
MUST disclose that a self-signed identity preserves application continuity but
does not give Apple notarization or normal Gatekeeper trust for manual installs.
It MUST also disclose the one-time public-certificate registration and that
removing or rotating that certificate can require the bootstrap again.

Release review MUST still distinguish compilation, tests, static analysis,
accessibility, privacy, license review, archive signing, update verification,
clean-account installation, and public endpoint behavior. Obsolete Raycast,
legacy desktop, Calibre, conversion, and conflicting documentation MUST be
removed as explicit migration work, not retained as fallbacks.

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

**Version**: 7.2.0 | **Ratified**: 2026-07-17 | **Last Amended**: 2026-07-30
