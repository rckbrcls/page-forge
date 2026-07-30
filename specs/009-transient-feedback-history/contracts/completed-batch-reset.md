# Contract: Completed Batch Reset

## Purpose

Provide one clear next action after a batch becomes terminal without mixing the
completed results with a new intake or silently discarding uncertain delivery
state.

## Primary action

| Batch state | Primary action |
|---|---|
| Empty/editing/preparing/ready | `Send` using current eligibility rules |
| Sending/cancelling | Existing progress and cancellation behavior |
| Completed | `Send More Books` |

`Send More Books` is never substituted before all current items are terminal
and the active pipeline task has ended.

## Completed-state behavior

- Existing items, outcomes, aggregate counts, and disclosures remain visible
  until deliberate reset.
- Definitively failed items retain the existing `Retry Failed` action.
- Intake mutation is unavailable in completed state.
- Drag/drop or Finder selection cannot add a new item to a completed batch.
- The pipeline enforces the completed-state guard independently of SwiftUI.

## Definitive reset

For a completed batch with no `Delivery Unknown` item:

1. the user invokes `Send More Books`;
2. the pipeline clears its completed batch, attempts, snapshot, and workspace;
3. the application adopts the new empty batch identity;
4. batch-scoped presentation state is removed;
5. the `Send` tab renders the existing empty intake state.

Reset is one user action and may expose routine transient success feedback only
if that feedback does not obscure the empty intake.

## Uncertain reset

For a completed batch containing one or more `Delivery Unknown` items:

1. `Send More Books` presents a native confirmation;
2. confirmation states that the provider may already have accepted a book;
3. cancelling leaves every item and presentation state unchanged;
4. confirming runs the definitive reset;
5. reset does not reinterpret, record, retry, or otherwise change the old
   uncertain outcome.

The confirmation must not claim that the item was delivered or rejected.

## Cleared state

Reset removes:

- item list and per-item terminal state;
- aggregate submitted/failed/cancelled/unknown counts;
- preparation and delivery progress;
- confirmation snapshot and pending confirmation presentation;
- selection and expanded item details;
- batch, batch-item, and delivery feedback;
- batch-scoped diagnostic presentation;
- delivery attempts and temporary/prepared workspace owned by the old batch.

Reset preserves:

- saved delivery setup;
- protected Keychain credential;
- shortcut and application preferences;
- application route;
- `Send`/`History` tab selection;
- all local send-history records.

## Stale-event isolation

- Every mutation-capable pipeline event is associated with an originating batch
  identifier or is reconciled against a snapshot that contains that identifier.
- After reset, an event from the old identifier is ignored by presentation.
- Ignoring a late event does not emit new success, failure, aggregate, or
  history feedback.
- A definitive accepted attempt recorded before reset remains in history.
- Reset cannot remove or roll back a previously persisted submission record.

## Failure behavior

- If pipeline clear fails, the current completed batch remains visible and a
  typed actionable failure appears.
- Partial presentation-only clearing is not accepted as success.
- Reset never retries SMTP.
- Reset never changes delivery truth for submitted, failed, cancelled, or
  uncertain items.

## Acceptance checks

- Submitted-only, failed-only, cancelled-only, mixed, and uncertain completed
  batches expose `Send More Books`.
- Active and partially completed batches do not.
- Failed items may be retried before reset.
- Cancelling uncertain reset preserves the batch.
- Confirming uncertain reset returns to empty intake.
- Setup, credentials, shortcut preferences, and history survive reset.
- A late event cannot repopulate the new batch.
- A new drag/drop or Finder selection creates a new batch after reset.
