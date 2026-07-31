# Data Model: Floating Feedback System

## Overview

The feature adds no durable product entity. It adds an ephemeral,
window-partitioned presentation model around the existing typed
`ActionFeedback` lifecycle and one deterministic row-position projection for
batch dividers.

`ActionFeedback` remains the semantic source of action truth. A floating entry
adds only presentation destination, configuration, queue/visibility phase, and
task identity. Manually hiding a persistent card does not delete the semantic
failure or change the underlying workflow.

## Existing source: `ActionFeedback`

The current model remains the semantic input.

| Field | Type | Rule |
|---|---|---|
| `id` | UUID | One action lifecycle identity |
| `scope` | `FeedbackScope` | Replacement and contextual evidence scope |
| `action` | `FeedbackAction` | Operation that produced the lifecycle |
| `state` | `FeedbackState` | Acknowledged, active, or terminal semantic state |
| `title` | String | Non-empty concise outcome title |
| `message` | String? | Optional safe supporting text |
| `startedAt` | Date | Lifecycle start |
| `updatedAt` | Date | Latest semantic update |
| `dismissal` | `FeedbackDismissalPolicy` | Source intent for temporary or persistent presentation |
| `failure` | `FailurePresentation?` | Sanitized durable contextual evidence |
| `occurrenceCount` | Int | Positive equivalent-occurrence count |

### Existing semantic transitions

```text
acknowledged -> inProgress -> succeeded
                           -> failed
                           -> cancelled
                           -> partial
                           -> unknown
```

Terminal semantic states do not transition further. A new action or retry
creates a new lifecycle identity.

## `NotificationDestination`

Identifies the owning native scene.

| Case | Meaning |
|---|---|
| `main` | Main `Book Sender` window, including onboarding, Send, History, update, and main diagnostics |
| `settings` | Native Settings window, including Delivery and Shortcut tabs |

### Validation

- Exactly one destination is required for every floating entry.
- Destination never changes for an existing lifecycle.
- A replacement may move to another destination only by creating a new
  lifecycle from the action's actual new origin.
- Destination is ephemeral and never persisted.

## `NotificationKey`

Stable current-entry slot.

| Field | Type | Rule |
|---|---|---|
| `destination` | `NotificationDestination` | Owning scene |
| `scope` | `FeedbackScope` | One current lifecycle per scope in the scene |

### Validation

- Equality and hashing use both fields.
- `deliverySetup` may exist once in `main` and once in `settings` without
  collision.
- Add `FeedbackScope.diagnosticCopy` for copy success/failure so it can coexist
  with the contextual failure scope that produced the copied details.
- A new feedback identity for the same key replaces the old entry.
- `batchItem` and `delivery` scopes remain contextual and are not individually
  promoted into the floating stack; the batch scope carries action summaries.

## `NotificationIcon`

Presentation-only icon policy.

| Case | Rule |
|---|---|
| `automatic` | Resolve from `FeedbackState` using the shared semantic map |
| `system(name)` | Use the named system symbol selected by the originating workflow |
| `none` | Render no icon and no empty icon frame |

### Automatic state mapping

| Feedback state | Default visual |
|---|---|
| `acknowledged` | Neutral/informational symbol |
| `inProgress` | Compact indeterminate progress indicator |
| `succeeded` | Success symbol |
| `failed` | Error symbol |
| `cancelled` | Cancel symbol |
| `partial` | Warning symbol |
| `unknown` | Uncertainty symbol |

### Validation

- Icon is supplementary; title/message remains the accessible meaning.
- An invalid selected symbol falls back to `automatic`, never to an empty
  interactive target.
- `none` removes both visual and accessibility icon content.

## `NotificationLifetime`

Normalized presentation lifetime derived from `FeedbackDismissalPolicy`.

| Case | Associated value | Rule |
|---|---|---|
| `temporary` | `seconds: TimeInterval` | Finite inclusive range `1...5` |
| `persistentUntilReplaced` | none | Remains while the semantic state is current |
| `explicit` | none | Remains until close/action/replacement |
| `stateDriven` | none | Remains until a newer state or action replaces it |

### Normalization

```text
missing temporary duration -> 4 seconds
non-finite duration         -> 4 seconds
duration < 1                -> 1 second
duration > 5                -> 5 seconds
duration in 1...5           -> unchanged
```

### State compatibility

- Successful and informational acknowledgements are always temporary.
- Failed, cancelled, partial, and unknown outcomes are persistent or explicit.
- Active work is state driven and cannot be manually removed when its card is
  the only progress indication.
- A temporary card may have only a nonessential action with another durable
  recovery path.

## `NotificationClosePolicy`

| Case | Rule |
|---|---|
| `shown` | Card exposes a labeled close control |
| `hidden` | Card exposes no visual or accessibility close target |

### Validation

- A persistent entry with hidden close must have an action or a guaranteed
  state-driven replacement.
- Active state may hide close when dismissal would falsely imply cancellation.
- Closing presentation never changes domain/application state.

## `NotificationActionDescriptor`

At most one typed optional action.

| Field | Type | Rule |
|---|---|---|
| `id` | UUID | Stable action-control identity for one feedback lifecycle |
| `label` | String | Non-empty concise English label |
| `command` | `RecoveryAction` | Existing exhaustive typed recovery command |
| `dismissalAfterActivation` | enum | `keep`, `hide`, or `awaitReplacement` |

### Validation

- No escaping handler closure is stored.
- The descriptor is `Equatable` and `Sendable`.
- One entry contains zero or one descriptor.
- A command is dispatched at most once while `isActionInFlight` is true.
- An essential command requires persistent lifetime.
- Destructive or multi-choice decisions remain in alerts/sheets and are not
  represented here.

## `FloatingNotificationConfiguration`

Normalized card options.

| Field | Type | Rule |
|---|---|---|
| `icon` | `NotificationIcon` | Automatic, selected, or absent |
| `lifetime` | `NotificationLifetime` | Normalized before publication |
| `closePolicy` | `NotificationClosePolicy` | Shown or hidden |
| `action` | `NotificationActionDescriptor?` | At most one typed action |
| `messageLineLimit` | Int | Shared bounded supporting-text limit |

### Default projection

| Feedback state | Lifetime | Close | Action |
|---|---|---|---|
| `acknowledged` | state driven | hidden | none |
| `inProgress` | state driven | hidden | none |
| `succeeded` | temporary 4s | shown | optional nonessential |
| `failed` | persistent | shown | failure recovery when available |
| `cancelled` | persistent | shown | optional contextual |
| `partial` | persistent | shown | optional recovery |
| `unknown` | persistent | shown | safe check/review only |

Originating workflows may customize icon, close visibility, permitted
temporary duration, and action without violating lifetime/state compatibility.

## `NotificationPhase`

Current presentation phase.

| Case | Meaning |
|---|---|
| `queued` | Relevant but not visible because the host is absent or three slots are occupied |
| `visible` | Rendered in the owning host; temporary timer may run |
| `hidden` | Manually dismissed persistent presentation; semantic feedback remains queryable |

Removed/expired/replaced entries are deleted rather than retained as another
phase.

## `FloatingNotificationEntry`

One current semantic lifecycle plus presentation state.

| Field | Type | Rule |
|---|---|---|
| `key` | `NotificationKey` | Current destination/scope slot |
| `feedback` | `ActionFeedback` | Semantic action truth |
| `configuration` | `FloatingNotificationConfiguration` | Normalized card behavior |
| `phase` | `NotificationPhase` | Queued, visible, or hidden |
| `enqueuedAt` | Date | Initial presentation publication time |
| `visibleAt` | Date? | Set only when promoted to visible |
| `isActionInFlight` | Bool | Prevents repeated action activation |

### Validation

- `feedback.scope == key.scope`.
- `visibleAt` is non-nil only for visible or previously visible hidden entries.
- A queued temporary entry has no expiry task.
- A visible temporary entry has exactly one matching task.
- Hidden entries have no expiry task and do not occupy a visible slot.
- Reconciliation retains identity for the same lifecycle and replaces identity
  for a new lifecycle.
- Equivalent repeated feedback updates occurrence count in place.

## `NotificationDestinationSnapshot`

Immutable projection consumed by one host.

| Field | Type | Rule |
|---|---|---|
| `destination` | `NotificationDestination` | Host identity |
| `visible` | `[FloatingNotificationEntry]` | At most three entries |
| `queuedCount` | Int | Still-relevant waiting count, not shown as a badge |
| `isHostAttached` | Bool | Whether a scene root currently renders the host |

### Ordering

- `visible[0]` is newest and closest to the top-trailing anchor.
- Promotion selects the oldest still-relevant queued entry, then inserts it at
  the newest visible position.
- Replacing a visible lifecycle retains its current stack position unless its
  destination changes through a new lifecycle.
- No UI exposes queue history or a queued-count surface.

## `NotificationTaskKey`

Expiry race guard.

| Field | Type | Rule |
|---|---|---|
| `destination` | `NotificationDestination` | Owning host |
| `feedbackID` | UUID | Exact visible temporary lifecycle |

### Expiry preconditions

Removal occurs only when:

1. the task is not cancelled;
2. the destination is still attached or the elapsed policy still applies;
3. the current key resolves to the same feedback identity;
4. the entry is still visible;
5. its normalized lifetime is still temporary.

## `NotificationFocusRequest`

Ephemeral bridge for a typed command that needs view-local focus.

| Field | Type | Rule |
|---|---|---|
| `id` | UUID | New identity for each request |
| `destination` | `NotificationDestination` | Owning scene |
| `action` | `RecoveryAction` | Typed requested recovery/focus |

### Validation

- Never persisted.
- Consumed only by the matching destination/view.
- Consuming focus does not re-run the recovery command.
- Replacement by a newer request makes the older request stale.

## `BatchRowPosition`

Derived presentation metadata for divider placement.

| Field | Type | Rule |
|---|---|---|
| `itemID` | UUID | Stable existing batch item identifier |
| `index` | Int | Position in current ordered item snapshot |
| `count` | Int | Snapshot item count |
| `showsDivider` | Bool | `index < count - 1` |

### Validation

- Empty and single-item batches show zero dividers.
- A batch of `n` items shows exactly `n - 1` dividers.
- Divider follows the complete row, including expanded details.
- Divider uses balanced horizontal insets and spans at least 90% of usable card
  row width.
- Batch mutations recompute position from the current stable ordered snapshot.

## State transitions

### Presentation lifecycle

```text
publish
   |
   +-> host attached and visibleCount < 3 -> visible -> temporary expiry -> removed
   |                                          |
   |                                          +-> close -> removed or hidden
   |                                          +-> action -> inFlight
   |                                          |              |
   |                                          |              +-> result replacement
   |                                          |              +-> hide/keep
   |                                          +-> replacement -> new lifecycle
   |
   +-> host absent/full -> queued -> promotion -> visible
                              |
                              +-> obsolete/replaced -> removed unseen

persistent visible -> manual close -> hidden
hidden -> new lifecycle for same key -> queued/visible
```

### Host lifecycle

```text
detached -> attach -> promote up to 3 relevant entries
attached -> detach -> cancel temporary tasks
                    -> remove temporary presentation
                    -> demote current persistent visible entries to queued
                    -> retain hidden semantic failures
```

## Relationships

```text
ActionFeedback
    -> FloatingNotificationConfiguration
        -> FloatingNotificationEntry
            -> NotificationDestinationSnapshot
                -> FloatingNotificationHost
                    -> FloatingNotificationCard

NotificationActionDescriptor
    -> RecoveryAction
        -> scene-root dispatcher
            -> AppModel operation or NotificationFocusRequest

BatchPresentation.items
    -> BatchRowPosition
        -> explicit inter-item Divider
```

## Persistence and privacy

None of the new entities are persisted. They MUST NOT enter preferences,
Keychain, send history, diagnostics, logs, reports, analytics, or remote
transport. Notification messages reuse already sanitized user-facing feedback;
raw exceptions, paths, addresses, credentials, book content, and SMTP dialogue
remain prohibited.
