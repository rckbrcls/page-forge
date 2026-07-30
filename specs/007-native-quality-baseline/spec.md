# Feature Specification: Native Quality Baseline

**Feature Branch**: `main`

**Created**: 2026-07-29

**Status**: Draft

**Input**: User description: "Review Book Sender and bring it to the expected
quality standard for a current native Mac application."

## User Scenarios & Testing _(mandatory)_

### User Story 1 - Complete Every Operation Reliably (Priority: P1)

A user configures delivery, adds books, waits for preparation, confirms a stable
batch, and receives a definitive result without the application hanging or
silently abandoning an operation.

**Why this priority**: A lightweight utility is trustworthy only when every
bounded local or network operation either completes or reaches an honest,
recoverable terminal state.

**Independent Test**: Exercise setup, file intake, preparation, confirmation,
delivery, timeout, and cancellation paths with controlled success and failure
conditions, then verify that every path finishes within its declared bound and
preserves completed work.

**Acceptance Scenarios**:

1. **Given** a delivery server stops replying before book data begins, **When**
   the current stage reaches its time limit, **Then** the attempt terminates with
   an actionable failure and the interface remains responsive.
2. **Given** an operation is cancelled before transmission begins, **When**
   cancellation is acknowledged, **Then** pending work stops, the active item
   becomes cancelled, and completed items remain unchanged.
3. **Given** cancellation or connection loss occurs after book data begins,
   **When** the attempt terminates without a definitive provider response,
   **Then** the item becomes `Delivery Unknown` and is not retried
   automatically.
4. **Given** a local safety operation reaches its declared limit, **When** the
   limit expires, **Then** the item becomes ineligible with a safe explanation
   and the remaining batch can continue.

---

### User Story 2 - Receive Complete Intake Feedback (Priority: P1)

A user adds EPUB or PDF books through Finder or drag and drop and receives an
honest result for every attempted input, including inputs that cannot be read or
interpreted.

**Why this priority**: Silent intake failures make the user repeat actions and
cannot be distinguished from an unresponsive application.

**Independent Test**: Attempt supported, unsupported, inaccessible, malformed,
and mixed selections through both intake paths, then verify that every attempted
input is either represented in the batch or explained visibly.

**Acceptance Scenarios**:

1. **Given** one or more readable EPUB or PDF files, **When** the user selects or
   drops them, **Then** each accepted file enters the same shared intake flow.
2. **Given** one input cannot be loaded from a mixed selection, **When** the
   remaining inputs are valid, **Then** valid inputs continue and the failed
   input receives concise, actionable feedback.
3. **Given** the file chooser or drop transfer fails before a usable file
   reference is created, **When** the failure is known, **Then** the application
   reports it instead of silently doing nothing.
4. **Given** intake is already busy, **When** the user attempts another intake
   action, **Then** the action remains unavailable without duplicating or losing
   the active batch.

---

### User Story 3 - Use a Native, Accessible Mac Interface (Priority: P2)

A user operates the two-screen application, its confirmation, and its two-tab
Settings window using pointer, keyboard, VoiceOver, and relevant accessibility
preferences without losing context or encountering ambiguous controls.

**Why this priority**: Native behavior and accessibility are part of the
product's lightweight promise, not optional visual polish.

**Independent Test**: Complete setup, sending, confirmation, settings, and
shortcut journeys using keyboard and accessibility inspection while Reduce
Transparency and Increase Contrast are enabled.

**Acceptance Scenarios**:

1. **Given** the Settings window is open, **When** the user switches between
   `Delivery` and `Shortcut`, **Then** both tabs expose standard labels,
   selection, focus, and keyboard behavior.
2. **Given** a confirmation is presented, **When** its underlying summary is
   dismissed or completed, **Then** the confirmation closes without blank,
   stale, or mismatched content.
3. **Given** the user changes text size or contrast preferences, **When** primary
   actions, file rows, and status text are displayed, **Then** labels remain
   readable without clipping or relying on color alone.
4. **Given** the primary window was closed, **When** the configured shortcut is
   invoked, **Then** the existing application reveals one primary window in the
   correct setup-derived state.

---

### User Story 4 - Keep the Credential Across Normal Updates (Priority: P1)

A returning user enters the SMTP app password once in the first corrected
version and continues using Book Sender after normal updates without repeated
credential entry.

**Why this priority**: A lightweight sender cannot require repeated secret entry,
and free distribution must preserve that continuity without weakening storage.

**Independent Test**: Save a credential through the traditional Keychain,
recreate the store, replace version N with N+1 signed by the same pinned identity,
and verify that setup remains complete without exposing the password.

**Acceptance Scenarios**:

1. **Given** no credential exists under the corrected contract, **When** setup is
   saved, **Then** the password is stored only in the traditional macOS Keychain.
2. **Given** a credential has been saved, **When** the app closes, reopens, or
   recreates its credential store, **Then** the credential remains readable
   without another prompt.
3. **Given** version N and N+1 use the pinned certificate and exact designated
   requirement, **When** N+1 replaces N, **Then** the credential remains readable.
4. **Given** an obsolete credential cannot be read, **When** the corrected app
   opens, **Then** only non-secret fields are prefilled and the password is
   requested once without unsafe migration.
5. **Given** a release lacks or diverges from the pinned signing material,
   **When** automation validates it, **Then** publication stops before packaging
   and never falls back to ad-hoc signing.
6. **Given** the pinned self-signed identity has no Apple Team ID, **When** the
   signed app loads Sparkle under the hardened runtime, **Then** only the main
   executable's library-validation exception permits the pinned framework and
   the process remains alive through the release launch gate.

### Edge Cases

- A reply arrives at the same moment that its delivery stage reaches the time
  limit.
- Cancellation occurs while an operation is suspended waiting for data rather
  than actively processing bytes.
- A mixed drop contains valid books, unreadable items, unsupported types, and
  repeated references.
- A file chooser is dismissed normally versus failing to return selected files.
- A confirmation summary becomes unavailable while the presentation transition
  is in progress.
- Accessibility text sizing causes long filenames, status labels, errors, or
  button labels to compete for space.
- The shortcut is invoked before the primary window has been captured or several
  times while a reveal is already pending.
- A pre-migration Data Protection Keychain item is inaccessible.
- Release secrets are absent, malformed, or identify a different certificate.
- A nested Sparkle component is unsigned, ad-hoc signed, or signed by another
  identity.
- A statically valid signed app is rejected by dyld because the self-signed main
  executable and Sparkle framework have no Apple Team ID.
- Emergency certificate rotation is required after loss or compromise.

## Requirements _(mandatory)_

### Functional Requirements

- **FR-001**: Every declared local and network time limit MUST produce a terminal
  result without leaving suspended work that prevents the operation from
  returning.
- **FR-002**: Cancellation MUST release every pending wait, stop future
  scheduling, and preserve completed outcomes.
- **FR-003**: Delivery interruption before book data begins MUST remain
  distinguishable from interruption after transmission begins.
- **FR-004**: A timed-out or cancelled item MUST NOT block independent eligible
  items from continuing through the sequential batch.
- **FR-005**: Finder selection and drag and drop MUST feed the same ordered intake
  behavior and produce equivalent item outcomes.
- **FR-006**: Every attempted intake item MUST either enter the batch or produce
  concise visible feedback; transfer and chooser failures MUST NOT be ignored.
- **FR-007**: A failure in one item from a mixed intake MUST NOT discard
  successfully loaded items from the same action.
- **FR-008**: Confirmation presentation MUST be derived from one complete stable
  summary and MUST NOT display empty, stale, or partially cleared values.
- **FR-009**: The Settings window MUST retain exactly the `Delivery` and
  `Shortcut` tabs with standard selection, focus, labeling, and keyboard
  behavior.
- **FR-010**: Every icon-only control MUST have an accessible action name, and
  every progress-only state MUST have an accessible status name.
- **FR-011**: Statuses and validation failures MUST remain understandable without
  color and legible with supported text, contrast, motion, and transparency
  preferences.
- **FR-012**: Primary actions and status labels MUST adapt to available space and
  accessibility text preferences without clipping essential meaning.
- **FR-013**: Window reveal behavior MUST produce at most one primary window and
  MUST remain correct when requested before capture or repeatedly.
- **FR-014**: Quality corrections MUST preserve setup persistence, protected
  credentials, stable batch confirmation, original-file immutability, and
  explicit delivery consent.
- **FR-015**: Every corrected timeout, cancellation, intake-failure,
  confirmation, settings, and accessibility behavior MUST have focused
  regression evidence.
- **FR-016**: The quality pass MUST remove obsolete interaction behavior where a
  supported native equivalent exists, without changing the visible product
  scope.
- **FR-017**: SMTP passwords MUST use only generic-password items in the
  traditional file-based macOS Keychain; queries MUST NOT select the Data
  Protection Keychain, synchronization, or custom accessibility attributes.
- **FR-018**: Credentials MUST NOT fall back to files, `UserDefaults`, remote
  storage, or encryption protected by an application-embedded key.
- **FR-019**: An inaccessible obsolete credential MUST preserve only non-secret
  draft fields and require one password entry without unsafe migration.
- **FR-020**: Every distributed version and nested executable MUST use the same
  pinned self-signed release certificate, and the main app MUST retain the exact
  designated requirement anchored to it and `com.rckbrcls.BookSender`.
- **FR-021**: Missing or invalid PKCS#12 secrets, certificate drift, designated
  requirement drift, ad-hoc signing, or invalid nested signatures MUST fail the
  release before packaging or publication with no fallback.
- **FR-022**: The installer MUST reject unsigned, ad-hoc, differently signed, or
  requirement-divergent archives before replacing an installed app.
- **FR-023**: Sparkle EdDSA MUST remain an independent mandatory update-archive
  signature.
- **FR-024**: Distributed builds MUST retain the hardened runtime and MAY disable
  only library validation on the main executable to load bundled Sparkle code
  signed by the pinned self-signed identity.
- **FR-025**: A signed-app launch smoke test MUST keep the process alive for a
  bounded interval before packaging; dyld rejection or early exit MUST fail the
  release.
- **FR-026**: The installer MUST verify the GitHub Release asset SHA-256 digest
  and pinned public DER certificate, then idempotently register only that public
  certificate in the user's default Keychain when absent and after explicit
  terminal confirmation; it MUST NOT import a private key or install an explicit
  trust override.
- **FR-027**: Publication MUST depend on a separate clean macOS runner that
  receives neither PKCS#12 nor private identity, installs the packaged candidate
  through the real certificate bootstrap, proves no private identity was
  imported, and passes strict signature and launch verification.

### Constitution Constraints _(mandatory)_

- **CC-001**: Feature MUST remain within `Delivery Setup` and `Send Book`;
  dialogs, progress, and inline disclosure MUST NOT become additional primary
  screens.
- **CC-002**: Feature MUST keep advanced EPUB safety, audit, deterministic
  cleanup/restoration, separate-copy writing, and revalidation in the
  background.
- **CC-003**: Feature MUST expose concise derived states and only reveal
  technical evidence inline when it supports an action, failure, or decision.
- **CC-004**: Feature MUST process a stable batch sequentially, isolate outcomes
  per book, preserve completed work, and define cooperative cancellation.
- **CC-005**: Feature MUST keep processing local, preserve originals and existing
  files, and require explicit confirmation before SMTP transmission.
- **CC-006**: Feature MUST use typed pipeline evidence and failures, keep domain
  rules outside interface views, and test every automatic rule with fixtures.
- **CC-007**: Feature MUST NOT introduce external ebook engines, helper
  processes, conversion, DRM removal, library, history, cloud, account, AI, or a
  parallel product surface.
- **CC-008**: Feature MUST use traditional Keychain storage, the stable pinned
  release identity, the bounded library-validation exception, and the launch
  gate required by constitution 7.1.0; ad-hoc signing is permitted only for
  non-distributed test hosts.

### Key Entities

- **Pending Wait**: One suspended operation awaiting a local or remote event,
  with a terminal completion, timeout, or cancellation path.
- **Intake Attempt**: One Finder or drop action containing ordered input items and
  an outcome for each attempted item.
- **Confirmed Batch Summary**: The complete immutable destination and item counts
  presented for one explicit send decision.
- **Accessibility State**: The labels, focus order, semantic status, and
  preference-dependent presentation exposed to assistive technologies.
- **Quality Evidence**: A focused acceptance result tied to one corrected
  behavior and its relevant boundary conditions.
- **Release Signing Policy**: The stable identity name, public certificate
  fingerprint, bundle identifier, and exact designated requirement required by
  CI and the installer.

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: 100% of controlled stalled-operation scenarios terminate no later
  than one second after their declared time limit instead of hanging.
- **SC-002**: 100% of controlled cancellation scenarios release pending work no
  later than one second after cancellation is requested, except an active
  transmission that correctly becomes `Delivery Unknown`.
- **SC-003**: 100% of attempted files in Finder, drop, and mixed-intake
  acceptance scenarios receive either a batch item or visible failure feedback.
- **SC-004**: Setup, send, confirmation, Settings, and shortcut journeys complete
  successfully using keyboard-only operation with every actionable control
  exposing a meaningful accessible label.
- **SC-005**: The interface remains readable in all covered Reduce Transparency,
  Increase Contrast, and enlarged-text scenarios, with no critical action or
  terminal status clipped or communicated by color alone.
- **SC-006**: All existing two-screen, original-preservation, privacy, explicit
  confirmation, and batch-isolation acceptance scenarios continue to pass after
  the quality corrections.
- **SC-007**: The final review records zero unresolved high-severity reliability
  or accessibility findings within the defined scope.
- **SC-008**: The first corrected version requires at most one credential
  re-entry, and a same-identity N-to-N+1 update requires none.
- **SC-009**: Automated signing contracts reject every missing-secret, invalid
  PKCS#12, certificate-drift, requirement-drift, ad-hoc, unsigned, and
  differently signed fixture before packaging or replacement.
- **SC-010**: A release cannot be published unless a fresh macOS runner with no
  private signing identity registers only the pinned public certificate and
  keeps the installed candidate alive through the launch gate.

## Assumptions

- The current two-screen product, native Settings window, advanced local
  preparation pipeline, and explicit delivery model remain the approved product.
- The active implementation specification remains
  `specs/006-replace-mock-workflows/`; this feature is a focused quality baseline
  and does not replace its functional scope.
- Provider acceptance, authenticated delivery, clean-account installation, and
  public distribution remain separate validation gates.
- A normal user dismissal of a system picker is not an error and requires no
  warning.
- Accessibility validation covers supported system preferences and assistive
  interaction without adding a custom appearance mode.
- No new product dependency, primary screen, persistent history, or external
  processing service is required.
- The private signing identity has an encrypted backup outside the repository;
  only the public DER certificate is versioned.
- A self-signed identity is not Developer ID, provides no notarization, and does
  not remove normal Gatekeeper friction from manual installation.
- Identity rotation is exceptional, requires explicit authorization and a
  migration plan, and may require one-time credential re-entry.
