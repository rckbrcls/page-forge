# Contract: Send History Storage

## Purpose

Persist a privacy-minimized, bounded, local record of definitive SMTP
submissions without changing delivery outcomes or creating a book-management
system.

## Storage port

The domain port exposes values, not file details:

```swift
protocol SendHistoryStoring: Sendable {
    func load() async throws -> [SubmissionRecord]
    func replace(with records: [SubmissionRecord]) async throws
    func clear() async throws
}
```

The port accepts no receipt, batch, item, path, URL, credential, address, SMTP
reply, provider text, book content, or arbitrary metadata.

## Application service

The application service exposes semantic operations:

```swift
actor SendHistoryService {
    func snapshot() async throws -> SendHistorySnapshot
    func record(_ receipt: SubmissionReceipt) async throws
    func clear() async throws
}
```

The exact Swift signatures may evolve during implementation, but the
responsibility split is fixed:

- pipeline creates a receipt only after definitive acceptance;
- service projects the receipt to the three-field record;
- service deduplicates, orders, and enforces retention;
- adapter validates and persists the versioned envelope;
- presentation receives only immutable snapshots and typed failures.

## Record-once contract

1. SMTP returns definitive acceptance for one delivery attempt.
2. Pipeline fixes `acceptedAt` and creates `SubmissionReceipt`.
3. Service projects `attemptID`, `displayName`, and `acceptedAt`.
4. If that identifier already exists, recording succeeds without duplication.
5. Otherwise the service inserts, orders, truncates to 500, and persists.
6. Only after persistence resolves does the pipeline advance its local history
   event/presentation path.

Each retry has a new delivery attempt identifier. Therefore two independently
accepted attempts for the same book remain two records.

## Inclusion matrix

| Delivery outcome | Create history record |
|---|---|
| Definitive provider acceptance / `Submitted` | Yes, exactly once |
| Provider rejection / failed | No |
| User cancellation before definitive acceptance | No |
| Excluded or unsupported item | No |
| Unattempted pending item | No |
| `Delivery Unknown` | No |

No later user belief, Kindle appearance, or manual action rewrites an uncertain
attempt as a definitive record.

## Envelope

Initial logical representation:

```json
{
  "schemaVersion": 1,
  "records": [
    {
      "id": "8A393502-DA20-45E9-A614-7C0B938EAA77",
      "displayName": "Example.epub",
      "acceptedAt": "2026-07-30T18:45:12Z"
    }
  ]
}
```

This example defines field shape, not a required human-readable encoding.
Dates must round-trip as absolute instants.

## File behavior

- Store one file at
  `Application Support/Book Sender/SendHistory/history-v1.json`.
- Create the parent directory with owner-only permissions when absent and keep
  the file owner-readable and owner-writable.
- Serialize access inside an actor.
- Reject files larger than 1 MiB before decoding.
- Validate schema version, record count, identifiers, display names, and dates.
- Write a temporary file in the same directory and atomically replace the
  destination.
- Do not follow external references or load book files.
- Do not silently delete, repair, or overwrite an unreadable existing file.
- No migration is required before schema version 1 exists. A future schema
  requires an explicit versioned migration plan.

## Ordering and retention

- Returned and persisted records are newest first.
- `acceptedAt` descending is the primary order.
- Identifier descending is a deterministic tie-breaker.
- After insertion, retain exactly the newest 500 or fewer.
- In a multi-book insertion crossing capacity, each accepted attempt remains
  independently idempotent and final storage still contains the newest 500.

## Clearing

- UI confirmation occurs before the service receives `clear`.
- Successful clear leaves an empty snapshot and removes or replaces only the
  history file.
- Clear never touches the current batch, workspace, setup, credential,
  preferences, diagnostic storage, or application route.
- Cancelling confirmation calls no storage operation.
- Clear failure preserves the existing visible snapshot until a later
  successful reload proves otherwise.

## Failure isolation

History failures use stable typed codes and safe recovery presentation.

- Load failure: show an empty or unavailable history state plus actionable
  feedback; do not claim there are no records if loading is unknown.
- Record failure: keep delivery `Submitted`, do not retry SMTP, and explain that
  the local record could not be saved.
- Clear failure: keep the existing snapshot visible and explain that clearing
  did not complete.

Raw errors, paths, payloads, and records do not enter display, logging, copied
diagnostics, or feedback.

## Privacy acceptance checks

Automated source and model tests must prove the durable record contains only:

- record identifier;
- original sanitized display name;
- definitive acceptance timestamp.

Tests must reject accidental addition of:

- source path or URL;
- book content or metadata beyond display name;
- sender, username, recipient, or Kindle address;
- credential or Keychain data;
- SMTP command, response, status prose, or message bytes;
- batch, snapshot, item, diagnostic, telemetry, or remote identifiers.
