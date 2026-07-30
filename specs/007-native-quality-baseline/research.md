# Research: Native Quality Baseline

## Scope

This research resolves the implementation choices needed to raise Book Sender's
native macOS quality baseline while preserving the current product, architecture,
dependencies, security posture, and sequential processing model.

## Decision 1: Make SMTP reply waiters cancellation-aware

**Decision**: Give every suspended reply waiter a token owned by
`SMTPReplyQueue`. Register and remove that token through actor-isolated methods,
wrap suspension in `withTaskCancellationHandler`, and guarantee exactly one
resume path.

**Rationale**: The current timeout race cancels the losing child task, but a
checked continuation stored by the queue is not inherently cancellation-aware.
If the timeout wins, structured concurrency can still wait for the child whose
continuation remains stored. Tokenized ownership makes cancellation and queue
finish explicit and testable.

**Alternatives considered**:

- Keep the current task group and rely on child cancellation. Rejected because
  cancellation alone does not resume a stored checked continuation.
- Use an unstructured task and abandon the loser. Rejected because it leaks
  lifetime ownership and weakens deterministic cleanup.
- Poll the queue. Rejected because polling adds latency and needless wakeups.

## Decision 2: Preserve typed timeout meaning at adapter boundaries

**Decision**: Keep timeout detection reusable only at the scheduling level.
Each adapter continues mapping timeout, cancellation, unsafe input, malformed
content, and delivery uncertainty into its existing typed failures.

**Rationale**: Archive, XML, and SMTP timeouts have different user and retry
semantics. A generic error would erase whether delivery may already have begun.

**Alternatives considered**:

- Introduce one application-wide `TimeoutError`. Rejected because it loses
  adapter-specific recovery and uncertainty information.
- Leave timeout behavior untested in each adapter. Rejected because cancellation
  defects occur at ownership boundaries, not only in a shared timer.

## Decision 3: Use per-provider transferable loading for drag and drop

**Decision**: Keep the drop target's per-provider accounting and replace
deprecated `loadItem` usage with `loadTransferable(type: URL.self)`. Aggregate
ordered successes and sanitized failures before calling the shared intake path.

**Rationale**: The feature requires an outcome for every attempted item. A
per-provider loader can count conversion failures that occur before a URL reaches
application validation, while the shared intake service remains responsible for
extensions, deduplication, batch limits, and security-scoped access.

**Alternatives considered**:

- Use only `dropDestination(for: URL.self)`. Not selected because unsuccessful
  provider-to-URL transfers may be hidden before the action receives its values.
- Continue using `NSItemProvider.loadItem`. Rejected because the API is
  deprecated and its loosely typed result encourages silent `try?` paths.
- Move validation into the view. Rejected because it would duplicate the Finder
  path and violate application boundaries.

## Decision 4: Treat Finder cancellation separately from failure

**Decision**: Explicitly switch over `fileImporter` results. A user cancellation
produces no error banner; any other import failure becomes sanitized visible
feedback.

**Rationale**: Cancellation is an expected user action, while ignoring an actual
import error violates the requirement that attempted intake has a clear outcome.

**Alternatives considered**:

- Ignore every failure. Rejected because it produces silent dead ends.
- Show raw localized errors. Rejected because provider errors can reveal paths or
  implementation details.

## Decision 5: Drive confirmation from the batch summary value

**Decision**: Use `ConfirmedBatchSummary?` as the only stored confirmation
presentation state and present the sheet with item-driven state.

**Rationale**: The optional value already represents both readiness and the
stable confirmed snapshot. A second Boolean can disagree with it and makes
dismissal/cancellation cleanup ambiguous.

**Alternatives considered**:

- Keep the Boolean and synchronize it with observers. Rejected because it
  retains two mutable sources of truth.
- Recompute the summary when the sheet opens. Rejected because the user must
  confirm a stable batch snapshot.

## Decision 6: Modernize Settings with native semantic APIs

**Decision**: Use the modern SwiftUI `Tab` API for the two Settings tabs and
semantic text styles instead of fixed point sizes.

**Rationale**: Native semantic APIs preserve platform behavior, accessibility,
and future compatibility without inventing a custom navigation or typography
system.

**Alternatives considered**:

- Custom segmented navigation. Rejected because it adds presentation code and
  weakens native keyboard/accessibility behavior.
- Preserve fixed sizes and scale manually. Rejected because it duplicates system
  typography behavior and is harder to validate.

## Decision 7: Tie AppKit window capture to view lifecycle

**Decision**: Capture the hosting window from an `NSVisualEffectView` lifecycle
hook and perform Sparkle observation updates in an explicit `@MainActor` task.

**Rationale**: Window availability is a lifecycle event, not a reason to enqueue
work on every representable update. Explicit actor ownership also matches Swift 6
complete concurrency checking.

**Alternatives considered**:

- Continue dispatching from every `updateNSView`. Rejected because repeated
  asynchronous callbacks obscure ownership and can produce stale ordering.
- Search `NSApplication.windows` globally. Rejected because it can select the
  auxiliary Settings window or another transient window.
- Move all window code into the presentation model. Rejected because the model
  should not own AppKit view lifecycle.

## Decision 8: Validate observable outcomes, not implementation gestures

**Decision**: UI tests must verify the visible result after a keyboard shortcut,
tab selection, confirmation dismissal, or accessibility setting. Adapter tests
must verify terminal typed outcomes and elapsed release bounds.

**Rationale**: Delivering a key event or starting a timer is not evidence that the
user-visible contract completed.

**Alternatives considered**:

- Assert only focus and key presses. Rejected because those assertions can pass
  while the intended action is disconnected.
- Use broad end-to-end tests for every timeout. Rejected because deterministic
  adapter tests isolate the ownership defect more reliably.

## Decision 9: Use traditional Keychain with one pinned self-signed identity

**Decision**: Keep the existing generic-password, service, account, revision,
transaction, and sanitized-failure contracts, but remove Data Protection,
accessibility, and synchronization query attributes. Sign every distributed
version with the same self-signed Code Signing identity and explicit designated
requirement anchored to its versioned public certificate.

**Rationale**: The traditional Keychain does not require the missing application
access-group entitlement and recognizes updates by their designated requirement.
A stable self-signed identity supplies continuity without paying for Developer
ID, while CI and the installer can reject identity drift.

**Alternatives considered**:

- Keep Data Protection Keychain. Rejected because the free signed sandboxed app
  cannot access the item without the required entitlement contract.
- Store the password in preferences, files, or custom encryption. Rejected
  because each weakens the protected-secret boundary or embeds decryption
  authority in the app.
- Continue ad-hoc signing. Rejected because it cannot provide one stable
  designated requirement for Keychain continuity.
- Treat Sparkle EdDSA as code signing. Rejected because archive authentication
  and macOS code identity are independent protections.

## Dependency and persistence conclusion

No dependency addition, upgrade, preference schema, remote service, telemetry
surface, helper process, or new product persistence surface is required. The
first corrected save creates a traditional-Keychain item; inaccessible legacy
items are not migrated and require one password entry.

## Decision 10: Keep hardened runtime with one bounded library exception

**Decision**: Keep hardened runtime on distributed code and add
`com.apple.security.cs.disable-library-validation` only to the main executable.
Continue signing and verifying every bundled Sparkle executable with the pinned
self-signed certificate, and run the signed main executable for a bounded
five-second launch gate before packaging.

**Rationale**: Apple-issued Team IDs are absent from the pinned self-signed
identity. Hardened runtime enables library validation and dyld rejects Sparkle
even when static strict-signature checks pass. The one documented runtime
exception is narrower than removing hardened runtime, while certificate pinning,
bundle sealing, Sparkle EdDSA, and the launch gate preserve independent checks.

**Alternatives considered**:

- Remove hardened runtime. Rejected because it would discard unrelated runtime
  protections to solve one library-loading restriction.
- Rotate to another self-signed certificate. Rejected because self-signed
  identities still lack an Apple-issued Team ID and rotation breaks credential
  continuity.
- Rely on strict `codesign` verification. Rejected because v0.2.2 passed static
  verification but dyld rejected Sparkle at process launch.

## Primary references

- [NSItemProvider.loadTransferable(type:completionHandler:)](https://developer.apple.com/documentation/foundation/nsitemprovider/loadtransferable(type:completionhandler:))
- [Transferable](https://developer.apple.com/documentation/coretransferable/transferable)
- [Tab](https://developer.apple.com/documentation/swiftui/tab)
- [Disable Library Validation Entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.cs.disable-library-validation)
