# US4 Settings and Shortcut Validation

## Static implementation evidence

- Settings contains only Delivery and Shortcut tabs.
- Blank-password edits reuse the protected credential identity while advancing
  the setup revision.
- Delivery save is disabled while a confirmation or send is active.
- Shortcut state publishes registered, disabled, or sanitized conflict
  feedback.
- Shortcut invocation only reconciles the setup-derived route, activates the
  app, and reveals the captured primary window.
- The primary scene is a single `Window`; reopening requests are deduplicated
  until that main window is captured.
- Settings windows are never captured as the main window and shortcut
  invocation never confirms or starts delivery.

## Validation boundary

Static source and identifier checks passed. Keyboard registration, global
invocation, window focus, accessibility, and responsiveness were not executed.
