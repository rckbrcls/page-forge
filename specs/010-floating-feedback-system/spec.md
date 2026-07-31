# Feature Specification: Floating Feedback System

**Feature Branch**: `main`

**Created**: 2026-07-30

**Status**: Draft

**Input**: User description: "Make each batch-item divider span almost the full
row and replace the application's inline action feedback with a modular,
Sonner-style floating notification system. Notifications must support temporary
or persistent presentation, configurable duration, icon, message, optional
close control, and an optional action button with an originating-workflow-defined
label and behavior."

## Governance Alignment

This feature changes how concise action feedback is presented without changing
what constitutes success, failure, uncertainty, active work, or definitive
submission. It preserves the Book Sender Constitution 8.0.0 rules that
successful and informational acknowledgements disappear within five seconds,
while blocked, failed, cancelled, partial, and delivery-unknown outcomes remain
available until deliberately resolved, replaced, or cleared.

The notification system is a shared presentation capability inside the existing
`Delivery Setup`, `Send Book`, and auxiliary Settings surfaces. It does not add
a primary screen, notification center, activity log, system notification,
history destination, or remote service. The bounded send history remains
unchanged.

## Scope Boundary

The feature migrates concise action feedback that is currently inserted into
the middle of a screen or form, including acknowledgements and action-level
failures for setup, shortcut preferences, book intake, batch actions, delivery
summaries, diagnostic copying, history actions, and application-level actions.

The following are stateful content rather than floating notifications and MUST
remain in their existing workflow context:

- field-level validation beside the affected field;
- blocking setup guidance required to complete the form;
- active book preparation and delivery progress;
- each book's current status and terminal outcome;
- aggregate batch counts and delivery-unknown guidance;
- expanded diagnostic and failure evidence;
- empty, loading, and unavailable screen states;
- confirmation sheets and destructive or uncertainty alerts;
- the initial blocking application-opening state.

An action-level failure MAY also produce a persistent floating notification, but
the notification MUST provide a direct route to the durable contextual evidence
when that evidence is needed to understand or recover from the failure.

## User Scenarios & Testing _(mandatory)_

### User Story 1 - Receive Feedback Without Moving the Workflow (Priority: P1)

A user completes an action and sees a compact notification float above the
current content near the upper trailing edge of the active window. The
notification does not insert itself between controls, move the batch list, push
the form, reserve empty space after dismissal, or appear in the center of the
workflow.

**Why this priority**: Action feedback should be visible without interrupting
the spatial continuity of setup, sending, history, or shortcut configuration.

**Independent Test**: Trigger one success, informational result, and failure in
each supported feedback scope, then compare the positions and dimensions of the
underlying controls before, during, and after each notification.

**Acceptance Scenarios**:

1. **Given** the send screen is visible, **When** a book is added, removed, or
   cleared, **Then** the acknowledgement appears in a floating notification
   near the upper trailing edge and the drop target, batch card, and primary
   action do not move.
2. **Given** the delivery form is visible, **When** setup is saved,
   **Then** the success acknowledgement appears above the form content rather
   than occupying a form row.
3. **Given** the shortcut settings tab is visible, **When** the shortcut is
   registered, changed, disabled, or rejected, **Then** its action feedback
   appears in the settings window's notification area without moving the
   recorder or switch.
4. **Given** the history tab is visible, **When** history is cleared or a
   history action fails, **Then** the notification does not move the centered
   empty state, list, count, or clear action.
5. **Given** a notification disappears or is closed, **When** the user
   continues working, **Then** no placeholder, blank row, stale accessibility
   value, or reserved notification frame remains in the content.
6. **Given** a sheet or alert is presented, **When** a notification is already
   visible, **Then** the sheet or alert remains visually and interactively
   dominant and the notification cannot obstruct its controls.

---

### User Story 2 - Configure a Reusable Notification (Priority: P1)

Every product surface can request the same notification behavior while choosing
whether the notification is temporary or persistent, how long a temporary
notification remains, which icon and message it presents, whether it has a close
control, and whether it offers one action button with a specific label and
outcome chosen by the originating workflow.

**Why this priority**: A single configurable feedback contract prevents each
screen from inventing a different banner, lifetime, dismissal rule, or action
layout.

**Independent Test**: Present a controlled matrix of notifications covering
temporary and persistent lifetimes, the shortest and longest permitted
durations, custom and derived icons, one-line and multi-line messages, close
control shown and hidden, and action present and absent.

**Acceptance Scenarios**:

1. **Given** a successful or informational action has no special policy,
   **When** its notification appears, **Then** it uses the default temporary
   duration of approximately four seconds and is absent no later than five
   seconds after becoming visible.
2. **Given** a producer specifies a permitted temporary duration, **When** the
   notification appears, **Then** it remains visible for that duration within
   normal scheduling tolerance and never exceeds the constitutional
   five-second maximum.
3. **Given** a notification is persistent, **When** more than five seconds
   elapse, **Then** it remains visible until closed, resolved, or replaced
   according to its declared policy.
4. **Given** a close control is enabled, **When** the user activates it,
   **Then** only that notification closes and the underlying action or durable
   workflow state is unchanged.
5. **Given** a close control is disabled, **When** the notification appears,
   **Then** no empty close target is exposed visually or to assistive
   technology.
6. **Given** a persistent notification has no close control, **When** it is
   requested, **Then** it has either a meaningful action or a defined
   state-driven replacement or resolution path so it cannot become trapped on
   screen.
7. **Given** an icon is specified, **When** the notification appears, **Then**
   that icon is displayed with a semantic accessibility description or is
   hidden from assistive technology when the message already communicates the
   same meaning.
8. **Given** no icon is specified, **When** the notification appears, **Then**
   the presentation remains aligned and understandable without an empty icon
   placeholder.
9. **Given** a message contains a concise title and supporting detail,
   **When** it appears at the minimum supported window size, **Then** it wraps
   within the notification rather than truncating essential meaning or
   expanding across the center of the window.
10. **Given** an action label and outcome are provided, **When** the user
    activates the action, **Then** exactly that declared outcome runs once and
    the notification is updated, replaced, or dismissed according to the
    resulting state.
11. **Given** a notification action is the only route to required recovery,
    **When** the notification appears, **Then** it is persistent so keyboard and
    assistive-technology users are not required to reach the action within a
    short timer.
12. **Given** a temporary notification includes a nonessential action,
    **When** the notification expires before the action is used, **Then** the
    underlying workflow still provides every required recovery or next step.

---

### User Story 3 - Manage Multiple Notifications Calmly (Priority: P1)

When actions complete close together, the user sees a compact ordered stack
rather than overlapping notices, repeated duplicates, or a growing wall of
feedback.

**Why this priority**: Batch and setup workflows can produce several outcomes in
quick succession, and an unmanaged overlay would obscure the product as readily
as the current inline feedback.

**Independent Test**: Publish notifications from the same and different scopes
in rapid succession, including repeated results, persistent failures, queued
temporary acknowledgements, individual dismissal, navigation, window
deactivation, and reactivation.

**Acceptance Scenarios**:

1. **Given** notifications from different actions are visible,
   **When** another notification arrives, **Then** the stack keeps a stable
   vertical order with the newest notification closest to the anchor and no
   overlap between cards.
2. **Given** the same action publishes the same outcome repeatedly,
   **When** the repeated result arrives, **Then** the visible notification is
   updated in place and may show an occurrence count rather than adding a
   duplicate card.
3. **Given** the same action transitions from active to succeeded, failed,
   cancelled, partial, or unknown, **When** the state changes, **Then** the
   existing notification updates in place while preserving one lifecycle
   identity.
4. **Given** three notifications are visible in one window, **When** a fourth
   distinct notification arrives, **Then** no more than three cards are shown
   at once and the additional result is handled without discarding a persistent
   actionable notification.
5. **Given** an overflow notification is waiting, **When** a visible slot
   becomes available, **Then** the next relevant notification appears and a
   temporary lifetime starts only when that notification becomes visible.
6. **Given** one notification is closed, **When** other notifications remain,
   **Then** they retain their own identity, content, lifetime, and actions.
7. **Given** a temporary notification's lifetime ends while the application is
   inactive, **When** the application becomes active again, **Then** the
   expired notification does not reappear.
8. **Given** a persistent failure is visible when its originating tab becomes
   hidden, **When** the user returns to that context, **Then** the actionable
   state is still available without moving to another window or being
   represented as success.
9. **Given** a notification belongs to the main window,
   **When** the Settings window becomes active, **Then** the notification does
   not jump into Settings; each window presents only its own relevant feedback.

---

### User Story 4 - Act On or Dismiss Feedback Accessibly (Priority: P2)

A keyboard, pointer, or assistive-technology user can understand a notification,
reach its optional action and close control, activate either once, and continue
working without losing the current input focus unexpectedly.

**Why this priority**: Floating presentation must not trade a cleaner layout for
unreachable actions, repeated announcements, or focus disruption.

**Independent Test**: Operate every notification variant using keyboard-only
navigation, supported screen-reading features, Reduce Motion, Reduce
Transparency, Increase Contrast, and pointer interaction.

**Acceptance Scenarios**:

1. **Given** a meaningful notification appears, **When** assistive technology is
   active, **Then** its action and outcome are announced once without moving
   keyboard focus away from the user's current control.
2. **Given** a notification has a close control or action,
   **When** the user navigates by keyboard, **Then** each visible control has a
   meaningful label, visible focus state, and deterministic activation order.
3. **Given** a notification does not expose interactive controls,
   **When** keyboard navigation continues, **Then** the notification does not
   add an empty or redundant focus stop.
4. **Given** a notification is closed, expires, or is replaced,
   **When** focus was elsewhere in the workflow, **Then** that workflow focus
   remains stable.
5. **Given** Reduce Motion is enabled, **When** notifications appear, reorder,
   update, or disappear, **Then** the state change remains understandable
   without spatial movement.
6. **Given** Reduce Transparency or Increase Contrast is enabled,
   **When** a notification appears over any supported content,
   **Then** its text, icon, controls, border, and focus treatment remain
   legible.
7. **Given** a persistent failure exposes a recovery action,
   **When** the user activates it, **Then** the relevant field, item, detail, or
   retry workflow becomes available without the notification hiding the
   underlying failure evidence.
8. **Given** a delivery outcome is unknown,
   **When** its notification is presented or dismissed, **Then** the wording
   continues to state uncertainty and no notification action silently retries
   or reclassifies it as submitted.

---

### User Story 5 - Scan Batch Rows With Near-Full Dividers (Priority: P2)

A user viewing multiple selected books can follow each row across the batch card
because the separator between adjacent books extends across almost the entire
usable row width rather than appearing only beneath the trailing status area.

**Why this priority**: The current short divider weakens row grouping and makes
the filename, status, and removal control look visually disconnected.

**Independent Test**: Display batches containing short and long names, status
changes, expanded details, and enough items to scroll, then measure each
inter-row divider within the batch card.

**Acceptance Scenarios**:

1. **Given** two or more books are visible in the batch card,
   **When** the list is displayed, **Then** every divider between adjacent
   books spans at least 90% of the usable row width with balanced outer insets.
2. **Given** the last book in the list, **When** the card is displayed,
   **Then** no unnecessary divider is shown below the final row.
3. **Given** a row contains an expanded detail disclosure,
   **When** the detail opens or closes, **Then** the divider remains associated
   with the complete book row and does not cut through the disclosed content.
4. **Given** the list scrolls or the window resizes,
   **When** rows are reused or reflowed, **Then** divider width and alignment
   remain consistent without crossing the card boundary.
5. **Given** Increase Contrast is enabled,
   **When** the batch card is visible, **Then** dividers remain perceivable but
   do not become more prominent than book names or statuses.

### Edge Cases

- A temporary notification is replaced just before its timer completes.
- An older timer completes after a replacement notification has appeared.
- A notification is dismissed while its action is executing.
- An action publishes a new outcome synchronously while its original
  notification is being closed.
- Equivalent feedback arrives from the same scope many times in a short period.
- Three persistent notifications occupy all visible slots while temporary
  acknowledgements continue to arrive.
- A queued temporary notification becomes obsolete before it is displayed.
- The user closes the window that owns visible or queued notifications.
- The main and Settings windows display independent notifications at the same
  time.
- The application resigns activity before a temporary notification expires.
- A sheet or alert opens while the notification stack is visible.
- The window is resized to its supported minimum while three multi-line
  notifications are visible.
- A long localized accessibility description exceeds the visual message length.
- A notification has a close control but no action, an action but no close
  control, both controls, or neither control.
- A requested duration is missing, zero, negative, not finite, or greater than
  the allowed temporary maximum.
- A persistent notification without a close control loses its intended
  state-driven resolution source.
- A recovery action targets content that is currently on another local tab.
- A batch row has a very long filename, a trailing removal control, and expanded
  diagnostic details.
- Only one batch row is present, so no divider is needed.

## Requirements _(mandatory)_

### Functional Requirements

#### Shared Floating Presentation

- **FR-001**: The product MUST provide one reusable floating-notification
  behavior shared by onboarding delivery setup, saved delivery settings,
  shortcut settings, send actions, history actions, diagnostic-copy
  acknowledgements, and application-level action feedback.
- **FR-002**: Supported action feedback MUST appear as an overlay within the
  active owning window and MUST NOT participate in the content's layout
  measurement or reserve space after removal.
- **FR-003**: Each owning window MUST anchor its notification stack near the
  upper trailing content edge below the window toolbar and outside the central
  reading or editing path.
- **FR-004**: Notifications MUST remain inside visible window bounds at every
  supported window size and MUST NOT cover standard window controls, toolbar
  controls, or modal actions.
- **FR-005**: Main-window feedback MUST NOT appear in the Settings window, and
  Settings feedback MUST NOT appear in the main window.
- **FR-006**: A modal alert or sheet MUST remain above notifications in visual,
  keyboard, and pointer priority.
- **FR-007**: Appearing, updating, reordering, closing, and expiring a
  notification MUST NOT change the position or size of the underlying workflow
  content.

#### Notification Content and Configuration

- **FR-008**: Every notification MUST have a stable identity, owning scope,
  semantic state, and concise user-facing message.
- **FR-009**: A notification MUST support an optional concise title and optional
  supporting message without requiring both.
- **FR-010**: A notification MUST support either a caller-selected icon, a
  semantic-state icon, or no icon.
- **FR-011**: Icons MUST supplement rather than replace textual meaning, and
  notification meaning MUST NOT depend on color alone.
- **FR-012**: A notification MUST support an independently configured close
  control that can be shown or hidden.
- **FR-013**: A notification MUST support at most one action button with an
  originating-workflow-defined English label and one declared outcome.
- **FR-014**: Activating a notification action MUST execute the declared outcome
  at most once for that activation and MUST NOT trigger an unrelated workflow.
- **FR-015**: Closing a notification MUST affect only its presentation and MUST
  NOT cancel work, delete durable data, clear a batch, retry delivery, or change
  a domain outcome unless the close control is explicitly the named action for
  that behavior.
- **FR-016**: A persistent notification whose close control is hidden MUST have
  either an available action or a defined state transition that replaces or
  removes it.
- **FR-017**: When a notification action is the only route to required recovery
  or resolution, the notification MUST be persistent; a temporary notification
  MAY contain only a nonessential action whose expiry does not remove a required
  recovery path.
- **FR-018**: Message wrapping MUST preserve essential meaning without allowing
  a notification to extend into the central workflow at the minimum supported
  window size.
- **FR-019**: Long nonessential supporting text MUST be abbreviated in the
  notification and, when needed, exposed through a contextual details action
  rather than expanding the floating card indefinitely.

#### Lifetime and Dismissal

- **FR-020**: A notification MUST declare either a temporary or persistent
  lifetime.
- **FR-021**: Temporary notifications MUST accept a configurable visible
  duration from one through five seconds.
- **FR-022**: Temporary notifications without an explicit duration MUST use a
  default visible duration of approximately four seconds.
- **FR-023**: Successful and informational acknowledgements MUST be temporary,
  including when they contain a nonessential action.
- **FR-024**: No successful or informational notification MAY remain visible
  more than five seconds after it becomes visible.
- **FR-025**: Active, blocked, failed, cancelled, partial, and
  delivery-unknown notifications MUST remain until replaced, resolved, or
  deliberately dismissed according to their declared policy.
- **FR-026**: Temporary lifetime measurement MUST begin when the notification
  becomes visible, not while it is waiting for a visible stack position.
- **FR-027**: Expiry work for an older notification MUST NOT remove or shorten
  the lifetime of a newer replacement.
- **FR-028**: Temporary notifications whose lifetime ends while the application
  is inactive MUST be absent when the application is reactivated.
- **FR-029**: Invalid temporary durations MUST resolve to a safe permitted
  duration and MUST NOT create an immediately disappearing, indefinitely
  visible, or constitutionally overlong acknowledgement.

#### Stacking, Replacement, and Scope

- **FR-030**: A window MUST display no more than three notification cards at the
  same time.
- **FR-031**: Visible notifications MUST form one non-overlapping vertical stack
  with the newest visible result closest to the anchor.
- **FR-032**: Additional relevant notifications MUST wait for a visible
  position rather than cover content, overlap another card, or evict a
  persistent actionable notification.
- **FR-033**: A queued notification that is replaced, resolved, or obsolete
  before display MUST NOT later appear as stale feedback.
- **FR-034**: Equivalent repeated feedback for the same scope, action, state,
  title, message, and failure MUST update the existing lifecycle instead of
  creating a duplicate card.
- **FR-035**: Repeated equivalent feedback MAY show an occurrence count when it
  helps communicate that the action happened more than once.
- **FR-036**: A state transition for the same action MUST update or replace its
  existing notification without leaving the older state visible.
- **FR-037**: Dismissing, expiring, or replacing one notification MUST NOT
  change another notification's content, timer, action, or dismissal policy.
- **FR-038**: Closing an owning window MUST remove that window's temporary
  presentation and cancel pending presentation work without changing durable
  application outcomes.

#### Feedback Migration and Durable Context

- **FR-039**: Existing standalone inline action-feedback presentations MUST be
  removed from the middle of delivery setup, shortcut settings, send, history,
  and expanded diagnostic layouts once their equivalent floating notification
  coverage exists.
- **FR-040**: Field validation MUST remain adjacent to the affected field and
  MUST NOT be replaced solely by a floating notification.
- **FR-041**: Active preparation and delivery progress, batch aggregate state,
  per-book state, delivery-unknown guidance, and screen loading, empty, or
  unavailable states MUST remain in their workflow context.
- **FR-042**: Detailed failure evidence MUST remain available through contextual
  progressive disclosure and MUST NOT be compressed exclusively into a
  temporary notification.
- **FR-043**: A persistent failure notification that requires contextual
  evidence or recovery MUST provide an action that reveals or focuses the
  relevant durable content.
- **FR-044**: Confirmation sheets and alerts MUST remain explicit modal decisions
  and MUST NOT be replaced by notification action buttons.
- **FR-045**: Notification dismissal MUST NOT erase a per-book terminal result,
  hide delivery uncertainty, or alter send-history eligibility.
- **FR-046**: `Delivery Unknown` feedback and actions MUST preserve uncertainty,
  MUST NOT claim successful submission, and MUST NOT initiate automatic retry.
- **FR-047**: A successful action acknowledgement MUST be announced once when it
  becomes visible and MUST NOT be announced again solely because it expires.
- **FR-048**: A replacement notification MUST be announced only when its
  identity or semantic outcome independently warrants a new announcement.

#### Accessibility and Interaction

- **FR-049**: Notification appearance MUST NOT steal keyboard focus from the
  user's current control.
- **FR-050**: Every visible close control and action button MUST be keyboard
  reachable, have a meaningful English accessibility label, expose a visible
  focus state, and meet the product's normal pointer target expectations.
- **FR-051**: A notification without interactive controls MUST NOT introduce an
  empty keyboard focus stop.
- **FR-052**: Closing, expiring, or replacing a notification MUST preserve focus
  in the underlying workflow unless the user activated an action that
  intentionally moves focus.
- **FR-053**: Notifications MUST remain readable and operable with Reduce
  Motion, Reduce Transparency, and Increase Contrast enabled.
- **FR-054**: With Reduce Motion enabled, appearance, replacement, reorder, and
  dismissal MUST remain understandable without relying on movement.
- **FR-055**: Notification text, icon, close control, action, and semantic state
  MUST expose a coherent reading order to supported assistive technology.

#### Batch Row Dividers

- **FR-056**: Each divider between adjacent batch items MUST span at least 90%
  of the card's usable row width.
- **FR-057**: Divider leading and trailing insets MUST be visually balanced and
  consistent across every row.
- **FR-058**: No divider MUST appear below the final batch item.
- **FR-059**: A divider MUST separate complete book rows, including any expanded
  details, and MUST NOT pass through a book's disclosed content.
- **FR-060**: Dividers MUST retain their alignment during scrolling, window
  resizing, status changes, and row expansion.
- **FR-061**: Divider contrast MUST remain visible but subordinate to filenames,
  statuses, focus, warnings, and selection in normal and increased-contrast
  appearances.

### Notification Coverage

The shared floating system MUST cover at least these existing action-feedback
categories:

- delivery setup save, update, deletion, credential access, and setup-level
  action failure;
- shortcut registration, change, disable, clear, conflict, and registration
  failure;
- file intake acknowledgement or action failure;
- book addition, removal, and batch clear acknowledgements;
- preparation action summaries that are not the active per-book progress state;
- definitive delivery summary, cancellation summary, partial outcome, and
  action-level delivery failure or uncertainty;
- diagnostic copy success or failure;
- history clear success or failure and history-record persistence feedback;
- application-level action acknowledgement, including update-check feedback
  when that action produces an in-app result.

The catalogue MUST be verified against the application at planning and
implementation time. A newly discovered action acknowledgement MUST use the
shared system or be explicitly classified as durable contextual state.

### Constitution Constraints _(mandatory)_

- **CC-001**: The feature MUST retain exactly two primary screens,
  `Delivery Setup` and `Send Book`; floating notifications and their host MUST
  NOT become another screen, window, navigation destination, or Settings tab.
- **CC-002**: The feature MUST preserve the distinction between temporary
  successful or informational acknowledgement and persistent active,
  actionable, failed, cancelled, partial, or uncertain state.
- **CC-003**: Successful and informational acknowledgements MUST disappear
  automatically within five seconds.
- **CC-004**: Active work, blocked state, failure evidence, cancellation,
  partial outcome, and `Delivery Unknown` MUST remain available until changed or
  deliberately cleared.
- **CC-005**: The feature MUST keep advanced EPUB preparation in the background,
  preserve sequential batch behavior, preserve originals, and require explicit
  confirmation before SMTP transmission.
- **CC-006**: Notification actions MUST NOT bypass setup validation, delivery
  confirmation, retry safety, history eligibility, credential protection, or
  delivery-unknown acknowledgement.
- **CC-007**: The feature MUST NOT introduce remote notification transport,
  telemetry, cloud synchronization, notification history, analytics, a
  persistent queue, or storage of book content, paths, credentials, provider
  replies, or diagnostic evidence.
- **CC-008**: The feature MUST preserve bounded local send-history behavior and
  MUST NOT treat a notification as evidence of Kindle receipt or processing.
- **CC-009**: Feedback classification and lifecycle rules MUST remain outside
  individual screen-specific presentation so every supported scope follows the
  same replacement, timing, and persistence contract.
- **CC-010**: The feature MUST remain visually calm, keyboard accessible, and
  legible with system accessibility appearance settings.

### Key Entities

- **Floating Notification**: One concise action outcome presented above content,
  identified by its owning window, scope, action, semantic state, and lifecycle
  identity.
- **Notification Content**: The optional title, supporting message, chosen or
  derived icon, occurrence count, close-control visibility, and optional action
  label displayed by one notification.
- **Notification Lifetime**: A temporary duration from one through five seconds
  or a persistent policy that ends only through replacement, resolution, or
  deliberate dismissal.
- **Notification Action**: At most one named user choice attached to a
  notification, with a caller-declared outcome that runs once per activation.
- **Notification Scope**: The workflow context that owns replacement,
  deduplication, accessibility announcement, and dismissal behavior.
- **Notification Stack**: The ordered set of up to three currently visible
  notifications within one window plus any still-relevant waiting results.
- **Durable Contextual State**: Field validation, progress, per-book outcome,
  aggregate guidance, failure evidence, empty or unavailable state, or
  confirmation that remains in the workflow rather than becoming notification
  content.
- **Batch Item Divider**: The visual separator between two complete adjacent
  book rows inside the current-batch card.

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: In 100% of the catalogued setup, shortcut, intake, batch, delivery,
  diagnostic-copy, history, and application action-feedback cases, the feedback
  appears through the shared floating presentation and no equivalent standalone
  action banner remains inserted in the content.
- **SC-002**: Under the supported minimum window sizes, notification appearance,
  update, reorder, and removal cause zero measurable movement in the underlying
  form fields, drop target, batch card, history content, shortcut controls, or
  primary actions.
- **SC-003**: In 100% of temporary-notification timing checks, the notification
  remains for its configured permitted duration within normal scheduling
  tolerance, uses four seconds by default, and is absent by five seconds.
- **SC-004**: In 100% of covered active, blocked, failed, cancelled, partial, and
  delivery-unknown cases, the actionable outcome remains available after ten
  seconds or until the user deliberately resolves, replaces, or dismisses it.
- **SC-005**: A rapid sequence of 20 feedback events never displays more than
  three notification cards at once, never overlaps cards, never drops a
  persistent actionable result, and never presents an obsolete queued result.
- **SC-006**: Repeating the same feedback 20 times produces one visible
  notification identity with an accurate occurrence count or equivalent
  in-place update, not 20 stacked duplicates.
- **SC-007**: Every permitted combination of temporary or persistent lifetime,
  icon present or absent, close control shown or hidden, and action present or
  absent has a deterministic acceptance result, with zero required recovery
  paths lost to expiry and zero unreachable persistent notifications.
- **SC-008**: Keyboard-only and supported assistive-technology checks can
  identify, reach, and activate every visible notification control, while
  noninteractive notifications add no redundant focus stop and no notification
  steals the user's current focus.
- **SC-009**: Each meaningful notification is announced once; expiry produces
  zero extra announcements, and repeated unchanged state produces zero
  duplicate announcements.
- **SC-010**: At every supported window size, the visible notification stack
  remains within the owning window, below the toolbar, outside standard window
  controls, and does not obstruct modal actions or the main bottom action.
- **SC-011**: With Reduce Motion, Reduce Transparency, and Increase Contrast
  enabled, 100% of notification meanings, controls, focus states, and batch
  dividers remain perceivable and operable.
- **SC-012**: In batches from two through twenty visible or scrollable books,
  every inter-item divider spans at least 90% of usable card width, remains
  aligned through row expansion and resizing, and no divider appears after the
  final item.
- **SC-013**: Regression review confirms zero changes to field-level validation,
  active progress, per-book state, failure evidence, modal confirmation,
  original-file preservation, explicit delivery, delivery-unknown safety, or
  bounded send-history eligibility.
- **SC-014**: Acceptance review confirms the product still exposes exactly two
  primary screens and contains no notification center, notification history,
  remote notification service, analytics surface, queue, or new durable data.

## Assumptions

- "Sonner-style" describes the floating, stackable interaction pattern and does
  not require adding a third-party library, web runtime, remote service, or
  separate product dependency.
- The default location is the upper trailing area below the toolbar because it
  keeps notifications outside the central editing and reading path.
- "All visual feedback" means concise action-level feedback currently presented
  as standalone acknowledgements or action failures. Field validation, active
  progress, per-book status, durable failure evidence, confirmation, loading,
  unavailable, and empty states retain their contextual presentation.
- The default temporary duration remains four seconds to preserve Feature 009;
  per-notification customization is bounded from one through five seconds by the
  constitution.
- An action that is required for recovery makes its notification persistent. A
  temporary notification may offer only a nonessential action when the same
  required recovery or next step remains available in the workflow.
- At most one action button per notification is sufficient for this lightweight
  product; destructive or multi-choice decisions remain modal confirmations.
- A maximum of three visible cards per window provides enough concurrent
  feedback without covering the workflow.
- Notification configuration belongs to product call sites, not to a new
  end-user preferences screen.
- Existing send-history retention, privacy, and record-eligibility rules are
  unchanged.

## Out of Scope

- macOS Notification Center or notifications outside Book Sender windows;
- a notification inbox, archive, history, search, export, or activity log;
- user-configurable screen placement, themes, sounds, drag gestures, or
  notification retention;
- more than one action button per notification;
- replacing field validation, progress, per-book status, failure evidence,
  empty states, loading states, unavailable states, sheets, or alerts;
- storing notifications across relaunches or synchronizing them between
  windows, devices, or accounts;
- changing SMTP delivery, ebook preparation, send-history semantics,
  credentials, release behavior, or the two-primary-screen product boundary.
