# Feature Specification: Transient Feedback and Send History

**Feature Branch**: `main`

**Created**: 2026-07-30

**Status**: Draft

**Input**: User description: "Make action feedback disappear after a short
period, replace the completed Send action with a way to start another send that
clears the current batch and its states, and add a simple history tab showing
the date and time each book was sent."

## Governance Alignment

Book Sender Constitution 8.0.0 explicitly permits and requires the bounded local
send history defined by this specification. The history remains inside the
existing `Send Book` surface, preserves the two-primary-screen boundary, and
inherits the constitution's retention, privacy, clearing, and non-management
constraints.

## User Scenarios & Testing _(mandatory)_

### User Story 1 - See Timely Feedback Without Stale Notices (Priority: P1)

A user receives a concise acknowledgement after a successful action, has enough
time to understand it, and then sees it disappear automatically so an old result
does not look like the application's current state.

**Why this priority**: Persistent success notices create uncertainty about
whether a later action completed and make a lightweight workflow feel stuck.

**Independent Test**: Save delivery setup, add and remove a book, clear a batch,
change a shortcut, complete a send, and clear history, then verify that each
successful acknowledgement appears once and disappears automatically while
active work and actionable failures remain available.

**Acceptance Scenarios**:

1. **Given** valid delivery details, **When** setup is saved successfully,
   **Then** the user sees a success acknowledgement that disappears
   automatically after approximately four seconds.
2. **Given** a transient success or informational acknowledgement is visible,
   **When** no newer feedback replaces it, **Then** it is removed no later than
   five seconds after it first became available.
3. **Given** an equivalent action is completed again while its prior
   acknowledgement is visible, **When** the new result arrives, **Then** the
   existing acknowledgement is replaced rather than duplicated and its visible
   interval restarts.
4. **Given** feedback disappears, **When** the user continues on the same screen
   or returns later, **Then** no empty placeholder or stale success state remains.
5. **Given** an operation is active, blocked, failed, or delivery-unknown,
   **When** a transient-feedback interval elapses, **Then** the meaningful
   progress or actionable outcome remains available until the operation changes
   or the user resolves or clears it.
6. **Given** an important transient acknowledgement appears, **When** assistive
   technology is active, **Then** it is announced once even though its visual
   presentation later disappears.

---

### User Story 2 - Start Another Send From a Completed Batch (Priority: P1)

After every item in the current batch reaches a terminal outcome, a user can
start another send from the same primary action area. One deliberate action
clears the completed batch and all of its temporary state, returning the send
surface to an empty intake state.

**Why this priority**: A completed batch currently leaves the disabled `Send`
action and terminal items on screen without a clear next step.

**Independent Test**: Complete batches containing successful, failed,
cancelled, and delivery-unknown outcomes, choose `Send More Books`, and verify
that the current batch resets completely without changing setup, preferences, or
history.

**Acceptance Scenarios**:

1. **Given** every item in the current batch has a terminal outcome, **When** the
   batch completes, **Then** the primary action changes from `Send` to
   `Send More Books` and remains available.
2. **Given** a completed batch with only definitive outcomes, **When** the user
   chooses `Send More Books`, **Then** the item list, aggregate counts, open
   details, confirmation snapshot, progress, transient feedback, and per-item
   states are cleared in one action.
3. **Given** the completed batch is cleared, **When** the reset finishes, **Then**
   the user sees the empty `Send` tab ready for drag and drop or Finder selection
   and can create a new batch without relaunching the application.
4. **Given** setup, shortcut preferences, or recorded send history already
   exists, **When** the user starts another send, **Then** those durable values
   remain unchanged.
5. **Given** the completed batch contains a `Delivery Unknown` item, **When** the
   user chooses `Send More Books`, **Then** the application requires
   acknowledgement that the provider may have accepted that item before
   discarding its visible uncertain outcome.
6. **Given** an active or partially completed batch, **When** work is still
   scheduled or running, **Then** `Send More Books` is not offered in place of
   the existing progress and cancellation behavior.
7. **Given** one or more definitively failed items remain eligible for explicit
   retry, **When** the batch is complete, **Then** the user may retry them or
   deliberately choose `Send More Books` to discard the current batch.

---

### User Story 3 - Review a Simple Local Send History (Priority: P2)

A user can open a `History` tab within `Send Book` and review a simple
newest-first list showing each successfully submitted book and the local date
and time of that submission.

**Why this priority**: A durable record lets the user confirm what they already
submitted without retaining completed batches in the active sending workflow.

**Independent Test**: Submit individual and batched books across application
restarts, include failed and uncertain attempts, and verify that the history
contains exactly one correctly dated entry per definitive successful submission
and no entry that claims an uncertain or failed attempt succeeded.

**Acceptance Scenarios**:

1. **Given** the user is in `Send Book`, **When** they choose the `History` tab,
   **Then** they see a simple list ordered from newest to oldest with the book
   display name, submission date, and submission time on every row.
2. **Given** the provider definitively accepts a book submission, **When** that
   delivery attempt completes, **Then** exactly one history entry is recorded
   for that book using the acceptance time.
3. **Given** a batch contains multiple successful submissions, **When** the
   batch completes, **Then** each successfully submitted book has its own
   history entry and timestamp.
4. **Given** a book fails, is cancelled, is excluded, or becomes
   `Delivery Unknown`, **When** the attempt ends, **Then** no history entry
   represents that book as successfully submitted.
5. **Given** the same book is successfully submitted more than once, **When**
   the user opens history, **Then** each submission appears as a separate entry.
6. **Given** recorded history exists, **When** the application quits and later
   reopens, **Then** the same records remain available locally.
7. **Given** no successful submission has been recorded, **When** the user opens
   `History`, **Then** the interface shows a calm `No books submitted yet.`
   empty state.
8. **Given** a current batch exists or is actively sending, **When** the user
   switches between `Send` and `History`, **Then** the current batch continues
   unchanged and is still present on return.
9. **Given** history contains records, **When** the user chooses
   `Clear History` and confirms, **Then** all history records are removed without
   clearing or cancelling the current batch.

### Edge Cases

- Setup save completes immediately before the user navigates to `Send Book`.
- Multiple transient acknowledgements arrive in quick succession for the same
  action or for different items.
- The application becomes inactive while a transient acknowledgement is
  visible and is reactivated after its interval has elapsed.
- A batch completes with a mix of submitted, failed, cancelled, excluded, and
  delivery-unknown items.
- The user chooses `Send More Books` while failed-item details or diagnostic
  disclosure is open.
- A late event from the cleared batch arrives after the new empty state is
  visible.
- The application quits after provider acceptance but before the active batch
  finishes updating its presentation.
- The same display name is submitted from different source locations or in
  separate batches.
- The system clock, time zone, or regional date format changes after an entry is
  recorded.
- The history reaches its retention limit while a multi-book batch is adding
  several new successful records.
- History removal is cancelled or local history storage is unavailable.
- A `Delivery Unknown` result is later believed to have arrived at Kindle; the
  application still lacks definitive provider evidence and must not rewrite it
  as a successful submission automatically.

## Requirements _(mandatory)_

### Functional Requirements

- **FR-001**: Successful and informational action acknowledgements MUST be
  transient by default and MUST disappear automatically after approximately
  four seconds and no later than five seconds after becoming visible.
- **FR-002**: Repeated feedback for the same unchanged action outcome MUST replace
  the existing acknowledgement rather than create duplicate notices.
- **FR-003**: A newer acknowledgement MUST replace an older transient
  acknowledgement in the same presentation area and begin its own complete
  visible interval.
- **FR-004**: Removing transient feedback MUST also remove its occupied layout
  space and MUST NOT leave stale text when the user revisits the surface.
- **FR-005**: Active progress, validation guidance, blocked states, failures,
  cancellation results, and delivery-unknown outcomes MUST NOT disappear merely
  because a transient-feedback interval elapsed.
- **FR-006**: Important transient acknowledgements MUST be announced once to
  supported assistive technology and MUST NOT depend on color alone.
- **FR-007**: When every item in a current batch becomes terminal, the primary
  action in the existing send area MUST become `Send More Books`.
- **FR-008**: `Send More Books` MUST clear the complete temporary current-batch
  state, including items, aggregate counts, selection, confirmation snapshot,
  open item detail, progress, action feedback, and terminal outcomes.
- **FR-009**: Starting another send MUST preserve delivery setup, protected
  credentials, shortcut preferences, application preferences, and send-history
  records.
- **FR-010**: After the reset, the `Send` tab MUST show its empty intake state and
  MUST accept a new batch through the existing drag-and-drop and Finder paths.
- **FR-011**: `Send More Books` MUST NOT replace active progress or cancellation
  controls before the current batch is fully terminal.
- **FR-012**: Definitively failed items MUST retain their existing explicit retry
  path until the user retries them or deliberately starts another send.
- **FR-013**: Before a visible `Delivery Unknown` outcome is cleared,
  `Send More Books` MUST require the user to acknowledge that the provider may
  already have accepted the book.
- **FR-014**: Late events associated with a cleared batch MUST NOT repopulate or
  mutate the new batch.
- **FR-015**: The existing `Send Book` primary surface MUST contain exactly two
  local tabs labeled `Send` and `History`, with `Send` remaining the default.
- **FR-016**: Switching tabs MUST NOT clear, cancel, restart, duplicate, or
  otherwise change the current batch.
- **FR-017**: A send-history entry MUST be created exactly once for each book
  whose independent delivery attempt receives definitive provider acceptance.
- **FR-018**: Failed, cancelled, excluded, unattempted, and delivery-unknown books
  MUST NOT be recorded or displayed as successful submissions.
- **FR-019**: Each history entry MUST show the original book display name and the
  date and time of definitive provider acceptance using the user's current
  regional and time-zone conventions.
- **FR-020**: History MUST be ordered newest first, and repeated successful
  submissions of the same display name MUST remain separate entries.
- **FR-021**: Send history MUST persist locally across normal application
  relaunches and MUST retain no more than the latest 500 successful submission
  entries.
- **FR-022**: History storage MUST contain only a record identifier, the original
  display name, and the definitive acceptance timestamp; it MUST NOT contain
  book content, source paths, credentials, SMTP conversation data, or remote
  telemetry identifiers.
- **FR-023**: The `History` tab MUST expose a `Clear History` action that requires
  confirmation and removes all history entries without affecting setup,
  preferences, or the current batch.
- **FR-024**: An empty history MUST display `No books submitted yet.` and MUST
  remain usable by keyboard and supported assistive technology.
- **FR-025**: A history persistence failure MUST NOT change a successful delivery
  into a failure, retry the delivery, or claim that the submission failed; it
  MUST provide separate actionable feedback that the local record could not be
  saved.
- **FR-026**: History wording MUST describe definitive SMTP submission and MUST
  NOT claim Kindle receipt, processing, or library availability.

### Constitution Constraints _(mandatory)_

- **CC-001**: Feature MUST retain exactly two primary screens, `Delivery Setup`
  and `Send Book`; `Send` and `History` MUST remain local tabs within the
  existing `Send Book` surface rather than becoming a third primary screen or
  Settings workflow.
- **CC-002**: Feature MUST keep advanced EPUB preparation in the background and
  MUST preserve the existing sequential, explicit, independent delivery
  behavior.
- **CC-003**: Feature MUST preserve originals, local processing, protected
  credentials, typed outcomes, and the distinction between `Submitted`,
  `Failed`, `Cancelled`, and `Delivery Unknown`.
- **CC-004**: Feature MUST keep technical evidence collapsed during successful
  use and MUST retain actionable failure or uncertainty evidence until the user
  resolves or deliberately clears it.
- **CC-005**: Feature MUST NOT introduce a library, persistent or scheduled
  queue, reader, editor, account, cloud sync, analytics, AI, conversion, DRM
  removal, external processing, or a parallel product surface.
- **CC-006**: History MUST remain bounded, local, user-visible, and independently
  clearable, with no hidden collection or remote transmission.
- **CC-007**: Feature MUST comply with Book Sender Constitution 8.0.0 and MUST
  preserve its bounded local-history, two-primary-screen, privacy, and
  non-management boundaries through planning, implementation, and validation.

### Key Entities

- **Transient Feedback**: A concise success or informational acknowledgement
  scoped to one completed action, with its visible start, replacement identity,
  and automatic expiration.
- **Current Batch**: The ordered temporary set of selected books, aggregate
  progress, confirmation snapshot, item details, and terminal outcomes that are
  cleared together when another send begins.
- **Send Reset**: The deliberate transition from one fully terminal current
  batch to a new empty intake state without changing durable setup,
  preferences, or history.
- **Submission Record**: One local record of a definitively accepted delivery,
  containing only a record identifier, original display name, and acceptance
  timestamp.
- **Send History**: The bounded newest-first collection of successful
  submission records displayed inside the `History` tab.

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: In 100% of covered successful setup, preference, intake, batch,
  send-summary, and history actions, the acknowledgement appears once and is no
  longer visible within five seconds without additional user action.
- **SC-002**: In 100% of covered failure, blocked, active, cancellation, and
  delivery-unknown cases, actionable state remains available after transient
  acknowledgements expire.
- **SC-003**: After a fully terminal batch, a user reaches an empty intake state
  ready for another batch with one `Send More Books` action in under two
  seconds, without relaunching the application.
- **SC-004**: Across batches containing 20 mixed outcomes, 100% of definitive
  successful submissions create exactly one history entry, and 0 failed,
  cancelled, excluded, or delivery-unknown items are represented as successful.
- **SC-005**: Every retained history entry displays the correct book name and
  acceptance date and time across application relaunches and supported regional
  and time-zone changes.
- **SC-006**: A newest-first history containing 500 entries becomes readable
  within one second of choosing `History` on a supported Mac.
- **SC-007**: Privacy inspection finds zero credentials, source paths, book
  content, provider transcripts, or remote telemetry identifiers in send
  history.
- **SC-008**: Setup save, batch completion, `Send More Books`, tab switching,
  empty history, and history clearing are fully operable by keyboard and
  meaningfully announced by supported assistive technology.
- **SC-009**: Acceptance review confirms exactly two primary screens, with no
  queue, library, account, cloud, analytics, or delivery-status claim beyond
  definitive SMTP submission.

## Assumptions

- "Feedback" means transient success and informational acknowledgements, not
  active progress, validation guidance, blocked states, failures, or uncertain
  delivery evidence.
- The standard transient-feedback interval is approximately four seconds and
  never exceeds five seconds unless the feedback becomes actionable.
- The completed batch remains available for review until the user explicitly
  chooses `Send More Books`; the transient aggregate success acknowledgement may
  disappear independently.
- `Submitted` means the configured SMTP provider definitively accepted the
  message. It does not mean Kindle processed the book or added it to a library.
- Send history persists only on the local Mac, records one row per individual
  definitive submission, and treats repeated submissions as separate events.
- A bounded limit of 500 entries is sufficient for the requested lightweight
  tracking use case; the oldest records are removed first when the limit is
  exceeded.
- Clearing history is separate from clearing the current batch and does not
  affect delivery setup or protected credentials.
- This feature depends on the behavior contracts established by Features 006,
  007, and 008. Feature 008 remains responsible only for feedback and diagnostic
  history boundaries; this feature owns the separate bounded send history.

## Out of Scope

- Confirming Kindle receipt, processing, conversion, or library availability.
- Retrying, resending, opening, locating, previewing, or managing a book from
  history.
- Search, filters, grouping, statistics, exports, sharing, cloud sync, or
  cross-device history.
- Per-entry editing or deletion; the supported removal action clears all local
  history after confirmation.
- Persistent or scheduled queues, automatic retry, and sending directly from
  history.
- Recording failed, cancelled, excluded, unattempted, or delivery-unknown items
  as successful submissions.
