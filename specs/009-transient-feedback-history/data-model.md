# Data Model: Transient Feedback and Send History

## Overview

The feature adds one ephemeral presentation selection, one cancellation-safe
feedback expiry boundary, one accepted-submission receipt, and one bounded
durable history collection. Current delivery state remains the source of truth
for whether an attempt was submitted, failed, cancelled, or uncertain.

## `SendBookTab`

Ephemeral selection inside the existing `Send Book` primary screen.

| Field | Type | Rule |
|---|---|---|
| value | enum | Exactly `send` or `history` |

### Validation

- Default is `send`.
- Changing the value has no pipeline side effect.
- The value is not a new application route and is not durable user data.

## `ActionFeedback` expiry projection

The existing feedback value gains no persisted state. Its current identity,
scope, lifecycle, and dismissal policy determine scheduling.

| Field | Type | Rule |
|---|---|---|
| id | UUID | Identifies one feedback lifecycle |
| scope | `FeedbackScope` | Determines one replacement/expiry slot |
| state | `FeedbackState` | Determines whether feedback is actionable |
| dismissal | `FeedbackDismissalPolicy` | Success/info use delayed four-second policy |
| createdAt | Date | Used for observable lifecycle, not persistence |

### `FeedbackExpiryKey`

An internal non-persisted key:

| Field | Type | Rule |
|---|---|---|
| scope | `FeedbackScope` | One active expiry task per scope |
| feedbackID | UUID | Task may remove only this exact feedback |

### State transitions

```text
acknowledged -> inProgress -> succeeded/info -> scheduledExpiry -> removed
                                  |
                                  +-> replaced -> cancelOldTask -> scheduleNew

acknowledged -> inProgress -> failed/cancelled/partial/unknown -> persistent
```

### Validation

- Delayed feedback receives a four-second minimum visible interval.
- Replacement cancels the prior task and starts a full new interval.
- Expiry removes only when both scope and identity still match.
- Expiry removes the value and its layout space.
- Removing a visual value emits no second accessibility announcement.

## `SubmissionReceipt`

Ephemeral application value created only after definitive SMTP acceptance.

| Field | Type | Rule |
|---|---|---|
| attemptID | UUID | Existing independent delivery-attempt identifier |
| batchID | UUID | Used to reject stale presentation events; not stored |
| snapshotID | UUID | Correlates confirmed batch; not stored |
| itemID | UUID | Correlates current batch item; not stored |
| displayName | String | Intake-sanitized original display name |
| acceptedAt | Date | Timestamp assigned at definitive provider acceptance |

### Validation

- Created only for `submitted`.
- Never created for failed, cancelled, excluded, unattempted, or
  `deliveryUnknown`.
- `acceptedAt` reflects definitive acceptance, not batch completion, UI
  observation, or later history load time.
- Receipt projects into a durable record before it crosses the history storage
  port.

## `SubmissionRecord`

Only durable user-visible history entity.

| Field | Type | Rule |
|---|---|---|
| id | UUID | Equal to the originating `attemptID`; idempotency key |
| displayName | String | Non-empty, sanitized original display name |
| acceptedAt | Date | Definitive acceptance timestamp stored as an absolute instant |

### Validation

- Contains exactly the three fields above.
- Does not contain source path, file URL, book content, batch/snapshot/item ID,
  address, credential, SMTP reply, message data, remote identifier, or Kindle
  state.
- Repeated accepted sends of the same display name use distinct identifiers and
  remain separate.
- Inserting an existing identifier is a successful no-op.
- Date/time formatting occurs at presentation time with current locale and time
  zone; formatted text is never persisted.

## `SendHistoryEnvelope`

Versioned file representation owned by the history adapter.

| Field | Type | Rule |
|---|---|---|
| schemaVersion | Int | Initial supported value is `1` |
| records | `[SubmissionRecord]` | At most 500 validated records |

### Validation

- Reject an unsupported schema version with a typed failure.
- Reject files larger than 1 MiB before decoding.
- Reject malformed, over-count, empty-name, or otherwise invalid payloads
  without exposing raw file content or paths.
- Do not silently delete or overwrite an unreadable existing envelope.
- Successful writes use same-directory atomic replacement.
- Use `Application Support/Book Sender/SendHistory/history-v1.json` with
  app-private directory and file permissions.
- An empty history may be represented by no file or a valid version-1 envelope
  with an empty record array.

## `SendHistorySnapshot`

Immutable application/presentation projection.

| Field | Type | Rule |
|---|---|---|
| records | `[SubmissionRecord]` | Newest first, at most 500 |
| loadedAt | Date | Ephemeral observation timestamp, not stored |

### Ordering

1. `acceptedAt` descending;
2. `id.uuidString` descending as deterministic tie-breaker.

### Retention

When adding an accepted record:

1. discard an existing record with the same identifier;
2. append the new record;
3. sort newest first;
4. retain prefix 500;
5. atomically persist the resulting collection;
6. publish the new immutable snapshot.

The operation is logically idempotent for the same record identifier.

## `HistoryFailure`

Typed local persistence failure distinct from delivery outcome.

| Field | Type | Rule |
|---|---|---|
| operation | enum | `load`, `record`, or `clear` |
| code | stable code | Safe catalog key |
| recovery | `RecoveryAction` | Retry load/clear or explain local record failure |

### Minimum stable codes

- `history.unavailable`
- `history.read`
- `history.decode`
- `history.unsupported-schema`
- `history.limit`
- `history.write`
- `history.clear`

Raw filesystem errors, paths, payload data, and encoded records do not cross the
adapter boundary.

## Completed-batch reset projection

No new durable batch entity is introduced. Reset derives from the current
`CurrentBatch`.

| Derived value | Rule |
|---|---|
| `isTerminal` | Batch phase is completed and every item has a terminal result |
| `hasDeliveryUnknown` | At least one item delivery state is `deliveryUnknown` |
| `canRetryFailed` | At least one definitively failed item is retryable |
| `canStartAnotherSend` | Batch is terminal and no active pipeline task remains |

### State transitions

```text
editing -> preparing -> readyForConfirmation -> sending -> completed
                                                       |         |
                                                       |         +-> retryFailed
                                                       |         +-> requestReset
                                                       |                  |
                                                       |                  +-> unknownPresent
                                                       |                  |    -> confirm/cancel
                                                       |                  +-> clear
                                                       |                       -> new editing batch
                                                       +-> cancelling -> completed
```

### Reset invariants

Reset clears:

- current items and terminal item states;
- aggregate counts and progress;
- selection and expanded detail state;
- confirmation and stable snapshot presentation;
- batch/item/delivery feedback and batch-scoped diagnostics;
- prepared workspace and delivery attempts through the pipeline boundary.

Reset preserves:

- delivery setup and non-secret preferences;
- Keychain credential;
- shortcut and application preferences;
- send-history records;
- application route and selected local tab.

Events associated with the previous batch identifier cannot mutate the new
batch.

## Relationships

```text
DeliveryAttempt (accepted)
    -> SubmissionReceipt (ephemeral pipeline context)
        -> SubmissionRecord (privacy-minimized durable projection)
            -> SendHistoryEnvelope (adapter representation)
                -> SendHistorySnapshot (ordered UI projection)

ActionFeedback
    -> FeedbackExpiryKey (ephemeral task guard)

CurrentBatch (completed)
    -> reset confirmation when uncertain
        -> new CurrentBatch identity
```
