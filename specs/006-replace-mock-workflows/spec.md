# Feature Specification: Replace Mock Workflows

**Feature Branch**: `main`

**Created**: 2026-07-29

**Status**: Draft

**Input**: User description: "Replace all mocked behavior with the proposed real functionality and remove the mock navigation button."

## User Scenarios & Testing _(mandatory)_

### User Story 1 - Complete Real Delivery Setup (Priority: P1)

A first-time user enters valid delivery details, saves them securely, and reaches
`Send Book` only after the setup is genuinely valid and retained for later
sessions. Invalid or incomplete setup remains on `Delivery Setup` with actionable
field feedback.

**Why this priority**: Every real preparation and delivery journey depends on a
valid, durable delivery configuration. A preview route would bypass the product's
required safety boundary.

**Independent Test**: Launch with no saved setup, verify that no preview or demo
navigation is available, attempt an invalid save, then save valid details and
confirm that a later launch opens `Send Book` without exposing the credential.

**Acceptance Scenarios**:

1. **Given** no saved delivery setup, **When** the application opens, **Then**
   only `Delivery Setup` is available and no preview, demo, or bypass control is
   shown.
2. **Given** missing or invalid delivery values, **When** the user selects
   `Save Setup`, **Then** the relevant fields explain the problem and the user
   remains on `Delivery Setup`.
3. **Given** valid delivery values, **When** the setup is saved successfully,
   **Then** the application opens `Send Book`, retains the non-secret values for
   future sessions, and protects the credential from later display.

---

### User Story 2 - Prepare and Send Real Books (Priority: P1)

A returning user adds EPUB and PDF books, waits for genuine local eligibility
results, confirms the stable eligible batch and destination, and receives the
real outcome of each independent delivery attempt.

**Why this priority**: This is the product's core value. A ready label, send
button, or terminal message must represent completed work rather than a simulated
result.

**Independent Test**: With valid setup, add one healthy EPUB and one valid PDF
through the supported intake paths, confirm their real readiness, approve the
destination and counts, and verify that both receive independent terminal
delivery outcomes without any placeholder-unavailable message.

**Acceptance Scenarios**:

1. **Given** valid saved setup, **When** supported books are added through drag
   and drop or the file chooser, **Then** both paths create the same real batch
   items and begin actual eligibility work.
2. **Given** a valid PDF, **When** intake completes, **Then** it becomes eligible
   without conversion or modification of the selected original.
3. **Given** a supported EPUB, **When** preparation completes, **Then** it becomes
   eligible only after local safety checks, structural audit, deterministic
   preparation when required, separate-copy writing, and successful
   revalidation.
4. **Given** one or more eligible books, **When** the user confirms the displayed
   destination and stable batch counts, **Then** each eligible book receives a
   real independent delivery attempt and an honest terminal outcome.

---

### User Story 3 - Recover a Mixed Batch (Priority: P2)

A user can understand and recover from unsupported books, unsafe books,
preparation failures, network failures, cancellation, and uncertain delivery
without losing completed work or affecting unrelated items.

**Why this priority**: Real local files and delivery providers fail in different
ways. The batch remains trustworthy only when those failures are isolated and
recoverable.

**Independent Test**: Add a mixed batch containing eligible, duplicate,
unsupported, unsafe, and repairable books; cancel during active work; then retry
only definitively failed items and verify that completed and uncertain outcomes
are preserved.

**Acceptance Scenarios**:

1. **Given** a mixed batch, **When** eligibility work completes, **Then** each item
   shows a real concise state and only actionable blocked or failed items reveal
   supporting detail.
2. **Given** one item fails preparation or delivery, **When** later eligible items
   remain, **Then** the failure does not prevent their independent processing.
3. **Given** an active batch, **When** the user cancels, **Then** pending work
   stops, active work is interrupted where safe, completed outcomes remain, and a
   delivery already handed to the provider may become `Delivery Unknown`.
4. **Given** a completed batch with failed and delivery-unknown items, **When**
   retry is offered, **Then** only definitively failed items are eligible for an
   explicit retry and uncertain items are never retried automatically.

---

### User Story 4 - Edit Settings and Use the Shortcut (Priority: P3)

A returning user edits saved delivery values or configures the global shortcut
from the auxiliary Settings window. The shortcut reveals the existing primary
window and routes according to real setup state without initiating work.

**Why this priority**: These supporting capabilities make repeated use efficient
while preserving the two-screen product boundary.

**Independent Test**: Edit non-secret delivery values while preserving the
existing credential, configure and disable the shortcut, and verify that accepted
shortcut invocation focuses the one existing primary window without changing or
sending the current batch.

**Acceptance Scenarios**:

1. **Given** saved setup, **When** the user changes non-secret delivery values
   without entering a replacement credential, **Then** the existing credential
   remains valid and the updated values are used after successful validation.
2. **Given** a configured shortcut, **When** it is invoked while the application
   is active, **Then** the existing primary window is revealed on `Send Book` for
   complete setup or `Delivery Setup` for incomplete setup.
3. **Given** a shortcut conflict or disabled shortcut, **When** the preference is
   saved, **Then** the conflict or disabled state is explained and normal
   application use remains available.

### Edge Cases

- Setup persistence succeeds but protected credential storage fails, or the
  reverse; the application must not report setup as complete or retain an
  inconsistent usable configuration.
- A selected file changes, disappears, loses access, or is duplicated before
  preparation or after confirmation.
- A batch contains eligible, repairable, unsafe, unsupported, encrypted,
  duplicate, and malicious books.
- A repair plan becomes ambiguous or the written working copy fails
  revalidation.
- The user edits the delivery destination while books are selected or while a
  confirmed snapshot is active.
- Cancellation occurs before transmission, while book data is being transmitted,
  or after the provider accepted data without a definitive final response.
- The network disappears, authentication fails, the provider rejects a recipient
  or message, or the connection times out.
- The shortcut is invoked repeatedly while the window is closed, while setup is
  incomplete, or while preparation or delivery is active.

## Requirements _(mandatory)_

### Functional Requirements

- **FR-001**: The product MUST expose exactly two primary screens:
  `Delivery Setup` and `Send Book`.
- **FR-002**: The product MUST remove every preview, demo, and mock navigation
  control, including the setup-to-send preview and its return-to-setup control.
- **FR-003**: A user MUST reach `Send Book` from first-launch setup only after a
  valid setup has been saved successfully; no bypass path may simulate completed
  setup.
- **FR-004**: Setup MUST validate sender address, host, port, security mode,
  username, credential, and Kindle destination at the relevant field before it
  becomes usable.
- **FR-005**: Non-secret setup values MUST persist locally across launches, while
  credentials MUST remain only in traditional file-based macOS Keychain
  generic-password items and MUST never be displayed, written to files or
  preferences, logged, or included in reports after entry.
- **FR-006**: Normal launch and shortcut routing MUST derive from the actual
  completeness of saved setup rather than a preview or in-memory demonstration
  state.
- **FR-007**: Drag and drop and the file chooser MUST use one shared intake
  behavior for supported EPUB and PDF files.
- **FR-008**: Intake MUST use the selected files to create real batch items,
  detect duplicate references, reject unsupported inputs, and report file access
  or change failures without fabricated ready states.
- **FR-009**: PDF files MUST receive bounded eligibility checks and remain
  byte-for-byte unchanged.
- **FR-010**: EPUB files MUST be treated as untrusted and MUST complete local
  safety checks, structural audit, deterministic cleanup or restoration when
  supported, separate-copy writing, and revalidation before becoming eligible.
- **FR-011**: Automatic EPUB changes MUST be limited to unambiguous,
  evidence-backed actions that preserve intended content and can be verified
  after writing.
- **FR-012**: Ambiguous, unsafe, encrypted, unsupported, or unsuccessfully
  revalidated EPUB files MUST remain unchanged and MUST NOT become eligible.
- **FR-013**: Selected originals and pre-existing files MUST never be modified,
  overwritten, renamed, moved, or removed by preparation, cancellation, failure,
  retry, or delivery.
- **FR-014**: The send action MUST remain unavailable until setup is complete and
  at least one real batch item is eligible.
- **FR-015**: Before any transmission, the product MUST require explicit
  confirmation of the destination, eligible count, and excluded count.
- **FR-016**: Confirmation MUST capture a stable eligible snapshot so later batch
  changes cannot silently alter the approved delivery set.
- **FR-017**: Every confirmed eligible book MUST receive one real, independent,
  sequential SMTP delivery attempt using a secure connection; one item's outcome
  MUST NOT determine another's.
- **FR-018**: The product MUST support both implicit TLS and STARTTLS delivery and
  MUST refuse credential transmission over an unprotected connection.
- **FR-019**: Each attempted book MUST end with an honest `Submitted`, `Failed`,
  `Cancelled`, or `Delivery Unknown` result based on observed delivery progress;
  placeholder success, forced readiness, and protocol-unavailable mock messages
  are prohibited.
- **FR-020**: Cancellation MUST stop pending scheduling, cooperatively interrupt
  active work where safe, preserve completed outcomes, and distinguish definitive
  cancellation from uncertain delivery after message data begins.
- **FR-021**: Failed and delivery-unknown attempts MUST NOT retry automatically;
  the user MAY explicitly retry only definitively failed items.
- **FR-022**: After batch completion, the user MUST be able to remove individual
  items, clear the temporary batch, add more books, or explicitly retry failed
  items from `Send Book`.
- **FR-023**: Per-book feedback MUST reflect real work through concise states
  equivalent to `Checking`, `Preparing`, `Ready`, `Needs Attention`, `Sending`,
  and the terminal outcomes.
- **FR-024**: Detailed findings and applied actions MUST remain collapsed for
  healthy or successfully prepared books and MAY appear inline only when they
  explain a blocked item, failure, applied restoration, or user decision.
- **FR-025**: Progress MUST remain honest and MUST NOT use invented percentages or
  simulated delays.
- **FR-026**: The Settings window MUST contain only `Delivery` and `Shortcut`,
  with delivery edits using the same real validation, persistence, and credential
  preservation rules as first-launch setup.
- **FR-027**: The global shortcut MUST be configurable or disabled, MUST explain
  registration conflicts, and MUST reveal and focus the existing primary window
  without creating duplicate windows, changing the batch, or initiating delivery.
- **FR-028**: Expected setup, intake, preparation, filesystem, shortcut, and
  delivery failures MUST be presented as safe, actionable messages without raw
  exceptions, credentials, or source paths.
- **FR-029**: All fields, intake actions, batch actions, confirmation controls,
  statuses, Settings controls, and recovery actions MUST be keyboard accessible
  and meaningfully announced by the supported screen reader.
- **FR-030**: Book processing MUST remain local except for the explicitly
  confirmed SMTP transmission, and the product MUST collect no book content,
  filenames, source paths, credentials, analytics, or hidden usage data.
- **FR-031**: All preview-only data models, routes, conditions, accessibility
  identifiers, copy, tests, and documentation MUST be removed or replaced by
  acceptance coverage for the real behavior.
- **FR-032**: If an obsolete or inaccessible credential cannot be read, setup
  MUST preserve only non-secret draft values and request the password once
  without attempting an unsafe migration.
- **FR-033**: Every distributed app and nested executable MUST use the pinned
  self-signed release certificate, and the main app MUST retain the exact
  designated requirement anchored to it and `com.rckbrcls.BookSender`.
- **FR-034**: Missing or invalid signing secrets, certificate drift, designated
  requirement drift, ad-hoc signing, or invalid nested signatures MUST fail
  release before packaging with no fallback.
- **FR-035**: The installer MUST enforce the pinned certificate and designated
  requirement before replacing an installation; Sparkle EdDSA remains a
  separate required update signature.
- **FR-036**: The installer MUST verify the GitHub asset SHA-256 digest and
  pinned public DER certificate, then idempotently register only that public
  certificate in the user's default Keychain when absent and after explicit
  terminal confirmation; no private key or explicit trust override is
  permitted.
- **FR-037**: Publication MUST require a separate clean macOS runner with no
  private signing material to install the packaged candidate through the real
  bootstrap and pass strict signature plus launch validation.

### Constitution Constraints _(mandatory)_

- **CC-001**: The feature MUST remain within `Delivery Setup` and `Send Book`;
  dialogs, progress, system pickers, Settings, and inline disclosure MUST NOT
  become additional primary screens.
- **CC-002**: Advanced EPUB preparation MUST remain an automatic local background
  capability rather than user-facing navigation.
- **CC-003**: The default interface MUST expose concise derived states and reveal
  detailed evidence only when it supports an action, failure, restoration, or
  user decision.
- **CC-004**: A confirmed batch MUST remain stable and sequential, isolate
  outcomes per book, preserve completed work, and support cooperative
  cancellation.
- **CC-005**: Originals and existing files MUST remain immutable, credentials
  MUST remain protected only by the traditional macOS Keychain without a file
  or preference fallback, and SMTP transmission MUST require explicit
  confirmation.
- **CC-006**: Every automatic safety, audit, cleanup, restoration, revalidation,
  and delivery rule MUST have focused evidence-backed acceptance coverage.
- **CC-007**: The feature MUST NOT introduce conversion, DRM removal, an external
  ebook engine, helper processes, executable downloads, a library, history,
  persistent queue, cloud account, AI, browser automation, or a parallel product
  surface.
- **CC-008**: Distributed artifacts MUST use the stable pinned signing identity
  and exact designated requirement; ad-hoc signing is permitted only for
  non-distributed test hosts.

### Key Entities

- **Delivery Setup**: The validated non-secret delivery values, protected
  credential reference, and Kindle destination required before sending.
- **Current Batch**: The ordered temporary collection of selected books and their
  genuine eligibility, progress, and outcome states.
- **Confirmed Batch Snapshot**: The immutable set of eligible items and
  destination explicitly approved for one send operation.
- **Batch Item**: One selected EPUB or PDF with source identity, format,
  preparation state, eligibility, findings, and delivery outcome.
- **Health Finding**: Concrete evidence about one EPUB, including severity,
  repairability, location when applicable, action, and revalidation result.
- **Prepared Book**: An eligible original PDF or successfully revalidated EPUB
  working copy selected for possible delivery.
- **Delivery Attempt**: One independent transmission of one prepared book with
  progress and an observed terminal outcome.
- **Shortcut Preference**: The enabled or disabled global key combination and its
  current registration or conflict state.

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: Repository and interface acceptance review finds zero preview,
  demo, or mock navigation controls, states, identifiers, placeholder outcomes,
  simulated delays, or unavailable-protocol messages in production behavior.
- **SC-002**: At least 90% of first-time participants can save valid setup and
  reach a genuinely ready supported book in under three minutes without external
  documentation.
- **SC-003**: One hundred percent of tested transmissions begin only after
  explicit confirmation of the real destination and stable eligible batch.
- **SC-004**: A mixed batch of 20 supported, repairable, unsafe, unsupported,
  failed, and uncertain books produces exactly 20 independent outcomes without
  one item preventing later eligible items from being attempted.
- **SC-005**: One hundred percent of selected originals and pre-existing files
  remain byte-for-byte unchanged across success, repair, failure, cancellation,
  unsafe input, retry, and delivery-unknown acceptance cases.
- **SC-006**: Credential and privacy review reveals zero complete credentials,
  book contents, filenames, or source paths in preferences, interface state,
  errors, logs, reports, analytics, or hidden network requests.
- **SC-007**: At least 95% of normal launches make the correct primary screen
  interactive within two seconds on the supported reference environment.
- **SC-008**: At least 95% of accepted shortcut invocations reveal and focus the
  correct existing primary window within one second while the application is
  active.
- **SC-009**: All setup, intake, confirmation, progress, cancellation, recovery,
  retry, Settings, and shortcut journeys can be completed by keyboard and are
  announced meaningfully by the supported screen reader.
- **SC-010**: Acceptance review confirms exactly two primary screens and no mock
  route, third workflow surface, library, history, persistent queue, account,
  reader, editor, conversion, or automated website interaction.
- **SC-011**: A credential saved by the first corrected version remains readable
  after an N-to-N+1 update signed with the same pinned identity.

## Assumptions

- The target user has a supported Mac, local EPUB or PDF books, valid provider
  credentials, network access, and a Kindle personal-document address.
- The email provider and Amazon sender approval are configured outside the
  application.
- The temporary current batch is not a persistent queue or delivery history.
- A concise confirmation, system file picker, inline detail, result alert, or
  auxiliary Settings window does not count as another primary screen.
- Closing the primary window may leave the lightweight application active so the
  configured shortcut remains available; explicit quit ends shortcut
  availability.
- All application-facing strings remain in English.

## Dependencies

- A supported macOS environment and permission to read user-selected files.
- Working provider credentials and network access for explicit SMTP delivery.
- Continued provider and Amazon support for personal-document email delivery.
- The approved local EPUB preparation and application distribution constraints
  already defined by the product constitution.

## Out of Scope

- Conversion among ebook or document formats.
- DRM removal, decryption, destructive repair, or ambiguous content changes.
- Amazon login, browser automation, or automated upload to the Send to Kindle
  website.
- Persistent or scheduled queues, delivery history, library management, reading,
  editing, annotation, catalogs, or cloud synchronization.
- User accounts, remote backends, analytics, telemetry, AI, chat, or hidden
  content processing.
- Mobile, Windows, Linux, browser, command-line, launcher-extension, or parallel
  legacy product surfaces.
