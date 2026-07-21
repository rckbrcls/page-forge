# EPUB Engine Contracts

The engine is independent of React and Raycast. Expected failures use typed results; generic exceptions are caught and sanitized at adapter boundaries.

## Dependency Direction

```text
Raycast entrypoints
  -> command views
  -> application services
  -> audit/repair domain
  -> archive, XML, filesystem, delivery, and Raycast adapters
```

Domain modules must not import Raycast, ZIP-library, filesystem, SMTP, or UI modules.

## Result Type

```text
Result<T, F> = { ok: true, value: T } | { ok: false, failure: F }
```

All public application and adapter operations return a `Result` or an async stream of typed progress plus one terminal `Result`.

## Application Services

### Select EPUBs

```text
selectEpubs(source, signal)
  -> Result<SelectionSnapshot, ProcessingFailure>
```

Guarantees stable order, deduplication, validation, and item-level rejections.

### Inspect EPUBs

```text
inspectEpubs(snapshot, ports, signal, onProgress)
  -> BatchOperation<HealthReport>
```

Guarantees sequential isolation, complete reports only, no writes, and no network calls.

### Prepare EPUBs

```text
planEpub(source, report, outputPort)
  -> Result<RepairPlan, ProcessingFailure>

prepareEpub(confirmedPlan, ports, signal, onProgress)
  -> PreparationResult
```

Guarantees stale-source detection, planned changes only, temporary output cleanup, full disk revalidation, comparison, and atomic final promotion. An unsuccessful result retains before/after reports and comparison when available without constructing `PreparedEpub`.

### Send EPUBs

```text
sendEpubs(confirmedEligibleSet, configuration, deliveryPort, signal, onProgress)
  -> BatchOperation<DeliveryResult>
```

Guarantees sequential one-attachment transactions, no automatic retry, sanitized results, and phase-aware cancellation.

## Domain Services

### Audit

```text
auditEpub(preflightOutcome, ruleCatalog)
  -> HealthReport

deriveHealth(findings)
  -> HealthState
```

Rules are deterministic pure functions over bounded projections whenever possible. `preflightOutcome` contains findings plus an optional safe projection. Unsupported/Unsafe terminal findings can prevent projection creation while still producing a report; every later rule is explicitly marked `not_applicable` or `not_run_after_terminal_finding`. Operational filesystem errors and user cancellation remain `ProcessingFailure`.

### Repair Planning

```text
createRepairPlan(source, report, candidateFacts, predictedOutput)
  -> Result<RepairPlan, ProcessingFailure>
```

Each operation must:

- reference one or more findings;
- belong to the allowed `RepairKind` set;
- have exactly one deterministic target;
- identify changed archive entries;
- preserve meaning and unrelated resources;
- include a user-readable explanation.

### Revalidation Comparison

```text
compareReports(before, after, appliedRepairs)
  -> RevalidationComparison
```

Finding identity is code + normalized internal location + target identifier. Comparison enriches each finding occurrence with applied-repair and revalidation status. Success requires final `healthy` state, no introduced Error/Critical finding, and every confirmed operation applied or proven already satisfied.

## Archive Port

```text
preflightArchive(verifiedDescriptor, limits, signal)
  -> Result<PreflightOutcome<{ session?: ArchiveSession, projection?: ArchiveProjection, findings: Finding[], ruleResults: RuleResult[] }>, ProcessingFailure>

ArchiveSession.openEntry(entry, signal)
  -> Result<BoundedReadable, ProcessingFailure>

rebuildArchive(sourceSession, plan, tempOutput, limits, signal, onProgress)
  -> Result<AppliedRepair[], ProcessingFailure>
```

### Preflight invariants

- Inspect central directory before opening content streams.
- Produce terminal Unsafe findings for a source over 200,000,000 bytes, more than 10,000 entries, entries over 100,000,000 expanded bytes, expanded aggregate over 1,000,000,000 bytes, or expansion above 100:1.
- Ratio uses integer comparison `expanded > compressed * 100`; directory entries are excluded. An empty file (`expanded = 0`) has ratio zero. Any non-empty file with `compressed = 0` is Unsafe. Aggregate ratio compares summed expanded bytes to summed compressed bytes for regular files using the same zero rule. ZIP structural overhead is excluded.
- Accept only STORE and DEFLATE.
- Reject encryption, invalid/multi-disk ZIP, unsafe ZIP64, symlinks, special files, unsafe names, duplicates, and path conflicts.

### Stream invariants

- One active entry stream.
- Actual expanded bytes cannot exceed declared or configured bounds.
- Actual CRC must match the central-directory value.
- Abort destroys streams and closes archive handles.
- Unchanged entry data is streamed, not buffered as a whole.

### Reconstruction invariants

- Canonical `mimetype` is first, ASCII-exact, STORE, and has no local-header extras.
- Other entries retain original relative order after removed/replaced entries.
- No unplanned entry is removed or introduced.
- XML buffers are capped at 10,000,000 bytes.
- Output stream is capped at 200,000,000 bytes.

## XML Port

```text
parseContainer(xmlStream, limits, signal)
  -> Result<ParseOutcome<ContainerProjection>, ProcessingFailure>

parsePackage(xmlStream, limits, signal)
  -> Result<ParseOutcome<PackageProjection>, ProcessingFailure>

parseContentReferences(xmlStream, mediaType, limits, signal)
  -> Result<ParseOutcome<ContentProjection>, ProcessingFailure>
```

Rules:

- UTF-8, UTF-16LE, and UTF-16BE only; fatal decoding.
- XML 1.0 only.
- Maximum 10,000,000 decoded input bytes and depth 64.
- Reject every DOCTYPE and undeclared/entity-expansion attempt.
- Never resolve local or remote entities/resources.
- Match namespace URI and local name, never a hard-coded prefix.
- Check cancellation between bounded chunks and yield to the event loop.
- Record bounded line/column evidence; never retain long book excerpts.
- `ParseOutcome` carries an optional projection plus structural/safety findings. Malformed, excessive, DTD/entity, or unsupported XML is reported as findings; only operational stream/parser failures use `ProcessingFailure`.

## Filesystem Port

```text
snapshotSource(path)
  -> Result<SelectedEpub, ProcessingFailure>

openVerifiedSource(snapshot)
  -> Result<VerifiedReadDescriptor, ProcessingFailure>

predictOutput(sourcePath, suffixPolicy)
  -> Result<PredictedOutput, ProcessingFailure>

createSameDirectoryTemporary(prediction)
  -> Result<TemporaryOutput, ProcessingFailure>

promoteNoClobber(temp, currentCandidate)
  -> Result<FinalOutput, ProcessingFailure>

cleanupTemporary(temp)
  -> Result<void, ProcessingFailure>
```

Rules:

- Source opens read-only and must remain unchanged.
- Output candidates are `<base>-kindle-ready.epub`, then `-2`, `-3`, etc.; planning predicts but does not create one.
- Promotion uses same-directory atomic hard-link creation so an existing path is never overwritten; `EEXIST` advances the suffix and unsupported no-clobber semantics fail clearly.
- Temporary names are random, recognizable as Page Forge-owned, and in the same directory.
- Final promotion occurs only after successful revalidation/comparison and all confirmed operations are applied or proven already satisfied.
- Cleanup never removes source, final, prior output, or unrecognized files.
- Source and output are opened read-only, validated with `fstat`, read through that same descriptor, and checked again after the operation. Prepared outputs retain identity, size, digest, and modification evidence for delivery.

## Timeout and Cancellation

- Compose user cancellation with a 120,000 ms per-file deadline.
- Check before and after each phase, between entries, and between XML chunks.
- Timeout during inspection produces `ARCHIVE_TIMEOUT` and an Unsafe report. Timeout during reconstruction or revalidation produces typed `REPAIR_TIMEOUT` or `REVALIDATION_TIMEOUT`, no final output, and retained comparison evidence when available.
- User cancellation returns `cancelled` and stops pending scheduling.
- JavaScript work must be chunked/yielded; a signal cannot interrupt a long synchronous call.
- SMTP timing follows the separate [delivery contract](./delivery.md).

## Privacy and Logging

- Domain and adapters emit structured progress identifiers, not book content.
- No full source/output paths, filenames, XML text, metadata text, raw exceptions, SMTP responses, or credentials are logged.
- User-visible reports may include internal EPUB paths and basenames where necessary.
- Inspect and prepare dependency graphs contain no network port.
