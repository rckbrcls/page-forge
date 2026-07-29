# Data Model: Lightweight macOS Book Sender

All domain and application value types are immutable `Sendable` structs or enums.
Secrets and raw framework exceptions are excluded from these models.

## DeliverySetup

| Field | Type | Rules |
|---|---|---|
| `senderAddress` | `EmailAddress` | Required, normalized for comparison |
| `smtpHost` | `SMTPHost` | Required hostname, no URL components |
| `smtpPort` | `UInt16` | Required, non-zero |
| `securityMode` | `SecurityMode` | `implicitTLS` or `startTLS` |
| `username` | `String` | Required |
| `credentialReference` | `CredentialReference` | Opaque Keychain identity, never secret bytes |
| `kindleAddress` | `EmailAddress` | Required |

`DeliverySetupDraft` may contain incomplete strings for field validation.
`DeliverySetup` exists only after all values validate and a credential is
successfully stored.

## ShortcutPreference

Fields: `isEnabled`, normalized key combination, and `registrationState`.

`registrationState` is `registered`, `disabled`, or
`conflict(message: SanitizedMessage)`. Invoking a shortcut changes only window
activation; it never changes batch or delivery state.

## CurrentBatch

Fields: `id`, ordered `items`, `phase`, and optional
`confirmedSnapshotIdentifier`.

Phases:

```text
editing -> preparing -> readyForConfirmation -> sending -> completed
                     \-> cancelling -> completed
```

Items may be added or removed only while they are not part of an active confirmed
snapshot. A new intake group is appended deterministically. Duplicate source
identities are excluded unless the user later performs a separate explicit
action.

## BatchItem

| Field | Type | Purpose |
|---|---|---|
| `id` | `UUID` | Stable UI and pipeline identity |
| `displayName` | `String` | Sanitized original filename for UI/MIME |
| `sourceIdentity` | `SourceIdentity` | File resource identity plus intake fingerprint |
| `format` | `BookFormat` | `epub` or `pdf` |
| `stagedSource` | `StagedFileReference` | Opaque private snapshot reference |
| `health` | `BookHealth?` | Derived audit state |
| `preparation` | `PreparationState` | Current local pipeline state |
| `delivery` | `DeliveryState` | Current SMTP state/outcome |
| `findings` | `[HealthFinding]` | Internal evidence; collapsed by default |
| `appliedActions` | `[AppliedRepairAction]` | Auditable deterministic changes |

## HealthFinding

Fields: stable `code`, `severity`, `location`, `messageKey`, `repairability`, and
evidence metadata.

- Severity: `info`, `warning`, `error`, `critical`.
- Repairability: `notApplicable`, `automatic(ruleID)`, `manualReview`, or
  `forbidden`.
- Health: `healthy`, `repairable`, `needsReview`, `unsupported`, or `unsafe`.

Severity and repairability remain separate. Presentation receives sanitized,
localized descriptions but the domain retains stable codes for fixtures.

## PreparationPlan

Fields: original audit identifier, ordered deterministic actions, safety limits,
expected postconditions, and decision (`useOriginalSnapshot`, `writeWorkingCopy`,
or `blocked`).

An EPUB plan is executable only when every action is deterministic and all
preconditions hold. A PDF plan never changes content and uses its staged
snapshot for delivery.

## PreparedBook

Fields: batch item identity, private file reference, original display name,
format, byte count, content digest, and revalidation comparison.

A prepared EPUB exists only after a `.partial` working copy is closed, reopened,
re-audited, compared, and promoted. A prepared PDF points to the immutable staged
snapshot. Neither exposes a user-controlled write path.

## RevalidationComparison

Fields: original report ID, prepared report ID, resolved finding codes, retained
finding codes, introduced finding codes, verified action IDs, and readiness
decision.

Readiness requires:

- no introduced critical finding;
- every applied action verified;
- every delivery eligibility rule satisfied;
- all archive and XML limits still satisfied.

## ConfirmedBatchSnapshot

Fields: unique ID, setup revision, Kindle destination display value, ordered
eligible item IDs, ordered excluded item IDs, and confirmation timestamp.

It is immutable. Later UI additions, removals, or setup edits do not silently
alter it. The pipeline processes `eligibleItemIDs` exactly once and in order.

## PipelineEvent

Minimal typed events include item added/excluded, checking, preparing, ready,
needs attention, sending, submitted, failed, cancelled, delivery unknown, batch
progress, and batch completed. Events carry identifiers and sanitized action
descriptors, never credentials, raw paths, book bytes, or raw adapter errors.

## DeliveryAttempt

Fields: attempt ID, item ID, setup revision, stage, whether DATA transmission
started, sanitized server category, timestamps, and terminal outcome.

Stages:

```text
connecting -> securing -> authenticating -> envelope -> transmitting -> awaitingAcceptance
```

Terminal outcomes:

- `submitted`: final SMTP `250` received for this message.
- `failed(FailureCode)`: definitive failure before or after transmission.
- `cancelled`: cancellation completed before DATA transmission began.
- `deliveryUnknown`: DATA began but no definitive final acceptance/rejection was
  received.

No failed or unknown attempt transitions automatically back to sending.

## Typed failures

Failure families are `IntakeFailure`, `ArchiveFailure`, `XMLFailure`,
`AuditFailure`, `RepairFailure`, `FilesystemFailure`, `CredentialFailure`, and
`DeliveryFailure`. Each has a stable code, sanitized user action, and optional
safe evidence. Raw framework errors are adapter-private.

## Temporary workspace

```text
BookSender/<batch-id>/<item-id>/
├── .booksender-workspace
├── source.snapshot
├── extracted/
├── prepared.partial.epub
└── prepared.epub
```

Only the app-generated IDs form paths. The original filename is metadata only.
Terminal item cleanup removes extraction and partial output. Clearing or quitting
removes the batch root. Startup cleanup deletes only marker-valid orphan roots
older than the documented threshold under the exact BookSender temporary root.
