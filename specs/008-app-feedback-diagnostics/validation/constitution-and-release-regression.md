# Constitution and Release Regression Review

**Date**: 2026-07-30
**Constitution**: 7.2.0
**Status**: Passed by source and diff review only

## Product and architecture

- The visible product still has two primary routes: `Delivery Setup` and
  `Send Book`.
- The auxiliary Settings window still has only `Delivery` and `Shortcut`.
- Feedback, presentation, recording, and clipboard components follow the
  existing dependency direction. SwiftUI views do not interpret raw adapter
  failures.
- No helper process, runtime tool, telemetry service, diagnostic-history surface,
  custom diagnostic log store, diagnostic database, or source dependency was
  added. Feature 009 owns the separate bounded send-history surface.

## Credentials and privacy

- SMTP credentials continue to use the traditional file-based macOS Keychain
  through `KeychainCredentialStore`.
- Passwords are absent from feedback, diagnostic models, local records, copied
  details, preferences, and project files.
- Failure adapters translate raw boundary errors into closed codes and typed
  evidence before presentation, recording, or copying.
- The diagnostic recorder uses bounded macOS unified logging only. Retention
  remains system-managed.

## Book and pipeline integrity

- Originals remain read-only. Working-copy creation, collision handling,
  validation, and cleanup remain owned by the existing workspace and EPUB
  pipeline.
- The batch pipeline remains sequential and isolates item outcomes.
- Cancellation stops pending work and waits for the active delivery operation
  to settle. Delivery after message transmission begins remains explicitly
  uncertain and is not automatically retried.
- Authored fixture-backed tests cover the migrated archive, XML, audit, repair,
  filesystem, pipeline, and SMTP failure boundaries. Those tests were not
  executed in this pass.

## Update, signing, and release continuity

- `SPUStandardUpdaterController` remains the standard Sparkle update UI owner.
- `Package.resolved`, the Xcode project dependency declarations, release
  workflows, signing scripts, `appcast.xml`, `Info.plist`, and entitlements
  contain no feature change.
- The pinned `Book Sender Release Signing` identity, designated requirement,
  Sparkle EdDSA verification, hardened runtime, nested-signature checks,
  public-certificate bootstrap, clean-runner installation gate, and launch
  smoke test remain governed by the existing release workflow.
- No build, signature verification, package creation, installation, launch, or
  publication was performed.

## Evidence separation

- Static repository checks are recorded in `static-validation.md`.
- Compilation and deterministic tests require explicit authorization and
  remain unexecuted.
- UI/accessibility execution, local unified-log inspection, authenticated
  provider acceptance, signing, packaging, installation, and publication
  remain separate pending gates.
