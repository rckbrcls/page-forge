# Quickstart: Validate Transient Feedback and Send History

## Purpose

Use this guide after implementation to validate Feature 009 without confusing
static evidence, compiled behavior, macOS runtime behavior, authenticated SMTP
acceptance, and release publication.

The repository working agreement forbids build and run commands unless Erick
explicitly authorizes them. The commands below are planned validation commands;
only the static gate may be used by default.

## Prerequisites

- macOS 26.0+ and the repository-selected Xcode toolchain;
- the existing exact Swift package versions resolved by the project;
- an isolated test history root and preference suite for automated tests;
- no personal credentials in fixtures, logs, screenshots, or reports;
- explicit authorization before build, test, app launch, UI automation, or live
  SMTP validation.

Read:

- [data-model.md](./data-model.md)
- [feedback lifecycle contract](./contracts/feedback-lifecycle.md)
- [completed batch reset contract](./contracts/completed-batch-reset.md)
- [send history storage contract](./contracts/send-history-storage.md)
- [send history UI contract](./contracts/send-history-ui.md)

## Gate 1: Static source checks

These checks do not build or run the app:

```bash
git diff --check
rg -n 'case deliverySetup|case sendBook' BookSender/App
rg -n 'Send More Books|No books submitted yet\\.|Clear History|Send|History' \
  BookSender BookSenderTests BookSenderUITests
rg -n 'sourcePath|sourceURL|kindleAddress|password|smtpReply|bookContent' \
  BookSender/Adapters/History \
  BookSender/Application/History \
  BookSender/Domain/Ports/HistoryProtocols.swift
rg -n 'repositoryURL' BookSender.xcodeproj/project.pbxproj
rg -n 'Resend|Locate|Preview|Export|Synchronize|Search|Filter|Analytics' \
  BookSender/Features/SendBook/SendHistoryView.swift \
  BookSender/Application/History \
  BookSender/Adapters/History
xcrun swiftc -frontend -parse \
  $(rg --files BookSender BookSenderTests BookSenderUITests -g '*.swift')
```

Expected:

- application routing still exposes only `Delivery Setup` and `Send Book`;
- the exact required UI strings exist in the intended feature files;
- history models and storage contain no prohibited private fields;
- no source package was added for timing, persistence, or tabs;
- documentation and source diffs contain no whitespace errors.

## Implementation evidence — 2026-07-30

Completed static evidence:

- `git diff --check`: passed with no whitespace errors.
- Route scan: exactly `deliverySetup` and `sendBook` remain application routes.
- Required-string scan: `Send`, `History`, `Send More Books`,
  `No books submitted yet.`, and `Clear History` are present in the intended
  source and test surfaces.
- Durable-history prohibited-field scan: no source path/URL, address, password,
  SMTP reply, book-content, batch, snapshot, or item identifier appears in the
  history adapter, application service, or storage port. The ephemeral
  `SubmissionReceipt` intentionally carries local batch correlation before its
  three-field record projection.
- Package scan: the project still references only KeyboardShortcuts,
  ZIPFoundation, swift-nio, swift-nio-ssl, and Sparkle.
- History-management scan: no resend, locate, preview, export, synchronization,
  search, filter, or analytics action appears in the history feature, service,
  or adapter.
- Process/helper scan: no `Process`, system executable, helper process, Docker,
  Calibre, Python, or Java dependency appears in the history implementation.
- Static Swift parse: all 121 Swift source and test files passed
  `xcrun swiftc -frontend -parse`.
- Focused static type checks passed for the four-file history
  model/port/service/store slice and for the 14 Foundation-only domain and
  feedback/diagnostic presentation sources. A 13-file domain/workspace slice
  also passed after the reset cleanup contract change. All used an isolated
  module cache.

Not executed:

- compilation or deterministic test execution;
- UI/accessibility or performance test execution;
- app launch or manual macOS validation;
- authenticated SMTP validation;
- signing, packaging, update, publication, or release validation.

These remain separate pending gates and require explicit authorization.

## Requirement traceability

| Requirements | Implementation evidence | Authored validation |
|---|---|---|
| FR-001–FR-006 | `ActionFeedbackService`, scoped expiry tasks in `AppModel`, identity/state announcements | `ActionFeedbackServiceTests`, `ActionFeedbackExpiryTests`, setup/shortcut/batch accessibility journeys |
| FR-007–FR-014 | completed read-only derivations, guarded pipeline clear, `Send More Books`, uncertainty confirmation, batch-scoped events | `CompletedBatchResetTests`, `BatchRetryTests`, `BatchSendUITests`, `AccessibilityUITests` |
| FR-015–FR-016 | local `SendBookTab` selection and segmented `Send`/`History` presentation | active and ready tab-switching journeys in `SendHistoryUITests` |
| FR-017–FR-021 | accepted-at receipt, record-before-advance service call, versioned local store, newest-first retention | history model/service/adapter/pipeline/performance tests and relaunch UI journey |
| FR-022 | exact three-field `SubmissionRecord` projection and storage allow-list | `SendHistoryPrivacyTests` and static prohibited-field scan |
| FR-023–FR-024 | confirmed independent clear, exact empty/loading/unavailable states | `SendHistoryUITests` clear success/cancel/failure and empty/unavailable journeys |
| FR-025–FR-026 | separate typed history failure leaves delivery `Submitted`; wording is SMTP submission only | `PipelineHistoryTests`, `FailurePresentationTests`, and history-management scan |

## Gate 2: Compilation and deterministic tests

Requires explicit authorization:

```bash
xcodebuild \
  -project BookSender.xcodeproj \
  -scheme BookSender \
  -destination 'platform=macOS' \
  build

xcodebuild \
  -project BookSender.xcodeproj \
  -scheme BookSender \
  -destination 'platform=macOS' \
  test
```

Expected deterministic coverage:

- success/info feedback uses a four-second delayed policy;
- a controllable sleeper proves expiry, replacement, and stale-task safety;
- active, failed, cancelled, partial, and unknown feedback remains;
- accepted attempts record exactly once;
- failed, cancelled, excluded, unattempted, and uncertain attempts record zero
  entries;
- identical display names from separate accepted attempts remain separate;
- records are newest first and capped at 500 across multi-item inserts;
- malformed, unsupported, over-size, read-only, and clear-failure stores produce
  typed safe failures;
- history failure never changes `Submitted` or triggers SMTP retry;
- completed reset preserves setup, preferences, credentials, and history;
- a late old-batch event cannot mutate the new batch.

## Gate 3: UI and accessibility journeys

Requires explicit authorization to build and launch the test host:

```bash
xcodebuild \
  -project BookSender.xcodeproj \
  -scheme BookSender \
  -destination 'platform=macOS' \
  -only-testing:BookSenderUITests \
  test
```

Validate:

1. Save setup and observe the success acknowledgement once.
2. Advance or wait through the full four-second interval and confirm the
   acknowledgement and layout space disappear no later than five seconds.
3. Replace visible success feedback and confirm the new result receives a full
   interval.
4. Confirm active progress, failure, cancellation, partial, and
   `Delivery Unknown` remain.
5. Complete a definitive batch and confirm the primary action becomes
   `Send More Books`.
6. Reset and confirm all temporary batch state disappears while setup and
   history remain.
7. Complete an uncertain batch; cancel the reset confirmation, then confirm it
   and verify both paths.
8. Retry a failed item from the completed state without resetting.
9. Switch between `Send` and `History` during an active batch and confirm no
   pipeline state changes.
10. Verify history rows, newest-first order, locale-aware date/time, empty
    state, clear confirmation, and relaunch persistence.
11. Verify keyboard focus, native control labels, visible status text, and one
    accessibility announcement per important transient feedback identity.

## Gate 4: Manual macOS runtime matrix

Requires explicit authorization to launch the app:

- make the application inactive while feedback is visible and reactivate it
  after expiry;
- change system time zone and regional format, then confirm stored timestamps
  render using current conventions;
- exercise Reduce Transparency, Increase Contrast, larger text, keyboard-only
  operation, and VoiceOver;
- make the isolated history location unavailable and confirm separate safe
  feedback without changing accepted delivery;
- quit immediately after a controlled definitive acceptance and relaunch to
  confirm the record exists;
- cancel `Clear History` and confirm no record changes.

## Gate 5: Authenticated SMTP acceptance

Requires separate explicit authorization and dedicated non-personal
credentials:

1. send one EPUB and one PDF through the real configured provider;
2. confirm exactly one record appears for each definitive SMTP acceptance;
3. induce or safely simulate rejection and uncertainty and confirm neither is
   recorded as submitted;
4. verify display wording says submitted and does not claim Kindle receipt,
   processing, or library availability.

Never include credentials, addresses, provider replies, paths, filenames,
message data, or book content in validation artifacts.

## Gate 6: Release validation

Feature acceptance does not establish signing or publication. Keep the existing
pinned-certificate signing, clean-runner installation, launch, Sparkle, appcast,
GitHub Release, and public-feed checks as separate release gates.

## Implementation status

No build, test, app launch, browser, UI automation, authenticated SMTP, signing,
or release command was executed during implementation. The static gate above is
complete; all later gates remain pending explicit authorization.
