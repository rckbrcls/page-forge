# Contract: UI, Settings, and Shortcut

## Product surfaces

Primary screens:

1. `Delivery Setup`
2. `Send Book`

The auxiliary native Settings window contains only:

1. `Delivery`
2. `Shortcut`

Sheets, system file pickers, confirmations, alerts, progress, and inline detail
are not primary screens. Preview, demo, back-to-setup bypass, library, history,
queue, report, repair, and account surfaces do not exist.

## Real-state presentation

- `Send Book` is reachable only from complete setup.
- Finder and drag-and-drop use the same real intake.
- Every visible row represents an actor-owned real item.
- Concise states are `Checking`, `Preparing`, `Ready`, `Needs Attention`,
  `Sending`, and one honest terminal outcome.
- Healthy and successfully prepared items keep technical evidence collapsed.
- Blocked, restored, failed, or uncertain items may reveal actionable inline
  detail.
- No invented percentage, simulated delay, fake ready state, placeholder
  success, or unavailable-protocol message appears.

## Commands

- Send is disabled without complete setup and an eligible item.
- Confirmation shows destination, eligible count, and excluded count.
- Cancel is available during active preparation or delivery.
- Remove and clear are unavailable while a confirmed send is active.
- `Retry Failed` targets only definitive failures.
- `Delivery Unknown` provides review guidance but no automatic retry.

## Settings

Delivery edits reuse first-launch validation and transaction rules. Existing
credential is preserved when password is blank. Saving is disabled during active
confirmed delivery. Editing an idle setup preserves the current unconfirmed batch.

Shortcut settings expose recorder, enabled state, and registered, disabled, or
conflict feedback. Conflict does not block normal launching.

## Window and shortcut

At most one primary window exists. New-window commands are absent. Shortcut
invocation:

- reconciles route from actual setup completeness;
- activates the application;
- reuses the captured main window or opens the main window when absent;
- preserves current batch and active operation;
- never confirms, retries, or initiates delivery.

## Accessibility

Every field, picker, drop target, batch item, state, confirmation, cancellation,
remove, clear, retry, Settings tab, and shortcut control is keyboard reachable,
has a stable non-preview identifier, and has a meaningful screen-reader label.
State is not communicated by color alone.

## UI-test state

UI tests use isolated, explicitly injected stores and deterministic fixture URLs.
They do not use production preview paths or rely on residual user preferences.
Reset/setup launch arguments are valid only when an app-side test composition
explicitly consumes them without weakening release behavior.
