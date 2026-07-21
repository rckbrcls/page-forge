# Feature Specification: Self-Contained Raycast EPUB Workflow

**Feature Branch**: `[004-raycast-epub-workflow]`

**Created**: 2026-07-20

**Status**: Draft

**Input**: User description: "Rebuild Page Forge as a public, self-contained Raycast extension that inspects, safely repairs, revalidates, and explicitly sends EPUB files to Kindle."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Inspect EPUB Health (Priority: P1)

As a Kindle user, I want to inspect one or more EPUB files selected in Finder or a file picker so that I can understand their structural health and Kindle compatibility without changing them.

**Why this priority**: Inspection is the foundation for every other action and delivers value without requiring repair or delivery configuration.

**Independent Test**: Select a valid EPUB and several malformed EPUB fixtures, run `Page Forge: Inspect EPUB`, and verify that each original remains byte-for-byte unchanged while receiving an individual health state and structured findings.

**Acceptance Scenarios**:

1. **Given** one or more readable `.epub` files selected in Finder, **When** the user runs the inspection command, **Then** every file is inspected locally and receives an individual detailed report.
2. **Given** no supported file is selected in Finder, **When** the user runs the inspection command, **Then** the user can choose one or more EPUB files with a file picker.
3. **Given** a structurally valid EPUB 2 or EPUB 3 file, **When** inspection completes, **Then** the report identifies it as `Healthy` unless a concrete compatibility finding warrants another state.
4. **Given** an EPUB with detectable faults, **When** inspection completes, **Then** every fault includes a stable code, severity, category, title, description, location when available, repairability, and recommended repair when applicable.
5. **Given** a non-EPUB file, an unreadable file, or a `.epub` that is not a valid archive, **When** inspection is attempted, **Then** that item is rejected with a clear, specific result and no other selected item is interrupted.

---

### User Story 2 - Prepare a Safe Repaired Copy (Priority: P1)

As a Kindle user, I want to review a deterministic repair plan and create a repaired EPUB copy so that common structural faults can be fixed without risking my original book.

**Why this priority**: Safe preparation is the core product outcome and converts diagnosis into a usable Kindle-ready file.

**Independent Test**: Inspect a fixture containing only safe, deterministic faults, review and confirm its plan, then verify that a collision-safe repaired copy is created, the original hash is unchanged, and the copy is fully revalidated.

**Acceptance Scenarios**:

1. **Given** an EPUB classified as `Repairable`, **When** the user runs `Page Forge: Prepare EPUB for Kindle`, **Then** the extension presents a repair plan before creating any output.
2. **Given** a repair plan, **When** the user reviews it, **Then** the plan identifies every repair operation, the findings it addresses, unresolved findings and reasons, and the predicted output name.
3. **Given** a confirmed plan containing only permitted repairs, **When** preparation succeeds, **Then** a new `-kindle-ready.epub` copy is created without changing the original or unrelated book content.
4. **Given** the default output path already exists, **When** preparation starts, **Then** an unused alternative path is selected without overwriting or removing any existing file.
5. **Given** a repaired copy has been written, **When** preparation continues, **Then** the complete inspection runs again and the final report distinguishes resolved, remaining, and newly introduced findings.
6. **Given** revalidation finds a new `Error` or `Critical` finding, **When** results are compared, **Then** preparation is reported as unsuccessful and the output is not presented as Kindle-ready.
7. **Given** a successful repaired copy, **When** the result is shown, **Then** the user can reveal it, copy its path, open its containing folder, view its final report, or start the separate send command.

---

### User Story 3 - Refuse Unsafe or Ambiguous Changes (Priority: P1)

As a user handling an untrusted ebook, I want dangerous archives and ambiguous repairs to be refused so that Page Forge cannot damage my files, execute book content, or make editorial decisions on my behalf.

**Why this priority**: Safety is a prerequisite for processing arbitrary local archives and for trusting any generated copy.

**Independent Test**: Inspect malicious, excessive, encrypted, and ambiguous fixtures and verify deterministic `Unsafe` or `Needs Review` outcomes, no content execution, no repaired final file, and actionable findings.

**Acceptance Scenarios**:

1. **Given** an archive containing traversal, absolute paths, duplicate entries, suspicious compression, excessive resources, external XML entities, or equivalent unsafe structures, **When** inspection reaches the applicable safety check, **Then** processing is bounded or stopped and the file is classified `Unsafe` with specific findings.
2. **Given** encrypted or DRM-protected content, **When** it is detected, **Then** Page Forge does not decrypt, inspect protected payloads, or repair the book and reports why processing cannot continue.
3. **Given** multiple plausible package documents or cover candidates, **When** preparation is requested, **Then** Page Forge reports `Needs Review` and does not choose one automatically.
4. **Given** a fault whose repair could alter text, reading order, navigation meaning, styling, metadata, scripts, fonts, or chapter inclusion, **When** a repair plan is generated, **Then** the fault remains unrepaired with a reason.
5. **Given** scripts, macros, executable resources, or active content within an EPUB, **When** the file is inspected, **Then** none of that content is executed and compatibility risks are reported.

---

### User Story 4 - Send Explicitly to Kindle (Priority: P2)

As a Kindle user, I want to send a healthy or prepared EPUB using my own email configuration, or continue through Amazon's official manual flow, so that delivery remains explicit and under my control.

**Why this priority**: Delivery completes the workflow, but inspection and preparation remain useful without it.

**Independent Test**: Use `Page Forge: Send EPUB to Kindle` with valid and invalid delivery configurations, a healthy file, and a repairable file; verify explicit confirmation, single-file attachment behavior, redacted errors, and the manual fallback.

**Acceptance Scenarios**:

1. **Given** a healthy or successfully prepared EPUB and valid email settings, **When** the user explicitly confirms sending, **Then** only that chosen file is attached and progress concludes with a clear success or failure result.
2. **Given** a repairable EPUB, **When** the user starts the send command, **Then** Page Forge offers preparation and requires review and confirmation before any later send action.
3. **Given** a `Needs Review`, `Unsupported`, or `Unsafe` EPUB, **When** sending is attempted, **Then** automatic delivery is blocked and the reason is shown.
4. **Given** missing or invalid email settings, **When** the user attempts automatic delivery, **Then** no message is sent and the user can reveal the EPUB or open the official Send to Kindle page.
5. **Given** a network failure, rejected attachment, invalid credentials, or cancellation, **When** delivery ends, **Then** the user receives a sanitized result that contains no password or other secret.
6. **Given** inspection or preparation alone, **When** it completes, **Then** no book is transmitted unless the user separately initiates and confirms delivery.

---

### User Story 5 - Process and Recover a Batch (Priority: P2)

As a user with multiple ebooks, I want each EPUB processed independently and long work cancellable so that one bad item does not lose other results or leave partial files.

**Why this priority**: Finder selection naturally supports batches, and isolation makes the workflow reliable for mixed-quality collections.

**Independent Test**: Process a batch containing valid, repairable, unsupported, unsafe, and unreadable fixtures; cancel during reconstruction and delivery; verify individual results, retry of failed items, cleanup, and preservation of completed outputs.

**Acceptance Scenarios**:

1. **Given** multiple selected EPUBs with different outcomes, **When** inspection or preparation runs, **Then** each file receives an independent status, report, and output where applicable.
2. **Given** one item fails, **When** batch processing continues, **Then** remaining items are still attempted unless the user cancels the operation.
3. **Given** a completed batch with failures, **When** results are shown, **Then** the user can retry only failed items.
4. **Given** cancellation during reconstruction, **When** cancellation takes effect, **Then** the original and previous outputs remain intact, temporary data is removed when safe, and no partial file is presented as final.
5. **Given** cancellation during delivery, **When** cancellation takes effect before SMTP message data begins, **Then** no file is sent and the delivery result is `cancelled`.
6. **Given** cancellation or connection loss after SMTP message data may have begun, **When** server acceptance cannot be determined, **Then** the result is `delivery_unknown`, no automatic retry occurs, and any later send requires a new explicit action with a duplicate warning.

---

### User Story 6 - Install One Focused Product (Priority: P3)

As a Raycast user, I want Page Forge to install as one small public extension without companion software so that the feature works without maintaining a separate ebook application or toolchain.

**Why this priority**: This establishes the new product boundary and is required for publication, while the preceding stories define the direct user workflows.

**Independent Test**: Install the packaged extension on a supported macOS system with Raycast but without Calibre, Java, Python, Homebrew, EPUBCheck, local services, or helper applications; verify that only the three specified commands are exposed and all core fixtures can be inspected or prepared.

**Acceptance Scenarios**:

1. **Given** Raycast on a supported macOS system, **When** Page Forge is installed, **Then** inspection and preparation work without additional user-installed software or downloaded executables.
2. **Given** the installed extension, **When** its commands are listed, **Then** only `Page Forge: Inspect EPUB`, `Page Forge: Prepare EPUB for Kindle`, and `Page Forge: Send EPUB to Kindle` are provided by the first version.
3. **Given** the final repository, **When** its production, test, configuration, asset, and documentation surfaces are reviewed, **Then** no independently built legacy application, old distribution artifact, Calibre integration, format conversion, or conflicting product documentation remains.
4. **Given** a prospective user or reviewer, **When** they read the project documentation, **Then** they can identify installation steps, commands, privacy behavior, limitations, supported files, repair policy, and email delivery setup.

### Edge Cases

- A file has an `.epub` extension but is not a ZIP, is an empty ZIP, or is a valid ZIP that is not an EPUB.
- A file cannot be read, its source is on an external volume, or its destination directory cannot be written.
- A source filename contains Unicode; internal names contain Unicode, spaces, reserved characters, malformed encodings, or case mismatches.
- An EPUB is version 2, version 3, fixed-layout, scripted, interactive, empty, encrypted, or DRM-protected.
- `mimetype` is absent, compressed, not first, duplicated, or has the wrong content.
- `META-INF/container.xml` or its referenced package document is missing, malformed, unsafe, or inconsistent.
- The archive contains no OPF, one discoverable OPF, or multiple plausible OPFs.
- The package has missing essential metadata, malformed manifest or spine data, duplicate IDs, missing resources, incorrect media types, invalid reading order, missing navigation, no identifiable cover, or multiple plausible covers.
- XHTML or XML is malformed; relevant files or chapters are empty; internal links or image, stylesheet, and font references are missing, external, or differ only by case.
- The archive contains traversal paths, absolute paths, escaping `..` segments, duplicate entries, symlinks or equivalents, executable content, external entities, suspicious compression, too many entries, oversized entries, or excessive expanded size.
- Images or other resources are unusually large, and the EPUB is near a configured delivery attachment limit.
- An output name already exists, including multiple previously generated alternatives.
- Cancellation occurs during inspection, archive reconstruction, post-repair validation, or delivery.
- Delivery encounters missing settings, malformed addresses, unsupported security settings, authentication failure, network interruption, timeout, or server-side attachment rejection.
- A batch mixes healthy, repairable, ambiguous, unsupported, unsafe, unreadable, failed, cancelled, and successfully prepared items.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Page Forge MUST be delivered as one public Raycast extension for macOS and MUST expose exactly the three first-version commands named in this specification.
- **FR-002**: Each command MUST accept one or more Finder-selected files and MUST offer a multi-file picker when no supported Finder selection is available.
- **FR-003**: Files whose names do not end in `.epub`, using case-insensitive matching, MUST be rejected clearly before EPUB processing.
- **FR-004**: Each selected file MUST be handled independently so that one rejection, failure, or cancellation result does not erase completed results for other files.
- **FR-005**: `Inspect EPUB` MUST analyze supported inputs without modifying, renaming, moving, or deleting the original file.
- **FR-006**: Every inspected file MUST receive exactly one derived health state: `Healthy`, `Repairable`, `Needs Review`, `Unsupported`, or `Unsafe`.
- **FR-007**: Health-state precedence MUST be `Unsafe`, `Unsupported`, `Needs Review`, `Repairable`, then `Healthy`; a higher-precedence applicable state MUST win while all underlying findings remain visible.
- **FR-008**: `Healthy` MUST mean no relevant unresolved warning, error, or critical finding; informational findings MAY remain. `Repairable` MUST mean all relevant faults have safe deterministic repairs. `Needs Review` MUST mean at least one relevant fault is ambiguous or not safely repairable. `Unsupported` MUST mean the input is not a supported EPUB. `Unsafe` MUST mean processing would violate a safety bound or encounter dangerous or protected content.
- **FR-009**: Every finding MUST include a stable code, one of the severities `Info`, `Warning`, `Error`, or `Critical`, a category, title, description, internal path or location when available, automatic-repair eligibility, a recommended repair when applicable, an applied-repair reference when repaired, and its revalidation result when comparison is available.
- **FR-010**: Reports MUST derive health from concrete findings and MUST NOT replace those findings with an unexplained aggregate score.
- **FR-011**: Container inspection MUST determine whether the input is a valid completely readable ZIP and detect duplicate entries and invalid internal paths.
- **FR-012**: Container inspection MUST verify that `mimetype` exists, is the first archive entry, is stored without compression, and contains exactly `application/epub+zip`.
- **FR-013**: Container inspection MUST verify that `META-INF/container.xml` exists, is interpretable, identifies a package document, and references an existing package document.
- **FR-014**: Package inspection MUST verify the existence and interpretability of an OPF package document, essential metadata, manifest, spine, unique IDs, resource references, media types, spine-to-manifest references, required navigation, identifiable cover information, and structurally valid reading order.
- **FR-015**: Content inspection MUST detect malformed XHTML or XML, broken internal links, missing image, stylesheet, and font references, case-mismatched paths, unexpected remote resources, relevant empty files, chapters without useful content, encrypted or protected content, and scripts or interactive resources with potential Kindle limitations.
- **FR-016**: Inspection MUST identify external local-file references and MUST NOT access content outside the selected EPUB.
- **FR-017**: `Prepare EPUB for Kindle` MUST inspect the original and create a reviewable repair plan before writing a final output.
- **FR-018**: A repair plan MUST list the findings to be repaired, the operation for each repair, findings left unchanged with reasons, and the predicted collision-safe output path.
- **FR-019**: Preparation MUST require explicit user confirmation of the repair plan and MUST NOT trigger delivery.
- **FR-020**: Automatic repair MUST be limited to unambiguous creation or normalization of `mimetype`; compliant ordering and storage of `mimetype`; reconstruction of `META-INF/container.xml` when exactly one valid OPF is unambiguous; correction of evident media types from file extensions; correction of references with exactly one matching target; normalization of equivalent internal paths; meaning-preserving XML encoding normalization; and standards-compliant archive reconstruction.
- **FR-021**: Automatic repair MUST preserve every archive resource and content item not explicitly changed by the confirmed plan.
- **FR-022**: Automatic repair MUST NOT choose among plausible OPFs or covers; remove chapters, fonts, scripts, or resources; rewrite textual content; deeply reconstruct a manifest; infer navigation; destructively repair XHTML; alter editorial metadata; or change CSS for aesthetic reasons.
- **FR-023**: Faults covered by FR-022 MUST be reported as `Needs Review` with an explanation rather than changed automatically.
- **FR-024**: Preparation MUST create a new file beside the source by default, using `<original-base>-kindle-ready.epub` and a deterministic unused suffix when that path exists.
- **FR-025**: Preparation MUST never silently overwrite any path and MUST keep the original byte-for-byte unchanged regardless of success, failure, or cancellation.
- **FR-026**: A final output MUST become visible to the user only after archive reconstruction completes successfully; interrupted or failed temporary output MUST NOT appear as a valid final EPUB.
- **FR-027**: Every generated copy MUST undergo the complete inspection defined for originals before preparation can be reported successful.
- **FR-028**: The comparison report MUST identify original findings, repairs applied, resolved findings, remaining findings, newly introduced findings, and the final health state.
- **FR-029**: Preparation MUST be reported unsuccessful if revalidation finds any newly introduced `Error` or `Critical` finding, and no copy may be presented as Kindle-ready or eligible for delivery unless its final health is `Healthy`.
- **FR-030**: After successful preparation, users MUST be able to reveal the output in Finder, copy its path, open its containing folder, view its final report, and start the separate send flow.
- **FR-031**: `Send EPUB to Kindle` MUST accept only a user-chosen EPUB that is `Healthy` or has completed preparation without a failed revalidation.
- **FR-032**: If a chosen file is `Repairable`, the send flow MUST offer preparation first; it MUST block automatic delivery for `Needs Review`, `Unsupported`, and `Unsafe` files.
- **FR-033**: Automatic Kindle delivery MUST use user-provided sender address, SMTP host, port, security mode, username, application password, and personal `@kindle.com` address as applicable.
- **FR-034**: Delivery settings and the selected file MUST be validated before transmission; invalid or incomplete settings MUST prevent sending and produce an actionable result.
- **FR-035**: Every delivery MUST require an explicit user action after file and destination review, attach only the selected EPUB, show progress, and end with `submitted`, `failed`, `cancelled`, or `delivery_unknown`; the unknown result applies when SMTP acceptance cannot be determined and MUST NOT trigger automatic retry.
- **FR-036**: Credentials MUST never appear in logs, reports, diagnostic details, or error messages and MUST never be stored remotely.
- **FR-037**: When automatic delivery is unavailable, users MUST be able to reveal the EPUB and open Amazon's official Send to Kindle page without blocking inspection or preparation.
- **FR-038**: Inspection and repair MUST occur entirely on the local device; no book content, metadata, filename, full source path, finding, or report MAY be sent to a backend, analytics service, third-party API, AI model, or telemetry system.
- **FR-039**: The only permitted book transmission MUST be an explicit delivery action to the user's configured Kindle address.
- **FR-040**: Batch results MUST show each file's state, report, output path when applicable, and operation result; users MUST be able to retry only failed items.
- **FR-041**: Users MUST be able to cancel long inspection, repair, and delivery operations; cancellation MUST preserve originals, completed outputs, and pre-existing files.
- **FR-042**: Cancellation or failure MUST remove temporary files when safe and MUST never send or present an incomplete output as valid.
- **FR-043**: Reports MUST be available within the Raycast interface. Copying a concise text or Markdown report MAY be offered, but generated PDF or HTML reports are not required.
- **FR-044**: The final repository MUST contain only the Raycast extension product and supporting tests, fixtures, documentation, and publication assets required for it.
- **FR-045**: The final repository MUST remove production and distribution surfaces for the prior desktop application, Swift and SwiftUI code, Xcode projects and workspaces, desktop-only assets, Calibre discovery and commands, conversion, non-EPUB formats, old scripts, signing and notarization, app updates, obsolete tests, old generated artifacts, unused dependencies, and conflicting documentation.
- **FR-046**: Domain rules retained from the prior product MUST conform to this specification and MUST have corresponding focused tests; no legacy implementation MAY be retained solely as a fallback.
- **FR-047**: The test corpus MUST include small fixtures for valid EPUB, valid EPUB 2, valid EPUB 3, invalid ZIP, non-EPUB ZIP, missing/compressed/misordered/incorrect `mimetype`, missing `container.xml`, missing OPF, ambiguous OPFs, invalid manifest, invalid spine, duplicate ID, missing resource, incorrect media type, broken internal link, case mismatch, malformed XHTML, missing cover, ambiguous covers, encryption, traversal path, absolute path, duplicate entry, suspicious compression, excessive entry count, and oversized individual entry.
- **FR-048**: Every inspection rule and every automatic repair rule MUST have focused automated acceptance coverage using an applicable fixture.

### Non-Functional Requirements

- **NFR-001 - Self-containment**: The installed product MUST require only Raycast and dependencies packaged with the extension; it MUST NOT require or download Calibre, EPUBCheck, Java, Python, Homebrew, command-line tools, helper applications, native executables, or local services.
- **NFR-002 - Archive safety**: Inputs MUST be rejected as `Unsafe` before unsafe extraction or repair when they contain traversal or absolute paths, escaping segments, invalid names, duplicates, symlinks or equivalent links, suspicious compression, excessive entry count, an oversized individual entry, excessive total expanded size, or structures that exceed bounded memory or processing limits.
- **NFR-003 - Explicit safety limits**: A selected EPUB MUST NOT exceed 200 MB compressed size, 10,000 archive entries, 100 MB for any one expanded entry, 1 GB total expanded size, or a 100:1 aggregate or per-entry expansion ratio. Any XML document MUST NOT exceed 10 MB or 64 levels of nesting. Inspection or repair of one file MUST stop safely after 120 seconds. An input that reaches an inspection safety limit MUST produce an `Unsafe` report; a timeout while reconstructing or revalidating an already inspected file MUST produce a safe preparation failure with no final output. Boundary tests MUST cover values immediately below, at, and above every limit.
- **NFR-004 - XML safety**: XML inspection MUST reject external entities and external resource resolution, bound recursive or malformed structures, and avoid reading local or remote resources referenced by XML.
- **NFR-005 - Active-content safety**: Page Forge MUST never execute scripts, macros, executables, embedded commands, or any other active content found in an EPUB.
- **NFR-006 - Responsiveness**: During supported inspection, repair, and delivery work, users MUST retain access to progress and cancellation controls, and the Raycast interface MUST not become unresponsive for more than one second at a time.
- **NFR-007 - Performance**: At least 95% of healthy EPUBs up to 50 MB and 2,000 entries in the acceptance corpus MUST produce an inspection result within 10 seconds on a supported reference Mac under normal local load.
- **NFR-008 - Batch capacity**: A batch of 20 supported EPUBs within individual safety limits MUST complete with 20 independent results and without failure caused solely by batch size.
- **NFR-009 - Privacy**: Page Forge MUST collect no analytics or hidden usage data, retain no unnecessary book copies, avoid logging book excerpts, filenames, or full source paths, and limit reports to concise structural evidence and internal EPUB paths.
- **NFR-010 - Credential protection**: Delivery credentials MUST be held in secure local settings, redacted from all user-visible and diagnostic output, and used only for the explicitly requested transmission.
- **NFR-011 - Publication readiness**: The extension MUST pass all required package validation, build, lint, type checking, tests, metadata review, license review, and documentation checks before Store submission.
- **NFR-012 - Accessibility**: All three commands and their primary actions, reports, confirmations, progress, cancellation, and recovery paths MUST be fully usable by keyboard and expose meaningful labels through Raycast's supported accessibility behavior.

### Constitution Constraints *(mandatory)*

- **CC-001**: The feature MUST directly support the EPUB-to-Kindle pipeline and accept EPUB only.
- **CC-002**: The feature MUST keep processing local, preserve originals, and require explicit delivery intent.
- **CC-003**: The feature MUST NOT introduce conversion, DRM removal, content editing, reading, library, cloud, account, desktop-app, AI, or generic-document scope.
- **CC-004**: The feature MUST use the Raycast product surface and preserve a small keyboard-first command set.
- **CC-005**: The feature MUST define safe, bounded untrusted-archive processing and keep the interface responsive.
- **CC-006**: The feature MUST produce structured reports and failures and test every audit rule and automatic repair with fixtures.
- **CC-007**: The feature MUST NOT add Calibre, EPUBCheck, executable dependencies, external processing services, helper processes, or user-installed dependencies.

### Key Entities

- **Selected EPUB**: A user-chosen local file, identified by display name and source location, whose original bytes are immutable throughout the workflow.
- **Archive Entry**: An internal EPUB resource with a normalized path, declared and detected media information, compressed and expanded sizes, and safety characteristics.
- **Finding**: A concrete inspection observation with stable code, severity, category, title, description, optional internal location, repairability, recommended repair, optional applied-repair reference, and revalidation result when available.
- **Health Report**: A derived health state plus the complete ordered findings for one EPUB and the inspection outcome.
- **Repair Plan**: The proposed output path, deterministic operations to apply, findings addressed, and unresolved findings with reasons, reviewed before preparation.
- **Applied Repair**: Evidence that one planned operation was performed, including the finding addressed and internal resources changed.
- **Revalidation Comparison**: The relationship between original and repaired reports, grouping resolved, remaining, and newly introduced findings and determining preparation success.
- **Batch Item Result**: One selected EPUB's independent inspection, preparation, cancellation, or failure result, including report and output when applicable.
- **Delivery Configuration**: User-provided sender, server, security, credential, and Kindle destination settings used only for explicit email delivery.
- **Delivery Result**: The chosen file, sanitized progress outcome, and submitted, failed, cancelled, or delivery-unknown status, without credentials or book content.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In acceptance testing, 100% of valid EPUB 2 and EPUB 3 fixtures receive a detailed health report without any byte change to the original.
- **SC-002**: In acceptance testing, 100% of fixtures containing only permitted deterministic faults produce a separate repaired copy, and every copy receives a complete post-repair report.
- **SC-003**: Across all repair tests, 100% of originals and pre-existing destination files remain byte-for-byte unchanged, including after failure and cancellation.
- **SC-004**: In acceptance testing, 100% of ambiguous OPF, cover, navigation, editorial, and destructive-content cases are left unchanged and classified for review rather than repaired arbitrarily.
- **SC-005**: Every required malicious or excessive fixture is rejected or safely bounded before external access, content execution, unsafe extraction, or final output creation.
- **SC-006**: At least 95% of supported EPUBs up to 50 MB and 2,000 entries return an initial result within 10 seconds on the reference acceptance environment, while progress and cancellation remain available.
- **SC-007**: A 20-file mixed batch produces an individual result for every item, and a failure in one item does not prevent the other 19 from being attempted.
- **SC-008**: 100% of successful preparations report the exact output path and provide all five result actions: reveal file, copy path, open folder, view final report, and start delivery.
- **SC-009**: No acceptance test transmits a book without a separate explicit send action and confirmation; no inspection or preparation test produces network transmission.
- **SC-010**: Email delivery tests attach exactly one user-selected eligible EPUB, report success or sanitized failure, and expose zero credential values in logs, reports, or errors.
- **SC-011**: A first-time Raycast user can complete inspect, review, and prepare for a healthy or repairable fixture in under three minutes using only in-product labels and actions.
- **SC-012**: The product installs and completes core inspection and preparation acceptance tests on a supported Mac without any software beyond Raycast and the installed extension package.
- **SC-013**: Repository review finds zero functional or documentary references that instruct users to use the removed desktop application, Calibre, conversion, or unsupported ebook formats.
- **SC-014**: Every inspection and repair rule maps to at least one passing focused test and every required fixture category is represented in the test corpus.
- **SC-015**: Before publication review, all required package validation, build, lint, type checking, test, license, metadata, privacy, and documentation checks pass with no unresolved errors.

## Assumptions

- The target user already has Raycast installed on a supported macOS version and has access to local EPUB files they are permitted to process.
- Finder selection is preferred when supported files are present; otherwise the file picker is the fallback. A mixed Finder selection rejects unsupported items while continuing with valid EPUBs.
- Generated files are placed beside the original by default. If that location is not writable, preparation fails clearly rather than silently choosing a distant location.
- `Healthy` permits informational compatibility notes but no unresolved warning, error, or critical finding.
- Fixed-layout and scripted EPUBs are inspectable, but their characteristics produce compatibility findings and are not automatically removed or rewritten.
- Encrypted or DRM-protected books are treated as `Unsafe` for processing and are never decrypted or repaired.
- Safety limits follow NFR-003 and are independent of delivery-provider limits; provider attachment restrictions may be lower and must be reported before or during delivery.
- Email delivery depends on the user's provider, credentials, Amazon-approved sender configuration, network, and attachment limits; Page Forge can validate configuration and report outcomes but cannot guarantee provider acceptance.
- The official manual Send to Kindle flow remains controlled by Amazon; Page Forge opens the official destination but does not automate the website or authenticate with Amazon.
- Reports remain in the Raycast interface and may be copied as concise text or Markdown only if this does not expand the first-version scope.
- The repository migration is destructive with respect to obsolete product code and documentation: no parallel legacy application is retained.

## Dependencies

- A supported Raycast installation on macOS.
- Local read access to selected EPUBs and write access to their destination directories for preparation.
- User-supplied email delivery settings, network access, and an Amazon-approved sender only when automatic delivery is explicitly requested.
- Continued availability of Amazon's official Send to Kindle page for the manual fallback.

## Out of Scope

- A standalone desktop application; Swift, SwiftUI, Electron, Tauri, mobile, Windows, or Linux product surfaces.
- EPUB reading, full-book preview, editing, library management, catalogs, or visual Kindle-rendering validation.
- Format conversion or support for PDF, MOBI, AZW, AZW3, KFX, or generic documents.
- DRM removal, bypass, decryption, or interpretation of protected payloads.
- Editorial rewriting, translation, AI, chat, agents, automatic aesthetic changes, or inferred content and metadata.
- User accounts, cloud synchronization, remote storage, backend processing, analytics, or telemetry.
- Calibre, installed EPUBCheck, Java, Python, Homebrew, local services, helper applications, executable installation, runtime binary downloads, or other user-installed processing tools.
- Amazon login or website automation, direct Amazon upload automation, remote credential storage, or guaranteed delivery-provider acceptance.
- PDF, HTML, or other standalone report generation in the first version.
