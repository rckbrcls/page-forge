# Data Model: Replace Mock Workflows

All domain and application values are `Sendable`. Mutable batch ownership is
actor-isolated. Secrets, raw framework errors, source paths, SMTP payloads, and
book bytes are excluded from presentation models and pipeline events.

## ValidatedDeliverySetup

| Field | Type | Rules |
|---|---|---|
| `senderAddress` | `EmailAddress` | Required and normalized |
| `smtpHost` | `SMTPHost` | Required hostname without URL components |
| `smtpPort` | `UInt16` | Required and non-zero |
| `securityMode` | `SecurityMode` | `implicitTLS` or `startTLS` |
| `username` | `String` | Required and normalized |
| `credentialReference` | `CredentialReference` | Opaque, revision-scoped, readable |
| `kindleAddress` | `EmailAddress` | Required `@kindle.com` destination |
| `revision` | `Int` | Monotonically increases after successful save |

`DeliverySetupDraft` remains incomplete UI input. A validated setup exists only
after field validation, successful protected credential persistence, successful
non-secret preference persistence, and credential-reference verification.

`SetupLoadResult` is either `complete(ValidatedDeliverySetup)` or
`incomplete(prefilledDraft, SanitizedFailure?)`. This lets routing reject a
missing credential while preserving safe non-secret values for correction.

### Setup persistence transition

```text
draft
  -> validation failed
  -> store new credential reference
  -> persist new setup revision
  -> delete superseded credential
  -> complete
```

If preference persistence fails, only the newly created reference is removed and
the previous setup remains usable. Blank-password edits reuse the current
reference.

## CredentialReference

Fields: `service`, opaque revision identity, and no secret value.

The SMTP username remains in `ValidatedDeliverySetup`; it is not required to be
the Keychain account identity. A replacement password receives a new reference
so rollback cannot delete the previous credential.

## ShortcutPreference

| Field | Type | Rules |
|---|---|---|
| `isEnabled` | `Bool` | User-controlled |
| `keyCombination` | `Shortcut?` | Configurable; absent only when disabled or unresolved |
| `registrationState` | `ShortcutRegistrationState` | `registered`, `disabled`, or `conflict` |

Shortcut invocation changes only route reconciliation and window activation. It
never changes the batch, confirmation, preparation, or delivery state.

## IntakeOutcome

One outcome is produced in selection order:

- `accepted(BatchItem)`
- `excluded(BatchItem)`
- `cancelled(BatchItem)`

An excluded item carries a sanitized failure for duplicate, unsupported,
unreadable, changed, oversized, or over-capacity input. No selected URL becomes
silently ready or silently disappears. Raw URLs do not survive into presentation
state.

## SourceIdentity

Fields: stable file resource identifier when available, original byte count,
modification date, and staged content digest.

The staged digest is authoritative for preservation and delivery evidence. File
resource identity plus metadata supports early duplicate detection; the digest
detects equivalent staged bytes and change during snapshot.

## CurrentBatch

| Field | Type | Purpose |
|---|---|---|
| `id` | `UUID` | Temporary batch identity |
| `items` | `[BatchItem]` | Ordered actor-owned items |
| `phase` | `BatchPhase` | Command and transition guard |
| `activeSnapshot` | `ConfirmedBatchSnapshot?` | Immutable confirmed values |
| `completedCount` | `Int` | Honest aggregate progress |

Phases:

```text
editing
  -> importing
  -> preparing
  -> readyForConfirmation
  -> sending
  -> cancelling
  -> completed

completed -> editing        (append, remove, clear, or explicit retry)
```

Only the actor mutates these fields. Editing commands are rejected while
`sending` or `cancelling`.

## BatchItem

| Field | Type | Purpose |
|---|---|---|
| `id` | `UUID` | Stable UI and pipeline identity |
| `displayName` | `String` | Sanitized original filename |
| `sourceIdentity` | `SourceIdentity?` | Present after a stable supported snapshot |
| `format` | `BookFormat?` | `epub`, `pdf`, or absent for unsupported input |
| `stagedSource` | `StagedFileReference?` | Present only after accepted staging |
| `health` | `BookHealth?` | Domain-derived health |
| `preparation` | `PreparationState` | Local stage or terminal exclusion |
| `delivery` | `DeliveryState` | SMTP stage or terminal outcome |
| `findings` | `[HealthFinding]` | Collapsed evidence |
| `appliedActions` | `[AppliedRepairAction]` | Verified automatic actions |
| `preparedBook` | `PreparedBook?` | Eligible attachment evidence |

Accepted items require identity, format, and staged source. Excluded or cancelled
intake items retain only safe display metadata and their sanitized terminal
preparation state, allowing every selection to remain visible without inventing
file evidence.

Preparation transitions:

```text
waiting -> checking -> preparing -> ready
                           |------> needsAttention
                           |------> excluded
                           |------> cancelled
```

Delivery transitions:

```text
notScheduled
  -> sending(connecting -> securing -> authenticating -> envelope
             -> transmitting -> awaitingAcceptance)
  -> submitted | failed | cancelled | deliveryUnknown
```

## HealthFinding

Fields: stable code, severity, location when safe and applicable, message key,
repairability, and bounded evidence.

- Severity: `info`, `warning`, `error`, `critical`.
- Repairability: `notApplicable`, `automatic(ruleID)`, `manualReview`,
  `forbidden`.
- Health serialization: `healthy`, `repairable`, `needs_review`, `unsupported`,
  `unsafe`.

Swift case names may remain idiomatic, but persisted and fixture values use the
constitutional snake-case contract.

## PreparationPlan

Fields: original audit identifier, ordered actions, expected postconditions,
limits version, and decision.

Decisions:

- `writeEPUBWorkingCopy`
- `deliverImmutablePDFSnapshot`
- `blocked`

Every automatic action has explicit preconditions and postconditions. An action
that lacks fixture-backed write and revalidation evidence cannot enter an
executable plan.

## PreparationResult

| Field | Type | Purpose |
|---|---|---|
| `originalReport` | `AuditReport?` | EPUB evidence before writing |
| `plan` | `PreparationPlan` | Deterministic decision |
| `appliedActions` | `[AppliedRepairAction]` | Actions with verified postconditions |
| `preparedReport` | `AuditReport?` | EPUB evidence after reopen |
| `comparison` | `RevalidationComparison?` | Before/after decision |
| `preparedBook` | `PreparedBook?` | Eligible attachment |
| `failure` | `SanitizedFailure?` | Typed blocked/cancelled result |

Exactly one of `preparedBook` or `failure` is present at terminal preparation.

## PreparedBook

Fields: stable item identity, private file reference, original display name,
format, byte count, content digest, and revalidation comparison.

- PDF points to the immutable staged snapshot.
- EPUB points only to promoted `prepared.epub`.
- No prepared book references the user-selected original path.

## ConfirmedBatchItem

Fields: item ID, display name, prepared file reference, format, byte count,
content digest, and prior definitive outcome when this is an explicit retry.

It is a value copy. Later editing of `CurrentBatch` cannot alter it.

## ConfirmedBatchSnapshot

| Field | Type | Rules |
|---|---|---|
| `id` | `UUID` | Unique confirmation |
| `setup` | `ValidatedDeliverySetup` | Includes opaque credential reference, never secret |
| `eligibleItems` | `[ConfirmedBatchItem]` | Ordered and non-empty |
| `excludedItemIDs` | `[UUID]` | Display count and evidence only |
| `confirmedAt` | `Date` | User confirmation time |
| `kind` | `initial` or `retryFailed` | Explains consent scope |

Creation immediately moves the batch out of editing. Every eligible item receives
exactly one attempt for this snapshot unless cancellation stops scheduling.

## DeliveryAttempt

Fields: attempt ID, snapshot ID, item ID, setup revision, stage,
`dataTransmissionStarted`, start/completion timestamps, and terminal outcome.

Outcome rules:

- `submitted`: definitive final SMTP `250`.
- `failed`: definitive sanitized failure.
- `cancelled`: cancellation completed before message data began.
- `deliveryUnknown`: message data began but no definitive final response arrived.

No terminal attempt transitions automatically back to sending.

## PipelineEvent

Events cover batch snapshot replacement, item intake outcome, checking,
preparing, ready, needs attention, sending stage, submitted, failed, cancelled,
delivery unknown, aggregate progress, and batch completion.

Events carry value snapshots or stable IDs plus sanitized data. They never carry
credentials, raw URLs, book bytes, SMTP transcripts, or raw adapter errors.

## Temporary workspace

```text
BookSender/<batch-id>/<item-id>/
├── .booksender-workspace
├── source.partial
├── source.snapshot
├── prepared.partial.epub
└── prepared.epub
```

Only app-generated IDs select write paths. Failed/cancelled partial output is
removed. Clear/quit removes the batch root when safe. Startup orphan sweep removes
only marker-valid workspaces older than the configured threshold under the exact
Book Sender root.
