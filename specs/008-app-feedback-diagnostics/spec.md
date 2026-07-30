# Feature Specification: App Feedback and Diagnostics

**Feature Branch**: `main`

**Created**: 2026-07-30

**Status**: Draft

**Input**: User description: "Improve visual feedback for every action across the
entire app and replace vague error output with more verbose, actionable,
privacy-safe diagnostics so real failures can be identified."

## User Scenarios & Testing _(mandatory)_

### User Story 1 - Know That Every Action Worked (Priority: P1)

A user performs an action anywhere in Book Sender and receives a clear,
proportionate acknowledgement, an honest in-progress state when work continues,
and a visible terminal result. Successful actions do not rely on a field
clearing, a screen reloading, or another indirect side effect to communicate
completion.

**Why this priority**: A user cannot trust setup, intake, preparation, delivery,
or recovery when the application changes state without explaining whether the
requested action succeeded.

**Independent Test**: Exercise launch restoration, initial setup save, saved
setup edit, app-password replacement, file intake, item removal, batch clearing,
confirmation, cancellation, shortcut changes, send, and failed-item retry, then
verify that every accepted action has a visible and accessible acknowledgement
and terminal result.

**Acceptance Scenarios**:

1. **Given** valid delivery details and a newly entered app password, **When** the
   user saves setup successfully, **Then** the application confirms that setup
   was saved and that the password was stored securely without displaying the
   password.
2. **Given** a successful setup edit that clears the password field for
   security, **When** the save finishes, **Then** the success confirmation makes
   it unambiguous that clearing the field was intentional and not data loss.
3. **Given** an accepted action that takes noticeable time, **When** processing
   begins, **Then** the relevant control or content area communicates the active
   action until it reaches a terminal result.
4. **Given** a successful remove, clear, cancel, shortcut, or retry action,
   **When** the visible content changes, **Then** the application also
   communicates what completed instead of relying only on the changed content.
5. **Given** an action is temporarily unavailable, **When** its unavailable
   reason is not evident from the surrounding state, **Then** the user can
   discover why and what must happen before the action becomes available.
6. **Given** an actionable control is available, focused, pressed, loading, or
   disabled, **When** the user interacts by pointer or keyboard, **Then** its
   visual and accessible state communicates the interaction without changing
   the action's meaning.

---

### User Story 2 - Understand Every Failure (Priority: P1)

A user who encounters a failure can understand what action failed, where it
failed, what was and was not completed, the most specific safe cause known to
the application, and the next useful recovery action.

**Why this priority**: Messages such as "could not be completed" or "provider
rejected this delivery" prevent the user and developer from separating setup,
credential, file, provider, and application defects.

**Independent Test**: Trigger one controlled failure from every supported
failure family and verify that each result identifies the affected action,
failure phase, safe cause category, impact, retry classification, recovery
action, and stable diagnostic identifier without revealing private values.

**Acceptance Scenarios**:

1. **Given** setup validation, protected-storage, preference-storage, intake,
   filesystem, archive, XML, audit, repair, shortcut, update, or delivery work
   fails, **When** the failure is presented, **Then** the message names the
   affected action and gives the most specific safe explanation available.
2. **Given** a known failure has a user recovery path, **When** its details are
   shown, **Then** the user sees one primary next step such as editing setup,
   choosing another file, reviewing the book, retrying a definitive failure, or
   checking an uncertain delivery.
3. **Given** a failure has additional technical evidence, **When** the user opens
   its details, **Then** the application shows a stable error identifier,
   subsystem, phase, retry classification, and sanitized context without
   replacing the concise default message.
4. **Given** an unexpected failure cannot be classified more specifically,
   **When** it is presented, **Then** it is explicitly identified as unexpected,
   receives a stable diagnostic reference, explains the operation's observed
   outcome, and offers a safe next step.
5. **Given** identical failures repeat during one operation, **When** feedback is
   updated, **Then** the application avoids stacking duplicate notices while
   preserving the occurrence count and latest relevant state.

---

### User Story 3 - Diagnose Delivery Rejections Safely (Priority: P1)

A user can distinguish connection, secure-channel, authentication, sender,
recipient, message-transfer, final-acceptance, timeout, cancellation, and
uncertain-delivery failures without seeing credentials or a raw provider
conversation.

**Why this priority**: Delivery is the only external side effect and the current
generic rejection message cannot reveal whether a new credential was accepted
or which later provider phase failed.

**Independent Test**: Exercise controlled delivery outcomes for every declared
phase, including provider authentication codes `534` and `535`, and verify that
the displayed and copied diagnostics identify the phase and safe provider code
while redacting addresses, credentials, message data, and raw replies.

**Acceptance Scenarios**:

1. **Given** the provider rejects authentication, **When** delivery fails,
   **Then** the message distinguishes an app-password or account-authentication
   problem from sender, recipient, and attachment problems and directs the user
   to edit setup.
2. **Given** the provider returns a safe numeric or enhanced status code,
   **When** delivery fails, **Then** the diagnostic details retain that code and
   the phase in which it was observed without displaying the raw provider reply.
3. **Given** the provider rejects the sender, recipient, message body, or final
   submission, **When** delivery terminates, **Then** each rejection is
   distinguishable and the user sees the recovery action appropriate to that
   phase.
4. **Given** connection loss or cancellation occurs after message data begins,
   **When** no definitive final response exists, **Then** the result remains
   `Delivery Unknown`, explains that the provider may have accepted the book,
   and never recommends an automatic retry.
5. **Given** delivery fails before message data begins, **When** the failure is
   definitive, **Then** the application identifies it as safe to retry only when
   retrying would not repeat a known setup problem.

---

### User Story 4 - Share Useful Diagnostics Without Sharing Private Data (Priority: P2)

A user can copy a compact diagnostic block for a current failure and provide it
for troubleshooting without first editing out credentials, email addresses,
book content, or private filesystem information.

**Why this priority**: More verbose diagnostics are useful only if they remain
safe to inspect, copy, and share.

**Independent Test**: Generate diagnostics from fixtures containing credential
canaries, personal addresses, Unicode filenames, private paths, provider reply
text, and book excerpts, then verify that the copied result remains actionable
and contains none of those protected values.

**Acceptance Scenarios**:

1. **Given** a visible current failure, **When** the user chooses `Copy Error
   Details`, **Then** the copied block includes the application version, action,
   subsystem, phase, stable code, safe status code when any, terminal
   classification, and recovery guidance.
2. **Given** diagnostic context contains private or untrusted values, **When**
   details are displayed, logged, or copied, **Then** credentials, full
   addresses, source paths, book excerpts, message bytes, and raw protocol
   transcripts are absent.
3. **Given** the user has multiple failed books, **When** one item's details are
   copied, **Then** the diagnostic block clearly identifies the selected item by
   a session-safe reference without exposing its full local path.
4. **Given** no current failure exists, **When** the user uses the application
   normally, **Then** this feature introduces no diagnostic-history screen,
   remote telemetry, or hidden upload; the separate bounded send history remains
   governed by Feature 009.
5. **Given** a startup or fatal failure ends the current session before details
   can be copied, **When** troubleshooting continues after restart, **Then** a
   bounded local diagnostic record remains available without creating an
   in-app diagnostic history.

---

### User Story 5 - Receive Calm and Accessible Feedback (Priority: P2)

A user receives richer feedback without the two-screen product becoming noisy,
modal, or dependent on color, animation, pointer use, or vision.

**Why this priority**: Verbosity must improve confidence and diagnosis without
turning a lightweight utility into a monitoring dashboard.

**Independent Test**: Complete success, failure, cancellation, partial-batch,
and delivery-unknown journeys using keyboard and the supported screen reader
with increased contrast, reduced transparency, and reduced motion enabled.

**Acceptance Scenarios**:

1. **Given** an action changes state, **When** feedback appears, **Then** its
   meaning is conveyed through text and semantics rather than color alone.
2. **Given** a screen reader is active, **When** an important in-progress or
   terminal state changes, **Then** the new state is announced once with the
   affected action or item and does not repeatedly interrupt the user.
3. **Given** a successful normal workflow, **When** technical evidence is not
   needed, **Then** the interface remains concise and keeps diagnostic details
   collapsed.
4. **Given** several batch items progress independently, **When** aggregate and
   per-item feedback update, **Then** the user can understand both overall
   progress and each terminal outcome without conflicting messages.

### Edge Cases

- An action completes so quickly that an in-progress indicator would flicker;
  the terminal acknowledgement must still be perceivable.
- Setup saves successfully while the password field is focused, and secure
  clearing occurs before the user sees the terminal state.
- A repeated save or send request arrives while the original request is still
  active.
- A success arrives at the same moment as cancellation or a timeout.
- A mixed batch contains successful, failed, cancelled, excluded, and
  delivery-unknown items at the same time.
- A user removes or clears the item whose error disclosure is currently open.
- A provider returns an unknown code, malformed reply, localized text, personal
  address, or echoed untrusted input.
- A file or book name contains a credential-like canary, control characters, or
  a full path.
- A failure occurs during initial launch restoration before the main workflow is
  ready.
- Shortcut registration or update checking fails while the primary workflow
  remains usable.
- A failure repeats rapidly and could otherwise produce notification spam.
- Diagnostic copying fails or clipboard access is unavailable.
- The application terminates before a current, non-persistent diagnostic can be
  copied.

## Requirements _(mandatory)_

### Functional Requirements

- **FR-001**: Every accepted user action MUST have an explicit lifecycle
  equivalent to acknowledged, in progress when applicable, and one terminal
  outcome.
- **FR-002**: A successful action MUST communicate what completed and MUST NOT
  rely solely on navigation, field clearing, control enablement, or content
  disappearance as proof of success.
- **FR-003**: Successful setup creation, setup editing, and app-password
  replacement MUST confirm that delivery setup was saved and that the password
  was stored securely without redisplaying the password.
- **FR-004**: Security-motivated clearing of a secret field MUST be accompanied
  by feedback that distinguishes intentional clearing from failed persistence.
- **FR-005**: Launch restoration, setup, Settings, shortcut configuration, file
  intake, preparation, batch editing, confirmation, sending, cancellation,
  retry, and existing in-app update interactions MUST follow the same feedback
  quality contract.
- **FR-006**: Work of noticeable duration MUST expose an honest in-progress
  state tied to the affected action or item and MUST NOT invent percentages or
  stages that are not observed.
- **FR-007**: Cancellation MUST communicate when the request is acknowledged,
  what stopped, what already completed, and whether any outcome remains
  uncertain.
- **FR-008**: Partial batch results MUST communicate aggregate progress and
  retain a separate terminal outcome for every item.
- **FR-009**: Remove, clear, confirmation dismissal, shortcut changes, and
  failed-item retry MUST provide terminal feedback proportionate to their
  consequence.
- **FR-010**: When an important action is unavailable for a non-obvious reason,
  the interface MUST expose a concise explanation and the condition required to
  make it available.
- **FR-011**: Success feedback MUST remain perceivable long enough to be
  understood and MUST not block the next valid action.
- **FR-012**: Feedback MUST avoid duplicate notices for the same unchanged state
  while preserving new failures and meaningful state transitions.
- **FR-013**: Every expected failure MUST retain a stable diagnostic identifier
  that does not depend on localized prose.
- **FR-014**: Every presented failure MUST identify the affected action or item,
  the most specific safe phase, the observed impact, and one primary recovery
  action when recovery is possible.
- **FR-015**: A known specific cause MUST NOT be replaced by a generic message
  such as "could not be completed" or "provider rejected this delivery."
- **FR-016**: Concise error summaries MUST remain readable by non-technical
  users, while additional technical evidence MUST be available through
  progressive disclosure.
- **FR-017**: Expanded error details MUST include the stable code, subsystem,
  phase, terminal classification, retry classification, and sanitized context
  needed to distinguish supported failure causes.
- **FR-018**: Unexpected failures MUST receive an explicit unexpected-failure
  classification, a stable diagnostic reference, the last known safe phase, the
  observed operation outcome, and a safe recovery suggestion.
- **FR-019**: Repeated identical failures in one active operation MUST be
  consolidated without losing their occurrence count or latest relevant state.
- **FR-020**: Delivery diagnostics MUST distinguish connection, secure-channel,
  authentication, sender, recipient, message-transfer, final-acceptance,
  timeout, cancellation, and uncertain-delivery phases.
- **FR-021**: Safe provider numeric and enhanced status codes MUST be retained
  with the delivery phase in which they were observed.
- **FR-022**: Provider codes that indicate credential or account authentication
  failure, including `534` and `535`, MUST produce authentication-specific
  guidance rather than a generic retry recommendation.
- **FR-023**: Delivery retry guidance MUST account for whether message data
  started and whether the failure is definitive, transient, setup-related, or
  uncertain.
- **FR-024**: Raw provider replies, protocol transcripts, message bytes, and
  credentials MUST NOT be displayed, logged, copied, or included in reports.
- **FR-025**: Every failed or uncertain operation MUST produce a structured,
  local diagnostic event containing timestamp, application version, action,
  subsystem, phase, stable code, severity, terminal classification, retry
  classification, and sanitized context when available.
- **FR-026**: A current failure MUST offer `Copy Error Details` when diagnostic
  evidence is available.
- **FR-027**: Copied error details MUST be compact, deterministic, human-readable,
  and sufficient to correlate the visible failure with its local diagnostic
  event.
- **FR-028**: Displayed, logged, and copied diagnostics MUST exclude passwords,
  credential material, complete email addresses, full source paths, book
  excerpts, message payloads, raw protocol transcripts, and unnecessary
  filenames.
- **FR-029**: Diagnostic context originating from files or remote providers MUST
  be treated as untrusted and MUST not alter interface structure or diagnostic
  formatting.
- **FR-030**: Diagnostic information MUST remain local unless the user explicitly
  copies it; the application MUST NOT add telemetry, remote reporting, hidden
  uploads, a diagnostic-history screen, or diagnostic evidence to the bounded
  send history.
- **FR-031**: Diagnostic detail for healthy and successful work MUST remain
  collapsed or absent during normal use.
- **FR-032**: Feedback status, severity, and actionability MUST remain
  understandable without color alone.
- **FR-033**: Important in-progress, success, failure, cancellation, partial, and
  uncertain states MUST expose meaningful accessible labels and announcements.
- **FR-034**: Accessibility announcements MUST identify the affected action or
  item, announce meaningful changes once, and avoid repeating unchanged states.
- **FR-035**: Feedback MUST remain legible and operable with supported increased
  contrast, reduced transparency, reduced motion, keyboard navigation, and
  enlarged text preferences.
- **FR-036**: Richer feedback MUST remain inline, in an existing confirmation or
  alert, or in progressive disclosure and MUST NOT create another primary
  screen.
- **FR-037**: Every supported action lifecycle, expected failure family,
  delivery phase, redaction rule, copyable diagnostic field, recovery action,
  and accessibility announcement MUST have focused acceptance evidence.
- **FR-038**: Existing successful behavior, protected credential storage,
  original-file immutability, sequential batch isolation, explicit delivery
  confirmation, and honest `Delivery Unknown` semantics MUST remain unchanged.
- **FR-039**: Actionable controls MUST expose understandable default, pointer,
  keyboard-focus, pressed, disabled, and loading states while preserving a
  visible focus indicator.
- **FR-040**: Failed and uncertain operations, including startup and fatal
  failures, MUST leave bounded privacy-safe local diagnostic evidence available
  after restart through the platform's normal troubleshooting facilities,
  without creating a custom log archive or in-app diagnostic history.

### Constitution Constraints _(mandatory)_

- **CC-001**: Feature MUST remain within `Delivery Setup` and `Send Book`; native
  Settings, confirmations, alerts, progress, and inline disclosure MUST NOT
  become additional primary screens.
- **CC-002**: Feature MUST keep advanced EPUB safety, audit, deterministic
  cleanup/restoration, separate-copy writing, and revalidation in the
  background.
- **CC-003**: Feature MUST keep normal successful feedback concise and reveal
  detailed evidence only when it supports an action, failure, recovery, or
  decision.
- **CC-004**: Feature MUST preserve stable sequential batch processing, isolate
  outcomes per book, retain completed work, and keep cancellation cooperative.
- **CC-005**: Feature MUST keep processing and diagnostics local, preserve
  originals and existing files, and require explicit confirmation before SMTP
  transmission.
- **CC-006**: Feature MUST derive feedback and diagnostics from typed evidence;
  raw adapter exceptions and presentation-owned domain rules are prohibited.
- **CC-007**: Feature MUST NOT introduce external ebook engines, helper
  processes, conversion, DRM removal, library, persistent queue, unbounded or
  remote history, diagnostic-history UI, history-driven sending, cloud, account,
  AI, analytics, or a parallel product surface.
- **CC-008**: Feature MUST keep credentials in protected storage and MUST redact
  credentials, book excerpts, full paths, personal addresses, and unnecessary
  filenames from every diagnostic surface.

### Key Entities

- **Action Feedback**: The user-visible lifecycle of one accepted action,
  including acknowledgement, optional active state, terminal outcome, concise
  message, and available recovery action.
- **Diagnostic Event**: One local, structured record of a failed or uncertain
  operation with stable identity, timing, subsystem, phase, classification, and
  sanitized context.
- **Failure Detail**: The progressive-disclosure content that connects a concise
  user explanation to stable technical evidence and recovery guidance.
- **Operation Outcome**: The terminal classification of an action or item as
  successful, failed, cancelled, partial, or uncertain.
- **Delivery Diagnostic**: A delivery-specific failure detail that retains the
  safe provider status code, observed delivery phase, transmission boundary,
  and retry classification.
- **Diagnostic Copy**: The deterministic, privacy-safe text produced only when
  the user explicitly copies the current error details.

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: 100% of supported user actions in launch restoration, setup,
  Settings, shortcut configuration, intake, preparation, batch editing,
  confirmation, delivery, cancellation, retry, and existing update interactions
  expose an acknowledged or active state and one terminal result.
- **SC-002**: In 100% of setup-save acceptance scenarios, users can determine
  within two seconds whether setup and a replacement app password were saved
  successfully without inferring from an empty password field.
- **SC-003**: 100% of expected failure fixtures present the affected action,
  safe phase, specific cause category, stable diagnostic identifier, observed
  impact, and appropriate next step.
- **SC-004**: In controlled SMTP failures, users can distinguish every declared
  delivery phase and identify safe provider codes `534` and `535` within
  30 seconds without accessing credentials or raw transcripts.
- **SC-005**: 100% of copied diagnostic fixtures contain the required diagnostic
  fields and zero credential canaries, complete email addresses, full source
  paths, book excerpts, message bytes, or raw provider replies.
- **SC-006**: Success, failure, cancellation, partial completion, and uncertain
  delivery remain distinguishable in all covered visual and screen-reader
  scenarios without relying on color alone.
- **SC-007**: Important state changes are announced once in all covered
  screen-reader scenarios, with zero repeated announcements for unchanged
  states.
- **SC-008**: A mixed 20-item batch preserves one understandable outcome per
  attempted item and one non-conflicting aggregate result while duplicate
  notices remain consolidated.
- **SC-009**: The completed delivery adds no primary screen, unbounded or remote
  history, diagnostic-history UI, telemetry, hidden upload, credential exposure,
  raw transcript exposure, or regression in the existing privacy and
  original-preservation acceptance suite.
- **SC-010**: During moderated acceptance, users correctly identify whether a
  controlled failure requires editing setup, choosing another file, reviewing a
  book, retrying, or checking Kindle in at least 9 of 10 scenarios without
  developer assistance.
- **SC-011**: 100% of actionable controls in the two primary screens, existing
  Settings, and confirmations expose understandable focus, pressed, disabled,
  and loading states in pointer, keyboard, and accessibility acceptance.
- **SC-012**: 100% of controlled startup and fatal failures can be correlated
  after restart with a sanitized local diagnostic record containing no protected
  fixture value.

## Assumptions

- This feature improves the presentation and diagnostic evidence of existing
  operations; it does not add a new product workflow or change preparation and
  delivery semantics.
- "Across the entire app" includes launch restoration, both primary screens, the
  two existing Settings tabs, confirmations, file intake, book preparation,
  delivery, retry, cancellation, shortcut behavior, and existing in-app update
  interactions.
- Installer, release automation, continuous-integration output, and hosted
  publication diagnostics remain outside this in-app delivery.
- "Logs" means privacy-safe local diagnostic events retained only through
  bounded platform troubleshooting facilities plus explicitly copyable details
  for the current failure, not a custom persistent diagnostic history or remote
  observability service.
- Current typed findings, failures, progress, and terminal outcomes remain the
  source of truth and may be expanded with safe structured context.
- Raw exceptions and untrusted provider text remain internal boundaries and are
  never shown directly merely to increase verbosity.
- A normal system-picker dismissal is not an error and needs no warning.
- Successful common paths remain visually calm; technical details are primarily
  for failures, blocked work, partial results, and uncertain outcomes.
- Authenticated provider acceptance remains a separate runtime validation gate
  and must use user-controlled credentials without recording private
  transcripts.
