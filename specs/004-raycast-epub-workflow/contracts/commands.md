# Command Contracts

These contracts define the public Raycast behavior. All UI strings are US English and all primary actions are keyboard accessible.

## Shared Intake Contract

1. Snapshot Finder-selected items when the command opens.
2. Keep readable regular files whose basename ends in `.epub`, case-insensitively.
3. Report rejected mixed-selection items without preventing valid EPUB processing.
4. If no valid EPUB remains, show a multi-file picker that accepts files only.
5. Revalidate extension, regular-file status, readability, size, identity, and modification evidence on submission.
6. Collapse duplicate paths/filesystem identities while preserving first-selection order.
7. Process the stable snapshot sequentially; files selected later are not added to the active run.

## `Page Forge: Inspect EPUB`

**Manifest name**: `inspect-epub`  
**Mode**: `view`  
**Input**: Shared intake snapshot  
**Network access**: None

### Flow

1. Show one list item per selected file with pending state.
2. Inspect sequentially and update phase/progress without removing completed items.
3. Show health, finding counts, EPUB version, duration, and concise detail per item.
4. Open a full report detail grouped by severity/category with code, location, repairability, recommendation, and compatibility notes.
5. Offer retry for failed items and prepare action only for `repairable` items. Cancelled items can be selected in a new operation.

### Required actions

- View Full Report
- Prepare EPUB, when repairable
- Reveal in Finder
- Copy File Path
- Retry Failed Items
- Cancel Active Operation

### Completion

No source file changes, output file creation, preference requirement, or network request is permitted.

## `Page Forge: Prepare EPUB for Kindle`

**Manifest name**: `prepare-epub-for-kindle`  
**Mode**: `view`  
**Input**: Shared intake snapshot  
**Network access**: None

### Flow

1. Inspect each source.
2. For `repairable`, create a plan and show operations, addressed findings, unresolved findings/reasons, and predicted output basename.
3. Require an explicit `Prepare EPUB` action after the plan is visible.
4. Revalidate source snapshot before writing.
5. Reconstruct to a hidden same-directory temporary path.
6. Reinspect and compare the closed temporary file.
7. Promote only a successful result to a no-clobber output path; if the predicted path raced, select the next suffix and report the actual path.
8. Keep each batch item independent.

### Non-repairable states

- `healthy`: show report and explain that no preparation is required; no duplicate copy is created by default.
- `needs_review`: show unresolved findings; no repair action.
- `unsupported`: show reason; no repair action.
- `unsafe`: show safety finding; stop all reads not required for safe diagnosis; no repair action.

### Required result actions

- Reveal Output in Finder
- Copy Output Path
- Open Containing Folder
- View Final Report
- Send EPUB to Kindle
- Retry Failed Items
- Cancel Active Operation

## `Page Forge: Send EPUB to Kindle`

**Manifest name**: `send-epub-to-kindle`  
**Mode**: `view`  
**Input**: Shared intake snapshot  
**Network access**: Only after explicit reviewed confirmation

### Eligibility

- `healthy`: eligible.
- Successfully prepared output with no failed revalidation: eligible.
- `repairable`: offer the prepare flow first; sending remains a later explicit action.
- `needs_review`, `unsupported`, `unsafe`: blocked.

### Batch semantics

- Multiple input EPUBs are accepted.
- The confirmation detail lists every eligible basename and the configured Kindle destination.
- One explicit `Send EPUBs` action authorizes the reviewed eligible set.
- Each eligible EPUB is submitted sequentially in its own SMTP transaction with exactly one attachment.
- No failed or uncertain item is retried automatically.
- Cancellation stops unscheduled items; the active item follows [delivery.md](./delivery.md) cancellation semantics.

### Required actions

- Send EPUB / Send EPUBs, only after eligibility and configuration review
- Prepare EPUB, for repairable items
- Open Delivery Preferences
- Open Send to Kindle
- Reveal in Finder
- View Health Report
- Retry Failed Items
- Send Again, only for an unknown submission and with a duplicate warning
- Cancel Pending Deliveries

### Manual fallback

The official `https://www.amazon.com/sendtokindle` action remains available when SMTP is absent or invalid. It opens the browser only; Page Forge does not log in, upload, or populate the website.

## Progress and Cancellation Contract

- UI progress reflects actual files, phases, or entries; it never invents a time-based percentage.
- The active operation owns one `AbortController`.
- Cancel marks pending items cancelled, signals the active phase, destroys active streams/connections where possible, and preserves completed results.
- The UI must update or yield at least once per second during supported work.
- Closing the Raycast view is not treated as guaranteed cleanup; the next run may remove only recognizable orphan temporary files created by Page Forge.
