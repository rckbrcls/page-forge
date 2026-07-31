# Contract: Floating Notification Lifecycle

## Purpose

Define deterministic destination isolation, normalization, visible capacity,
queue promotion, replacement, expiry, manual hiding, and host lifecycle.

## Publication input

Every publication includes:

- typed `ActionFeedback`;
- `NotificationDestination`;
- optional icon override;
- optional close-policy override;
- optional permitted temporary duration;
- optional one-action descriptor.

The presentation factory normalizes the request before the center accepts it.

## Configuration normalization

### Temporary duration

| Input | Normalized result |
|---|---|
| omitted | 4 seconds |
| non-finite | 4 seconds |
| less than 1 | 1 second |
| 1 through 5 | unchanged |
| greater than 5 | 5 seconds |

### Lifetime compatibility

| State | Allowed lifetime |
|---|---|
| `acknowledged` | state driven |
| `inProgress` | state driven |
| `succeeded` | temporary only |
| informational acknowledgement | temporary only |
| `failed` | persistent/explicit |
| `cancelled` | persistent/explicit |
| `partial` | persistent/explicit |
| `unknown` | persistent/explicit |

A temporary action must be nonessential. An essential recovery action requires a
persistent/explicit card.

### Close compatibility

- A temporary result may show or hide close.
- An active state hides close unless a separate cancel operation exists and is
  explicitly represented elsewhere.
- A persistent card may show close.
- A persistent card with hidden close must have a typed action or guaranteed
  state replacement.

Invalid combinations are rejected in tests and normalized to the nearest safe
configuration in production: preserve persistence and expose close rather than
creating an unreachable card.

## Current-slot rule

The center stores at most one current lifecycle for each
`NotificationKey(destination, scope)`.

Diagnostic-copy acknowledgements use `FeedbackScope.diagnosticCopy`; they do
not replace the failure scope whose safe details were copied.

### Same identity

- update title/message/state/configuration in place;
- preserve visible position when still visible;
- reconcile occurrence count;
- cancel/restart timer only when lifetime or visible identity requires it;
- do not re-announce an unchanged semantic state.

### New identity for same key

- cancel old task;
- remove old identifier from visible/queued/hidden sets;
- replace current entry;
- select queued or visible phase based on host capacity;
- announce the new meaningful state once when visible.

## Visible-stack rule

- Maximum visible entries: three per destination.
- Ordering: newest visible nearest the anchor.
- Cards never overlap.
- Persistent entries are never evicted for capacity.
- Closing/expiry removes one entry and immediately promotes the oldest
  still-current queued entry.
- Promotion inserts the promoted entry at the newest visible position.

## Queue rule

- A relevant entry waits when its host is detached or already has three visible
  cards.
- Temporary lifetime does not start while queued.
- Queued entries are not announced as visible.
- Replacement removes the old queued identity.
- Resolution/removal before promotion prevents stale presentation.
- Per-item/per-delivery progress does not enter the queue.
- The queue is ephemeral and is never shown as a count, inbox, or history.

## Temporary expiry algorithm

For every visible temporary entry:

1. cancel any task for the same destination/scope;
2. create `NotificationTaskKey(destination, feedbackID)`;
3. capture the injected sleeper and normalized duration;
4. wait without blocking the main actor;
5. return to main-actor center state;
6. confirm task is not cancelled;
7. confirm destination, scope, identity, visible phase, and temporary lifetime
   still match;
8. remove the entry and task;
9. promote the next still-current queued entry;
10. do not post a removal accessibility announcement.

Application inactivity does not pause the task.

## Manual close

### Temporary or nonactionable result

- cancel task;
- remove entry;
- promote next queued entry;
- do not change workflow/domain state.

### Persistent failure/unknown/partial/cancelled result

- cancel any task;
- move entry to `hidden`;
- remove it from visible capacity;
- retain semantic feedback and failure for contextual detail;
- promote next queued entry.

A new lifecycle for the same key removes the hidden marker and becomes eligible
for presentation.

## Action activation

1. Verify the entry is current and visible.
2. Verify an action exists and is not in flight.
3. Mark `isActionInFlight = true`.
4. Disable the action control.
5. Dispatch the typed command once through the owning scene root.
6. Apply `keep`, `hide`, or `awaitReplacement`.
7. If dispatch cannot change state and policy keeps the card, restore
   `isActionInFlight = false`.

Double click, key repeat, or repeated accessibility activation while in flight
executes zero additional commands.

## Host attachment

### Attach

- mark destination attached;
- retain current hidden state;
- promote relevant persistent/temporary queued entries until three are visible;
- begin temporary lifetime only on promotion.

### Detach

- cancel all temporary tasks for that destination;
- remove visible/queued temporary acknowledgements;
- demote visible persistent entries to queued;
- keep hidden persistent semantic feedback;
- do not affect the other destination or any durable workflow state.

## Deterministic acceptance matrix

- Replacement at 3.9 seconds prevents the old task from removing the new card.
- A queued four-second card receives four visible seconds after promotion.
- Three persistent cards keep a fourth card queued without eviction.
- Hiding one persistent card promotes one queued card.
- Resolving a queued card means it never appears.
- Main detach changes no Settings entry.
- Settings detach changes no main entry.
- An expired card remains absent after app reactivation.
- Equivalent repeated feedback occupies one card.
- A hidden failure remains available through contextual detail.
