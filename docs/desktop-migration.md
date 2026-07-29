# Native macOS Product Boundary

## Target Product

- One native Swift and SwiftUI macOS application
- Exactly two primary screens: `Delivery Setup` and `Send Book`
- One temporary batch with multi-file EPUB and PDF intake
- One advanced sequential background preparation pipeline
- One explicit sequential SMTP delivery flow with independent per-book outcomes
- One optional configurable global shortcut for quick access

## Interaction Boundary

The user configures SMTP once, selects books, waits for concise readiness, confirms
the stable eligible batch, and sees per-book delivery results. Inspection,
cleanup, restoration, revalidation, and technical reports are not peer navigation
surfaces.

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

## Repository Boundary

The repository contains one native application product in `BookSender.xcodeproj`.
Production source exists only in `BookSender/**/*.swift`. Removed Raycast, Node,
PageForge, Calibre, conversion, Python, Sparkle, appcast, and historical product
trees must not be recreated as fallback implementations.

## Validation Boundary

Static checks do not prove compilation, automated tests, runtime behavior,
authenticated SMTP delivery, signing, notarization, or production release. Each
gate must be executed and reported independently when the repository workflow
allows it.
