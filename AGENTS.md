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
- Base product specification: `specs/005-lightweight-macos-sender/`.
- Active implementation specification:
  `specs/006-replace-mock-workflows/`, which removes preview behavior and
  completes real setup, preparation, batch, SMTP, recovery, Settings, and
  shortcut workflows without expanding the two-screen product.
- Book Sender is a lightweight, self-contained native macOS application with
  exactly two primary screens: `Delivery Setup` and `Send Book`.
- A native auxiliary Settings window contains only `Delivery` and `Shortcut`
  tabs; it is not a third primary workflow screen.
- The final repository contains one Swift and SwiftUI macOS application plus its
  tests, fixtures, documentation, and distribution assets.
- Raycast, Electron, Tauri, Python, Java, Docker, Calibre, installed EPUBCheck,
  processing helpers, local services, executable downloads, and parallel legacy
  products are obsolete or forbidden runtime dependencies. Sparkle's embedded
  update services and repository release scripts are the only distribution
  exception.
- Required dependency direction:
  `SwiftUI Screens -> Application Pipeline -> Ebook Audit and Repair Domain -> Archive, XML, Filesystem, SMTP, and Credential Adapters`.
- Planned source areas:
  - `BookSender/App/`: application lifecycle and composition
  - `BookSender/Features/DeliverySetup/`: SMTP setup screen only
  - `BookSender/Features/SendBook/`: batch intake, minimal feedback, and delivery screen
  - `BookSender/Features/Settings/`: saved delivery edits and global shortcut preferences
  - `BookSender/Application/Pipeline/`: sequential background orchestration
  - `BookSender/Domain/Audit/`: EPUB rules and health derivation
  - `BookSender/Domain/Repair/`: cleanup, restoration, planning, and comparison
  - `BookSender/Domain/Models/`: typed findings, failures, plans, results, and state
  - `BookSender/Adapters/`: archive, XML, filesystem, SMTP, and credential boundaries
  - `BookSenderTests/Fixtures/`: valid, malformed, ambiguous, and malicious EPUB fixtures

## Product Positioning

- Keep the visible product limited to SMTP setup and batch book sending.
- Keep the advanced pipeline internal:
  `Safety Check -> Structural Audit -> Cleanup/Restore -> Write Working Copy -> Revalidate -> Ready`.
- Default feedback is concise: checking, preparing, ready, needs attention,
  sending, and a terminal result.
- Reveal detailed evidence inline only when it explains a blocked item, failure,
  applied restoration, or user decision.
- Support EPUB background preparation and direct PDF delivery. Do not add
  conversion or MOBI, AZW, AZW3, or KFX handling.
- Use explicit SMTP delivery only. Do not automate Amazon login, browser upload,
  or the official Send to Kindle website.
- Do not implement DRM removal.
- Keep the product fast, light, minimal, and visually calm.

## Implementation Conventions

- Keep one shared intake path for drag and drop and the Finder file picker.
- Process a stable confirmed batch sequentially, one EPUB, one archive entry, and
  one delivery attempt at a time; isolate failures per book.
- Cancellation stops pending scheduling and cooperatively interrupts active
  streams; SMTP may become `delivery_unknown` after message data begins.
- Never modify or overwrite an original. EPUB cleanup and restoration use a
  separate collision-safe copy and preserve the original display name for Kindle
  delivery.
- Apply only deterministic, evidence-backed cleanup or restoration and revalidate
  the written copy before readiness.
- Keep audit, repair, restoration, filesystem, credential, and SMTP rules out of
  SwiftUI views.
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
- Every audit and automatic cleanup or restoration rule requires a focused fixture-backed test.
- Keep all production implementation inside `BookSender/**/*.swift`.

## Dependencies And Platform

- Product surface: macOS 26.0+, Swift 6 language mode with complete concurrency
  checking, SwiftUI, AppKit, Observation, Foundation, Security.framework, and
  UniformTypeIdentifiers.
- Application state: `@MainActor @Observable` presentation model; one actor-owned
  sequential pipeline that emits minimal typed events through `AsyncStream`.
- Source dependencies: exact compatible versions of KeyboardShortcuts,
  ZIPFoundation, swift-nio, swift-nio-ssl, and Sparkle only. Keep ebook
  processing inside the app process; Sparkle may use its embedded installer
  service only for signed application updates. Review versions and licenses.
- Sandbox entitlements: user-selected read-only files and outgoing network client
  plus Sparkle's required installer-service mach-lookup exception.
- Archive/XML: bounded ZIPFoundation entry streaming and Foundation `XMLParser`
  with external entities disabled; never use `Process`, `/usr/bin/zip`, or
  `/usr/bin/unzip`.
- SMTP: a narrow SwiftNIO/NIOSSL state machine supporting implicit TLS and
  STARTTLS, TLS-only authentication, streaming MIME, cancellation, and typed
  `delivery_unknown`.
- Tests: Swift Testing for domain, pipeline, adapter, and fixture contracts;
  XCTest/XCUITest for UI, accessibility, and performance.
- Secrets: traditional file-based macOS Keychain generic-password items; never
  Data Protection Keychain selectors, ordinary preferences, project files,
  logs, reports, presentation models, remote storage, or custom encrypted files.
- Forbidden: processing helpers, executable downloads, Calibre, installed
  EPUBCheck, Raycast, Python or Java runtime requirements, Docker, local
  services, and user-installed processing tools. The Python appcast script runs
  only in GitHub Actions and is never bundled as an app runtime dependency.

## Credential And Release Signing Law

- SMTP passwords MUST use only the traditional file-based macOS Keychain.
- Never persist credentials in plaintext, `UserDefaults`, project files, custom
  files, or encryption protected by a key embedded in the application.
- Every distributed version and nested executable MUST use the stable
  `Book Sender Release Signing` identity and the pinned certificate in
  `scripts/signing/BookSenderReleaseSigning.cer`.
- The main app MUST retain the exact designated requirement anchored to the
  pinned certificate and `com.rckbrcls.BookSender`.
- Ad-hoc and unsigned signatures are prohibited for distributed artifacts.
  Ad-hoc signing remains permitted only for non-distributed test hosts.
- Missing, invalid, or divergent private signing material MUST block release;
  never add an ad-hoc, alternate-identity, or unsigned fallback.
- Identity rotation requires Erick's explicit authorization, a written migration
  plan, and a user notice that the SMTP password may require one-time re-entry.
- Sparkle EdDSA remains independent and mandatory. The self-signed identity is
  not Developer ID, provides no Apple notarization, and does not remove
  Gatekeeper friction from manual installation.
- The installer MUST verify the GitHub asset SHA-256 digest and the pinned
  public DER certificate before registering only that public certificate in
  the user's default Keychain. The first registration MUST require explicit
  terminal confirmation. Registration MUST be idempotent and MUST NOT use
  `security add-trusted-cert`, import a private key, or install an explicit
  Always Trust override.
- Distributed builds MUST retain the hardened runtime. Because the pinned
  self-signed identity has no Apple Team ID, only the main executable MAY carry
  `com.apple.security.cs.disable-library-validation`.
- The library-validation exception MUST NOT weaken artifact verification:
  every bundled Sparkle executable remains signed by the pinned certificate.
- A signed-app launch smoke test MUST pass before packaging so dyld framework
  rejection or an early process exit blocks publication.
- Publication MUST also depend on a separate clean macOS runner that never
  receives the PKCS#12, installs the packaged candidate through the real
  public-certificate bootstrap, confirms that no private signing identity was
  imported, and passes strict signature and launch checks.

## Repository Layout

- `BookSender.xcodeproj/`: the sole application project.
- `BookSender/`: all production Swift source and app resources.
- `BookSenderTests/`: domain, application, adapter, privacy, and performance tests.
- `BookSenderUITests/`: two-screen, keyboard, accessibility, and journey tests.
- `.github/workflows/release.yml`, `appcast.xml`, and `scripts/`: the approved
  Sparkle, GitHub Release, GitHub Pages, and installer distribution surfaces.
- `specs/005-lightweight-macos-sender/`: active product specification and
  validation records.
- Do not recreate the removed Raycast, Node, PageForge, Calibre, conversion, or
  historical product trees.

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
