# Data Model: Simplified Document Workflow

**Feature**: `002-simplify-document-workflow`  
**Date**: 2026-07-18

## Design Rules

- Queue state is session-only and lives in the main workflow view model.
- Local files remain authoritative; no database or cloud persistence is added.
- Original sources are immutable.
- Preparation state and output-action state are independent.
- Every accepted or rejected source and every save/send attempt has a per-item
  outcome.

## Enumerations

### DocumentFormat

- `epub`
- `mobi`
- `pdf`

`unknown` is an intake rejection reason, not an accepted queue format.

### PreparationState

- `queued`
- `preparing`
- `ready`
- `needsAttention`
- `blocked`
- `failed`
- `cancelled`

Mapping rules:

- A completed readiness report with `ready` maps to `ready`.
- `needs_fixes` after the safe path maps to `needsAttention`.
- `blocked` maps to `blocked`.
- Thrown validation, dependency, filesystem, conversion, or repair errors map to
  `failed` with an `OperationIssue`.
- A pending item not started after queue cancellation maps to `cancelled`.

### OutputActionState

- `idle`
- `inProgress`
- `succeeded`
- `failed`

Save and delivery each use their own `OutputActionState` value.

### QueueState

- `empty`
- `readyToPrepare`
- `processing`
- `partiallyCompleted`
- `completed`

This value is derived from items and is never independently persisted.

### IntakeRejectionReason

- `unsupportedType`
- `duplicate`
- `notLocalFile`
- `notRegularFile`
- `unreadable`
- `missing`
- `accessDenied`
- `resolutionFailed`

### OutputConflictPolicy

- `failIfExists` (default)
- `replaceConfirmed` (only after explicit confirmation)

## Entities

### DocumentItem

One accepted document and its complete session workflow state.

| Field               | Type                    | Rules                                            |
| ------------------- | ----------------------- | ------------------------------------------------ |
| `id`                | UUID                    | Stable for the queue session                     |
| `sourceURL`         | URL                     | Original selected local file                     |
| `canonicalIdentity` | String                  | Canonical path/resource identity used for dedupe |
| `displayName`       | String                  | Source filename                                  |
| `format`            | DocumentFormat          | EPUB, MOBI, or PDF                               |
| `isSelected`        | Bool                    | Drives Prepare/Save/Send eligibility             |
| `preparationState`  | PreparationState        | Starts as `queued`                               |
| `progressMessage`   | String?                 | Current human-readable step                      |
| `progressFraction`  | Double?                 | In `0...1` when determinable                     |
| `readinessReport`   | ReadinessReport?        | Present after readiness evaluation               |
| `preparedOutput`    | PreparedOutput?         | Present after a successful preparation           |
| `issue`             | OperationIssue?         | Current actionable warning/failure               |
| `saveResult`        | ExportResult?           | Independent from delivery                        |
| `deliveryResult`    | DocumentDeliveryResult? | Independent from save                            |
| `securityAccess`    | SecurityScopedAccess?   | Session access/bookmark metadata; never a secret |

Validation:

- Source must be local, existing, readable, regular, and supported at intake.
- Source is revalidated immediately before preparation.
- `ready` requires a readable `preparedOutput`.
- Save/Send eligibility requires `isSelected`, `ready`, and a readable output.
- Removing the item deletes only session state.

### DocumentQueue

The ordered collection rendered by the main screen.

| Field           | Type           | Rules                                        |
| --------------- | -------------- | -------------------------------------------- |
| `items`         | [DocumentItem] | Stable intake order                          |
| `isProcessing`  | Bool           | True while a preparation sequence is active  |
| `activeItemID`  | UUID?          | At most one because processing is sequential |
| `intakeSummary` | IntakeSummary? | Most recent add operation feedback           |

Derived values:

- `selectedItems`
- `selectedQueuedItems`
- `selectedReadyItems`
- `state: QueueState`
- completed/failed/attention/blocked counts
- booleans for Prepare, Save Files, Send to Kindle, Remove, and Retry actions

Validation:

- No two items share a canonical identity.
- At most one item is `preparing`.
- New intake appends items while processing without changing the active item.

### IntakeOutcome

One result for each URL passed to intake.

| Field          | Type             | Rules                                        |
| -------------- | ---------------- | -------------------------------------------- |
| `originalURL`  | URL              | Input value                                  |
| `acceptedItem` | DocumentItem?    | Set only when accepted                       |
| `rejection`    | IntakeRejection? | Set only when rejected                       |
| `inputIndex`   | Int              | Restores stable order after async resolution |

Exactly one of `acceptedItem` or `rejection` is present.

### IntakeSummary

| Field           | Type            | Rules                      |
| --------------- | --------------- | -------------------------- |
| `outcomes`      | [IntakeOutcome] | Same order as source input |
| `acceptedCount` | Int             | Derived                    |
| `rejectedCount` | Int             | Derived                    |

### IntakeRejection

| Field     | Type                  | Rules                                          |
| --------- | --------------------- | ---------------------------------------------- |
| `reason`  | IntakeRejectionReason | Stable category                                |
| `message` | String                | Names the affected item and explains rejection |

### PreparedOutput

| Field             | Type            | Rules                                         |
| ----------------- | --------------- | --------------------------------------------- |
| `sourceURL`       | URL             | Original EPUB/MOBI/PDF, never temporary input |
| `outputURL`       | URL             | Final local EPUB                              |
| `format`          | DocumentFormat  | Always `epub` for the primary flow            |
| `sizeBytes`       | Int64           | Re-read after creation                        |
| `readinessStatus` | ReadinessStatus | Must be retained from final report            |
| `createdAt`       | Date            | Result timestamp                              |

Rules:

- Default name is `<source-stem>-kindle-ready.epub`.
- The source and final output must be distinct paths.
- Temporary PDF conversion paths never appear here.
- A standalone structural repair remains `<source-stem>-repaired.epub` and is not
  substituted for this entity without final readiness preparation.

### OperationIssue

| Field            | Type            | Rules                                                                                              |
| ---------------- | --------------- | -------------------------------------------------------------------------------------------------- |
| `category`       | IssueCategory   | intake, dependency, validation, filesystem, conversion, repair, configuration, delivery, cancelled |
| `message`        | String          | User-facing and secret-free                                                                        |
| `recoveryAction` | RecoveryAction? | Retry, Open Settings, Choose Another Folder, Reveal File, or none                                  |

### ExportRequest

| Field                  | Type                 | Rules                             |
| ---------------------- | -------------------- | --------------------------------- |
| `outputs`              | [PreparedOutput]     | Selected and readable only        |
| `destinationDirectory` | URL                  | Existing writable local directory |
| `conflictPolicy`       | OutputConflictPolicy | Defaults to `failIfExists`        |

### ExportResult

| Field             | Type              | Rules                              |
| ----------------- | ----------------- | ---------------------------------- |
| `sourceOutputURL` | URL               | Existing prepared output           |
| `destinationURL`  | URL               | Intended/result path               |
| `state`           | OutputActionState | `succeeded` or `failed` terminally |
| `message`         | String            | Result or conflict/failure reason  |

Export uses copy semantics and never removes the source or prepared output.

### DeliveryRequest

| Field         | Type             | Rules                      |
| ------------- | ---------------- | -------------------------- |
| `outputs`     | [PreparedOutput] | Selected and readable only |
| `profileName` | String           | Explicit existing profile  |

### DocumentDeliveryResult

| Field         | Type              | Rules                               |
| ------------- | ----------------- | ----------------------------------- |
| `outputURL`   | URL               | Sent/attempted prepared output      |
| `profileName` | String            | Selected profile                    |
| `kindleEmail` | String?           | Present on success; safe to display |
| `state`       | OutputActionState | `succeeded` or `failed` terminally  |
| `message`     | String            | Secret-free result                  |

### SecurityScopedAccess

Session metadata required to keep access to a user-selected file valid.

| Field            | Type  | Rules                                                                 |
| ---------------- | ----- | --------------------------------------------------------------------- |
| `bookmarkData`   | Data? | Security-scoped bookmark when persistence beyond callback is required |
| `isAccessActive` | Bool  | Balanced start/stop access ownership                                  |

This is not persisted in queue logs and contains no delivery credential.

## Existing Entities Reused Unchanged

- `ReadinessStatus`: `ready`, `needs_fixes`, `blocked`
- `IssueSeverity`: `info`, `warning`, `error`, `fixable`
- `ReadinessIssue`
- `ReadinessReport`
- `DeliveryProfile`
- `DependencyStatus`
- `OperationJob` and `OperationLogEntry`

## State Transitions

### Preparation

```text
queued ──prepare──> preparing ──success──> ready
                           ├──report────> needsAttention
                           ├──report────> blocked
                           └──error─────> failed

needsAttention ──retry──> queued
failed ──────────retry──> queued
blocked ──after recovery/retry──> queued
queued ──cancel pending──> cancelled
cancelled ──retry──> queued
```

### Save

```text
idle ──save──> inProgress ──copied──> succeeded
                          └──error/conflict──> failed
failed ──retry/other destination──> inProgress
```

### Delivery

```text
idle ──send──> inProgress ──accepted──> succeeded
                          └──error────> failed
failed ──retry──> inProgress
```

Save or delivery failure does not change `PreparationState.ready`.
