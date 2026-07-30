# Native macOS Product Boundary

## Target Product

- One native Swift and SwiftUI macOS application
- Exactly two primary screens: `Delivery Setup` and `Send Book`
- One temporary batch with multi-file EPUB and PDF intake
- One advanced sequential background preparation pipeline
- One explicit sequential SMTP delivery flow with independent per-book outcomes
- One bounded local send history inside the existing `Send Book` primary screen
- One optional configurable global shortcut for quick access

## Interaction Boundary

The user configures SMTP once, selects books, waits for concise readiness, confirms
the stable eligible batch, and sees per-book delivery results. Inspection,
cleanup, restoration, revalidation, and technical reports are not peer navigation
surfaces.

`Send Book` contains `Send` and `History` as local tabs. `History` shows only
definitive SMTP submissions, retains at most 500 identifier/name/timestamp
records, and exposes no resend, retry, file-management, analytics, export, or
remote synchronization behavior.

Successful and informational acknowledgements remain visible for four seconds
and then collapse completely. Active, blocked, failed, cancelled, partial, and
delivery-unknown states remain until the state changes or the user deliberately
clears it. This timing applies independently to setup, shortcut, batch, update,
clipboard, and history feedback scopes.

Default item feedback remains limited to states equivalent to:

```text
Checking
Preparing
Ready
Needs Attention
Sending
Submitted / Failed / Cancelled / Delivery Unknown
```

Technical evidence stays collapsed unless it explains a blocked item, failure,
applied restoration, or decision.

## Pipeline Boundary

```text
Safety Check
-> Structural Audit
-> Deterministic Cleanup or Restoration
-> Separate Working Copy
-> Revalidation
-> Readiness
-> Explicit Confirmation
-> SMTP Delivery
```

- Originals and existing files remain immutable.
- EPUB preparation is local and uses a separate collision-safe working copy.
- PDF content is not converted or modified.
- Batch work is sequential and failures remain isolated per book.
- Cancellation preserves completed outcomes and stops pending scheduling.
- No failed or delivery-unknown attempt retries automatically.
- A completed batch can be cleared through `Send More Books` without deleting
  setup, credentials, shortcut preferences, application preferences, or send
  history. `Delivery Unknown` requires confirmation before visible results are
  discarded.
- Only definitive SMTP acceptance creates a history record; failed, cancelled,
  excluded, and delivery-unknown outcomes do not.
- History persistence failure never changes `Submitted` and never retries SMTP.
- A history row records SMTP acceptance only; it does not claim Kindle receipt,
  processing, availability, or library presence.

## Repository Boundary

The repository contains one native application product in `BookSender.xcodeproj`.
Production source exists only in `BookSender/**/*.swift`. Removed Raycast, Node,
PageForge, Calibre, conversion, and historical product trees must not be
recreated as fallback implementations. Sparkle, the appcast, and release scripts
exist only as the approved application-update and distribution path.

## Validation Boundary

Static checks do not prove compilation, automated tests, runtime behavior,
authenticated SMTP delivery, pinned release signing, credential continuity,
update installation, or production release. Each gate must be executed and
reported independently when the repository workflow allows it.
