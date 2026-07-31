# Quickstart: Validate Floating Feedback System

## Purpose

Use this guide after implementation to validate Feature 010 without confusing
static source evidence, compiled behavior, deterministic lifecycle tests,
macOS window/accessibility behavior, authenticated SMTP behavior, or release
publication.

The repository working agreement forbids build, test, app launch, UI
automation, and browser/run commands unless Erick explicitly authorizes them.
The commands are planned validation commands. Only the static source gate may
run by default.

## Prerequisites

- macOS 26.0+;
- repository-selected Xcode toolchain with Swift 6 complete concurrency checks;
- existing exact Swift package versions resolved by the project;
- UI-test launch fixtures with no personal credentials, addresses, paths, or
  book content in reports/screenshots;
- controlled `FeedbackSleep` for deterministic time;
- explicit authorization before build, test, app launch, UI automation,
  authenticated SMTP, signing, or release validation.

Read:

- [spec.md](./spec.md)
- [plan.md](./plan.md)
- [research.md](./research.md)
- [data-model.md](./data-model.md)
- [notification presentation contract](./contracts/notification-presentation.md)
- [notification lifecycle contract](./contracts/notification-lifecycle.md)
- [notification action and accessibility contract](./contracts/notification-action-accessibility.md)
- [batch row divider contract](./contracts/batch-row-divider.md)

## Gate 1: Static source checks

These checks do not build or launch the app:

```bash
git diff --check

rg -n 'FloatingNotificationHost|FloatingNotificationCard' \
  BookSender/App/BookSenderApp.swift \
  BookSender/Features/Settings/BookSenderSettingsView.swift \
  BookSender/Features/Shared

rg -n 'NotificationDestination|FloatingNotificationCenter|NotificationTaskKey' \
  BookSender/Application/Presentation \
  BookSender/App/AppModel.swift

rg -n 'ActionFeedbackView' \
  BookSender/Features \
  BookSender/App

rg -n 'notification\\.host\\.main|notification\\.host\\.settings|notification\\.' \
  BookSenderUITests

rg -n 'listRowSeparator|Divider|sendBook\\.item\\.divider' \
  BookSender/Features/SendBook/SendBookView.swift \
  BookSenderUITests

rg -n 'UserDefaults|AppStorage|FileManager|JSONEncoder|JSONDecoder|URLSession' \
  BookSender/Application/Presentation \
  BookSender/Features/Shared

rg -n 'repositoryURL' BookSender.xcodeproj/project.pbxproj

xcrun swiftc -frontend -parse \
  $(rg --files BookSender BookSenderTests BookSenderUITests -g '*.swift')
```

Expected:

- exactly one main host and one Settings host exist;
- destination is explicit and exhaustive;
- no feature view embeds `ActionFeedbackView`;
- failure/context views remain present;
- notification state has no persistence, network, filesystem, or preferences
  access;
- no package was added;
- explicit dividers exist and the default row separator is hidden;
- UI tests use `notification.*` rather than inline `feedback.*` selectors;
- Swift source parses and documentation has no whitespace errors.

An empty `ActionFeedbackView` search is expected after migration. The type/file
may be deleted once all consumers are gone.

### Static evidence recorded on 2026-07-31

- PASS: `git diff --check` reported no tracked whitespace errors.
- PASS: an equivalent `git diff --no-index --check` scan reported no whitespace
  errors in the 22 untracked Feature 010 source, test, contract, and planning
  files.
- PASS: `xcrun swiftc -frontend -parse` parsed all 133 Swift source and test
  files without diagnostics.
- PASS: the composition-root scan found exactly two
  `FloatingNotificationHost` uses: main and Settings.
- PASS: destination, host, card, action, close, count, focus-request, and
  diagnostic-copy identifier scans found the shared typed paths and 29
  notification selector references.
- PASS: the obsolete `ActionFeedbackView` and `feedback.*` UI-selector scan was
  empty after deletion.
- PASS: divider scans found stable `BatchRowPosition` projection, hidden native
  separators, deterministic divider identifiers, and the authored 0.90 geometry
  assertion.
- PASS: notification presentation/shared-component scans found no
  `UserDefaults`, `AppStorage`, filesystem, JSON persistence, network session,
  connection, or process execution.
- PASS: the project and resolved-package diff was empty; Feature 010 adds no
  package or project-file dependency change.

These results are syntax and source-structure evidence only. They do not
establish type checking, compilation, test execution, runtime layout,
accessibility behavior, provider delivery, signing, or release status.

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

- missing duration becomes four seconds;
- durations below one become one and above five become five;
- non-finite duration becomes four;
- success/information cannot remain persistent;
- failed/cancelled/partial/unknown cannot expire automatically;
- main and Settings hold independent current/visible/queued state;
- no more than three entries are visible per destination;
- persistent cards are never evicted;
- a fourth relevant entry waits and starts its timer only after promotion;
- equivalent feedback updates one identity and occurrence count;
- replacement cancels the old task;
- a stale task cannot remove a newer entry;
- queued obsolete feedback never appears;
- manual close removes temporary presentation;
- manual close hides persistent presentation while failure stays queryable;
- one action cannot execute twice while in flight;
- host detach cancels temporary tasks without changing durable workflow state;
- existing setup, batch, history, diagnostics, and delivery tests remain green.

## Gate 3: Focused UI and accessibility tests

Requires explicit authorization:

```bash
xcodebuild \
  -project BookSender.xcodeproj \
  -scheme BookSender \
  -destination 'platform=macOS' \
  -only-testing:BookSenderUITests/FloatingNotificationUITests \
  -only-testing:BookSenderUITests/AccessibilityUITests \
  -only-testing:BookSenderUITests/SettingsUITests \
  -only-testing:BookSenderUITests/BatchSendUITests \
  -only-testing:BookSenderUITests/SendHistoryUITests \
  test
```

### Main-host journey

1. Launch with configured deterministic PDF fixtures.
2. Capture drop target, batch card, and primary action frames.
3. Trigger add/remove/clear success.
4. Confirm one top-trailing `notification.batch` card.
5. Re-capture frames during and after the card.
6. Confirm no frame moves.
7. Confirm the card disappears by five seconds.

### Settings-host journey

1. Open Settings while the main window remains visible.
2. Save delivery setup and change/disable the shortcut.
3. Confirm cards appear only in `notification.host.settings`.
4. Confirm sender field, recorder, and switch frames do not move.
5. Trigger main-window feedback and confirm it appears only in the main host.
6. Close/reopen Settings and validate temporary/persistent host behavior.

### Stack and queue journey

1. Publish three controlled persistent cards in one destination.
2. Publish a fourth temporary card.
3. Confirm exactly three cards are visible and no overlap occurs.
4. Close one persistent card.
5. Confirm the queued card appears and receives its full visible interval.
6. Replace a queued entry before promotion and confirm stale content never
   appears.

### Action and close journey

1. Present close-only, action-only, both-control, and no-control permitted
   variants.
2. Navigate by keyboard through action then close.
3. Activate action once with Return and key repeat.
4. Confirm exactly one typed outcome.
5. Close a persistent failure card.
6. Confirm `FailureDetailView` and recovery remain available.
7. Confirm close never retries, cancels, clears, or reclassifies workflow state.

### Modal precedence journey

1. Keep a card visible.
2. Open batch confirmation, reset-unknown alert, and clear-history alert.
3. Confirm modal controls remain focused and hittable.
4. Confirm notification controls do not become the modal decision path.
5. Dismiss the modal and confirm card lifetime did not restart.

### Divider geometry journey

1. Load batches with 1, 2, 3, and 20 items.
2. Confirm divider counts are 0, 1, 2, and 19.
3. Compare every visible divider width with usable card row width.
4. Confirm every ratio is at least 0.90.
5. Confirm no final divider.
6. Expand an item detail and repeat.
7. Resize and scroll, then repeat for reused rows.

## Gate 4: Manual macOS runtime matrix

Requires explicit authorization to launch and inspect the app:

- main window only;
- Settings only after main closure;
- main and Settings visible together;
- minimum supported window size;
- larger main window;
- one short card;
- one long wrapping card;
- three persistent cards;
- one queued temporary card;
- repeated same feedback;
- replacement at the end of a timer;
- window deactivation past expiry;
- Settings closure/reopen;
- native sheet and alert over visible cards;
- keyboard-only operation;
- VoiceOver announcement and control order;
- Reduce Motion;
- Reduce Transparency;
- Increase Contrast;
- long filename plus expanded row detail;
- 20-item scrolling batch.

Expected:

- top-trailing cards never occupy the central workflow;
- no underlying layout moves;
- no card leaves window bounds or covers toolbar/window/modal controls;
- semantic meaning does not depend on color/icon;
- focus is stable unless an activated typed action intentionally moves it;
- temporary cards remain absent after expiry/reactivation;
- persistent failures remain recoverable;
- dividers remain near-full-width and subordinate.

## Requirement traceability

| Requirements | Implementation evidence | Authored validation |
|---|---|---|
| FR-001–FR-007 | root hosts, destination partition, overlay composition | static host scan, main/Settings layout-invariance UI journeys |
| FR-008–FR-019 | normalized presentation configuration and card | model matrix tests, wrapping/icon/action/close UI journey |
| FR-020–FR-029 | lifetime normalization and visible-only tasks | controlled sleeper, inactivity, replacement-race tests |
| FR-030–FR-038 | max-three destination snapshot and relevance queue | stack/queue/host-detach deterministic tests |
| FR-039–FR-048 | removed inline acknowledgements with contextual state retained | source scan, failure detail, unknown-delivery, modal regression journeys |
| FR-049–FR-055 | typed commands, focus requests, accessibility semantics | keyboard, single announcement, appearance matrix |
| FR-056–FR-061 | explicit conditional dividers | count and frame-ratio UI geometry tests |
| CC-001–CC-010 | two-screen/no-storage/no-new-dependency architecture | constitution review and separated gates |

## Implementation-time feedback catalogue reconciliation

| Producer/category | Floating destination | Durable contextual state retained |
|---|---|---|
| Application restore and update check | main | bootstrap route/setup result and native Sparkle UI |
| Delivery setup save/delete/credential outcomes | explicit main or Settings origin | field validation, save progress, setup guidance, failure details |
| Shortcut register/change/disable/conflict | Settings | recorder, enabled switch, registration state, failure details |
| Intake, add/remove/clear, preparation and batch summaries | main through `batch` | active progress, aggregate counts, every `BatchItemRow`, item details |
| Definitive/failed/cancelled/partial/unknown delivery summary | main through `batch` | per-book terminal result, retry controls, unknown guidance and confirmation |
| Diagnostic copy success/failure | originating main or Settings window through `diagnosticCopy` | original expanded diagnostic and recovery controls |
| History load/record/clear outcomes | main | loading/unavailable/empty/list/count state and clear confirmation |

`batchItem` and `delivery` remain typed semantic scopes for contextual item
truth; they are not promoted into one floating card per book. The `batch`
summary is the floating producer. Confirmation sheets, alerts, field errors,
active progress, per-book results, diagnostics, history content, and delivery
uncertainty remain durable contextual presentation.

The implementation-time scan found no additional action acknowledgement outside
these categories. Every floating publication flows through
`AppModel.publishNotification`, `ActionFeedbackService`, and the shared center.
The former `ActionFeedbackView` has no consumers and was removed. Notification
entries, queue order, hidden markers, focus requests, and timers remain
in-memory presentation only and do not create notification history.

## Gate 5: Existing delivery regression

Feature 010 does not change SMTP, ebook preparation, history eligibility, or
credential behavior. Deterministic existing tests must still prove:

- explicit confirmation before transmission;
- sequential independent attempts;
- no automatic retry;
- failure isolation;
- `Delivery Unknown` remains uncertain;
- only definitive acceptance creates history;
- notification close/action does not change delivery truth.

Authenticated SMTP validation, if desired, requires separate explicit
authorization and dedicated non-personal credentials. It must not claim Kindle
receipt or processing.

## Gate 6: Release validation

Feature acceptance does not establish signing or publication. Keep pinned
certificate signing, hardened runtime, nested Sparkle signature checks,
clean-runner installation, launch smoke test, appcast, GitHub Release, Pages,
and public endpoint verification as separate release gates.

## Implementation validation status

The static source gate is recorded separately below. Compilation, automated
tests, app launch, UI automation, authenticated SMTP, signing, packaging,
manual appearance inspection, and release commands remain unexecuted because
they require separate explicit authorization.
