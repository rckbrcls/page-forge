# Feature Specification: Lightweight macOS Book Sender

**Feature Branch**: `main` (no feature branch created)

**Created**: 2026-07-28

**Status**: Draft

**Input**: User description: "Replace the Raycast extension with a lightweight native macOS application centered on two screens: delivery setup and book sending, with a shortcut for quick access. Keep advanced ebook inspection, cleanup, restoration, and revalidation in a background pipeline with minimal feedback before explicit batch delivery."

## User Scenarios & Testing _(mandatory)_

### User Story 1 - Set Up and Send the First Book (Priority: P1)

As a first-time Kindle user, I want to enter my delivery settings and immediately send a local book so that I can complete the entire setup-to-delivery journey without learning a larger application.

**Why this priority**: The first successful delivery proves the complete product value and establishes the stored configuration needed by every later send.

**Independent Test**: Start with no saved delivery settings, complete the setup screen with valid values, select one or more supported books on the sending screen, confirm delivery, and verify clear per-book outcomes without opening any additional primary screen.

**Acceptance Scenarios**:

1. **Given** no complete delivery setup exists, **When** the user opens the application, **Then** the setup screen is shown with every required field, concise guidance, and one clear save action.
2. **Given** valid setup values, **When** the user saves them, **Then** the values are retained securely and the sending screen becomes the primary screen.
3. **Given** a complete setup and one or more eligible books, **When** the user confirms sending, **Then** every book is prepared as needed, delivered independently to the configured Kindle address, and receives a clear final result.
4. **Given** one or more invalid setup values, **When** the user attempts to save, **Then** the relevant fields identify what must be corrected and no credentials are exposed in the message.

---

### User Story 2 - Send One or More Books with Minimal Interaction (Priority: P1)

As a returning user, I want to drop one or more books or find them in Finder and send the batch from one calm screen so that repeated deliveries take only a few deliberate actions.

**Why this priority**: Fast repeated sending is the product's primary recurring use case.

**Independent Test**: Start with a valid saved setup, open directly to the sending screen, select a mixed batch of supported EPUB and PDF books by drag and drop or the Finder chooser, and complete the batch without visiting setup.

**Acceptance Scenarios**:

1. **Given** a complete saved setup, **When** the user opens the application, **Then** the sending screen is shown with a prominent drop area, a Finder selection action, and a send action.
2. **Given** no book is selected, **When** the sending screen is visible, **Then** the send action is unavailable and the screen clearly communicates how to select one or more books.
3. **Given** one or more EPUB or PDF books are dropped, **When** intake begins, **Then** every selected book appears in a compact batch list with only its name, type, and concise derived state while advanced preparation continues in the background.
4. **Given** at least one eligible book is selected, **When** the user invokes the send action, **Then** the application requests one explicit batch confirmation that identifies the destination, eligible count, and excluded items before transmitting any book.
5. **Given** a mixed batch contains eligible and ineligible books, **When** the user confirms sending, **Then** eligible books are attempted sequentially, ineligible books remain unsent with clear reasons, and one item's failure does not prevent later eligible items from being attempted.
6. **Given** batch delivery finishes, **When** the final results appear, **Then** every book has an individual outcome and the user can retry only failed items or clear the batch from the same screen.

---

### User Story 3 - Open the Sender with a Global Shortcut (Priority: P2)

As a frequent user, I want a configurable system-wide keyboard shortcut to reveal the sending screen so that I can begin a delivery without searching for the application.

**Why this priority**: Quick invocation distinguishes the lightweight desktop experience while remaining secondary to reliable setup and delivery.

**Independent Test**: Keep the configured application active in the background, switch to another application, invoke the configured shortcut, and verify that the sending screen becomes visible, active, and ready for intake.

**Acceptance Scenarios**:

1. **Given** the application is active in the background and setup is complete, **When** the user invokes the configured shortcut from another application, **Then** the application comes to the foreground and focuses the sending screen.
2. **Given** setup is incomplete, **When** the shortcut is invoked, **Then** the application comes to the foreground and shows the setup screen instead of an unusable sending screen.
3. **Given** the sending screen is already visible, **When** the shortcut is invoked, **Then** the existing window becomes active without creating a duplicate window or resetting the current batch.
4. **Given** the user changes or disables the shortcut, **When** the new preference is saved, **Then** the previous shortcut no longer triggers the application.

---

### User Story 4 - Recover from Setup, Book, and Delivery Problems (Priority: P2)

As a Kindle user, I want failures to be concise and recoverable so that a malformed book, rejected connection, or interrupted delivery does not require me to restart the application or risk the original file.

**Why this priority**: The two-screen design remains trustworthy only if error recovery happens in context and does not expand into a separate workflow.

**Independent Test**: Exercise invalid settings, a mixed supported and unsupported batch, a repairable EPUB, an unsafe EPUB, a provider rejection, and a cancelled batch; verify that every item remains on one of the two primary screens and offers an appropriate next action.

**Acceptance Scenarios**:

1. **Given** an unsupported, unreadable, or unsafe file within a batch, **When** intake or preparation completes, **Then** the sending screen explains why that item cannot be sent without discarding or blocking other eligible items.
2. **Given** an EPUB with only deterministic repairable faults, **When** background preparation completes, **Then** a separate cleaned or restored and revalidated working copy becomes ready while the original remains unchanged and technical details stay collapsed by default.
3. **Given** saved delivery settings no longer work, **When** delivery fails, **Then** the sending screen presents a sanitized failure and a direct action to open the Settings window's `Delivery` tab.
4. **Given** batch delivery is cancelled, **When** cancellation takes effect, **Then** pending books are not scheduled, the active attempt is interrupted when safe, completed outcomes are preserved, and every original remains unchanged.
5. **Given** one delivery is interrupted after transmission may have begun, **When** the outcome cannot be confirmed, **Then** that item states that delivery is unknown, is not retried automatically, and later pending items remain cancelled unless the user explicitly starts them.

### Edge Cases

- The user adds the same file more than once, adds files through multiple intake methods, or adds another group while preparation is active.
- A mixed batch contains supported, unsupported, unreadable, unsafe, and duplicate items.
- The user drops a folder, alias, remote placeholder, unsupported extension, empty file, unreadable file, or file that changes during processing.
- One book in a batch exceeds the configured provider's attachment limit or the application's documented safe-processing limits.
- The selected EPUB is malformed, encrypted, protected by DRM, ambiguous to repair, malicious, or becomes invalid after a repair attempt.
- A corrected working filename collides with an existing file; no existing file is overwritten.
- The user edits setup while a batch is selected; the current batch remains intact unless the changed destination makes an item ineligible.
- The global shortcut conflicts with another application or cannot be registered; the application explains the conflict and remains usable through normal launching.
- The application is invoked repeatedly while a send is in progress; the existing operation and window remain singular.
- The network disappears, SMTP rejects authentication, the destination is rejected, or the provider accepts message data without returning a definitive final response.
- The window is closed while the application remains active for shortcut access; reopening restores the correct primary screen without exposing credentials.

## Requirements _(mandatory)_

### Functional Requirements

- **FR-001**: The product MUST be a self-contained macOS application and MUST NOT require Raycast to install, open, configure, or send a book.
- **FR-002**: The product MUST expose exactly two primary screens: `Delivery Setup` and `Send Book`.
- **FR-003**: First launch MUST show `Delivery Setup` until all required delivery values have been saved successfully.
- **FR-004**: `Delivery Setup` MUST include sender address, SMTP host, SMTP port, security mode, username, app password, and Kindle address.
- **FR-005**: Setup validation MUST identify missing or invalid values at the relevant field before the configuration can be used for delivery.
- **FR-006**: The app password and equivalent secrets MUST be stored in protected local credential storage and MUST never appear in plain text after entry, logs, reports, or user-visible errors.
- **FR-007**: Saved non-secret setup values MUST be available for later sessions and editable from the auxiliary Settings window's `Delivery` tab using the same validation and credential-preservation rules as initial `Delivery Setup`.
- **FR-008**: After setup is complete, normal launch MUST open `Send Book` as the primary screen.
- **FR-009**: `Send Book` MUST accept one or more local EPUB and PDF books through either drag and drop or a Finder file chooser.
- **FR-010**: Every intake path MUST apply the same eligibility, safety, and file-state checks.
- **FR-011**: The sending screen MUST show a compact current-batch list with each selected book's display name, format, and current readiness or failure state.
- **FR-012**: The send action MUST remain unavailable until setup is complete and at least one book in the current batch is eligible.
- **FR-013**: The user MUST explicitly confirm the destination, eligible book count, and excluded-item count before any network transmission begins.
- **FR-014**: PDF delivery MUST preserve the selected original without conversion or content modification.
- **FR-015**: EPUB intake MUST inspect the book locally before delivery and classify it as healthy, repairable, needs review, unsupported, or unsafe from concrete findings.
- **FR-016**: EPUB intake MUST automatically continue through bounded safety checking, structural audit, deterministic cleanup or restoration, separate-copy writing, and revalidation without requiring navigation or intermediate confirmation.
- **FR-017**: Only unambiguous, deterministic EPUB cleanup and restoration actions that preserve content meaning and can be verified after writing MAY be applied automatically.
- **FR-018**: An EPUB cleanup or restoration MUST use a separate collision-safe working copy, MUST never modify or overwrite the original, and MUST revalidate the written copy before it becomes eligible for delivery.
- **FR-019**: Ambiguous, destructive, encrypted, DRM-protected, or unsafe EPUBs MUST NOT be automatically changed or sent.
- **FR-020**: The user MUST be able to cancel the batch; cancellation MUST stop pending scheduling, cooperatively interrupt the active operation when safe, and preserve completed item outcomes.
- **FR-021**: Every selected book MUST end as submitted, failed, cancelled, delivery unknown, or excluded and MUST provide a concise next action appropriate to that outcome.
- **FR-022**: The application MUST NOT retry a failed or delivery-unknown transmission automatically.
- **FR-023**: After batch completion, the user MUST be able to retry only failed items, remove individual items, clear the batch, or add more books from the same sending screen.
- **FR-024**: The auxiliary Settings window's `Shortcut` tab MUST offer a configurable system-wide keyboard shortcut that reveals and activates the application's existing primary window while the application is active.
- **FR-025**: Shortcut invocation MUST open `Send Book` when setup is complete and `Delivery Setup` when setup is incomplete.
- **FR-026**: Shortcut invocation MUST NOT create duplicate primary windows, duplicate an active operation, clear a current selection, or initiate delivery.
- **FR-027**: Users MUST be able to change or disable the shortcut, and shortcut registration conflicts MUST be explained without preventing normal application use.
- **FR-028**: Closing the primary window MAY leave the application active for shortcut access, but MUST NOT continue preparation or transmission without a previously explicit user action.
- **FR-029**: All controls, fields, drop actions, status changes, confirmations, and recovery actions MUST be usable by keyboard and expose meaningful accessibility labels.
- **FR-030**: The application MUST process books locally except for the explicit user-confirmed SMTP transmission and MUST collect no analytics, book content, or hidden usage data.
- **FR-031**: The first release MUST NOT add a library, history screen, persistent or scheduled queue, account system, cloud sync, reader, editor, conversion, Amazon login automation, or automated Send to Kindle website interaction.
- **FR-032**: The final product and its documentation MUST remove Raycast as a runtime, installation, interaction, configuration, and distribution dependency.
- **FR-033**: Confirmation MUST capture a stable snapshot of the eligible batch; later additions or removals MUST NOT silently change an already confirmed batch.
- **FR-034**: The confirmed batch MUST be processed sequentially with at most one active EPUB preparation, archive entry operation, or delivery attempt at a time.
- **FR-035**: Each eligible book MUST be delivered through an independent attempt so one provider rejection or uncertain outcome does not determine another book's result.
- **FR-036**: Duplicate references to the same source file within the current batch MUST be identified and MUST NOT produce duplicate delivery attempts without a separate explicit user action.
- **FR-037**: A failure in one book MUST be isolated to that item and MUST NOT prevent later eligible items in the confirmed batch from being attempted unless the user cancels.
- **FR-038**: Default per-book feedback MUST use concise derived states equivalent to checking, preparing, ready, needs attention, sending, and a terminal result.
- **FR-039**: Healthy and successfully prepared books MUST NOT expose technical findings by default.
- **FR-040**: Detailed findings and applied actions MAY appear only through inline progressive disclosure when they explain a blocked item, a failure, an applied restoration, or a decision required from the user.
- **FR-041**: Progress MUST remain honest and MUST NOT display invented percentages when the current pipeline stage has no measurable completion fraction.
- **FR-042**: Background preparation MUST complete before an EPUB enters the stable eligible snapshot presented for delivery confirmation.
- **FR-043**: The primary window MUST use a system behind-window material across its content and titlebar areas, while custom Liquid Glass remains limited to important functional controls.

### Non-Functional Requirements

- **NFR-001 - Lightweight interaction**: The primary window MUST become ready for user interaction within two seconds for at least 95% of launches on a supported reference Mac under normal local load.
- **NFR-002 - Shortcut responsiveness**: When the application is active in the background, at least 95% of accepted shortcut invocations MUST reveal and focus the correct screen within one second.
- **NFR-003 - Interface responsiveness**: During supported preparation and delivery work, status and cancellation controls MUST remain responsive without visible stalls longer than one second.
- **NFR-004 - Credential privacy**: Acceptance testing and diagnostic review MUST expose zero complete credential values in interface states, errors, logs, or generated reports.
- **NFR-005 - Original preservation**: Across successful, failed, cancelled, unsafe, delivery-unknown, and mixed-batch acceptance cases, 100% of selected originals and pre-existing destination files MUST remain byte-for-byte unchanged.
- **NFR-006 - Batch capacity**: A batch of 20 supported books within individual safety limits MUST complete with 20 independent results and without failure caused solely by batch size.
- **NFR-007 - Untrusted input safety**: EPUB inspection and preparation MUST apply explicit limits for archive paths, entry count, expanded size, compression ratio, XML size and depth, duplicate entries, links, external entities, remote references, time, and memory before a file can be sent.
- **NFR-008 - Accessibility**: All primary journeys MUST be completable without a pointing device and remain understandable with the supported macOS screen reader.
- **NFR-009 - Adaptive appearance**: The complete interface MUST remain legible and operable in light and dark appearances, active and inactive window states, and with Reduce Transparency or Increase Contrast enabled.

### Constitution Constraints _(mandatory)_

- **CC-001**: The feature MUST retain only `Delivery Setup` and `Send Book` as primary screens. One auxiliary native Settings window MAY contain only `Delivery` and `Shortcut` tabs and MUST NOT contain intake, preparation, confirmation, delivery, queue, or history workflows.
- **CC-002**: EPUB safety checking, structural audit, deterministic cleanup or restoration, separate-copy writing, and revalidation MUST remain an automatic local background pipeline.
- **CC-003**: The default interface MUST expose concise derived states and reveal detailed evidence inline only when it supports an action, failure, applied restoration, or user decision.
- **CC-004**: The feature MUST process a stable batch sequentially, isolate outcomes per book, preserve completed work, and cooperatively cancel pending and active work.
- **CC-005**: Originals and existing files MUST remain immutable, credentials MUST use protected local storage, and SMTP transmission MUST require explicit confirmation.
- **CC-006**: Expected pipeline states and failures MUST be typed, domain rules MUST remain outside the interface, and every automatic cleanup or restoration rule MUST have focused fixture-backed tests.
- **CC-007**: The feature MUST NOT introduce Raycast, an external ebook engine, helper process, conversion, DRM removal, library, history, cloud, account, AI, third primary screen, or parallel product.
- **CC-008**: The app MUST target macOS 26.0 or later, use an adaptive system material for the complete window background, and reserve Liquid Glass for the functional control layer.

### Key Entities

- **Delivery Setup**: The locally retained sender identity, SMTP connection values, security mode, protected credential reference, and Kindle destination required for explicit delivery.
- **Shortcut Preference**: The user's enabled or disabled system-wide key combination and its latest registration state or conflict.
- **Current Batch**: The ordered, temporary collection of one or more selected books shown on the sending screen, including its stable confirmed snapshot and aggregate progress.
- **Batch Item**: One local EPUB or PDF in the current batch, including display identity, source state, format, eligibility, readiness, progress, and individual outcome.
- **Health Finding**: A concrete EPUB observation with a stable identifier, severity, explanation, location when applicable, and separate repairability state.
- **Prepared Book**: The eligible original PDF or the separate validated EPUB working copy chosen for possible delivery.
- **Delivery Attempt**: One independent transmission of one prepared book from a confirmed batch to the configured Kindle address, with progress and a submitted, failed, cancelled, or delivery-unknown terminal outcome.

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: In moderated first-use testing, at least 90% of participants can complete setup and reach a ready-to-send state in under three minutes without external documentation.
- **SC-002**: A returning user with valid setup can select multiple healthy supported books, confirm the batch, and begin sending in no more than four deliberate actions.
- **SC-003**: At least 95% of normal launches make the correct primary screen interactive within two seconds on the supported reference environment.
- **SC-004**: At least 95% of accepted global-shortcut invocations reveal and focus the correct primary screen within one second while the application is active.
- **SC-005**: Acceptance review finds exactly two primary screens and no library, persistent queue, history, account, reader, editor, or secondary workflow surface.
- **SC-006**: One hundred percent of tested sends require an explicit confirmation and no setup, intake, preparation, shortcut, or cancellation action transmits a book by itself.
- **SC-007**: One hundred percent of original books and pre-existing files remain byte-for-byte unchanged across healthy, repaired, failed, cancelled, unsafe, and delivery-unknown test cases.
- **SC-008**: One hundred percent of required setup fields, supported file outcomes, shortcut conflicts, and delivery terminal states produce a clear in-context explanation and an actionable recovery path.
- **SC-009**: Credential review across the interface, errors, logs, and reports reveals zero complete app passwords or equivalent secrets.
- **SC-010**: All setup, selection, confirmation, progress, cancellation, result, and shortcut-configuration journeys can be completed by keyboard and are announced meaningfully by the supported screen reader.
- **SC-011**: Repository and documentation review finds zero remaining instructions that require Raycast to install, configure, open, or use the final product.
- **SC-012**: A mixed batch of 20 supported, unsupported, repairable, unsafe, failed, and submitted books produces exactly 20 independent final results, and no single-item failure prevents a later eligible item from being attempted.
- **SC-013**: In default-state interface review, 100% of healthy and successfully prepared books show only a concise state and no expanded technical report, while 100% of blocked or failed items provide an actionable inline explanation.
- **SC-014**: Visual acceptance on macOS 26 confirms that the desktop remains visible through the complete window, all content remains readable across supported appearance and accessibility settings, and standard window controls and dragging remain functional.

## Assumptions

- The target user owns the selected books, has a Mac running macOS 26 or later, and has a Kindle personal-document address.
- `Delivery Setup` is configuration, not a remote account registration flow; the product has no user account or backend.
- The first release accepts a temporary batch of EPUB and PDF books but does not maintain a persistent queue or delivery history.
- The user obtains any provider-specific app password and approves the sender address through their email and Amazon settings outside the application.
- Implicit TLS and STARTTLS are the supported security choices; insecure unencrypted delivery is not offered.
- The global shortcut is configurable and may be disabled. It works while the application remains active; normal macOS launching is used after the application has fully quit.
- Closing the window keeps the lightweight application available in the background by default so the shortcut remains useful, while an explicit quit ends shortcut availability.
- EPUB inspection, cleanup, restoration, and revalidation remain internal background stages of the sending screen rather than separate user-facing screens.
- A concise confirmation, progress presentation, result alert, setup sheet reuse, or system file chooser does not count as an additional primary screen.
- All application-facing strings are in English.

## Dependencies

- macOS 26 or later and permission to read the selected local file.
- User-provided SMTP settings, working provider credentials, network access, and an Amazon-approved sender address.
- Continued support by the user's email provider and Amazon for personal-document email delivery.
- The native application implementation plan and its validated local processing dependencies.

## Out of Scope

- Raycast, a Raycast extension, Raycast Store distribution, or any required third-party launcher.
- More than the two primary screens `Delivery Setup` and `Send Book`.
- Persistent or scheduled queues, delivery history, library management, reading, editing, annotation, catalogs, or cloud synchronization.
- Conversion among EPUB, PDF, MOBI, AZW, AZW3, KFX, or other formats.
- DRM removal, bypass, decryption, or destructive and ambiguous content repair.
- Amazon authentication, browser automation, automated upload to the Send to Kindle website, or guarantees of Amazon acceptance.
- User accounts, remote backends, analytics, telemetry, AI, chat, or content analysis beyond local structural book preparation.
- Mobile, Windows, Linux, browser, command-line, or parallel legacy product surfaces.
