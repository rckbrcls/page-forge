# Research: Transient Feedback and Send History

## Scope and evidence

Research covered the active Feature 009 specification, Book Sender Constitution
8.0.0, current action-feedback models, `AppModel`, `SendBookView`,
`PipelineActor`, delivery-attempt state, intake display-name sanitization,
application dependency composition, filesystem and preferences adapters, unit
test doubles, and UI tests.

Representative repository evidence was rechecked locally:

- terminal action feedback currently defaults to
  `persistentUntilReplaced`, while the model already supports a delayed
  dismissal policy;
- no cancellation-aware scheduler currently removes delayed feedback;
- completed batches remain editable and the current primary action stays
  `Send`;
- the pipeline already owns a unique delivery-attempt identifier and a terminal
  completion timestamp;
- `.submitted` currently carries only an item identifier and no history is
  persisted;
- intake already sanitizes the original display name without storing the source
  path in presentation models;
- dependency composition already isolates production and UI-test preferences,
  credentials, workspace, delivery, and diagnostics;
- the Xcode project uses file-system synchronized groups, so new Swift files in
  the existing source/test roots do not require manual project membership.

All technical unknowns required for planning are resolved below.

## Decision 1: Schedule transient expiry in main-actor presentation state

**Decision**: Continue expressing dismissal intent through
`FeedbackDismissalPolicy.delayed(minimumVisibleDuration: 4)` and let `AppModel`
own cancellation-aware expiry tasks keyed by scope and feedback identity.
Inject a sleeper/clock boundary for deterministic tests.

**Rationale**: The feedback service remains a pure mapper, while the main-actor
model already owns the currently visible feedback. Identity checks ensure an
old task cannot remove a newer replacement. A controllable time dependency
proves four-second behavior without slow or flaky tests.

**Alternatives considered**:

- Sleep inside `ActionFeedbackService`: rejected because a pure service should
  not own task lifecycle or mutate observed state.
- Schedule expiry in each SwiftUI view: rejected because navigation and view
  recreation could duplicate or lose tasks.
- Use one global timer that scans all feedback: rejected because per-feedback
  tasks are simpler, cancel directly on replacement, and preserve full
  intervals independently.

## Decision 2: Apply delayed dismissal only to successful and informational results

**Decision**: Successful and informational acknowledgements use the four-second
delayed policy. In-progress, validation, blocked, failed, cancelled, partial,
and unknown feedback remains persistent or explicitly dismissible.

**Rationale**: This exactly preserves actionable state while removing stale
acknowledgements. It also avoids treating cancellation or mixed results as
routine success when the user may still need to understand or resolve them.

**Alternatives considered**:

- Expire every terminal result: rejected because failures, uncertainty, and
  cancellation may require action or conscious acknowledgement.
- Keep setup success persistent as a special case: rejected because Feature 009
  explicitly includes save feedback in the transient behavior.
- Show transient success as a detached toast: rejected because the existing
  inline feedback system already owns accessible action status.

## Decision 3: Persist history in a versioned Application Support JSON file

**Decision**: Add one actor-owned file adapter that stores a versioned Codable
envelope at
`Application Support/Book Sender/SendHistory/history-v1.json`, writes by
same-directory atomic replacement, and uses app-private directory/file
permissions. Enforce a 1 MiB encoded-size limit plus schema, field, and
500-record bounds.

**Rationale**: A structured bounded collection is durable and inspectable
without adding a database or dependency. An actor serializes concurrent read,
insert, and clear operations. One MiB safely contains 500 records even when
each sanitized display name reaches its existing 240-character limit, while
still rejecting unbounded input before decoding. Versioning makes future
compatibility explicit, and atomic replacement prevents partial files from
becoming accepted state.

**Alternatives considered**:

- `UserDefaults`: rejected because a 500-entry activity collection is not a
  preference and would expand an existing settings store with unrelated data.
- SQLite, SwiftData, or Core Data: rejected because query and relationship
  capabilities are unnecessary for a fixed 500-record list.
- One file per submission: rejected because it increases filesystem operations,
  cleanup complexity, and ordering work.
- Unified logging: rejected because history is user-visible durable product
  state with explicit clearing, not diagnostic evidence.

## Decision 4: Record at the definitive acceptance boundary inside the pipeline

**Decision**: Create and persist a typed submission receipt immediately after
the SMTP adapter returns definitive provider acceptance and before the pipeline
advances or publishes batch completion.

**Rationale**: The pipeline knows both delivery certainty and the owning
attempt. Recording there excludes failed, cancelled, unattempted, and uncertain
outcomes and closes the edge case where the app quits after acceptance but
before aggregate UI completion.

**Alternatives considered**:

- Record from `AppModel` when it observes `.submitted`: rejected because an
  application quit or observation interruption can lose the record after SMTP
  acceptance.
- Record when the whole batch completes: rejected because earlier accepted
  items could be lost if later work is interrupted.
- Let the SMTP adapter write history: rejected because adapters should not own
  product persistence or display-name policy.

## Decision 5: Use the delivery attempt identifier as the idempotency key

**Decision**: Project the existing delivery attempt UUID into
`SubmissionRecord.id` and treat insertion of an already stored identifier as a
successful no-op.

**Rationale**: Each independent retry already creates a distinct attempt, so
accepted repeat submissions remain separate while duplicate observation of the
same acceptance cannot create duplicate history.

**Alternatives considered**:

- Generate a new identifier in the history service: rejected because retrying a
  write after an ambiguous local failure could duplicate a record.
- Deduplicate by display name and timestamp: rejected because two accepted
  attempts may legitimately share both.
- Deduplicate by source path: rejected because paths are private, prohibited
  history data and not stable.

## Decision 6: Treat history persistence as best effort relative to delivery truth

**Decision**: A history read, write, or clear failure becomes a typed local
history failure with separate feedback. A failed write does not change
`Submitted`, retry SMTP, or claim the delivery failed.

**Rationale**: Provider acceptance is independent of local activity recording.
Conflating them could cause duplicate sends or lie about the provider outcome.
Typed failure feedback preserves recovery without exposing file paths or raw
filesystem errors.

**Alternatives considered**:

- Fail the delivery when history writing fails: rejected because the provider
  has already accepted the message.
- Retry SMTP together with the history write: rejected because it can duplicate
  delivery.
- Ignore storage failure silently: rejected because the user expects durable
  history and needs honest notice when it was not recorded.

## Decision 7: Enforce order, retention, and privacy in the application service

**Decision**: `SendHistoryService` deduplicates by attempt identifier, sorts
newest first with a stable identifier tie-breaker, retains the newest 500, and
projects only identifier, display name, and acceptance timestamp into storage.

**Rationale**: These are product rules, not file-format rules. Centralizing them
keeps the UI passive, permits an in-memory adapter in tests, and prevents any
future storage implementation from receiving prohibited receipt context.

**Alternatives considered**:

- Sort and truncate only in the view: rejected because excess or unordered
  records would still persist.
- Let the file adapter inspect the full pipeline receipt: rejected because batch
  and item identifiers are unnecessary durable data.
- Drop repeat display names: rejected because each definitive submission is a
  separate history event.

## Decision 8: Keep Send and History as native local tabs

**Decision**: Add a typed `SendBookTab` selection with exact values `Send` and
`History` inside `SendBookView`. Keep application routing unchanged and render a
simple native list for history.

**Rationale**: Local tabs match the constitution and preserve the two-primary-
screen product. A typed selection is testable, keyboard-accessible, and cannot
accidentally trigger pipeline lifecycle work.

**Alternatives considered**:

- Add a new application route or window: rejected because it creates a third
  primary workflow surface.
- Put history in Settings: rejected because Settings is limited to Delivery and
  Shortcut preferences.
- Append history below the active batch: rejected because it confuses current
  work with durable records and makes the send surface unnecessarily long.

## Decision 9: Make completed batches read-only until deliberate reset

**Decision**: Once a batch is terminal, disable intake mutation and change the
primary action to `Send More Books`. Reset creates a new batch identity and
clears only temporary batch/presentation state. If uncertainty exists, require
explicit acknowledgement first.

**Rationale**: The completed batch remains an honest visible result until the
user chooses the next workflow. A new identity prevents late events from
repopulating cleared state, while preservation of setup, preferences, and
history makes reset safe and predictable.

**Alternatives considered**:

- Clear automatically after success: rejected because results could disappear
  before the user understands them.
- Allow drag and drop directly into a completed batch: rejected because old and
  new outcomes would share state and aggregate counts.
- Require acknowledgement for every reset: rejected because only
  `Delivery Unknown` carries a material duplicate-delivery risk.

## Decision 10: Add no new package and keep evidence gates separate

**Decision**: Use Foundation concurrency, Codable, file APIs, and native SwiftUI
controls. Validate static structure, compilation, deterministic tests,
UI/accessibility runtime behavior, authenticated SMTP acceptance, and release
distribution as separate gates.

**Rationale**: Existing frameworks cover timing, storage, formatting, and UI.
Static or fixture success cannot prove macOS accessibility announcements, file
behavior across real relaunches, provider acceptance, Kindle processing, or
release correctness.

**Alternatives considered**:

- Add a persistence or scheduling package: rejected because it expands
  dependency and release risk without reducing this bounded design.
- Treat UI tests as proof of provider acceptance: rejected because controlled
  SMTP outcomes do not establish hosted provider behavior.
- Treat SMTP acceptance as proof of Kindle receipt: rejected because the
  product has no definitive Kindle processing signal.
