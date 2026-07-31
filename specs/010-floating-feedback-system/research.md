# Research: Floating Feedback System

## Scope and evidence

Research covered Feature 010, Book Sender Constitution 8.0.0, the current
`ActionFeedback` and dismissal models, `ActionFeedbackService`, main-actor
`AppModel`, root scene composition, Settings composition, every inline
`ActionFeedbackView` consumer, `FailureDetailView`, the batch `List`, and the
existing feedback, settings, batch, history, and accessibility tests.

Representative findings were rechecked locally:

- `AppModel` is already `@MainActor @Observable` and owns current feedback plus
  cancellation-aware expiry tasks;
- `ActionFeedback` and related enums are already typed, `Equatable`, and
  `Sendable`;
- success defaults to a four-second delayed policy while failed, cancelled,
  partial, and unknown states are persistent;
- current expiry begins at publication, which is too early for a queued card;
- `ActionFeedbackView` is inserted inline in delivery setup, send, history,
  shortcut settings, and diagnostic copy detail;
- the application has a singleton main `Window` and a separate native
  `Settings` scene sharing one `AppModel`;
- the batch uses a native `List` inside `GroupBox` with default separator
  insets, causing the short divider;
- UI tests currently find `feedback.batch`, `feedback.deliverySetup`, and
  `feedback.shortcut` in their inline positions;
- the project uses file-system synchronized Xcode groups, so new Swift files in
  existing roots do not require manual project membership;
- no package is needed for overlay, material, task timing, or accessibility.

All technical unknowns required for planning are resolved below.

## Decision 1: Keep semantic feedback and floating presentation separate

**Decision**: Continue constructing typed `ActionFeedback` through
`ActionFeedbackService`, then project it into a
`FloatingNotificationPresentation` containing destination, icon, close policy,
optional action, and stack phase. Add a dedicated
`FeedbackScope.diagnosticCopy` so copy results no longer require a parallel
unscoped feedback property.

**Rationale**: `ActionFeedback` already expresses action, scope, state,
lifecycle identity, message, occurrence count, failure, and dismissal intent.
Adding window and card configuration around it preserves current tests and
failure semantics without moving view-specific fields into delivery, history,
or ebook domain models. A dedicated copy scope lets the copied failure remain
current while its success/failure acknowledgement follows the shared lifecycle.

**Alternatives considered**:

- Replace all feedback with strings and booleans: rejected because it loses
  typed state, deduplication identity, failure evidence, and retry safety.
- Put icon, window, and buttons directly into every domain failure: rejected
  because these are application-presentation choices.
- Let each view translate feedback independently: rejected because it recreates
  the inconsistent inline system this feature removes.

## Decision 2: Use one main-actor notification center

**Decision**: Add one `@MainActor @Observable`
`FloatingNotificationCenter` owned by `AppModel`. It owns current entries,
visible and queued order, manual-hidden state, action-in-flight state, and
expiry tasks. `AppModel.feedback(for:)` delegates to it.

**Rationale**: The current model already owns feedback and tasks on the main
actor. A separate focused center modularizes that responsibility while keeping
Observation updates and UI interaction on one actor. It also provides one
deterministic unit-test seam.

**Alternatives considered**:

- Keep all new dictionaries and tasks directly in `AppModel`: rejected because
  it makes an already large orchestration model own card and queue mechanics.
- One center per feature view: rejected because view recreation and tab
  switching would duplicate tasks and lose queued/persistent state.
- A global singleton outside dependency composition: rejected because it
  complicates tests and can leak feedback between windows or test runs.
- An actor-backed notification store: rejected because every mutation and
  render occurs on the main actor, while a second actor would add unnecessary
  hops and Sendable pressure.

## Decision 3: Partition by explicit window destination

**Decision**: Introduce exactly two destinations, `.main` and `.settings`, and
key current feedback by `(destination, FeedbackScope)`. Every publishing action
supplies its origin. Main and Settings roots render separate projections.

**Rationale**: `FeedbackScope.deliverySetup` can originate from onboarding in
the main window or saved setup in Settings, so scope alone cannot prevent
cross-window leakage. Explicit destination also makes isolation testable.

**Alternatives considered**:

- Infer destination from feedback scope: rejected because delivery setup and
  diagnostic copying occur in both scenes.
- Show all feedback in the currently key window: rejected because a result
  could jump from main to Settings when focus changes.
- Create separate global models for main and Settings: rejected because the
  scenes intentionally share setup, diagnostics, and shortcut state.

## Decision 4: Compose hosts only at scene roots

**Decision**: Place one `FloatingNotificationHost` overlay around
`MainWindowContent` and one around `BookSenderSettingsView`'s root `TabView`.
Feature views no longer reserve notification layout space.

**Rationale**: A root overlay survives local route/tab changes, is naturally
window bounded, and does not affect form, list, or primary-action measurement.
Native sheets and alerts remain above root content.

**Alternatives considered**:

- Add the host to every feature screen: rejected because it duplicates
  rendering and can show two stacks during transitions.
- Use `safeAreaInset`: rejected because it participates in layout and would
  move content.
- Add a new panel or window: rejected because it expands product surface and
  complicates focus/window ordering.
- Use AppKit overlay windows: rejected because root SwiftUI overlays satisfy
  the current singleton window requirements.

## Decision 5: Maintain max-three visible plus a relevance queue

**Decision**: Each destination displays at most three cards, newest closest to
the top-trailing anchor. Additional still-current entries wait in FIFO order.
Persistent visible entries are never evicted. Equivalent entries update in
place, and replacement by destination/scope removes an obsolete queued or
hidden lifecycle.

**Rationale**: This satisfies the visible bound without discarding actionable
state. Because per-item progress stays inline and high-level feedback keeps one
current lifecycle per scope, the waiting collection remains naturally bounded.

**Alternatives considered**:

- Evict the oldest card unconditionally: rejected because it can discard a
  persistent failure or delivery uncertainty.
- Show every card: rejected because the stack could cover the workflow.
- Drop new temporary results when full: rejected because an acknowledgement
  may still be relevant after a slot becomes available.
- Persist an overflow history: rejected because the feature expressly forbids a
  notification center or archive.

## Decision 6: Start expiry on visible promotion

**Decision**: Schedule a temporary entry only when it enters the visible list.
Key each task by destination and feedback identity, use the injected
`FeedbackSleep`, and require destination/scope/id/phase/policy to match before
removal.

**Rationale**: A card waiting behind three persistent cards has not yet received
its visible interval. Identity and phase guards prevent cancelled or racing old
tasks from removing a replacement.

**Alternatives considered**:

- Keep scheduling in `AppModel` at publication: rejected because queued cards
  could expire unseen.
- Pause timers while the app is inactive: rejected because Feature 009 and the
  constitution require expired temporary feedback to stay absent on
  reactivation.
- Use one repeating timer: rejected because independent cancellation and
  deterministic tests are clearer with keyed tasks.

## Decision 7: Normalize duration and configuration centrally

**Decision**: A pure presentation factory normalizes missing duration to four
seconds, finite durations to the inclusive 1...5 range, and non-finite values to
four. It selects the automatic semantic icon and default close policy while
allowing explicit icon/none, close visibility, and one optional action.

**Rationale**: Central normalization ensures no call site can produce an
instant, infinite, or constitutionally overlong success. Defaults remain
consistent while the component stays configurable.

**Alternatives considered**:

- Trust every call site: rejected because invalid values would produce
  inconsistent lifecycle behavior.
- Accept an unlimited duration: rejected by the constitutional five-second
  maximum for successful/informational feedback.
- Model persistent as a magic duration: rejected because lifetime intent should
  remain explicit and testable.

## Decision 8: Route actions through typed commands, not stored closures

**Decision**: `NotificationActionDescriptor` stores label, a typed
`RecoveryAction`, and post-activation dismissal intent. Scene roots dispatch the
command on the main actor. No closure is stored in a `Sendable` notification or
crosses an actor boundary.

**Rationale**: Existing `FailurePresentation` already supplies safe recovery
actions. Typed commands are equatable, deduplicable, testable, and compatible
with complete Swift 6 concurrency checking. Scene roots can resolve environment
actions and focus requests that application state cannot perform directly.

**Alternatives considered**:

- Store arbitrary escaping closures in notification entries: rejected because
  equality, Sendable checking, lifecycle retention, and stale captures become
  fragile.
- Put all recovery inside the card view: rejected because the card must remain
  reusable and cannot know setup, history, batch, or focus behavior.
- Add string command identifiers: rejected because misspellings and incomplete
  switching would be runtime failures.

## Decision 9: Preserve contextual failure and progress separately

**Decision**: Remove only inline `ActionFeedbackView` acknowledgement cards.
Keep field validation, progress, per-item/aggregate state,
`FailureDetailView`, history screen states, sheets, and alerts. Manual card
dismissal hides presentation without deleting persistent typed failure.

**Rationale**: These states explain or control durable work and cannot safely
be reduced to transient floating content. Keeping the failure entry hidden but
queryable lets the inline detail remain after the user closes a card.

**Alternatives considered**:

- Move full diagnostics into floating cards: rejected because cards would
  become large, central, and difficult to navigate.
- Dismiss the underlying failure when closing a card: rejected because it hides
  actionable evidence and changes state semantics.
- Convert confirmation alerts into card actions: rejected because destructive
  and uncertainty choices require explicit modal priority.

## Decision 10: Use an adaptive material card, not decorative glass

**Decision**: Render compact cards with a native adaptive material, subtle
border/shadow, semantic foreground styles, and standard buttons. Use a restrained
opacity/trailing transition, switching to identity/opacity when Reduce Motion is
enabled.

**Rationale**: Notifications are content feedback, not a new primary control
layer. Native adaptive styling stays legible across appearance and
accessibility settings and fits the constitution's visually calm hierarchy.

**Alternatives considered**:

- Apply prominent Liquid Glass to the whole card: rejected because it competes
  with toolbar and primary-action glass and turns feedback into decoration.
- Use fixed opaque dark/light colors: rejected because they do not adapt to
  system appearance and contrast preferences.
- Add sound or bounce animation: rejected because the feature excludes sound
  and decorative interruption.

## Decision 11: Replace default list separators with explicit dividers

**Decision**: Keep the native batch `List`, hide its default separators, and
append an explicit `Divider` after the complete item/detail content for every
item except the last. Apply balanced row insets and identify dividers for UI
geometry checks.

**Rationale**: The current short line comes from system separator alignment.
An explicit divider gives deterministic width, last-row omission, and placement
after expanded details without replacing the scroll/list behavior.

**Alternatives considered**:

- Adjust only separator alignment guides: rejected because platform separator
  behavior remains less explicit and harder to measure across expanded rows.
- Replace `List` with `ScrollView`/`LazyVStack`: rejected because it is a broader
  accessibility, reuse, and scrolling change unrelated to the request.
- Draw a divider inside `BatchItemRow`: rejected because expanded
  `ItemDetailDisclosure` belongs to the same complete item and must precede the
  separator.

## Decision 12: Add no dependency, persistence, or app-wide notification history

**Decision**: Use existing SwiftUI, Observation, main-actor tasks,
`FeedbackSleep`, semantic models, and test infrastructure. Keep all notification
state ephemeral and scoped to the owning scene.

**Rationale**: Native capabilities cover the full design. No external Sonner
implementation applies to a native macOS app, and persisted notifications would
violate scope and privacy constraints.

**Alternatives considered**:

- Add a toast package: rejected because it expands dependency/release risk and
  may not satisfy the exact concurrency, window, and accessibility contracts.
- Store cards in preferences or history: rejected because notifications are
  presentation state, not durable user records.
- Use macOS Notification Center: rejected because the user requested in-window
  floating feedback and the product forbids external notification scope.
