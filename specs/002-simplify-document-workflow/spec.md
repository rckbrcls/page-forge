# Feature Specification: Simplified Document Workflow

**Feature Branch**: `main` (no feature branch created)

**Created**: 2026-07-18

**Status**: Draft

**Input**: User description: "Refactor PageForge into one simple screen where users import multiple Kindle-compatible documents, convert and prepare them with the existing ebook engine, then send them through the configured Kindle delivery profile or save the results. Preserve the current drag-and-drop component, add a compact drop target to the standard window toolbar, and move settings into a separate window opened by one button."

## User Scenarios & Testing _(mandatory)_

### User Story 1 - Import a document collection (Priority: P1)

A user opens PageForge and adds one or many EPUB, MOBI, or PDF files to a single
workspace. The existing large drag-and-drop area remains the clearest entry point
when the workspace is empty. The same files can also be added with a file chooser
or by dropping them onto a compact import target in the window toolbar.

**Why this priority**: A single, obvious intake flow removes the navigation and
mode decisions that currently make the app feel complex.

**Independent Test**: Add a mixed set of supported files through each intake
method and confirm that all valid files appear in one queue with an initial
status, while unsupported or duplicate files receive clear feedback.

**Acceptance Scenarios**:

1. **Given** the workspace is empty, **When** the app opens, **Then** the large
   drag-and-drop component is prominently visible as the primary content.
2. **Given** the app is open, **When** the user drops multiple supported files
   on the large drop area, **Then** every valid file is added to one processing
   queue.
3. **Given** the queue already contains files, **When** the user drops additional
   supported files on the toolbar import target, **Then** those files are appended
   without replacing the existing queue.
4. **Given** the user prefers a file chooser, **When** they activate Add Files,
   **Then** they can select multiple supported files in one action.
5. **Given** a selection contains unsupported or duplicate files, **When** it is
   imported, **Then** eligible files are retained and each rejected item receives
   a specific explanation.

---

### User Story 2 - Prepare every eligible file (Priority: P2)

The user starts one preparation action for the queue. PageForge determines the
required safe path for each item, converts legacy or document inputs when needed,
prepares Kindle-ready outputs, and reports progress per file without requiring the
user to choose among separate Readiness, Convert, Batch, Metadata, or Repair areas.

**Why this priority**: Preparation is the product's central job and should feel
like one coherent operation rather than a collection of tools.

**Independent Test**: Prepare a queue containing an EPUB, a MOBI, and a readable
PDF, then verify that each file reaches an independent result with a clear output
or an actionable failure.

**Acceptance Scenarios**:

1. **Given** one or more eligible files are queued, **When** the user starts
   preparation, **Then** each item reports queued, in-progress, completed, failed,
   or attention-required status independently.
2. **Given** an EPUB can be safely prepared, **When** its operation completes,
   **Then** the original remains unchanged and its prepared output uses the
   `*-kindle-ready.epub` naming contract.
3. **Given** a supported input requires conversion before preparation, **When**
   processing succeeds, **Then** the item exposes the resulting Kindle-ready file
   without asking the user to navigate to another area.
4. **Given** one item fails, **When** other eligible items remain, **Then** the
   remaining items continue and the failed item shows a recoverable explanation.
5. **Given** required conversion capabilities are unavailable, **When** the user
   starts preparation, **Then** affected items are blocked with guidance to open
   Settings while unrelated eligible items remain usable.

---

### User Story 3 - Send or save prepared files (Priority: P3)

After preparation, the user selects completed files and either sends them to
Kindle through the configured delivery profile or saves copies to a chosen local
folder. Both outcomes are available from the same screen.

**Why this priority**: Sending or keeping the result completes the workflow and
should not require another navigation destination.

**Independent Test**: Select multiple completed files, save them to a chosen
folder, and separately attempt delivery with both a complete and an incomplete
profile.

**Acceptance Scenarios**:

1. **Given** one or more completed files are selected, **When** the user chooses
   Save Files, **Then** the app lets them choose a destination and reports the
   saved location for each output.
2. **Given** one or more completed files and a valid delivery profile, **When**
   the user chooses Send to Kindle, **Then** each file receives a sent or failed
   delivery result.
3. **Given** the delivery profile is missing or incomplete, **When** the user
   chooses Send to Kindle, **Then** no delivery starts and the app offers a direct
   route to the separate Settings window.
4. **Given** a queue contains incomplete or blocked items, **When** the user
   selects completed items for an output action, **Then** only eligible prepared
   outputs are included.
5. **Given** the user removes an item from the queue, **When** its output already
   exists, **Then** removing the queue item does not delete the source or output
   file.

---

### User Story 4 - Configure without leaving the workflow (Priority: P4)

The user opens a separate Settings window from a single toolbar button to manage
delivery profiles, check preparation capabilities, choose relevant preferences,
and access troubleshooting information. Closing Settings returns focus to the
unchanged main queue.

**Why this priority**: Configuration remains available without competing with
the primary workflow or becoming permanent navigation.

**Independent Test**: Open Settings from the toolbar, update a delivery profile,
close the window, and confirm that the main queue and its progress are preserved.

**Acceptance Scenarios**:

1. **Given** the main window is open, **When** the user activates the single
   Settings toolbar button, **Then** a dedicated Settings window opens.
2. **Given** Settings is already open, **When** the user activates Settings again,
   **Then** the existing window is focused rather than duplicated.
3. **Given** queue work is in progress, **When** Settings opens or closes, **Then**
   processing and main-window state continue unchanged.
4. **Given** a delivery password or token is saved, **When** settings persist,
   **Then** the secret is protected by the system credential store and is not
   written as plain text in app configuration.

### Edge Cases

- The user drops a folder, alias, package, remote placeholder, unreadable file,
  or unsupported format instead of an eligible local file.
- The same file is added twice through different intake methods or path aliases.
- A source file is moved, renamed, or deleted after import and before processing.
- A selected output name already exists in the destination folder.
- Available disk space becomes insufficient during conversion or save.
- A readable PDF converts poorly, while a scanned PDF contains no extractable
  text; the app must not promise OCR.
- A prepared file exceeds the configured delivery channel's size limit.
- Network access is lost while sending multiple files; already completed sends
  remain reported separately from failed or unattempted sends.
- The user closes the main window or quits while work is active.
- The user drops new files while other files are processing.
- The toolbar is too narrow to show every item at full size; import and Settings
  remain discoverable and keyboard-accessible.

## Requirements _(mandatory)_

### Functional Requirements

- **FR-001**: The product MUST present one primary workflow screen instead of
  separate primary areas for readiness, conversion, batch, sending, metadata,
  settings, and logs.
- **FR-002**: The empty state MUST preserve the existing large drag-and-drop
  intake component as the primary visual element.
- **FR-003**: Users MUST be able to add multiple EPUB, MOBI, and PDF files through
  the large drop area, a multi-select file chooser, and a compact drop-capable
  import target in the standard window toolbar.
- **FR-004**: Every intake method MUST append eligible items to the same queue and
  MUST apply the same validation and duplicate-detection rules.
- **FR-005**: The queue MUST show, at minimum, each source name, current operation
  status, relevant progress, and available next action.
- **FR-006**: Users MUST be able to select all items, select individual items,
  remove items without deleting files, and retry failed or attention-required
  items.
- **FR-007**: The product MUST provide one primary preparation action that applies
  the appropriate readiness, safe-fix, and conversion path per selected file.
- **FR-008**: Processing one item MUST NOT prevent other queued items from
  completing or remaining actionable.
- **FR-009**: Long-running work MUST keep the interface responsive and MUST expose
  per-item progress and cancellation-safe status.
- **FR-010**: Original source files MUST remain unchanged by the simplified
  preparation workflow.
- **FR-011**: Prepared readiness outputs MUST preserve the
  `*-kindle-ready.epub` naming contract; standalone structural repair behavior,
  if exposed through progressive disclosure, MUST preserve `*-repaired.epub`.
- **FR-012**: Completed outputs MUST be selectable for Save Files and Send to
  Kindle actions directly from the main screen.
- **FR-013**: Save Files MUST write copies to a user-selected local destination,
  handle name conflicts explicitly, and report the resulting locations.
- **FR-014**: Send to Kindle MUST use an explicitly selected, complete local
  delivery profile and MUST report a separate outcome for every selected file.
- **FR-015**: A failed, blocked, unsupported, or incomplete item MUST present a
  concise reason and an actionable recovery path without blocking unrelated
  items.
- **FR-016**: The main window MUST expose one Settings button in the standard
  toolbar and MUST NOT treat Settings as main-screen navigation.
- **FR-017**: Settings MUST open in a dedicated, single-instance window and MUST
  preserve main-window queue state and active work.
- **FR-018**: The Settings window MUST contain delivery profile configuration,
  preparation capability status and recovery guidance, relevant output
  preferences, and access to troubleshooting information.
- **FR-019**: Delivery secrets MUST remain protected by the system credential
  store and MUST NOT appear in plain-text configuration or operational messages.
- **FR-020**: The simplified workflow MUST provide clear empty, importing,
  queued, processing, completed, partially completed, error, and blocked states.
- **FR-021**: Primary actions, queue selection, the toolbar import target, and
  Settings MUST be keyboard accessible and expose visible focus and disabled
  states.
- **FR-022**: The product MUST communicate that scanned PDFs may convert poorly
  and MUST NOT claim OCR, DRM removal, Amazon login automation, or direct Amazon
  upload automation.
- **FR-023**: Advanced diagnostics and preparation details MAY use progressive
  disclosure but MUST NOT restore separate top-level workflow destinations.

### Constitution Constraints _(mandatory)_

- **CC-001**: The feature MUST remain a focused local Kindle-ready workflow:
  intake, readiness, safe preparation, conversion when needed, and send or save.
- **CC-002**: The feature MUST preserve local-first operation and require explicit
  user actions before transforming, saving, or sending files.
- **CC-003**: The feature MUST retain the existing ebook engine boundary rather
  than reimplementing conversion, metadata, or polish capabilities.
- **CC-004**: The feature MUST keep readiness and safe preparation inside the
  primary flow, even though Readiness is no longer a separate navigation area.
- **CC-005**: The feature MUST NOT introduce DRM removal, OCR promises for scanned
  PDFs, Amazon login automation, or direct Amazon upload automation.
- **CC-006**: The feature MUST keep long-running preparation and delivery work
  non-blocking and report progress and failures clearly.
- **CC-007**: The feature MUST preserve established output safety and naming
  contracts unless a separate breaking change is explicitly approved.
- **CC-008**: The feature MUST favor the smallest maintainable product surface;
  advanced controls use progressive disclosure and require demonstrated need.

### Key Entities _(include if feature involves data)_

- **DocumentItem**: One imported source file, including its identity, supported
  format, selection state, current workflow status, progress, issue summary,
  prepared output, save result, and delivery result.
- **DocumentQueue**: The ordered collection of imported items and the aggregate
  selection and operation state shown on the main screen.
- **PreparedOutput**: A local result produced without modifying the source,
  including its location, format, size, readiness state, and eligibility for save
  or delivery.
- **DeliveryProfile**: A named local configuration used to send eligible outputs,
  with non-secret settings and a protected credential reference.
- **OperationIssue**: A concise per-item warning, blocking reason, or failure with
  a recovery action when one is available.
- **ReadinessReport**: A result with status `ready`, `needs_fixes`, or `blocked`
  and issues classified as `info`, `warning`, `error`, or `fixable`.

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: A first-time user can import, prepare, and choose to save or send a
  supported file without visiting documentation or navigating between screens in
  at least 9 of 10 moderated usability attempts.
- **SC-002**: Users can add at least 50 supported files in one intake action, and
  every accepted or rejected item receives visible feedback within 2 seconds of
  intake completion.
- **SC-003**: Every file in a mixed queue receives an independent terminal or
  actionable status; one failure never causes completed results for other files
  to be lost.
- **SC-004**: Users can reach both primary outcomes—Send to Kindle and Save
  Files—from the main screen in one explicit action after selecting completed
  outputs.
- **SC-005**: At least 90% of first-time users correctly identify the large empty
  state and the toolbar target as ways to add files without instruction.
- **SC-006**: Opening or closing Settings preserves 100% of queued items,
  selections, visible results, and active operation state.
- **SC-007**: During preparation or delivery of a 50-item queue, users can still
  inspect statuses, change selection, open Settings, and add files without the
  interface becoming unresponsive.
- **SC-008**: In acceptance testing, 100% of output, validation, conversion, and
  delivery failures identify the affected file and provide either a recovery
  action or a clear explanation that no action is available.

## Assumptions

- The target user is an individual preparing local ebook files on macOS.
- The existing conversion and preparation engine remains the source of ebook
  transformation behavior; this feature changes orchestration and presentation,
  not conversion semantics.
- EPUB, MOBI, and PDF remain the supported intake formats for this refactor.
- “Download” in the requested desktop workflow means saving or exporting prepared
  outputs to a user-selected local folder.
- Preparation is explicit rather than automatic on import so users retain control
  over local file transformations.
- Multiple files are processed independently in a single queue; a separate folder
  batch mode is no longer necessary as a primary surface.
- Metadata correction, structural repair details, logs, and dependency diagnostics
  remain supporting capabilities available only where needed through contextual
  or progressively disclosed controls.
- SMTP delivery through existing local profiles is the primary Send to Kindle
  path for this feature; Amazon web/app/USB handoff is not expanded by this work.
- No account system, cloud library, synchronization, OCR, or DRM workflow is
  introduced.
