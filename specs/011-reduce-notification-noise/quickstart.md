# Quickstart: Validate Essential Notification Feedback

## Purpose

Validate that Feature 011 removes redundant production notifications without
removing semantic feedback, contextual state, approved invisible-side-effect
cards, or the reusable Feature 010 component contract.

The repository working agreement forbids build, test, app launch, UI automation,
and browser/run commands unless Erick explicitly authorizes them. Commands below
are planned gates. Only static source checks may run by default.

## Prerequisites

- macOS 26.0+;
- repository-selected Xcode toolchain with Swift 6 complete concurrency checks;
- existing exact package versions resolved by the project;
- deterministic UI-test fixtures containing no personal credentials, addresses,
  paths, or book content in reports;
- controlled feedback sleeper for temporary-card tests;
- explicit authorization before build, test, app launch, UI automation,
  authenticated SMTP, signing, or release validation.

Read:

- [spec.md](./spec.md)
- [plan.md](./plan.md)
- [research.md](./research.md)
- [data-model.md](./data-model.md)
- [notification eligibility contract](./contracts/notification-eligibility.md)
- [approved catalogue](./contracts/approved-notification-catalogue.md)
- [contextual feedback contract](./contracts/contextual-feedback.md)
- [Feature 010 presentation contract](../010-floating-feedback-system/contracts/notification-presentation.md)
- [Feature 010 lifecycle contract](../010-floating-feedback-system/contracts/notification-lifecycle.md)

## Gate 1: Static source checks

These checks do not build or launch the app:

```bash
git diff --check

rg -n 'NotificationPublicationIntent|NotificationReason' \
  BookSender/Application/Presentation \
  BookSender/App/AppModel.swift \
  BookSenderTests

rg -n 'publishNotification\(|notificationCenter\.publish\(' \
  BookSender/App/AppModel.swift \
  BookSender/Application/Shortcut \
  BookSender/Features

rg -n 'notificationFeedback\(' \
  BookSender/Features \
  BookSender/App/AppModel.swift

rg -n 'feedback\(for:' \
  BookSender/Features/DeliverySetup \
  BookSender/Features/SendBook \
  BookSender/Features/Settings

rg -n 'uiTestNotification(Matrix|Stack|Appearance)|publishUITestTerminal' \
  BookSender/App \
  BookSenderTests \
  BookSenderUITests

rg -n 'notification\.(application|batch|history|shortcut|update)' \
  BookSenderUITests \
  BookSenderTests

rg -n 'floating notification|contextual|invisible' \
  README.md \
  docs/desktop-migration.md \
  docs/troubleshooting.md

rg -n 'repositoryURL' BookSender.xcodeproj/project.pbxproj

xcrun swiftc -frontend -parse \
  $(rg --files BookSender BookSenderTests BookSenderUITests -g '*.swift')
```

Expected:

- production acknowledged/in-progress feedback is never published;
- every production terminal card has one approved explicit reason;
- setup save/delete, diagnostic copy, and history persistence are the only
  current eligible action paths;
- application restore, batch, send, confirmation, history load/clear, shortcut,
  and successful update-check paths are silent;
- feature views obtain failure/context from semantic feedback rather than card
  entries;
- a new contextual action removes a stale card only for its matching scope and
  destination;
- test-only component scenarios still publish directly under their explicit
  launch arguments;
- component center/card/host files add no persistence or dependency;
- documentation describes contextual default and the reduced catalogue;
- no package/project dependency change exists;
- Swift source parses and documentation has no whitespace errors.

Static parsing does not establish type checking, compilation, test behavior,
runtime UI, accessibility, authenticated SMTP, signing, or release status.

### Static evidence recorded on 2026-07-31

- `git diff --check`: passed with no whitespace errors.
- Swift frontend parse across `BookSender`, `BookSenderTests`, and
  `BookSenderUITests`: passed with no syntax errors.
- Producer scan: six explicit `.floating(...)` terminal call sites map to the
  four approved current action paths; the two reserved reasons have no producer.
- Direct-center scan: production routing goes through the gated helper; direct
  publication remains only in the explicit matrix/stack/appearance UI-test
  fixture method.
- Semantic-consumer scan: production feature views contain no
  `notificationFeedback(...)` call; delivery, batch, history, and shortcut
  failure evidence reads `feedback(for:)`.
- Contextual UI assertions cover bootstrap, ready/send/reset, update, shortcut,
  history load/clear, validation, mixed/failure/cancelled/unknown delivery, and
  inline recovery without card expectations.
- Component, SMTP, history service, Keychain adapter, Xcode project, and
  `Package.resolved` comparison: no changes.
- Persistence scan: notification intent/reason types do not occur in domain,
  history, credential, or SMTP persistence boundaries.
- No build, type-check, test, app launch, UI automation, SMTP, signing, or
  release command was run; Gates 2–4 remain pending explicit authorization.

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

- all twenty actions have an explicit classification;
- new/unknown actions default to contextual;
- acknowledged and in-progress feedback never publishes;
- contextual terminal state remains available through `feedback(for:)`;
- contextual events create no visible entry, queued entry, expiry task, or
  accessibility announcement;
- setup save success publishes one temporary card to its originating window;
- setup validation/storage failure remains contextual and produces no card;
- setup deletion success/partial publishes one card;
- diagnostic-copy success/failure publishes independently from the original
  failure scope;
- history-write failure after accepted SMTP publishes one persistent card and
  does not change/retry delivery;
- application, batch, confirmation, send, history load/clear, shortcut, and
  update success remain silent;
- a new contextual action removes stale presentation for its own scope only;
- all Feature 010 center/model/queue/timing tests remain green;
- existing setup, pipeline, delivery, history, privacy, and diagnostics tests
  remain green.

## Gate 3: Focused UI and accessibility tests

Requires explicit authorization:

```bash
xcodebuild \
  -project BookSender.xcodeproj \
  -scheme BookSender \
  -destination 'platform=macOS' \
  -only-testing:BookSenderUITests/FloatingNotificationUITests \
  -only-testing:BookSenderUITests/AccessibilityUITests \
  -only-testing:BookSenderUITests/BatchSendUITests \
  -only-testing:BookSenderUITests/SettingsUITests \
  -only-testing:BookSenderUITests/SendHistoryUITests \
  -only-testing:BookSenderUITests/RecoveryJourneyUITests \
  -only-testing:BookSenderUITests/FloatingNotificationAppearanceUITests \
  test
```

### Zero-card normal send journey

1. Launch with configured deterministic PDF fixtures.
2. Add and prepare one book.
3. Confirm `Ready` in the row and no `notification.batch` card.
4. Open and dismiss confirmation; confirm no card.
5. Confirm and finish delivery; confirm per-book/aggregate terminal state and no
   card.
6. Start another send; confirm the list visibly resets and no card.

### Contextual failure journey

1. Submit invalid setup and confirm field errors/failure detail with no card.
2. Load unavailable history and confirm unavailable/retry state with no card.
3. Trigger shortcut conflict and confirm registration state/failure detail with
   no card.
4. Trigger failed/unknown/mixed delivery and confirm row plus aggregate evidence
   with no card.
5. Confirm every state remains keyboard reachable and understandable without
   color.

### Approved invisible-side-effect journey

1. Save valid setup and confirm exactly one temporary setup card in the
   originating window.
2. Delete setup and confirm exactly one terminal Keychain-result card.
3. Copy diagnostic details and confirm one success or failure card without
   removing the original failure detail.
4. Trigger controlled history persistence failure after accepted SMTP and
   confirm one persistent history card while the delivery remains submitted.

### Component-only journey

1. Launch matrix, stack, and appearance fixtures.
2. Confirm close-only, action-only, both-control, and no-control cards.
3. Confirm three visible cards, queued promotion, full promoted lifetime, and
   window isolation.
4. Confirm typed recovery, focus stability, Reduce Motion, Reduce Transparency,
   Increase Contrast, and Liquid Glass readability.
5. Confirm these fixtures do not alter the production catalogue.

## Gate 4: Manual macOS runtime matrix

Requires explicit authorization to launch and inspect the app:

- first launch with setup required;
- configured launch and global shortcut reveal;
- one-book and mixed multi-book intake;
- confirmation open/cancel/confirm;
- successful, failed, cancelled, partial, and unknown delivery;
- remove, clear, and send-more reset;
- history load, empty, unavailable, clear success/failure;
- shortcut enable, disable, register, and conflict;
- update interface opening;
- setup save and delete from onboarding/Settings;
- diagnostic copy success/failure;
- controlled history-write failure after accepted delivery;
- main and Settings visible together;
- keyboard-only and VoiceOver;
- Reduce Motion, Reduce Transparency, and Increase Contrast.

Expected:

- normal workflow changes produce no floating cards;
- visible contextual meaning and recovery remain complete;
- only invisible approved outcomes produce cards;
- every eligible card appears in its originating window;
- cards never steal focus or replace modal decisions;
- delivery uncertainty remains explicit without a card;
- no card dismissal changes a domain outcome.

## Requirement traceability

| Requirements | Planned implementation evidence | Authored validation |
|---|---|---|
| FR-001–FR-008 | default-contextual intent, silent progress, semantic view queries | exhaustive classification and zero-card workflow tests |
| FR-009–FR-016 | approved terminal opt-ins and reasons | setup/delete/copy/history persistence journeys |
| FR-017–FR-023 | typed recovery, stale removal, existing lifetime normalization | intent, semantic-retention, replacement, and expiry tests |
| FR-024–FR-028 | contextual accessibility plus isolated fixtures | announcement, focus, matrix, stack, and appearance tests |
| CC-001–CC-008 | no surface/storage/dependency/domain change | constitution and separated validation gates |

## Validation boundaries

- Static checks prove only source structure, syntax, and documentation hygiene.
- Build/test gates prove compilation and deterministic automated behavior only
  after explicit authorization.
- UI/runtime gates prove rendered silence, contextual evidence, focus, and
  accessibility only after explicit authorization.
- Authenticated SMTP proves provider interaction, not Kindle receipt or
  processing.
- Signing/release validation remains separate and is not required to design the
  presentation-policy reduction.
