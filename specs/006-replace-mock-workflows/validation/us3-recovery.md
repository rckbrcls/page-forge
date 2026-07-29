# US3 Recovery Validation

## Static implementation evidence

- The pipeline retains and cancels its active task, stops pending scheduling,
  and preserves completed item outcomes.
- Cancellation before SMTP message data is definitive; cancellation or channel
  loss after data begins is `delivery_unknown`.
- Editing, removal, clearing, and setup saving are phase guarded.
- Retry confirmation selects only definitive failures, preserves ordering, and
  creates a fresh snapshot and attempts.
- Submitted, cancelled, excluded, and unknown items are never included in
  automatic retry.
- Partial workspace and EPUB outputs are removed on typed failure or
  cancellation; startup orphan cleanup is marker and age bounded.

## Validation boundary

The recovery contracts and tests are present but were not compiled or
executed. Runtime cancellation latency, active-channel interruption, and
original digest evidence remain pending authorization.
