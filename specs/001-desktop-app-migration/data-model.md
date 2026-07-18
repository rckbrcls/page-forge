# Data Model: Desktop App Migration

**Feature**: `001-desktop-app-migration`  
**Date**: 2026-07-17  
**Source baseline**: current `src/page_forge/models.py` and workflow modules

## Enumerations

### ReadinessStatus
- `ready`
- `needs_fixes`
- `blocked`

### IssueSeverity
- `info`
- `warning`
- `error`
- `fixable`

### RepairMode
- `safe`
- `aggressive`

### ConversionTarget
- `epub`
- `mobi`

### OperationKind
- `readinessAudit`
- `readinessPrepare`
- `convert`
- `repair`
- `batchReadiness`
- `batchConvert`
- `batchRepair`
- `metadataInspect`
- `metadataUpdate`
- `send`
- `dependencyCheck`
- `setupGuidance`
- `updateGuidance`

### OperationState
- `queued`
- `running`
- `succeeded`
- `failed`
- `cancelled`

## Entities

### EbookSource
Represents a user-selected local input.

| Field | Type | Notes |
|------|------|-------|
| id | UUID | Stable UI identity for the session |
| path | URL/Path | Absolute local path |
| displayName | String | Filename |
| kind | `file` \| `folder` | Intake type |
| mediaTypeHint | `epub` \| `mobi` \| `pdf` \| `unknown` | From extension |
| isReadable | Bool | Snapshot at selection time |

Validation:
- Path must exist at operation start
- Supported extensions depend on operation

Relationships:
- Input to all job types

### ReadinessIssue
One diagnosis finding.

| Field | Type | Notes |
|------|------|-------|
| code | String | Stable machine code |
| severity | IssueSeverity | Required |
| message | String | Human-readable |
| path | String? | Optional internal archive/path context |

Validation:
- `code` and `message` required
- severity must be one of the four allowed values

### ReadinessReport
Result of audit or prepare.

| Field | Type | Notes |
|------|------|-------|
| inputPath | Path | Original source |
| status | ReadinessStatus | Required |
| issues | [ReadinessIssue] | May be empty |
| outputPath | Path? | Set after prepare/fix |
| convertedFrom | Path? | When MOBI was converted first |
| handoffURL | String | Default Amazon handoff URL |

Derived:
- `fixableIssues`
- `warningIssues`
- `blockingIssues` (severity `error`)
- `isReady` <=> status == `ready`

State transitions:
1. Audit-only → report with `outputPath == nil`
2. Prepare success → report with `outputPath` set and refreshed status
3. Prepare blocked → failed operation or report with `blocked` and no unsafe write

### PreparationRequest
User intent to create a Kindle-ready file.

| Field | Type | Notes |
|------|------|-------|
| source | EbookSource | Required |
| outputPath | Path? | Optional override |
| overwrite | Bool | Default false |

Validation:
- If output exists and overwrite is false, fail before write

### ConversionRequest / ConversionResult

**Request**

| Field | Type | Notes |
|------|------|-------|
| source | EbookSource | Required |
| target | ConversionTarget | `epub` or `mobi` |
| outputPath | Path? | Optional override |
| overwrite | Bool | Default false |

**Result**

| Field | Type | Notes |
|------|------|-------|
| inputPath | Path | |
| outputPath | Path | |
| intermediatePath | Path? | e.g. temp artifacts |

Allowed transforms:
- MOBI → EPUB
- PDF → EPUB
- EPUB → MOBI

### RepairRequest / RepairResult

**Request**

| Field | Type | Notes |
|------|------|-------|
| source | EbookSource | Must be EPUB for repair entry |
| mode | RepairMode | Default `safe` |
| outputPath | Path? | Optional override |
| overwrite | Bool | Default false |

**Result**

| Field | Type | Notes |
|------|------|-------|
| inputPath | Path | |
| outputPath | Path | Must follow `*-repaired.epub` default contract when unspecified |
| mode | RepairMode | Echo request mode |

Rules:
- Default mode is safe structural repair
- Aggressive mode requires explicit user intent

### BookMetadata

| Field | Type | Notes |
|------|------|-------|
| path | Path | |
| raw | String | Raw tool output or serialized source |
| fields | Map<String,String> | Parsed fields; title/author primary |

Update command fields:
- title optional
- author optional
- at least one mutation field required for update operations

### DeliveryProfile

| Field | Type | Notes |
|------|------|-------|
| name | String | Unique profile key |
| senderEmail | String | |
| kindleEmail | String | |
| smtpHost | String | Default `smtp.gmail.com` |
| smtpPort | Int | Default `587` |
| smtpUsername | String | Optional; falls back to senderEmail |
| useTLS | Bool | Default true |
| defaultOutputDir | String | Optional convenience path |

Derived:
- `loginUsername = smtpUsername.isEmpty ? senderEmail : smtpUsername`
- `isSendReady` requires sender, kindle, host, port, login username, and keychain secret presence

Secrets:
- password/token NOT stored on this entity
- referenced via profile name in Keychain

### AppConfig

| Field | Type | Notes |
|------|------|-------|
| defaultProfile | String | Profile name |
| profiles | Map<String, DeliveryProfile> | At least one profile |

### SendRequest / SendResult

**Request**

| Field | Type | Notes |
|------|------|-------|
| source | EbookSource | File to send |
| profileName | String? | Defaults to app default |

**Result**

| Field | Type | Notes |
|------|------|-------|
| inputPath | Path | |
| senderEmail | String | |
| kindleEmail | String | |
| profileName | String | |

### DependencyStatus (CalibreStatus)

| Field | Type | Notes |
|------|------|-------|
| ebookConvertPath | Path? | |
| ebookMetaPath | Path? | |
| ebookPolishPath | Path? | |

Derived:
- `isReady` all three present
- `missingTools` list of tool names

### BatchResult\<T\>
Generic batch envelope.

| Field | Type | Notes |
|------|------|-------|
| results | [T] | Successful or completed item results |
| skipped | [Path] | Unsupported/unreadable items |
| failures | [{path, message}] | Optional explicit failure list if not embedded in T |

Specializations:
- `ReadinessBatchResult` with ready/needs_fixes/blocked counts
- conversion/repair batch summaries

### OperationJob
UI/domain shared progress entity.

| Field | Type | Notes |
|------|------|-------|
| id | UUID | |
| kind | OperationKind | |
| state | OperationState | |
| sourcePaths | [Path] | |
| progressMessage | String? | Current step |
| percent | Double? | Optional 0...1 |
| startedAt | Date | |
| finishedAt | Date? | |
| errorMessage | String? | |
| resultRef | String? | Opaque link to result model id/path |

Transitions:
`queued → running → succeeded|failed|cancelled`

### OperationLogEntry

| Field | Type | Notes |
|------|------|-------|
| id | UUID | |
| timestamp | Date | |
| level | `info` \| `warning` \| `error` | |
| operationId | UUID? | |
| message | String | |

### LegacyReferenceCode
Project/repo concept, not runtime entity.

| Field | Type | Notes |
|------|------|-------|
| rootPath | `legacy/python-tui-cli` | Archived product surface |
| usage | reference only | No runtime import |

## Filename Contracts

| Operation | Default output pattern |
|-----------|------------------------|
| Safe/aggressive repair | `{stem}-repaired.epub` |
| Readiness prepare/fix | `{stem}-kindle-ready.epub` |
| Convert to EPUB | `{stem}.epub` or explicit output |
| Convert to MOBI | `{stem}.mobi` or explicit output |

Rules:
- Never silently overwrite without explicit force/overwrite
- Keep source file unchanged unless user chose an output path equal to source with overwrite enabled

## Relationship Diagram

```text
AppConfig
  └── DeliveryProfile* ──(secret by name)──> KeychainItem

EbookSource
  ├──> ReadinessReport ──> ReadinessIssue*
  ├──> ConversionResult
  ├──> RepairResult
  ├──> BookMetadata
  └──> SendResult

OperationJob ──> OperationLogEntry*
OperationJob result ──> one of the result entities above
DependencyStatus is consulted by services before Calibre-backed operations
```

## Parity Notes from Legacy

| Legacy type | Desktop entity |
|-------------|----------------|
| `CalibreStatus` | `DependencyStatus` |
| `ConversionResult` | `ConversionResult` |
| `BatchResult` | `BatchResult` |
| `BookMetadata` | `BookMetadata` |
| `Profile` | `DeliveryProfile` |
| `AppConfig` | `AppConfig` |
| `SendResult` | `SendResult` |
| `ReadinessIssue` | `ReadinessIssue` |
| `ReadinessReport` | `ReadinessReport` |
| `ReadinessBatchResult` | `ReadinessBatchResult` |
