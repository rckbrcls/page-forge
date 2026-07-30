# Implementation Inventory: App Feedback and Diagnostics

## Product boundary

- Primary screens: `Delivery Setup`, `Send Book`
- Auxiliary Settings tabs: `Delivery`, `Shortcut`
- Standard dependency-owned UI: Sparkle update cycle
- Prohibited additions: third primary screen, diagnostic history, telemetry,
  hidden upload, custom diagnostic log files, diagnostic database, helper
  process, or new source dependency
- The bounded send history is owned by Feature 009 and remains separate from
  diagnostic recording and copying.

## Dependency baseline

- Swift 6.0 with complete concurrency checking
- macOS 26.0+
- KeyboardShortcuts 3.0.1
- Sparkle 2.9.2
- ZIPFoundation 0.9.19
- swift-nio 2.86.0
- swift-nio-ssl 2.35.0

## Accepted actions

| Action | Owning surface | Terminal feedback owner | Story |
|---|---|---|---|
| Restore application | App bootstrap | `AppModel` | US1 |
| Save delivery setup | Delivery Setup / Settings | `AppModel` | US1 |
| Delete delivery setup | Delivery Settings | `AppModel` | US1 |
| Save shortcut | Shortcut Settings | `ShortcutService` / `AppModel` | US1 |
| Clear shortcut | Shortcut Settings | `ShortcutService` / `AppModel` | US1 |
| Add books | Send Book | `AppModel` / `PipelineActor` | US1 |
| Remove book | Send Book | `AppModel` / `PipelineActor` | US1 |
| Clear batch | Send Book | `AppModel` / `PipelineActor` | US1 |
| Confirm batch | Confirmation sheet | `AppModel` | US1 |
| Prepare book | Send Book row | `PipelineActor` / `AppModel` | US1 |
| Send book | Send Book row | `PipelineActor` / `AppModel` | US1 |
| Send batch | Send Book | `PipelineActor` / `AppModel` | US1 |
| Cancel operation | Send Book | `PipelineActor` / `AppModel` | US1 |
| Dismiss confirmation | Confirmation sheet | `AppModel` | US1 |
| Copy error details | Failure disclosure | `AppModel` | US4 |
| Check for updates | App command | Sparkle standard UI | US1 |

## Failure families and current construction sites

| Family | Stable codes | Construction owners |
|---|---|---|
| Intake | `intake.capacity`, `intake.changed`, `intake.duplicate`, `intake.failed`, `intake.size`, `intake.unreadable`, `intake.unsupported`, `pdf.cancelled`, `pdf.read`, `pdf.signature`, `pdf.size`, `pdf.structure`, `unexpected.intake` | `BookIntakeService.swift`, `PDFEligibilityService.swift` |
| Archive | `archive.duplicate-path`, `archive.encrypted`, `archive.entry-limit`, `archive.entry-unavailable`, `archive.expansion-ratio`, `archive.extract`, `archive.open`, `archive.size-limit`, `archive.timeout`, `archive.unsafe-path`, `archive.unsupported-entry`, `unexpected.archive` | `ZIPFoundationEPUBArchive.swift`, `EPUBArchiveWriter.swift` |
| XML | `xml.byte-limit`, `xml.cancelled`, `xml.external-entity`, `xml.invalid`, `xml.structure-limit`, `xml.text-limit`, `xml.timeout`, `unexpected.xml` | `BoundedXMLParser.swift` |
| Audit | `unexpected.audit`; rule findings remain the closed `FindingCode` set in `AuditModels.swift` | `EPUBAuditEngine.swift`, `EPUBRepairEngine.swift` |
| Repair | `repair.attachment-size`, `repair.blocked`, `repair.cancelled`, `repair.container`, `repair.entry-create`, `repair.entry-missing`, `repair.failed`, `repair.invalid-plan`, `repair.media-type`, `repair.mimetype`, `repair.output-create`, `repair.path`, `repair.precondition`, `repair.reference`, `repair.revalidation-failed`, `repair.timeout`, `repair.unsupported-action`, `repair.write`, `repair.xml`, `unexpected.repair` | `EPUBRepairEngine.swift`, `EPUBArchiveWriter.swift` |
| Filesystem/application | `workspace.collision`, `workspace.copy`, `workspace.invalid-marker`, `workspace.invalid-path`, `workspace.marker`, `workspace.partial-create`, `workspace.promote`, `workspace.size-limit`, `workspace.timeout`, `pipeline.missing-staged-source`, `pipeline.preparation-result`, `clipboard.write`, `startup.bootstrap`, `update.configuration`, `unexpected.filesystem` | `WorkspaceStore.swift`, `PipelineActor.swift`, `AppModel.swift` |
| Credential | `delivery-setup.validation`, `credential.delete`, `credential.empty`, `credential.missing`, `credential.read`, `credential.save`, `credential.ui-test`, `preferences.invalid`, `preferences.invalid-revision`, `unexpected.credential` | `KeychainCredentialStore.swift`, `DeliveryPreferencesStore.swift`, `DeliverySetupService.swift`, `AppDependencies.swift` |
| Delivery | `delivery.failed`, `mime.header-injection`, `smtp.attachment-size`, `smtp.auth-unavailable`, `smtp.authentication-rejected`, `smtp.command-size`, `smtp.connection-closed`, `smtp.data-rejected`, `smtp.delivery-unknown`, `smtp.ehlo`, `smtp.final-acceptance-rejected`, `smtp.greeting`, `smtp.recipient-rejected`, `smtp.reply-code`, `smtp.reply-count`, `smtp.reply-format`, `smtp.reply-line`, `smtp.secure-ehlo`, `smtp.secure-channel`, `smtp.sender-rejected`, `smtp.starttls`, `smtp.starttls-state`, `smtp.starttls-unavailable`, `smtp.timeout`, `smtp.transport`, `smtp.ui-test-rejected`, `unexpected.delivery` | `BookDeliveryService.swift`, `MIMEMessageEncoder.swift`, `SMTPReplyDecoder.swift`, `SMTPStateMachine.swift`, `NIOSMTPClient.swift`, `AppDependencies.swift` |
| Shortcut | `shortcut.conflict`, `unexpected.shortcut` | `ShortcutService.swift` |

## Existing `SanitizedFailure` boundaries

- `BookSender/App/AppDependencies.swift`
- `BookSender/Application/Delivery/BookDeliveryService.swift`
- `BookSender/Application/Delivery/DeliverySetupService.swift`
- `BookSender/Application/Intake/BookIntakeService.swift`
- `BookSender/Application/Intake/PDFEligibilityService.swift`
- `BookSender/Application/Pipeline/PipelineActor.swift`
- `BookSender/Domain/Repair/EPUBRepairEngine.swift`
- `BookSender/Adapters/Archive/EPUBArchiveWriter.swift`
- `BookSender/Adapters/Archive/ZIPFoundationEPUBArchive.swift`
- `BookSender/Adapters/Credentials/DeliveryPreferencesStore.swift`
- `BookSender/Adapters/Credentials/KeychainCredentialStore.swift`
- `BookSender/Adapters/Filesystem/WorkspaceStore.swift`
- `BookSender/Adapters/SMTP/MIMEMessageEncoder.swift`
- `BookSender/Adapters/SMTP/NIOSMTPClient.swift`
- `BookSender/Adapters/SMTP/SMTPReplyDecoder.swift`
- `BookSender/Adapters/SMTP/SMTPStateMachine.swift`
- `BookSender/Adapters/XML/BoundedXMLParser.swift`

`DiagnosticCode.expectedFamily` defines the one legal family for every code.
`SanitizedFailure` enforces that relationship. `FailurePresentationTests` runs
the complete `DiagnosticCode.allCases` set through the catalog so adding a code
without a specific title, summary, explanation, impact, and recovery contract
is a test-visible change.

## Action lifecycle coverage

| Actions | Implemented state owner | Focused evidence |
|---|---|---|
| Restore application; check for updates | `AppModel`; Sparkle remains update UI owner | `AppModelSetupTests`, `FirstBookJourneyUITests` |
| Create, edit, replace password, and delete setup | `AppModel`, `DeliverySetupView` | `AppModelSetupTests`, `SettingsDeliveryTests`, `FirstBookJourneyUITests` |
| Save, clear, and recover shortcut | `ShortcutService`, `ShortcutSettingsView` | `ShortcutServiceTests`, `SettingsUITests`, `GlobalShortcutUITests` |
| Add, remove, clear, confirm, dismiss, prepare, cancel, send, and retry | `AppModel`, `PipelineActor`, Send Book views | `FirstBookJourneyTests`, `PipelineCancellationTests`, `BatchSendUITests`, `RecoveryJourneyUITests` |
| Copy current error details | `AppModel`, `FailureDetailView` | `AppModelDiagnosticsTests`, `AppKitDiagnosticClipboardTests`, `RecoveryJourneyUITests` |

Every accepted lifecycle uses a new UUID, acknowledgement or progress, and one
terminal state. Setup success remains persistent after the password draft is
cleared. Repeated identical failures consolidate into one visible notice with
an incremented occurrence count. A failed-only retry gets a new lifecycle and
never selects `delivery_unknown` items.

## Recovery reconciliation

| Recovery action | Applied to | Evidence |
|---|---|---|
| `Edit Setup` | validation, credential, preferences, TLS/authentication, permanent sender/recipient setup failures | exhaustive catalog test; setup and SMTP state-machine tests |
| `Choose Another File` | unsupported/unreadable intake, PDF, MIME, and attachment input failures | intake, PDF, and catalog tests |
| `Review Details` | archive, XML, audit, repair, workspace, and permanent DATA/final rejection | archive/XML/repair/workspace and SMTP phase tests |
| `Retry` | conclusive retry-safe transient or transport failures; UI selects failed items only | retry, SMTP state-machine, and recovery journey tests |
| `Check Kindle Before Retrying` | post-transmission uncertainty only | uncertainty, cancellation, and recovery journey tests |
| `Choose Another Shortcut` | shortcut conflict or unexpected shortcut failure | shortcut service and Settings tests |

## SMTP phase matrix

| Phase | Stable causes and evidence | Certainty and guidance | Controlled evidence |
|---|---|---|---|
| Connecting | socket/channel closure, transport, timeout before greeting | failed; retry safe before data | state machine, uncertainty, and phase UI tests |
| Securing | greeting, EHLO, STARTTLS, TLS channel, post-TLS EHLO | failed; edit setup or retry according to cause | implicit TLS/STARTTLS tests and phase UI tests |
| Authenticating | AUTH unavailable; 530, 534, 535; other 4xx/5xx | credential/account rejection edits setup; transient 4xx may retry | authentication matrix and phase UI tests |
| Sender envelope | MAIL FROM 4xx/5xx | transient retry or permanent setup review | 450/550 matrix and phase UI tests |
| Recipient envelope | RCPT TO 4xx/5xx | transient retry or Kindle address/allow-list setup review | 450/550 matrix and phase UI tests |
| Message data | DATA rejection before bytes; interruption after bytes | conclusive 4xx retry, permanent review, or unknown after bytes | 450/550 and uncertainty tests |
| Final acceptance | response after message terminator | conclusive rejection or unknown if response is lost | 450/550, timeout/closure, and phase UI tests |

`SMTPReplyDecoder` retains only a validated three-digit status and the first
valid enhanced status. Raw provider lines remain transient and never enter
`SanitizedFailure`, `DiagnosticEvent`, unified logging, or copied details.

## Recording, copy, and redaction reconciliation

| Contract | Implementation | Evidence |
|---|---|---|
| One failed/uncertain record per operation | `DiagnosticService.recordOnce` and one typed event key | `DiagnosticServiceTests`, `AppModelDiagnosticsTests` |
| One vetted local sink | `UnifiedDiagnosticRecorder` with fixed subsystem, categories, templates, and `.error`/startup `.fault` levels | `UnifiedDiagnosticRecorderTests`, `PrivacyAuditTests` |
| Explicit write-only copy | `AppKitDiagnosticClipboard` clears then writes plain text without reading | `AppKitDiagnosticClipboardTests`, `RecoveryJourneyUITests` |
| Full canary removal | password, addresses, host, path, filename, book text, MIME bytes, provider prose, and raw platform error are fed through event, presentation, recorder spy, and formatter | `DiagnosticRedactionTests` |
| No new diagnostic persistence or egress | no app diagnostic log, diagnostic history, diagnostic database, telemetry, analytics, upload, or dependency | privacy source scan and static validation |

Copied fields are fixed and ordered: app version, timestamp, event ID, optional
operation ID, action, outcome, code, subsystem, phase, severity, retry
disposition, optional numeric/enhanced provider status, optional setup revision,
optional batch counts, optional transmission state, optional safety-limit
identifier, occurrence count, and optional next step.

## Accessibility and announcement reconciliation

- `ActionFeedbackView` exposes textual title/message, semantic state value, and
  an icon in addition to color.
- Important progress and terminal transitions post one keyed macOS
  accessibility announcement. Unchanged identity/state and repeated occurrence
  updates do not announce again.
- Aggregate batch feedback owns routine progress announcements; per-item rows
  retain outcomes without announcing routine healthy detail.
- Failure disclosure and recovery controls are keyboard reachable, use
  meaningful labels/hints, and keep healthy detail collapsed.
- Reduced Motion uses an identity transition; Increased Contrast and reduced
  transparency journeys keep state text and controls readable.
- Evidence: `ActionFeedbackServiceTests`, `AccessibilityUITests`,
  `SettingsUITests`, `FirstBookJourneyUITests`, and the mixed 20-item
  `BatchSendUITests` journey.

## Validation status

- Implemented source, authored model/adapter/application/UI/UI-test coverage,
  documentation, and non-executing repository checks: complete.
- `git diff --check`, JSON/plist syntax, Swift parser lint, Logger location,
  privacy scans, dependency diff, two-screen/two-tab review, and
  no-diagnostic-history review: passed on 2026-07-30.
- Compilation and unit tests: not run; explicit authorization required.
- UI/accessibility execution: not run; explicit authorization required.
- macOS unified-log runtime inspection: not run; explicit authorization
  required.
- Gmail/Kindle provider acceptance: not run; explicit authorization and
  dedicated non-personal credentials required.
- Release signing, packaging, installation, and publication: unchanged and not
  re-executed by this feature pass.
