# Data Model: App Feedback and Diagnostics

## Model boundaries

These are in-memory domain and application values. SMTP credentials remain only
in the traditional macOS Keychain, delivery preferences remain in the existing
preferences store, and diagnostic retention is delegated to Apple unified
logging. No model below is persisted in a Book Sender database, file, archive,
or diagnostic-history screen. The separate bounded send history uses Feature
009 models and never stores diagnostic evidence.

The same sanitized diagnostic snapshot is the source for:

1. inline failure presentation;
2. local diagnostic recording;
3. deterministic copied details;
4. redaction and catalog tests.

## `ActionFeedback`

Represents the user-visible lifecycle of one accepted action.

| Field | Type | Rules |
|---|---|---|
| `id` | `UUID` | Stable while the same action/state is presented; changes for a new lifecycle |
| `scope` | `FeedbackScope` | Identifies app, setup, shortcut, batch, item, delivery, or update |
| `action` | `FeedbackAction` | Closed set of supported user/application actions |
| `state` | `FeedbackState` | Acknowledged, in progress, or one terminal state |
| `title` | `String` | Short, plain-language, non-empty English UI text |
| `message` | `String?` | Optional concise result or progress explanation |
| `startedAt` | `Date` | Fixed at lifecycle creation |
| `updatedAt` | `Date` | Monotonic within the lifecycle |
| `dismissal` | `FeedbackDismissalPolicy` | Persistent, explicit, action-replaced, or delayed |
| `failure` | `FailurePresentation?` | Required for failed and unknown states |
| `occurrenceCount` | `Int` | At least 1; repeated identical failures increment instead of duplicating notices |

### `FeedbackScope`

- `application`
- `deliverySetup`
- `shortcut`
- `batch`
- `batchItem(UUID)`
- `delivery(UUID)`
- `update`

The scope is presentation routing, not log metadata. A batch item identifier must
be an existing opaque local identifier and must not derive from a filename.

### `FeedbackAction`

- `restoreApplication`
- `saveDeliverySetup`
- `deleteDeliverySetup`
- `saveShortcut`
- `clearShortcut`
- `addBooks`
- `removeBook`
- `clearBatch`
- `confirmBatch`
- `prepareBook`
- `sendBook`
- `sendBatch`
- `cancelOperation`
- `dismissConfirmation`
- `copyErrorDetails`
- `checkForUpdates`

Task generation must reconcile this closed set with every accepted action in the
two primary screens and existing Settings tabs. Adding a new supported action
requires a lifecycle contract and tests.

### `FeedbackState`

- `acknowledged`
- `inProgress`
- `succeeded`
- `failed`
- `cancelled`
- `partial`
- `unknown`

`succeeded`, `failed`, `cancelled`, `partial`, and `unknown` are terminal.
`unknown` is used only when completion cannot be established safely, including
post-transmission delivery uncertainty.

### `FeedbackDismissalPolicy`

- `persistentUntilReplaced`
- `explicit`
- `replaceOnNextAction`
- `delayed(minimumVisibleDuration)`

Success confirmation must remain perceivable long enough to understand. Setup
save success defaults to `persistentUntilReplaced`; failure and unknown default
to `explicit` or `persistentUntilReplaced`. Progress is replaced by its terminal
state and does not auto-dismiss independently.

## `SanitizedFailure`

The existing failure value remains the cross-layer expected-failure envelope.
It gains typed diagnostic evidence while preserving its current family, code,
message, and recovery action fields.

| Field | Type | Rules |
|---|---|---|
| `family` | `FailureFamily` | Existing closed subsystem family |
| `code` | `DiagnosticCode` | Stable, non-localized identifier |
| `message` | `String` | Safe concise fallback; never raw provider/platform text |
| `recoveryAction` | `RecoveryAction` | Existing actionable recovery |
| `evidence` | `DiagnosticEvidence` | Required for new and migrated failure sites |

### `DiagnosticCode`

A closed `String`-backed, `CaseIterable` enum that:

- exposes raw values matching `^[a-z][a-z0-9]*(\.[a-z0-9-]+)+$`;
- is stable across wording changes;
- identifies one expected failure cause or one explicit unexpected-failure
  boundary per family;
- contains no variable private data or numeric provider status;
- is exhaustively catalogued by `FailurePresentationService`.

Adding a production failure cause requires adding an enum case, catalog entry,
and focused test in the same change. Provider codes and other variable evidence
belong in `DiagnosticEvidence`, not in enum raw values.

Examples:

- `credential.save`
- `smtp.authentication-rejected`
- `smtp.recipient-rejected`
- `archive.unsafe-path`
- `pipeline.preparation-result`
- `unexpected.delivery`

## `DiagnosticEvidence`

Typed, safe evidence attached before a raw technical failure leaves an adapter.

| Field | Type | Rules |
|---|---|---|
| `phase` | `DiagnosticPhase` | Required and specific to the failing action |
| `severity` | `DiagnosticSeverity` | Derived from impact, not provider wording |
| `retryDisposition` | `RetryDisposition` | Must account for side effects and certainty |
| `providerStatus` | `ProviderStatus?` | SMTP only; numeric codes without reply prose |
| `context` | `DiagnosticContext` | Closed allow-list; no arbitrary key/value data |

### `DiagnosticPhase`

- `bootstrap`
- `preferenceRead`
- `preferenceWrite`
- `credentialRead`
- `credentialWrite`
- `credentialDelete`
- `inputValidation`
- `intake`
- `workspaceStaging`
- `archiveSafety`
- `xmlParsing`
- `structuralAudit`
- `repairPlanning`
- `workingCopyWrite`
- `revalidation`
- `shortcutRegistration`
- `updateCheck`
- `smtpConnecting`
- `smtpSecuring`
- `smtpAuthenticating`
- `smtpSender`
- `smtpRecipient`
- `smtpData`
- `smtpFinalAcceptance`
- `cleanup`

Unexpected boundaries must still select the closest phase rather than
introducing `unknown` phase strings.

### `DiagnosticSeverity`

- `info`
- `warning`
- `error`
- `critical`

Severity must not be the only user-visible state indicator. `critical` is
reserved for startup/fatal failures or safety failures that block the affected
operation.

### `RetryDisposition`

- `notRetryable`
- `editSetup`
- `retrySafe`
- `checkBeforeRetry`
- `chooseAnotherFile`
- `reviewBook`
- `restartApplication`

`retrySafe` is prohibited after SMTP message data begins unless the protocol
state proves rejection before provider acceptance. Uncertain post-data outcomes
must use `checkBeforeRetry`.

## `ProviderStatus`

Retains the useful structured portion of an SMTP provider response.

| Field | Type | Rules |
|---|---|---|
| `replyCode` | `UInt16` | Required; 200 through 599 |
| `enhancedStatus` | `EnhancedStatusCode?` | Optional validated code only |

`EnhancedStatusCode` contains three numeric components:

- class: `2`, `4`, or `5`;
- subject: `0...999`;
- detail: `0...999`.

Accepted textual shape: `[245].[0-9]{1,3}.[0-9]{1,3}`.

Provider text after or around the enhanced code is discarded. `ProviderStatus`
cannot store reply lines, hostnames, addresses, server identifiers, or protocol
transcripts.

## `DiagnosticContext`

A closed structure of optional safe fields:

| Field | Type | Purpose |
|---|---|---|
| `appVersion` | `AppVersion?` | Correlates a failure to a released build |
| `operationID` | `UUID?` | Anonymous lifecycle correlation |
| `setupRevision` | `Int?` | Identifies preference revision, never credential content |
| `batchTotal` | `Int?` | Aggregate scale |
| `batchCompleted` | `Int?` | Aggregate progress at failure |
| `transmissionStarted` | `Bool?` | Determines delivery certainty and retry guidance |
| `safetyLimit` | `SafetyLimitIdentifier?` | Names the enforced bounded rule |

Validation:

- batch counts are non-negative and completed does not exceed total;
- setup revision is non-negative;
- app version comes only from validated bundle metadata;
- operation identifiers are random and never derived from files, addresses, or
  credentials;
- safety limit is a closed enum, not a file or provider-controlled string.

Explicitly forbidden fields include password, username, sender address, Kindle
address, SMTP host, path, filename, display name, book title, content fragment,
message bytes, provider reply, exception description, and arbitrary metadata.

## `DiagnosticEvent`

The only value accepted by local recording and copied-detail formatting.

| Field | Type | Rules |
|---|---|---|
| `id` | `UUID` | Unique event identifier |
| `occurredAt` | `Date` | Terminal failure/uncertainty time |
| `action` | `FeedbackAction` | The affected action |
| `outcome` | `DiagnosticOutcome` | Failed or uncertain |
| `failure` | `SanitizedFailure` | Fully validated sanitized snapshot |
| `occurrenceCount` | `Int` | At least 1 |

### `DiagnosticOutcome`

- `failed`
- `uncertain`

Successful operations do not need verbose diagnostic records. Success remains
visible through `ActionFeedback`.

## `FailurePresentation`

Derived by `FailurePresentationService`; never stored independently.

| Field | Type | Rules |
|---|---|---|
| `title` | `String` | Concise affected-action result |
| `summary` | `String` | Plain-language cause and impact |
| `explanation` | `String?` | Expanded safe explanation |
| `code` | `DiagnosticCode` | Always visible in expanded details |
| `family` | `FailureFamily` | User-readable subsystem label |
| `phase` | `DiagnosticPhase` | User-readable phase label |
| `providerStatus` | `ProviderStatus?` | Safe numeric/enhanced status only |
| `retryDisposition` | `RetryDisposition` | Drives guidance |
| `recoveryTitle` | `String?` | Action label such as `Edit Setup` or `Retry` |
| `recoveryAction` | `RecoveryAction` | Existing application action |
| `copyAvailable` | `Bool` | True when a valid `DiagnosticEvent` exists |

The catalog owns user-facing wording. SwiftUI views render this structure and do
not switch on diagnostic codes.

## `DiagnosticCopy`

An ephemeral deterministic rendering, not a persisted entity.

Required ordered lines:

1. product and app version;
2. event timestamp;
3. affected action;
4. outcome;
5. stable code;
6. subsystem and phase;
7. safe provider status when present;
8. impact/retry guidance;
9. occurrence count when greater than one.

The formatter omits absent values and produces the same output for the same
event and locale. It never includes a raw error description or any forbidden
context field.

## Relationships

```text
ActionFeedback
  ├── scope/action/state
  └── failure? ───────────────> FailurePresentation
                                      ▲
                                      │ derives from
SanitizedFailure ──────────────> DiagnosticEvent
  └── DiagnosticEvidence              │
       ├── ProviderStatus?             ├── UnifiedDiagnosticRecorder
       └── DiagnosticContext           └── DiagnosticFormatter
                                                └── DiagnosticClipboard
```

## State transitions

```text
acknowledged
  ├── inProgress
  │     ├── succeeded
  │     ├── failed
  │     ├── cancelled
  │     ├── partial
  │     └── unknown
  ├── succeeded
  ├── failed
  └── cancelled
```

Rules:

- terminal states cannot transition back to in-progress;
- a retry creates a new `ActionFeedback.id`;
- repeated identical failure observations in one operation increment
  `occurrenceCount` without creating another visual notice or announcement;
- batch aggregate feedback is derived from per-item terminal states;
- `partial` requires at least one succeeded item and at least one
  failed/cancelled/unknown item;
- `unknown` requires a failure presentation and
  `RetryDisposition.checkBeforeRetry`;
- cancellation acknowledgement may be in progress until the active operation
  reaches a safe terminal point.
