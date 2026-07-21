# Feature Specification: Desktop App Migration

**Feature Branch**: `001-desktop-app-migration`

**Created**: 2026-07-17

**Status**: Draft

**Input**: User description: "vamos planejar a refatoracao inteira do codigo que tem hoje para uma versao desktop dela, com swiftui e etc, coloque o tui antigo em uma pasta legacy, vamos so usar de inspiracao"

## User Scenarios & Testing _(mandatory)_

### User Story 1 - Drop a book and see Kindle readiness (Priority: P1)

A macOS user opens PageForge, drops one ebook onto the app, and immediately sees
whether that book is ready for Kindle delivery. The report uses clear status
language and lists the issues found, without writing a new file yet.

**Why this priority**: This is the core product job. If this flow works, the
desktop migration already delivers the main value of PageForge.

**Independent Test**: Drop a valid EPUB and confirm a readiness report appears
with status and issues. Drop a blocked/invalid case and confirm the app explains
what is wrong without crashing.

**Acceptance Scenarios**:

1. **Given** the app is open on its default screen, **When** the user drops a
   supported ebook file, **Then** the app shows a readiness result for that file
   with status `ready`, `needs_fixes`, or `blocked`.
2. **Given** a readiness result with issues, **When** the user reviews the
   report, **Then** each issue has a severity of `info`, `warning`, `error`, or
   `fixable` and a human-readable explanation.
3. **Given** Calibre tools are missing and the selected action needs them,
   **When** the user tries to proceed, **Then** the app blocks the action with
   clear recovery guidance instead of failing silently.
4. **Given** the app launches, **When** no prior navigation has occurred,
   **Then** the default experience is Readiness-first rather than Settings.

---

### User Story 2 - Prepare a Kindle-ready file (Priority: P2)

After reviewing readiness issues, the user asks PageForge to apply safe fixes and
produce a prepared output file for Kindle delivery.

**Why this priority**: Diagnosis alone is incomplete. The product promise is to
help the user leave with a prepared book.

**Independent Test**: Start from a book that needs safe fixes, run prepare, and
verify a new Kindle-ready output is created while the original remains intact.

**Acceptance Scenarios**:

1. **Given** an EPUB with fixable readiness issues, **When** the user runs
   prepare/fix, **Then** the app writes a new `*-kindle-ready.epub` output and
   shows the resulting status.
2. **Given** a MOBI file, **When** the user runs prepare/fix, **Then** the app
   treats MOBI as legacy input, converts it into the readiness workflow, and
   produces a Kindle-ready EPUB when possible.
3. **Given** a book that is blocked from safe preparation, **When** the user
   attempts prepare/fix, **Then** the app refuses unsafe preparation and
   explains the blocking issues.
4. **Given** the user only wants diagnosis, **When** they run audit without
   prepare/fix, **Then** no prepared output file is written.

---

### User Story 3 - Convert and repair individual books (Priority: P3)

The user converts between supported formats and repairs EPUBs when needed, using
safe repair by default and aggressive repair only as an explicit secondary choice.

**Why this priority**: Conversion and repair are established baseline workflows
and often feed readiness/delivery.

**Independent Test**: Convert one MOBI or PDF to EPUB, repair one EPUB safely,
and confirm outputs and status messages are clear.

**Acceptance Scenarios**:

1. **Given** a MOBI file, **When** the user converts to EPUB, **Then** the app
   produces an EPUB output and reports success or a clear failure reason.
2. **Given** a PDF with extractable text, **When** the user converts to EPUB,
   **Then** the app produces an EPUB without promising OCR for scanned pages.
3. **Given** an EPUB, **When** the user converts to MOBI, **Then** the app
   produces a MOBI output or explains why conversion failed.
4. **Given** an EPUB needing structural repair, **When** the user runs safe
   repair, **Then** the app writes a distinct `*-repaired.epub` output.
5. **Given** safe repair is insufficient, **When** the user explicitly selects
   aggressive repair, **Then** the app runs that secondary mode only after clear
   labeling and user intent.

---

### User Story 4 - Send to Kindle or hand off (Priority: P4)

When a book is ready, the user either sends it through a configured local email
profile or opens the Amazon Send to Kindle handoff path.

**Why this priority**: Delivery completes the Kindle-ready mission.

**Independent Test**: With a configured profile and a ready file, send succeeds
or fails with actionable feedback. Without wanting SMTP, handoff can be opened
independently.

**Acceptance Scenarios**:

1. **Given** a configured delivery profile and a ready ebook, **When** the user
   sends to Kindle, **Then** the app attempts delivery and reports success or a
   clear failure reason.
2. **Given** no complete delivery profile, **When** the user tries SMTP send,
   **Then** the app blocks send and guides the user to finish profile setup.
3. **Given** a prepared or selected ebook, **When** the user chooses Send to
   Kindle handoff, **Then** the app opens the external handoff path without
   automating Amazon login or upload.
4. **Given** delivery secrets are stored, **When** the user inspects local app
   config files, **Then** passwords/tokens are not stored in plain config.

---

### User Story 5 - Process a folder in batch (Priority: P5)

The user points PageForge at a folder and runs readiness preparation, repair, or
conversion across many books, with a summary of outcomes.

**Why this priority**: Batch is part of the current product baseline and matters
for real libraries, but it is secondary to the single-book flow.

**Independent Test**: Run one batch operation on a small folder containing mixed
valid and invalid files and verify per-item outcomes plus totals.

**Acceptance Scenarios**:

1. **Given** a folder of ebooks, **When** the user runs batch readiness with
   prepare/fix, **Then** the app processes supported files and summarizes
   ready/needs_fixes/blocked counts.
2. **Given** a folder of EPUBs, **When** the user runs batch repair, **Then**
   repaired outputs are written according to the selected output location rules.
3. **Given** a folder of MOBI/PDF files, **When** the user runs batch conversion
   to EPUB, **Then** converted outputs are produced for eligible files and
   failures are reported per item.
4. **Given** a long batch run, **When** processing is underway, **Then** the
   interface remains usable and shows progress or current status.

---

### User Story 6 - Inspect and adjust metadata (Priority: P6)

The user inspects title/author metadata and makes light corrections needed for a
cleaner Kindle-ready book.

**Why this priority**: Metadata cleanup is in the baseline, but it supports the
main workflow rather than defining it.

**Independent Test**: Inspect one book, update title and/or author, and confirm
the change is visible on re-inspection.

**Acceptance Scenarios**:

1. **Given** a supported ebook, **When** the user inspects metadata, **Then**
   the app shows at least title and author information when available.
2. **Given** editable metadata fields, **When** the user updates title and/or
   author, **Then** the app saves the change and confirms success.
3. **Given** metadata tools are unavailable, **When** the user attempts inspect
   or update, **Then** the app explains the missing dependency clearly.

---

### User Story 7 - Configure app health, profiles, and logs (Priority: P7)

The user opens Settings to check Calibre availability, manage delivery profiles,
review status, access logs, and understand update/setup guidance.

**Why this priority**: Configuration and diagnostics are required for trust, but
they must not become the default home screen.

**Independent Test**: Open Settings, view Calibre status, create or edit a
delivery profile, and open logs without leaving the app unusable.

**Acceptance Scenarios**:

1. **Given** Calibre is installed and discoverable, **When** the user opens
   dependency status, **Then** the app reports the tools as available.
2. **Given** Calibre is missing or incomplete, **When** the user opens
   dependency status, **Then** the app shows what is missing and how to recover.
3. **Given** the user configures a delivery profile, **When** setup is saved,
   **Then** non-secret settings persist locally and secrets go to the system
   keychain.
4. **Given** operations have run, **When** the user opens Logs, **Then** recent
   operational messages are available for troubleshooting.
5. **Given** update actions exist, **When** the user reviews them, **Then** app
   updates and Calibre updates are presented as separate concerns.

---

### User Story 8 - Retire the old terminal UI to legacy reference (Priority: P8)

The project stops treating the old terminal UI as the product surface. Existing
terminal UI code is moved into a legacy reference area and used only as
behavioral inspiration during the desktop rebuild.

**Why this priority**: This enables a clean migration boundary and prevents dual
product maintenance, but it is a project transition story rather than an end-user
workflow.

**Independent Test**: Confirm the desktop app is the primary launchable product
surface and the old terminal UI lives only under a clearly marked legacy area.

**Acceptance Scenarios**:

1. **Given** the migration is applied, **When** a contributor inspects the repo,
   **Then** the old terminal UI is located under a legacy reference area rather
   than the primary product path.
2. **Given** the legacy terminal UI exists, **When** product work continues,
   **Then** new mission-critical behavior is implemented for the desktop product
   first and the legacy code is not the source of ongoing feature development.
3. **Given** the desktop app is the primary surface, **When** a user launches
   PageForge for normal use, **Then** they get the desktop experience rather than
   the old terminal UI.

---

### Edge Cases

- User drops an unsupported file type
- User drops multiple files when the current view expects one file
- Source file disappears or becomes unreadable during processing
- Output path already exists
- Disk is full or output directory is not writable
- Calibre is installed in a custom location
- SMTP profile is partially configured
- Network is unavailable during SMTP send
- Scanned PDF conversion yields empty/poor text
- Batch folder contains nested directories or mixed relevant/irrelevant files
- User quits while a long conversion/repair/batch is running
- Aggressive repair is attempted on a book that should remain on safe-only path

## Requirements _(mandatory)_

### Functional Requirements

- **FR-001**: Product MUST provide a native macOS desktop experience as the
  primary user surface for PageForge workflows.
- **FR-002**: Default desktop entry experience MUST open on Readiness.
- **FR-003**: Users MUST be able to add local ebook files through drag-and-drop
  and through an explicit file chooser.
- **FR-004**: System MUST support the baseline single-book workflows from the
  current product: readiness audit, readiness prepare/fix, safe repair,
  aggressive repair as secondary mode, conversion (`MOBI -> EPUB`,
  `PDF -> EPUB`, `EPUB -> MOBI`), metadata inspect/update, and Send to Kindle
  delivery/handoff.
- **FR-005**: System MUST support folder batch readiness, repair, and conversion
  workflows with per-item results and summary counts.
- **FR-006**: Readiness results MUST use statuses `ready`, `needs_fixes`, and
  `blocked`.
- **FR-007**: Readiness issues MUST use severities `info`, `warning`, `error`,
  and `fixable`.
- **FR-008**: Prepared readiness outputs MUST use `*-kindle-ready.epub` naming.
- **FR-009**: Structural repair outputs MUST remain distinct and use
  `*-repaired.epub` naming.
- **FR-010**: MOBI inputs MUST be treated as legacy inputs that can enter the
  readiness preparation path through conversion to EPUB.
- **FR-011**: PDF conversion MUST remain available without promising OCR for
  scanned documents.
- **FR-012**: System MUST keep original source files intact unless the user
  explicitly chooses an overwrite path.
- **FR-013**: System MUST expose Calibre dependency status and recovery guidance
  when required tools are missing or incomplete.
- **FR-014**: Users MUST be able to manage local delivery profiles for SMTP Send
  to Kindle.
- **FR-015**: Delivery secrets MUST be stored in the macOS keychain, not in plain
  local config files.
- **FR-016**: System MUST support explicit handoff to Amazon Send to Kindle
  without automating Amazon login or upload.
- **FR-017**: Desktop supporting surfaces MUST include Convert, Batch, Send to
  Kindle, Metadata, Settings, and Logs, with progressive disclosure for advanced
  or destructive controls.
- **FR-018**: Long-running operations MUST leave the interface responsive and
  show progress or current status.
- **FR-019**: System MUST present operation failures with actionable messages
  suitable for a non-expert user.
- **FR-020**: Existing terminal UI code MUST be moved into a legacy reference
  area and retained only as behavioral inspiration.
- **FR-021**: Legacy terminal UI MUST NOT remain the primary product surface
  after migration.
- **FR-022**: Desktop migration MUST preserve the product mission and safety
  boundaries: no DRM removal, no Amazon login/upload automation, no Calibre
  replacement positioning.
- **FR-023**: Users MUST be able to review recent operational logs from inside
  the app.
- **FR-024**: App update guidance and Calibre update guidance MUST remain
  separate concerns.

### Constitution Constraints _(mandatory)_

- **CC-001**: Feature MUST stay inside README mission scope: intake, readiness,
  conversion, repair, metadata cleanup, batch preparation, or Kindle send/handoff
- **CC-002**: Feature MUST preserve local-first operation and safe explicit actions
- **CC-003**: Feature MUST NOT introduce DRM removal, OCR promises for scanned PDFs,
  or Amazon login/upload automation
- **CC-004**: Feature MUST keep Readiness-first UX order; advanced controls use
  progressive disclosure
- **CC-005**: Feature MUST keep long-running work non-blocking and report
  progress/failures clearly
- **CC-006**: Feature MUST preserve output contracts (`*-repaired.epub` vs
  `*-kindle-ready.epub`) unless an explicit breaking change is approved

### Key Entities

- **EbookSource**: A local user-selected file or folder item used as input
- **ReadinessReport**: Diagnosis result with overall status and issue list
- **ReadinessIssue**: One finding with code/message and severity
- **PreparationResult**: Output path and final readiness outcome after prepare/fix
- **ConversionJob**: Requested format transform and resulting output/error
- **RepairJob**: Safe or aggressive repair request and resulting output/error
- **DeliveryProfile**: Local SMTP/send settings excluding secret material
- **DeliveryResult**: Success/failure outcome for a send attempt
- **DependencyStatus**: Availability of required external ebook tools
- **OperationLogEntry**: Timestamped message from an app operation
- **LegacyReferenceCode**: Archived terminal UI retained only for inspiration

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: A first-time user can drop one ebook and understand its readiness
  status in under 30 seconds for a typical local file.
- **SC-002**: A user can complete the path `diagnose -> prepare -> send or handoff`
  for one book without consulting external documentation.
- **SC-003**: At least 95% of single-book readiness audits on valid supported
  inputs complete with a definitive status rather than an unexplained failure.
- **SC-004**: The interface remains interactive during conversion, repair, and
  batch operations; users can still navigate and inspect status while work runs.
- **SC-005**: Users can distinguish prepared outputs from repaired outputs by
  filename contract in 100% of successful runs.
- **SC-006**: In usability review, at least 9 of 10 primary tasks map clearly to
  Readiness, Convert, Batch, Send, Metadata, Settings, or Logs without hidden
  extra primary destinations.
- **SC-007**: After migration, the old terminal UI is no longer required to
  perform any baseline workflow available in the desktop product.
- **SC-008**: Setup/recovery guidance allows a user with missing ebook engine
  tools to identify the blocker in under 1 minute from the status screen.

## Assumptions

- The current README capability set is the functional baseline to preserve in the
  desktop product unless a later approved change narrows scope for phased
  delivery.
- Phased implementation is acceptable, but the full migration scope includes the
  complete baseline above, not only readiness.
- The desktop product is macOS-only.
- External ebook engine tools remain required for conversion, metadata mutation,
  and polish operations.
- The preferred native desktop implementation approach is the one already adopted
  by project governance for macOS utilities; planning may refine structure later.
- Existing terminal UI is valuable as reference behavior and copy inspiration, not
  as a second maintained product.
- Existing terminal/CLI automation can be archived with the legacy surface for
  reference; desktop becomes the primary supported product experience.
- Amazon account authorization of sender email remains a user responsibility
  outside the app.
- No multi-user accounts, cloud sync, or online library features are included.
- Visual quality target is calm, lightweight, and premium, not dense dashboard UI.

## Scope Boundaries

### In Scope

- Full product migration from terminal-first experience to desktop-first experience
- Preservation of readiness, convert, repair, batch, metadata, send/handoff,
  settings, logs, and dependency guidance
- Archival of old terminal UI into a legacy reference area
- Interaction model upgrades appropriate to desktop, especially drag-and-drop

### Out of Scope

- Rebuilding a full Calibre GUI
- Multi-platform desktop support
- Cloud sync, accounts, collaboration, marketplace, or social features
- DRM removal
- Amazon login/upload automation
- OCR pipeline for scanned PDFs
- Ongoing feature development on the legacy terminal UI
