# Data Model: Self-Contained Raycast EPUB Workflow

**Date**: 2026-07-20
**Source**: [spec.md](./spec.md), [research.md](./research.md), and [contracts/](./contracts/)

The models below are logical contracts. Concrete TypeScript declarations may split them into files, but must preserve the discriminated states and dependency boundaries.

## Core Value Types

### HealthState

`healthy | repairable | needs_review | unsupported | unsafe`

Precedence is `unsafe > unsupported > needs_review > repairable > healthy`. Health is always derived from findings; callers cannot set it independently.

### Severity

`info | warning | error | critical`

Severity describes the finding, not whether it can be repaired. Repairability is a separate field.

### ProcessingPhase

`selecting | preflight | inspecting_container | inspecting_package | inspecting_content | planning | awaiting_confirmation | reconstructing | revalidating | comparing | promoting | checking_delivery_eligibility | awaiting_delivery_confirmation | connecting | transmitting | completed | failed | cancelled`

### InternalPath

A validated, relative, slash-separated archive path. It contains no empty, `.`, `..`, absolute, drive, UNC, NUL, backslash, or escaping segment. A single trailing `/` is permitted only as the canonical marker for a directory and is excluded from segment validation and collision keys. The original entry name remains separately available as evidence until preflight completes.

## SelectedEpub

Represents one immutable user-selected source.

| Field         | Type                      | Rules                                                                                              |
| ------------- | ------------------------- | -------------------------------------------------------------------------------------------------- |
| `id`          | opaque operation-local ID | Unique within a selection snapshot; not derived from the full path for display or logging          |
| `sourcePath`  | local path                | Internal use only; never included in logs or copied into reports by default                        |
| `displayName` | string                    | Basename only; Unicode preserved; must end in `.epub` case-insensitively                           |
| `identity`    | filesystem identity       | Used to collapse duplicate selections and detect replacement where available                       |
| `sizeBytes`   | non-negative safe integer | Values above 200,000,000 are retained as evidence and produce an Unsafe report before archive open |
| `modifiedAt`  | timestamp                 | Snapshot evidence used to detect changes before repair or delivery                                 |
| `readable`    | boolean                   | Must be true before inspection                                                                     |

Relationships:

- One `SelectedEpub` produces zero or one `LoadedEpub` per inspection run.
- One `SelectedEpub` produces one `BatchItemResult` per operation.
- Preparation never mutates or replaces this entity's file.

## ArchiveEntryDescriptor

Metadata for one central-directory entry, captured before content reads.

| Field                | Type                                    | Rules                                                   |
| -------------------- | --------------------------------------- | ------------------------------------------------------- |
| `index`              | integer                                 | Physical central-directory order, starting at zero      |
| `originalName`       | string/bytes evidence                   | Never used directly for filesystem access               |
| `path`               | `InternalPath` or invalid-path evidence | Valid only after path checks pass                       |
| `kind`               | `file                                   | directory                                               | symlink | special` | Only file and directory are accepted |
| `compressionMethod`  | integer                                 | Only STORE `0` and DEFLATE `8` accepted                 |
| `compressedSize`     | integer                                 | Safe non-negative integer                               |
| `expandedSize`       | integer                                 | Safe non-negative integer and at most 100,000,000 bytes |
| `crc32`              | unsigned integer                        | Verified while streaming file content                   |
| `encrypted`          | boolean                                 | Must be false                                           |
| `externalAttributes` | integer                                 | Used to detect links and special files                  |
| `flags`              | integer                                 | Used for encryption and filename interpretation         |

Aggregate archive rules:

- No more than 10,000 entries.
- Expanded sizes sum to at most 1,000,000,000 bytes.
- Compressed source and reconstructed output are at most 200,000,000 bytes.
- Aggregate and per-entry expansion ratios are at most 100:1.
- Exact, canonical Unicode-folded, and file/directory-conflicting names are rejected.

## LoadedEpub

A bounded projection of a source after archive preflight.

| Field              | Type                               | Description                                          |
| ------------------ | ---------------------------------- | ---------------------------------------------------- |
| `source`           | `SelectedEpub`                     | Immutable source snapshot                            |
| `entries`          | ordered `ArchiveEntryDescriptor[]` | Complete safe central-directory projection           |
| `entryIndex`       | path-to-entry map                  | Exact lookup only after duplicate checks             |
| `mimetype`         | optional `MimetypeProjection`      | Position, method, extras, and exact bounded content  |
| `container`        | optional `ContainerProjection`     | Parsed rootfile declarations and XML evidence        |
| `packages`         | `PackageProjection[]`              | Zero or more bounded OPF projections                 |
| `contentDocuments` | `ContentProjection[]`              | Bounded references and compatibility characteristics |
| `encryption`       | optional `EncryptionProjection`    | Presence and affected paths only; no decryption      |

`LoadedEpub` must not retain full image, font, stylesheet, or chapter buffers. Bounded changed XML may be held only during repair.

## Finding

One concrete, user-visible observation.

| Field               | Type                              | Rules                                                                                             |
| ------------------- | --------------------------------- | ------------------------------------------------------------------------------------------------- |
| `code`              | `FindingCode`                     | Stable value from [contracts/findings.md](./contracts/findings.md)                                |
| `severity`          | `Severity`                        | Fixed by rule and context                                                                         |
| `category`          | finding category                  | `input`, `archive`, `mimetype`, `container`, `package`, `content`, `compatibility`, or `delivery` |
| `title`             | string                            | Concise US English UI title                                                                       |
| `description`       | string                            | Actionable explanation without book excerpts or full local paths                                  |
| `location`          | optional `FindingLocation`        | Internal path, line/column, manifest ID, spine IDREF, or archive entry index                      |
| `repairability`     | `none                             | automatic`                                                                                        | Never encoded as severity |
| `recommendedRepair` | optional `RepairKind`             | Present only when a permitted deterministic operation exists                                      |
| `appliedRepair`     | optional applied-repair reference | Set on compared report occurrences when a confirmed repair addressed the finding                  |
| `revalidation`      | `not_compared                     | resolved                                                                                          | remaining                 | introduced` | Set to `not_compared` before a comparison and enriched afterward |
| `evidence`          | bounded key/value facts           | Numeric or structural evidence; no long content excerpts                                          |
| `stateImpact`       | `HealthState`                     | Minimum state caused by this finding                                                              |

Stable identity for before/after comparison is `(code, normalized location, target identifier)`. Descriptive text is not part of identity.

## HealthReport

| Field               | Type                | Description                                                                                       |
| ------------------- | ------------------- | ------------------------------------------------------------------------------------------------- |
| `sourceId`          | selected EPUB ID    | Links to the operation item without exposing path                                                 |
| `sourceFingerprint` | bounded fingerprint | Size, modification evidence, and cryptographic digest used for immutability tests                 |
| `epubVersion`       | `2                  | 3                                                                                                 | unknown` | Derived from the selected package, if unambiguous |
| `health`            | `HealthState`       | Derived by precedence from all findings                                                           |
| `findings`          | ordered `Finding[]` | Deterministic category, location, and code order                                                  |
| `inspectedAt`       | timestamp           | Local operation evidence, not persisted remotely                                                  |
| `durationMs`        | integer             | Non-negative; safe to display                                                                     |
| `ruleResults`       | `RuleResult[]`      | Every v1 rule is `completed`, `not_applicable`, or `not_run_after_terminal_finding` with a reason |

Validation:

- Every terminal inspection report accounts for every v1 rule in `ruleResults`. Unsafe/Unsupported preflight findings may mark later rules `not_run_after_terminal_finding` rather than reading dangerous content.
- User cancellation or an operational I/O failure returns `ProcessingFailure`; malformed, unsupported, excessive, encrypted, or unsafe EPUB evidence returns a `HealthReport` even when no `LoadedEpub` can be built.
- `healthy` allows only Info findings.
- `repairable` requires at least one relevant finding and every Warning/Error/Critical finding to have `automatic` repairability.

## RepairPlan

| Field                 | Type                          | Rules                                                                                                           |
| --------------------- | ----------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `source`              | `SelectedEpub` snapshot       | Must still match before execution                                                                               |
| `originalReport`      | `HealthReport`                | Must be complete and `repairable` for execution                                                                 |
| `operations`          | non-empty `RepairOperation[]` | Ordered, deterministic, and from the allowed set only                                                           |
| `unresolvedFindings`  | `UnresolvedFinding[]`         | Finding plus reason it remains unchanged                                                                        |
| `predictedOutputPath` | uncreated local path          | Collision-safe prediction shown for review; separate from source and subject to a later race-safe suffix update |
| `createdAt`           | timestamp                     | Plan evidence                                                                                                   |

### RepairOperation

Discriminated by `kind`:

- `write_canonical_mimetype`
- `rebuild_container_for_single_opf`
- `correct_manifest_media_type`
- `correct_unique_reference`
- `normalize_equivalent_internal_path`
- `normalize_xml_encoding`
- `rebuild_epub_archive`

Every operation includes finding identities addressed, exact internal paths read and changed, deterministic inputs, and an explanation. `rebuild_epub_archive` is the packaging operation that carries the entry-level changes; it is not permission to make additional repairs.

## AppliedRepair

| Field                 | Type                       | Description                            |
| --------------------- | -------------------------- | -------------------------------------- |
| `operation`           | planned operation identity | Must exist in the confirmed plan       |
| `resolvedFindingIds`  | finding identities         | Findings intended to be resolved       |
| `changedEntries`      | internal paths             | Exact bounded list                     |
| `preservedEntryCount` | integer                    | Number of resources streamed unchanged |
| `outcome`             | `applied                   | already_satisfied                      | failed` | `already_satisfied` requires proof that the planned finding no longer exists before mutation |

## RevalidationComparison

| Field         | Type                    | Description                                                                                                                                       |
| ------------- | ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `before`      | original `HealthReport` | Complete report used to create the plan                                                                                                           |
| `after`       | repaired `HealthReport` | Complete report read from the closed temporary output                                                                                             |
| `repairs`     | `AppliedRepair[]`       | Execution evidence                                                                                                                                |
| `resolved`    | finding identities      | Present before, absent after                                                                                                                      |
| `remaining`   | finding identities      | Present before and after                                                                                                                          |
| `introduced`  | findings                | Absent before, present after                                                                                                                      |
| `successful`  | boolean                 | True only when final health is Healthy, no introduced Error/Critical exists, and every confirmed operation is applied or proven already satisfied |
| `finalHealth` | `HealthState`           | Equal to `after.health`; successful output eligibility still requires allowed delivery state                                                      |

## PreparedEpub

Created only after successful comparison with final `healthy` state and atomic promotion.

| Field               | Type                                                     | Rules                                          |
| ------------------- | -------------------------------------------------------- | ---------------------------------------------- |
| `outputPath`        | final local path                                         | Exists, is closed, and differs from source     |
| `displayName`       | basename                                                 | Follows collision-safe naming contract         |
| `sizeBytes`         | integer                                                  | Within archive source/output limit             |
| `report`            | `HealthReport`                                           | Complete post-repair report                    |
| `comparison`        | `RevalidationComparison`                                 | `successful === true`                          |
| `sourceFingerprint` | fingerprint                                              | Links to original without changing it          |
| `outputSnapshot`    | filesystem identity, size, digest, modification evidence | Binds later delivery to the revalidated output |

## PreparationResult

A discriminated terminal result:

- `prepared` with `PreparedEpub`.
- `unsuccessful` with `ProcessingFailure`, original `HealthReport`, optional repaired `HealthReport`, optional `RevalidationComparison`, and temporary-output cleanup status. It never exposes a failed temporary artifact as Kindle-ready.
- `cancelled` with phase and cleanup status.

Revalidation failures retain the complete before/after evidence required by the report even though no `PreparedEpub` or final output is produced.

## BatchOperation and BatchItemResult

### BatchOperation

| Field                   | Type                   | Description                                          |
| ----------------------- | ---------------------- | ---------------------------------------------------- |
| `id`                    | opaque ID              | Operation-local                                      |
| `intent`                | `inspect               | prepare                                              | send` | One command intent |
| `items`                 | selected EPUB snapshot | Stable ordered snapshot                              |
| `phase`                 | `ProcessingPhase`      | Aggregate UI phase                                   |
| `activeIndex`           | optional integer       | At most one active file                              |
| `cancellationRequested` | boolean                | Stops pending scheduling and signals active adapters |
| `results`               | `BatchItemResult[]`    | Completed results are immutable within the operation |

### BatchItemResult

Discriminated by `status`:

- `pending`
- `in_progress` with phase and bounded progress
- `inspected` with `HealthReport`
- `prepared` with `PreparedEpub`
- `submitted` with `DeliveryResult`
- `failed` with `ProcessingFailure` and optional unsuccessful `PreparationResult` evidence
- `cancelled` with cancellation phase
- `delivery_unknown` with sanitized `DeliveryResult`

Batch retry is available only for `failed`, matching the feature requirement. A cancelled operation can be started again as a new operation. `delivery_unknown` offers a separate explicit `Send Again` action with a possible-duplication warning; it is never included in automatic or failed-item retry.

## DeliveryConfiguration

| Field           | Type          | Validation                                                          |
| --------------- | ------------- | ------------------------------------------------------------------- |
| `senderAddress` | email address | No CR/LF; syntactically valid                                       |
| `smtpHost`      | hostname      | Non-empty, no control characters, not logged                        |
| `smtpPort`      | integer       | `1...65535`; defaults follow selected security mode                 |
| `securityMode`  | `implicit_tls | starttls`                                                           | No plaintext mode |
| `username`      | string        | Non-empty, not logged                                               |
| `appPassword`   | secret string | Obtained from password preference, never copied into domain reports |
| `kindleAddress` | email address | Valid personal Kindle address; no CR/LF                             |

The model exists only for the active send operation and is not written to project files or duplicated into general storage.

## DeliveryResult

Discriminated by `status`:

- `not_started`
- `cancelled`
- `submitted`
- `failed`
- `delivery_unknown`

Fields include selected source ID, basename, start/end times, bytes streamed, sanitized failure category, numeric SMTP response code when safe, and whether manual retry is allowed. It never includes password, username, host, full path, raw server response, stack, message body, or book metadata.

## ProcessingFailure

A discriminated union rather than generic exceptions or display strings.

| Category             | Examples                                                                                                                                                                                                 |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `input`              | unsupported extension, missing/unreadable/non-regular source, source changed                                                                                                                             |
| `archive`            | operational archive open/read/close failure after structural evidence has been represented as findings                                                                                                   |
| `xml`                | operational parser/stream failure after malformed or unsafe XML evidence has been represented as findings                                                                                                |
| `repair`             | `REPAIR_PLAN_STALE`, `REPAIR_OUTPUT_UNWRITABLE`, `REPAIR_WRITE_FAILED`, `REPAIR_TIMEOUT`, `REPAIR_TEMP_CLEANUP_FAILED`, `REVALIDATION_TIMEOUT`, `REVALIDATION_NEW_ERROR`, or `REVALIDATION_NEW_CRITICAL` |
| `delivery_config`    | missing or invalid SMTP fields                                                                                                                                                                           |
| `delivery_transport` | DNS, connection, TLS, auth, envelope, message, stream, timeout                                                                                                                                           |
| `cancelled`          | phase-aware cooperative cancellation                                                                                                                                                                     |
| `internal`           | bounded fallback with no raw error or sensitive context                                                                                                                                                  |

Every failure has a stable code, safe user message, retryability, phase, and optional bounded facts. Raw adapter errors remain inside the adapter boundary and are never logged or returned.

## State Transitions

### Inspection

```text
selected
  -> preflight
  -> inspecting_container
  -> inspecting_package
  -> inspecting_content
  -> completed(report)

Any active phase -> failed(failure) | cancelled
```

### Preparation

```text
selected
  -> preflight -> inspecting_container -> inspecting_package -> inspecting_content
  -> planning
  -> awaiting_confirmation
  -> reconstructing(temp)
  -> revalidating(temp)
  -> comparing
  -> promoting
  -> completed(prepared)

awaiting_confirmation -> cancelled (no temp output)
reconstructing/revalidating/comparing -> failed|cancelled (temp cleanup, no final output)
```

### Delivery

```text
selected
  -> checking_delivery_eligibility
  -> awaiting_delivery_confirmation
  -> connecting
  -> transmitting
  -> submitted | failed | delivery_unknown

Before connecting -> cancelled
After DATA may begin -> delivery_unknown when acceptance cannot be determined
```

## Invariants

1. Original file bytes never change.
2. A final Kindle-ready path never names an incomplete or failed reconstruction.
3. A repair operation cannot exist without a confirmed plan and matching finding.
4. A terminal report accounts for the entire v1 rule catalog, including rules safely skipped after a terminal preflight finding.
5. Health cannot be assigned independently of findings.
6. One batch has at most one active EPUB and one active archive entry.
7. One SMTP message has exactly one EPUB attachment.
8. No secret or full local path crosses into findings, reports, delivery results, or logs.
9. No network dependency is reachable from inspect or prepare workflows.
10. Cancellation preserves originals, completed outputs, and pre-existing paths.
11. Inspection, repair, and delivery read through the same verified descriptor used for their before/after identity checks.
