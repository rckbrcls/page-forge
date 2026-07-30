# Contract: Native UI and Accessibility

## Product surface

1. The app retains exactly two primary screens: `Delivery Setup` and `Send Book`.
2. Settings remains an auxiliary native window with exactly `Delivery` and
   `Shortcut` tabs.
3. The main `Window` scene remains single-instance; Settings and transient sheets
   do not create another primary window.

## Confirmation presentation

1. Optional `ConfirmedBatchSummary` presence drives sheet presentation.
2. There is no independently mutable Boolean for the same presentation state.
3. Send, cancel, and dismiss act on and release the same stable snapshot.
4. Repeated intake cannot resurrect a dismissed stale snapshot.

## Typography and system settings

1. User-facing text uses semantic SwiftUI text styles.
2. Enlarged text preserves readable content, primary actions, terminal outcomes,
   and blocked-item explanations without clipping critical information.
3. Increased contrast preserves meaningful separation and focus.
4. Reduced transparency preserves hierarchy and legibility without relying on
   translucency alone.

## Keyboard and accessibility

1. Primary and secondary actions expose meaningful accessibility labels and
   roles.
2. Visible focus remains discernible.
3. Keyboard shortcuts produce an observable result, such as opening intake,
   sending a confirmed batch, cancelling pending work, or opening the intended
   Settings tab.
4. UI tests assert the result after the key action, not only the key event.

## AppKit interop

1. Window capture is driven by the representable view's attachment lifecycle.
2. Repeated SwiftUI updates do not enqueue duplicate main-thread window
   callbacks.
3. Sparkle observation updates cross to `MainActor` explicitly.
4. AppKit helpers remain presentation-only and do not own business rules.

## Required evidence

- Both Settings tabs are reachable and labeled.
- Main-window single-instance behavior.
- Confirmation send, cancel, and dismiss transitions.
- Keyboard actions with visible outcomes.
- Enlarged text, increased contrast, and reduced transparency coverage.
- Accessibility labels for primary actions, batch items, failures, and terminal
  results.
