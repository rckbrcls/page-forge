# Quickstart: Replace Mock Workflows Verification

This is a future verification guide. The planning workflow does not build, test,
launch, sign, send through SMTP, or publish the application.

## 1. Static repository gate

From the repository root:

```bash
git diff --check
plutil -lint BookSender.xcodeproj/project.pbxproj
plutil -lint BookSender/Info.plist
plutil -lint BookSender/BookSender.entitlements

rg -n -i \
  "PreviewBook|isPreviewing|previewSendBook|Back to Setup|Preview Send Book|mock|demo|SMTP delivery is not available" \
  BookSender BookSenderTests BookSenderUITests README.md .github

rg -n \
  "Raycast|@raycast|Calibre|EPUBCheck|Process\\(|/usr/bin/(zip|unzip)|child_process" \
  BookSender BookSenderTests BookSenderUITests BookSender.xcodeproj README.md
```

Expected:

- no preview/demo production source, identifier, test, or placeholder message;
- only reviewed contextual matches for forbidden historical terms;
- valid project and property-list syntax;
- one app target, one unit-test target, one UI-test target;
- exact existing package versions and no new dependency.

Also compare the feature contracts against the source and ensure every shipped
finding/repair rule has a named native fixture and focused test.

## 2. Compilation gate

These commands execute the project and require Erick's explicit authorization:

```bash
xcodebuild \
  -project BookSender.xcodeproj \
  -scheme BookSender \
  -destination 'platform=macOS' \
  build
```

Expected:

- Swift 6 complete concurrency checking succeeds;
- all filesystem-synchronized production/test sources belong to the intended
  targets;
- no warning indicates an unused repair plan, unreachable state, or unhandled
  actor isolation;
- dependency resolution matches `Package.resolved`.

Compilation does not prove tests, runtime behavior, authenticated delivery, or
distribution.

## 3. Unit and controlled integration gate

With separate authorization:

```bash
xcodebuild \
  -project BookSender.xcodeproj \
  -scheme BookSender \
  -destination 'platform=macOS' \
  test \
  -only-testing:BookSenderTests
```

Required groups:

- setup validation, Keychain lifecycle, revision-safe rollback, and preference
  privacy;
- shared intake outcomes, duplicate/change detection, PDF signature, digests,
  batch and attachment limits;
- workspace containment, original hashes, partial cleanup, clear/quit cleanup,
  and marker-bounded orphan sweep;
- archive preflight and XML boundaries at limit minus one, limit, and limit plus
  one;
- fixture-backed audit, deterministic repair, streaming write, reopen,
  revalidation, and regression rejection;
- stable value snapshots, actor ordering, cancellation, failure isolation,
  event projection, and failed-only retry;
- MIME and SMTP transcripts for implicit TLS, STARTTLS, authentication, replies,
  DATA, dot-stuffing, timeouts, final acceptance, and delivery uncertainty;
- privacy scans proving no secret, source path, payload, or hidden egress.

NIOEmbedded proves deterministic protocol transitions. A controlled loopback TLS
fixture proves channel upgrade and certificate behavior without using a personal
provider account.

## 4. UI and accessibility automation

With separate authorization:

```bash
xcodebuild \
  -project BookSender.xcodeproj \
  -scheme BookSender \
  -destination 'platform=macOS' \
  test \
  -only-testing:BookSenderUITests
```

Expected:

1. Reset state shows only `Delivery Setup` and no bypass.
2. Invalid save remains on setup with field-specific feedback.
3. Valid isolated test setup reaches `Send Book`; relaunch preserves only
   non-secret values.
4. Finder and drag/drop fixtures create the same real rows and states.
5. Confirmation shows the stable destination and counts before any controlled
   network activity.
6. Mixed results, cancel, remove, clear, failed-only retry, and unknown guidance
   remain available only in valid phases.
7. Settings contains only `Delivery` and `Shortcut`.
8. Shortcut reuses the one main window and correct route.
9. All journeys are keyboard reachable and meaningfully announced.

UI-test launch configuration must be explicitly consumed by a test-only
composition with isolated storage; residual user state is a failure.

## 5. Manual local acceptance

On a supported macOS 26+ test account:

1. Repeat first-launch setup, edit without a new password, replace the password,
   quit, relaunch, and inspect preferences for secret absence.
2. Add valid PDF, valid EPUB 2/3, repairable, ambiguous, unsafe, malicious,
   oversized, duplicate, and changed-file fixtures through both intake paths.
3. Compare original cryptographic digests before and after every success,
   failure, repair, cancellation, and unknown-delivery case.
4. Confirm a mixed 20-book batch; verify stable ordering, one active item,
   independent outcomes, later progress after one failure, and honest aggregate
   counts.
5. Cancel during intake, archive/XML work, writing, before SMTP DATA, and after
   DATA starts; verify cleanup and `Cancelled` versus `Delivery Unknown`.
6. Verify `Retry Failed` excludes submitted, cancelled, and unknown items.
7. Close the main window and invoke the shortcut repeatedly from another app;
   verify the same state returns within the target and no Settings window is
   mistaken for the primary window.
8. Repeat with keyboard, VoiceOver, light/dark appearance, active/inactive
   windows, Reduce Transparency, and Increase Contrast.

## 6. Authorized provider gate

Use a dedicated non-personal test mailbox and Kindle destination only after the
controlled SMTP suite passes. Do not record the credential or full transcript.

Verify separately:

- implicit TLS against a compatible provider;
- STARTTLS and second EHLO against a compatible provider;
- one successful EPUB and PDF;
- authentication and recipient rejection;
- network loss before and after DATA where safely reproducible;
- no automatic retry of uncertain delivery.

Redacted evidence may record setup mode, sanitized stage/outcome, timestamps, and
attachment digest. It must not record credential, message bytes, full source
path, or raw server material containing personal data.

## 7. Release gate

Before changing README/release notes from experimental or unavailable:

1. require compilation and the full approved unit/UI suite in release automation;
2. archive universal Release;
3. inspect sandbox entitlements and linked dependencies;
4. validate app and nested ad-hoc signatures;
5. validate Sparkle EdDSA and appcast identity;
6. inspect ZIP contents and absence of fixtures, previews, secrets, or legacy
   runtimes;
7. install and launch on a clean supported account;
8. verify an N-to-N+1 Sparkle update;
9. publish, redownload, and revalidate the public artifact and endpoints.

Ad-hoc signing is not notarization. A passing local build or authenticated SMTP
attempt does not prove update installation, clean-account behavior, or public
release correctness.
