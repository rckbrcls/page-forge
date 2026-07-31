# Feature Specification: Essential Notification Feedback

**Feature Branch**: `main`

**Created**: 2026-07-31

**Status**: Draft

**Input**: User description: "Reduce excessive floating feedback. Events whose
result is already visible through the application's normal behavior should not
also produce a notification. Reserve notifications for meaningful outcomes
that cannot otherwise be seen and need confirmation or attention."

## Governance Alignment

This feature narrows the notification coverage introduced by Feature 010. It
preserves the shared floating presentation for the small set of outcomes that
need it while restoring the constitution's visually calm, concise-feedback
principle.

The reduction does not remove field validation, progress, per-book status,
aggregate batch state, failure evidence, modal confirmation, delivery
uncertainty, or history state. Those remain visible in their durable workflow
context. Successful or informational notifications that remain eligible still
expire within five seconds; eligible failures and uncertain outcomes remain
available until deliberately resolved, replaced, or dismissed.

## Notification Eligibility Rule

A floating notification is eligible only when all of the following are true:

1. a meaningful action has produced a result that the user may reasonably need
   to confirm or act upon;
2. that result is not already communicated immediately and durably by the
   visible form, control, route, list, row, aggregate state, sheet, alert, empty
   state, unavailable state, or progress presentation; and
3. omitting the notification would leave the user uncertain about an invisible
   side effect, a consequential background result, or the location of required
   recovery.

When any condition is false, the product MUST rely on the existing contextual
presentation and MUST NOT show a redundant floating notification.

## Approved Notification Coverage

The reduced production catalogue consists of these categories:

- successful or failed copying of diagnostic details because clipboard changes
  are not otherwise visible;
- successful setup persistence when confirmation that the protected credential
  was stored is not otherwise visible;
- setup deletion outcomes that confirm an otherwise invisible credential
  deletion result, including a partial Keychain outcome;
- failure to record an already accepted submission in local history because the
  invisible persistence failure is distinct from the visible successful
  delivery;
- a consequential failure or uncertainty that has no immediately visible
  durable contextual representation, with an action that reveals the relevant
  recovery context when recovery is available;
- failure to open an explicitly requested external or auxiliary system action
  when no resulting interface appears to communicate that failure.

This catalogue is exhaustive for the feature. A new notification category must
independently satisfy the eligibility rule rather than inheriting eligibility
from being an action acknowledgement.

## Explicitly Silent Contextual Events

The following events MUST NOT produce floating notifications when their outcome
is already shown by the interface:

- application opening, restoration completion, route reconciliation, and
  window reveal;
- history loading or refresh while the history screen exposes loading, content,
  empty, or unavailable state;
- starting, completing, or cancelling book intake and preparation;
- adding, removing, or clearing books when the batch list visibly changes;
- preparation progress, per-book readiness, blocked items, and aggregate intake
  results;
- opening, preparing, dismissing, or losing availability of a confirmation
  sheet when the modal state is itself visible;
- starting, progressing, cancelling, completing, or retrying delivery while
  per-book and aggregate delivery state is visible;
- definitive delivery success, failure, cancellation, partial result, or
  delivery uncertainty when the corresponding row and aggregate guidance remain
  visible;
- starting another send when the completed batch visibly resets;
- history clearing when the confirmation, list, count, and resulting empty state
  make the outcome visible; a failure remains contextual when the history error
  state communicates it;
- shortcut registration, conflict, enabling, or disabling when the recorder,
  switch, and registration status visibly communicate the result;
- opening an update check when the standard update interface appears;
- field validation or setup failure already communicated next to the affected
  fields or through durable contextual failure evidence;
- any action whose only notification text restates a visible control, row,
  count, route, sheet, or status change.

## User Scenarios & Testing _(mandatory)_

### User Story 1 - Complete Normal Work Without Notification Noise (Priority: P1)

A user adds books, waits for preparation, confirms a batch, sends it, reviews
the outcomes, and starts another send without floating cards repeating states
that are already visible in the workflow.

**Why this priority**: The primary workflow already provides detailed durable
state. Repeating every transition as a notification obscures the books and
increases cognitive load without adding confidence.

**Independent Test**: Complete a successful one-book send and a mixed multi-book
send while recording every floating notification and every contextual state.

**Acceptance Scenarios**:

1. **Given** the send screen is visible, **When** books are added and prepared,
   **Then** the drop target, batch rows, and aggregate state communicate progress
   and no intake or preparation notification appears.
2. **Given** a confirmation is requested, displayed, dismissed, or becomes
   unavailable, **When** the corresponding modal state changes visibly, **Then**
   no notification restates that change.
3. **Given** a confirmed batch is sending, **When** connection stages, item
   outcomes, and aggregate progress change, **Then** those changes remain in the
   send workflow and no progress or terminal delivery notification duplicates
   them.
4. **Given** a completed batch can be reset, **When** the user starts another
   send and the list visibly clears, **Then** no reset acknowledgement appears.
5. **Given** the user removes one book or clears the editable batch, **When** the
   list visibly reflects the action, **Then** no removal or clearing
   notification appears.

---

### User Story 2 - Confirm an Invisible Side Effect (Priority: P1)

A user receives one concise notification when an action changes state outside
the visible workflow and the application otherwise cannot show whether that
side effect succeeded.

**Why this priority**: Clipboard, protected-credential, and separate persistence
operations can succeed or fail without an observable change in the current
content.

**Independent Test**: Exercise every approved invisible-side-effect category in
both success and failure conditions and verify that each produces exactly one
appropriate notification.

**Acceptance Scenarios**:

1. **Given** diagnostic details are available, **When** the user copies them,
   **Then** one temporary success notification confirms the clipboard change.
2. **Given** the clipboard write fails, **When** the copy action completes,
   **Then** one persistent failure notification communicates the failure without
   replacing the original diagnostic evidence.
3. **Given** valid delivery setup is saved, **When** protected credential
   persistence succeeds, **Then** one temporary notification may confirm that
   the setup and credential were stored securely.
4. **Given** delivery setup is deleted, **When** credential deletion succeeds or
   finishes partially, **Then** one notification communicates the otherwise
   invisible credential outcome without duplicating the visibly reset form.
5. **Given** a provider has definitively accepted a book, **When** recording that
   submission in local history fails, **Then** one persistent notification states
   that delivery succeeded but history was not updated.

---

### User Story 3 - Recover From a Non-Visible Consequential Failure (Priority: P2)

A user is notified when a consequential background or auxiliary action fails
without leaving an immediately visible durable state, and can reach the relevant
recovery context from that notification when recovery exists.

**Why this priority**: Reducing noise must not hide a failure that the current
screen cannot otherwise communicate.

**Independent Test**: Trigger a consequential failure with no visible contextual
representation, then repeat with equivalent durable evidence already visible.

**Acceptance Scenarios**:

1. **Given** an action fails and no visible contextual state communicates the
   failure, **When** the result becomes known, **Then** one persistent
   notification appears with concise meaning and an appropriate recovery route
   when available.
2. **Given** the same failure is already represented by a visible field error,
   book row, aggregate state, unavailable state, sheet, alert, or expanded
   failure detail, **When** it occurs, **Then** no duplicate notification appears.
3. **Given** the user requests an auxiliary system action, **When** no resulting
   interface appears because the request fails, **Then** a notification confirms
   that the requested action did not open.
4. **Given** an eligible persistent notification provides recovery, **When** the
   user activates it, **Then** the relevant durable context becomes available
   without executing a destructive action or silently retrying delivery.

---

### User Story 4 - Preserve Accessible, Durable Meaning (Priority: P2)

A keyboard or assistive-technology user receives essential notification
announcements without repeated narration of every visible workflow transition.

**Why this priority**: Redundant announcements are especially disruptive when
the same state is already exposed by controls and live workflow content.

**Independent Test**: Complete the normal send flow and every approved
notification flow using keyboard navigation and supported assistive technology.

**Acceptance Scenarios**:

1. **Given** a contextual state change is already visible and accessible,
   **When** it occurs, **Then** no separate notification announcement repeats it.
2. **Given** an eligible invisible outcome occurs, **When** its notification
   appears, **Then** it is announced once without stealing focus.
3. **Given** a failure notification is dismissed, **When** durable failure
   evidence exists elsewhere, **Then** that evidence remains available and its
   semantic outcome is unchanged.
4. **Given** delivery is uncertain, **When** the notification policy suppresses
   a redundant card, **Then** the visible row and aggregate guidance still expose
   the uncertainty and required caution accessibly.

### Edge Cases

- An action begins while its visible control is on screen but finishes after the
  user switches to another local tab.
- A visible contextual state disappears before the user can understand a
  consequential failure.
- An invisible side effect succeeds while an older notification from the same
  scope is still visible.
- Clipboard copying is requested repeatedly in a short interval.
- Setup persistence succeeds but navigation immediately changes the visible
  screen.
- Setup deletion clears the visible form while protected credential deletion
  finishes partially.
- SMTP acceptance succeeds while history persistence fails.
- Delivery becomes unknown while the corresponding row is outside the visible
  scroll region but remains durably represented in the batch.
- A modal confirmation appears while an eligible notification is visible.
- A failure has both visible field guidance and a background diagnostic record.
- A standard update interface opens slowly after the user requests it.
- A notification-eligible action produces the same result several times.

## Requirements _(mandatory)_

### Functional Requirements

#### Eligibility and Suppression

- **FR-001**: Every candidate floating notification MUST be evaluated against
  the Notification Eligibility Rule before presentation.
- **FR-002**: An event MUST NOT produce a floating notification solely because
  an action began, progressed, completed, failed, or was cancelled.
- **FR-003**: An event whose meaning is immediately and durably represented by a
  visible form, control, route, list, row, aggregate state, sheet, alert, empty
  state, unavailable state, or progress presentation MUST NOT produce a
  duplicate floating notification.
- **FR-004**: Normal book intake, preparation, confirmation, delivery, batch
  editing, batch reset, history browsing, shortcut editing, application opening,
  and successful update-interface opening MUST use their contextual presentation
  without floating notifications.
- **FR-005**: Progress-only states MUST remain contextual and MUST NOT occupy the
  floating notification stack.
- **FR-006**: Field validation and durable failure evidence MUST remain adjacent
  to their affected context and MUST NOT be duplicated by a notification.
- **FR-007**: A per-book or aggregate delivery result MUST remain visible in the
  send workflow even when no floating notification is presented.
- **FR-008**: Delivery uncertainty MUST remain explicit and durable in the send
  workflow and MUST NOT depend on a floating notification for safety meaning.

#### Approved Notifications

- **FR-009**: Successful diagnostic copying MUST produce one temporary
  notification confirming the otherwise invisible clipboard change.
- **FR-010**: Failed diagnostic copying MUST produce one persistent failure
  notification while preserving the original diagnostic evidence.
- **FR-011**: Successful setup persistence MAY produce one temporary
  notification confirming protected credential storage when that result is not
  otherwise visible.
- **FR-012**: Setup deletion MUST communicate an otherwise invisible credential
  deletion success or partial outcome with at most one notification.
- **FR-013**: Failure to record a definitively accepted submission in local
  history MUST produce one persistent notification that keeps delivery success
  distinct from history failure.
- **FR-014**: A consequential failure without an immediately visible durable
  representation MUST produce one persistent notification.
- **FR-015**: Failure to open an explicitly requested external or auxiliary
  system action MAY produce one notification only when no resulting interface
  appears to communicate the failure.
- **FR-016**: No approved notification category MAY imply Kindle receipt,
  provider processing, or successful delivery beyond a definitive SMTP
  acceptance already represented by the delivery domain.

#### Recovery and Lifetime

- **FR-017**: An eligible failure notification MUST provide a recovery action
  only when that action reveals or focuses durable recovery context or begins an
  already-safe, explicit recovery workflow.
- **FR-018**: A notification action MUST NOT replace modal confirmation for a
  destructive operation, delivery, retry, or uncertainty acknowledgement.
- **FR-019**: Closing a notification MUST affect only its presentation and MUST
  NOT alter the underlying outcome, durable evidence, current batch, history,
  setup, credential, or delivery state.
- **FR-020**: Eligible successful confirmations MUST disappear automatically no
  later than five seconds after becoming visible.
- **FR-021**: Eligible failure, partial, and uncertain notifications MUST remain
  until deliberately dismissed, resolved, or replaced.
- **FR-022**: Repeated equivalent eligible outcomes MUST update or replace one
  notification rather than create duplicate cards.
- **FR-023**: Suppressed events MUST NOT consume visible or queued notification
  capacity and MUST NOT create accessibility announcements through the floating
  system.

#### Accessibility and Auditability

- **FR-024**: Eligible notifications MUST remain keyboard accessible, announce
  meaningful new information once, and MUST NOT steal focus.
- **FR-025**: Suppressing a notification MUST NOT remove the accessible label,
  value, status, or recovery path from the contextual presentation that made the
  notification redundant.
- **FR-026**: The product MUST maintain an explicit reviewed classification of
  existing feedback events as `contextual`, `notify`, or `not applicable`, with
  a user-facing rationale for every `notify` classification.
- **FR-027**: Newly introduced action feedback MUST default to contextual
  presentation unless its specification demonstrates all notification
  eligibility conditions.
- **FR-028**: Test-only notification scenarios MAY continue exercising the full
  reusable component configuration matrix but MUST NOT expand production
  notification eligibility.

### Constitution Constraints _(mandatory)_

- **CC-001**: The feature MUST retain exactly two primary screens, `Delivery
  Setup` and `Send Book`, plus the existing bounded Settings window.
- **CC-002**: The feature MUST keep the interface visually calm and expose
  concise contextual progress without invented or duplicate feedback.
- **CC-003**: Eligible successful and informational notifications MUST disappear
  within five seconds.
- **CC-004**: Active progress, validation guidance, blocked state, failure
  evidence, cancellation, partial outcome, and `Delivery Unknown` MUST remain
  available contextually until changed or deliberately resolved.
- **CC-005**: Confirmation sheets and alerts MUST remain explicit decisions and
  MUST NOT be replaced by notification actions.
- **CC-006**: The reduction MUST NOT change ebook preparation, original-file
  preservation, sequential batch behavior, SMTP confirmation, cancellation, or
  delivery-unknown semantics.
- **CC-007**: The reduction MUST NOT change send-history eligibility, retention,
  privacy, ordering, persistence, or clearing behavior.
- **CC-008**: The feature MUST NOT add a notification history, system
  notifications, telemetry, remote transport, preferences screen, or new
  durable notification data.

### Key Entities

- **Feedback Event**: A meaningful action or state transition considered for
  either contextual presentation or floating notification presentation.
- **Contextual Evidence**: A visible and durable form error, control state,
  route, list mutation, row status, aggregate result, sheet, alert, empty state,
  unavailable state, progress state, or failure detail that already communicates
  an event.
- **Notification Eligibility Decision**: The reviewed classification of a
  feedback event as contextual or notification-worthy, including the reason the
  result cannot otherwise be seen.
- **Invisible Side Effect**: A meaningful result such as clipboard, protected
  credential, or separate-history persistence whose success or failure is not
  inherently visible in the current workflow.
- **Consequential Hidden Failure**: A failed or uncertain result without an
  immediately visible durable representation and whose omission could mislead
  the user or remove required recovery.

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: A complete successful send journey after setup—add, prepare,
  confirm, send, review, and reset—produces zero floating notifications while
  every meaningful state remains visible in the workflow.
- **SC-002**: Removing a book, clearing an editable batch, opening or dismissing
  confirmation, changing shortcut state, loading history, clearing visible
  history, opening the update interface, and revealing the application each
  produce zero redundant notifications in 100% of acceptance checks.
- **SC-003**: Every approved invisible-side-effect success or failure produces
  exactly one notification, with no duplicate contextual banner or repeated
  accessibility announcement.
- **SC-004**: In 100% of tested failures that already have visible contextual
  evidence, zero duplicate floating notifications appear and the contextual
  evidence remains actionable.
- **SC-005**: In 100% of tested consequential failures without visible durable
  evidence, one persistent notification appears and any required recovery path
  remains reachable.
- **SC-006**: The production notification catalogue contains no more than six
  explicitly approved categories, and every category documents which invisible
  result or required confirmation it communicates.
- **SC-007**: Eligible temporary confirmations disappear within five seconds;
  eligible persistent outcomes remain after ten seconds until deliberately
  resolved, replaced, or dismissed.
- **SC-008**: Keyboard and assistive-technology review finds zero redundant
  floating announcements during the normal send journey and one announcement
  for each eligible invisible outcome.
- **SC-009**: Regression review confirms zero loss of visible field validation,
  per-book progress, aggregate progress, terminal outcomes, delivery uncertainty,
  confirmation, failure evidence, or recovery actions after notification
  suppression.
- **SC-010**: The feature changes no setup, credential, ebook preparation,
  delivery, history, privacy, or release outcome beyond presentation eligibility.

## Assumptions

- A visible contextual result is preferable to a floating notification because
  it remains associated with the object or control that produced it.
- "Needs confirmation" means the user needs acknowledgement of an otherwise
  invisible result; it does not mean replacing existing modal confirmation
  sheets or alerts with notification buttons.
- Protected credential persistence and deletion are treated as invisible side
  effects even when the surrounding setup form visibly changes.
- A definitive SMTP result already shown in a book row and aggregate batch state
  does not need a second floating confirmation.
- A history-record failure after successful SMTP acceptance remains eligible
  because it is a distinct invisible persistence outcome, not a duplicate of the
  delivery result.
- Test-only scenarios may continue presenting every notification configuration
  to verify the reusable component independently from the reduced production
  catalogue.

## Dependencies

- The existing contextual form, batch, per-book, aggregate, history, shortcut,
  failure-detail, sheet, and alert states remain the source of durable visible
  meaning for suppressed events.
- The existing reusable floating-notification capability remains available for
  the reduced approved catalogue.
- Feature 010 remains the presentation and accessibility contract for eligible
  notifications; Feature 011 replaces only its broad production coverage
  policy.

## Out of Scope

- Removing or redesigning contextual progress, row status, aggregate state,
  field validation, failure details, confirmation sheets, alerts, or history;
- changing the reusable notification component's visual appearance, stacking,
  timing, icon, close, or action capabilities;
- changing SMTP delivery, preparation, cancellation, retry, setup, credentials,
  history semantics, or application navigation;
- adding system notifications, sounds, badges, notification preferences,
  notification history, remote transport, telemetry, or analytics.
