# Preparation Workflow Contract

**Feature**: `002-simplify-document-workflow`  
**Audience**: Workflow view model, domain services, job coordinator, and tests

## Primary Action

The main screen exposes `Prepare Files` for selected eligible rows. It replaces
separate Audit, Convert, Batch, and safe Repair navigation decisions.

Preconditions:

- At least one selected item is `queued`, `failed`, `needsAttention`, `blocked`
  after recovery, or `cancelled` and eligible for retry.
- Every item is revalidated immediately before work.
- Preparation never overwrites an existing output without explicit confirmation.

## Domain Interface

```text
DocumentPreparing.prepare(
    source: URL,
    format: DocumentFormat,
    overwrite: Bool,
    progress: (PreparationProgress) -> Void
) -> DocumentPreparationResult
```

The concrete `DocumentPreparationService` composes existing services. The view
model does not choose Calibre commands or repair steps.

## Format Routing

### EPUB

1. Call readiness preparation for the source.
2. Preserve the source.
3. Produce `<stem>-kindle-ready.epub` when successful.
4. Return the final readiness report.

### MOBI

1. Delegate to existing readiness preparation.
2. Existing behavior converts to EPUB before readiness preparation.
3. Preserve `convertedFrom` context.
4. Produce `<stem>-kindle-ready.epub` when successful.

### PDF

1. Create a unique temporary working directory.
2. Convert the PDF to a temporary EPUB through `ConversionService`.
3. Prepare that EPUB through `ReadinessService`, passing a final path derived from
   the original PDF: `<pdf-stem>-kindle-ready.epub`.
4. Return a result whose source is the original PDF, never the temporary EPUB.
5. Add or retain clear information that PDF conversion does not perform OCR and
   scanned PDFs may produce poor results.
6. Remove temporary files on success and best-effort on failure.

## Readiness and Output Rules

- Final statuses remain `ready`, `needs_fixes`, or `blocked`.
- Issue severities remain `info`, `warning`, `error`, or `fixable`.
- Successful primary preparation returns a `PreparedOutput` only when the final
  file exists and is readable.
- Primary output is always EPUB and follows `*-kindle-ready.epub`.
- Standalone structural repair remains a separate advanced behavior using
  `*-repaired.epub`; it never masquerades as a completed primary output.
- Original EPUB, MOBI, and PDF files are never modified.

## Queue Execution

- Snapshot selected eligible item IDs when Prepare Files begins.
- Process the snapshot in queue order, one item at a time, off the main actor.
- Mark the active row `preparing` and report its current step.
- Reconcile each result on the main actor.
- Continue after an item report or thrown error.
- Items added after the snapshot remain queued for a later run.
- Selection changes during processing affect later user actions but do not alter
  the active preparation snapshot.

## Progress

Progress may be indeterminate when the underlying tool exposes no fraction. Every
update still includes a specific text step, for example:

- `Validating document`
- `Converting PDF to EPUB`
- `Converting MOBI to EPUB`
- `Preparing EPUB for Kindle`
- `Verifying output`

The interface remains usable throughout the sequence.

## Failure Isolation

Each item independently records:

- blocked readiness report;
- dependency error with Open Settings recovery;
- missing/unreadable source;
- output collision;
- conversion/repair failure;
- cancelled-before-start state.

Prior and later successes remain available. Aggregate status may be partially
completed but never replaces per-item outcomes.

## Cancellation

Initial implementation contract:

- Stop scheduling remaining snapshot items.
- Mark not-started snapshot items `cancelled`.
- Request cooperative cancellation for the workflow task.
- Do not claim immediate termination of an already running external process.
- When the active process returns, reconcile its actual result and finish in a
  consistent terminal state.

Hard child-process termination requires a future explicit cancellable
`CalibreProcessRunner` contract and is not silently inferred.

## Contextual Advanced Capabilities

- Metadata inspection/editing is available from a selected row's advanced menu.
- Aggressive repair is available only for an appropriate failed/attention EPUB,
  clearly labeled and confirmed.
- These controls never become default preparation behavior or top-level screens.

