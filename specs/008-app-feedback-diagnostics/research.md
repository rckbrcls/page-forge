# Research: App Feedback and Diagnostics

## Scope and evidence

Research covered the current application models, application services, SMTP and
credential adapters, SwiftUI screens, updater composition, privacy checks,
domain/application/adapter tests, UI tests, packaging configuration, and the
active product specifications.

Representative repository evidence was rechecked locally:

- `SanitizedFailure` currently carries only family, code, message, and recovery
  action.
- `FailurePresentationService` maps broad families but returns the failure
  message without a phase-aware catalog.
- `AppModel.saveSetup()` clears the secret draft after success but does not
  publish a durable success confirmation.
- `SMTPStateMachine` maps provider replies at or above 400 to a generic provider
  failure before phase-specific reply handling.
- `SMTPReplyDecoder` retains raw reply lines, while current presentation tests
  correctly assert that raw provider detail is not exposed.
- `PrivacyAuditTests` currently prohibits every `Logger` and `os_log` call in
  production source.
- `BookSenderApp` uses `SPUStandardUpdaterController`, so Sparkle already owns
  standard update-cycle UI.

All technical unknowns needed for planning are resolved below.

## Decision 1: Use Apple unified logging through one vetted adapter

**Decision**: Add one `UnifiedDiagnosticRecorder` backed by `OSLog.Logger`.
Permit `Logger` only in that file and continue to prohibit direct production
logging everywhere else. Use one Book Sender subsystem and fixed categories for
startup, setup, credentials, intake, preparation, shortcut, delivery, and
updates.

**Rationale**: Apple unified logging provides local, system-managed retention
and standard inspection through Console and log tooling. It satisfies the need
to correlate failures after restart without adding an app-owned database, file,
archive, export flow, third screen, or telemetry destination. A single adapter
creates an auditable privacy boundary.

**Alternatives considered**:

- In-memory diagnostics only: rejected because startup and fatal evidence would
  not remain available after restart.
- App-owned rotating text files: rejected because this creates a new storage,
  retention, cleanup, and privacy surface.
- A diagnostics SDK or remote telemetry service: rejected because diagnostics
  must remain local and no new dependency is justified.

**Reference**:
[Apple unified logging](https://developer.apple.com/documentation/os/logging)

## Decision 2: Accept only typed, allow-listed diagnostic evidence

**Decision**: The recorder, formatter, and presentation catalog accept only
domain diagnostic values. Context is a closed typed structure, not
`[String: String]`, `Error`, `NSError`, or arbitrary interpolated text.

**Rationale**: A closed schema makes privacy review deterministic. It prevents
future callers from casually adding paths, filenames, addresses, credentials,
provider prose, book content, or raw exceptions. The same value can safely drive
display, local recording, copied details, and tests.

**Alternatives considered**:

- Redact arbitrary strings at the recorder: rejected because reliable
  after-the-fact redaction is not possible for unknown input.
- Maintain different structures for UI, logs, and clipboard: rejected because
  the copies can drift and leak different information.
- Serialize raw platform errors: rejected because their descriptions and user
  info can contain private or provider-controlled text.

## Decision 3: Translate in adapters and record once at terminal boundaries

**Decision**: Archive, XML, filesystem, Keychain, shortcut, and SMTP adapters
translate raw failures into `SanitizedFailure` plus typed evidence before
returning. The application records failed or uncertain terminal outcomes once
where startup, setup, shortcut, pipeline, or delivery outcomes are consumed.

**Rationale**: Adapters know the technical phase and safe code. Application
boundaries know whether an operation actually ended and can prevent duplicate
records when one failure travels through multiple layers.

**Alternatives considered**:

- Log at every catch site: rejected because one failure would produce duplicate,
  inconsistently redacted records.
- Log only in views: rejected because startup, background, and non-visible
  failures can bypass a view.
- Log only inside adapters: rejected because adapters cannot reliably determine
  final application outcome, cancellation, or `delivery_unknown`.

## Decision 4: Build one stable presentation catalog

**Decision**: Expand `FailurePresentationService` into the only mapping from
stable failure code, family, phase, and retry disposition to user-facing
summary, explanation, recovery action, and technical details. Add a
catalog-completeness test for all typed production failure codes.

**Rationale**: Current messages are distributed across models, services,
adapters, and views. A central catalog prevents a known cause from degrading into
generic text and makes wording, accessibility, and recovery behavior reviewable
without moving technical rules into SwiftUI.

**Alternatives considered**:

- Keep strings at throw sites: rejected because adapter copy becomes UI policy
  and terminology remains inconsistent.
- Map only by broad failure family: rejected because `delivery`, `credential`,
  `archive`, and `filesystem` families each contain materially different
  recovery paths.
- Display raw localized errors for specificity: rejected because they are
  unstable, technical, and potentially private.

## Decision 5: Use one action-feedback lifecycle with bounded announcements

**Decision**: Model supported actions with acknowledged, in-progress, succeeded,
failed, cancelled, partial, and unknown states. Inline feedback uses stable
identities, proportional persistence, deduplication, and one accessibility
announcement for each important identity/state transition.

**Rationale**: The product needs consistent feedback across setup, Settings,
shortcut, batch, cancellation, and updater entry points without a new global
notification center. A stable identity suppresses duplicate visual notices and
screen-reader announcements when observation re-renders an unchanged state.

**Alternatives considered**:

- Use transient toasts for every action: rejected because they can disappear
  before they are perceived and create noisy batch behavior.
- Add a persistent feedback or diagnostic-activity panel: rejected because it
  creates a diagnostic-history surface. The bounded send history is a separate
  Feature 009 capability inside `Send Book`.
- Let each view invent local booleans and messages: rejected because lifecycle,
  timing, and accessibility behavior would diverge.

**Reference**:
[Apple accessibility announcements](https://developer.apple.com/documentation/accessibility/accessibilitynotification/announcement)

## Decision 6: Preserve SMTP phase and safe provider status only

**Decision**: Interpret a provider reply in the active SMTP state before mapping
it to a failure. Retain the three-digit reply code and, when present, only a
syntactically valid enhanced status code. Discard provider prose and protocol
lines. Map authentication/account failures such as 534 and 535 to edit-setup
guidance. Include whether message data began when deriving retry safety.

**Rationale**: A numeric status without phase is insufficient: a 5xx reply after
authentication, recipient submission, or final acceptance implies different
actions and delivery certainty. Numeric and enhanced codes are useful for
diagnosis without copying provider-controlled text. Post-data interruption must
preserve the existing `delivery_unknown` contract.

**Alternatives considered**:

- Keep the current generic `smtp.provider-<code>` failure: rejected because it
  loses phase, account guidance, and retry certainty.
- Record full SMTP replies or transcripts: rejected because they can contain
  addresses, provider text, server identifiers, and message-related data.
- Retry all transient-looking codes automatically: rejected because retry after
  message data begins can duplicate delivery.

## Decision 7: Make clipboard export explicit and write-only

**Decision**: Add a `DiagnosticClipboard` port with a single explicit write
operation. Its AppKit adapter clears and writes the general pasteboard after
`Copy Error Details`; it never reads clipboard contents or copies
automatically.

**Rationale**: Copying is useful for support while remaining user-controlled.
The formatter uses the same safe diagnostic value as local recording, and the
narrow port is straightforward to fake in deterministic tests.

**Alternatives considered**:

- Automatically copy on failure: rejected because clipboard mutation must be
  explicit.
- Expose raw logs for manual selection: rejected because raw logs are less
  reviewable and can include unrelated system information.
- Create a diagnostic file export: rejected because the specification does not
  require a new archive or file-retention surface.

**References**:
[NSPasteboard](https://developer.apple.com/documentation/appkit/nspasteboard),
[clearing pasteboard contents](https://developer.apple.com/documentation/appkit/nspasteboard/clearcontents())

## Decision 8: Retain Sparkle's standard updater feedback boundary

**Decision**: Keep `SPUStandardUpdaterController` and its standard interface for
checking, no-update, update-available, progress, and updater errors. Book Sender
owns only the existing menu entry, its enabled state, and application-visible
startup/configuration failures.

**Rationale**: Sparkle's standard controller already provides the full user
interface for a typical updater. Reimplementing it would duplicate state,
increase release risk, and exceed the feedback feature.

**Alternatives considered**:

- Build custom update progress and error UI: rejected because it duplicates an
  approved dependency and broadens scope.
- Add updater diagnostics to the local application catalog for every Sparkle
  internal event: rejected because the app does not need to ingest or persist
  the dependency's internal protocol.

**References**:
[SPUStandardUpdaterController](https://sparkle-project.org/documentation/api-reference/Classes/SPUStandardUpdaterController.html),
[SPUUpdater](https://sparkle-project.org/documentation/api-reference/Classes/SPUUpdater.html)

## Decision 9: Add no new dependency or application-owned schema

**Decision**: Use existing Swift/macOS capabilities and the approved exact
package set. No database migration, preferences schema for diagnostics, log file
format, archive format, or remote API contract is introduced.

**Rationale**: The new models are ephemeral application/domain values; system
logging owns retention. Keeping the dependency and persistence footprint
unchanged supports the lightweight native product and reduces release risk.

**Alternatives considered**:

- Add a structured logging package: rejected because `Logger` and typed domain
  values cover the requirement.
- Persist feedback in preferences: rejected because action feedback is current
  state, not user configuration.
- Add a diagnostics database: rejected because no in-app diagnostic history is
  allowed.

## Decision 10: Separate deterministic, runtime, and provider validation

**Decision**: Treat source scans, unit/fixture tests, compiled application
behavior, accessibility runtime behavior, and real provider acceptance as
distinct evidence gates. Provider tests use dedicated non-personal credentials
only when explicitly authorized.

**Rationale**: Static evidence can prove model coverage and banned-data
boundaries but cannot prove that macOS announced feedback or that Gmail/Kindle
accepted a delivery. Fixture SMTP tests can prove state-machine mapping but not
live provider policy.

**Alternatives considered**:

- Claim provider correctness from fixtures alone: rejected because hosted
  policy and account state are external.
- Require live provider access for every development check: rejected because it
  is slow, credential-sensitive, and unsuitable for deterministic tests.
- Combine release and feature acceptance: rejected because signing, packaging,
  feed publication, and delivery diagnostics have different evidence.
