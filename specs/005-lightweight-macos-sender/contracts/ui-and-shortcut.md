# Contract: UI and Global Shortcut

## Primary surfaces

The application exposes exactly:

1. `Delivery Setup`
2. `Send Book`

A sheet, alert, file importer, confirmation, or inline disclosure is not a
primary screen. There is no Settings scene, library, history, queue, inspector,
repair screen, or report screen.

## Launch routing

- Incomplete setup routes to `Delivery Setup`.
- Complete setup routes to `Send Book`.
- Editing setup reuses `Delivery Setup` and returns to the intact send context.
- No credential value is restored into visible plain text.

## Main window

- At most one primary window exists.
- Closing it may keep the process active.
- Reopening or shortcut activation restores the existing window and state.
- New-window commands are unavailable.
- Activation never initiates preparation confirmation or SMTP delivery.

## Send screen

Finder selection and drag-and-drop both accept multiple EPUB/PDF URLs through the
same intake service. The default item presentation is limited to display name,
format, and a concise derived state. Technical evidence is collapsed and appears
only when it supports a blocked/failure/recovery decision.

The send action is disabled without complete setup and an eligible item. Before
network activity, confirmation identifies destination, eligible count, and
excluded count. Retry targets failed items only; delivery-unknown items require a
fresh explicit decision and are never automatically retried.

## Shortcut

- The shortcut is configurable and disableable.
- A registration conflict is shown inline and does not block normal launching.
- When setup is complete, invocation focuses `Send Book`.
- When setup is incomplete, invocation focuses `Delivery Setup`.
- Invocation while visible reuses the current window and batch.
- No Accessibility permission or event-tap permission is required.

## Accessibility

Every field, drop target, picker, list item, state, confirmation, cancellation,
recovery action, and shortcut recorder is keyboard reachable and has a stable
accessibility identifier and meaningful label. State meaning is not conveyed by
color alone.
