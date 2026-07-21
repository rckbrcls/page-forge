# Quickstart Validation Guide

This guide validates the implemented Page Forge Raycast extension end to end. It is not an implementation tutorial. Commands are documented for the future implementation and were not run during planning.

## Prerequisites

- A supported macOS version with Raycast installed.
- Node.js in the range declared by `package.json`.
- npm.
- No Calibre, EPUBCheck, Java, Python, Homebrew tool, helper application, or local service is required.
- SMTP test credentials and a controlled recipient are needed only for explicit delivery validation.

## Install and Static Validation

From the repository root after implementation:

```bash
npm ci
npm run lint
npm run format:check
npm test
npm run coverage
npm run build
```

Expected outcomes:

- Dependency installation uses the committed lockfile and installs no runtime native binary.
- Lint, formatting, type checking included by the Raycast build, tests, coverage thresholds, and distribution build pass.
- The package manifest exposes exactly three macOS `view` commands.
- The build output contains no Swift, Python, Calibre, EPUBCheck, executable download, helper process, or desktop app artifact.

## Load the Extension for Manual Validation

Run only in an environment where starting Raycast development mode is allowed:

```bash
npm run dev
```

Expected commands in Raycast:

1. `Page Forge: Inspect EPUB`
2. `Page Forge: Prepare EPUB for Kindle`
3. `Page Forge: Send EPUB to Kindle`

No separate Page Forge application should exist or launch.

## Scenario 1: Finder Inspection

1. Select the valid EPUB 2 and EPUB 3 fixtures in Finder.
2. Run `Page Forge: Inspect EPUB`.
3. Wait for both independent results.
4. Open each full report.
5. Compare source hashes before and after.

Expected outcomes:

- Both files report `Healthy`, allowing only Info compatibility notes.
- Reports include EPUB version, an accounted v1 rule set, duration, and structured findings.
- No output file or network request is created.
- Source hashes are unchanged.

## Scenario 2: Picker Fallback and Mixed Selection

1. Open the inspection command without Finder frontmost or without a supported selection.
2. Choose one valid EPUB, one non-EPUB file, and one invalid-ZIP `.epub` with the picker.

Expected outcomes:

- The picker supports multiple files.
- The non-EPUB item is clearly rejected without blocking the others.
- The valid EPUB receives its report.
- The invalid ZIP receives `Unsupported` with `ZIP_INVALID`.

## Scenario 3: Safe Preparation

1. Select fixtures with missing, compressed, misordered, and incorrect `mimetype` entries.
2. Run `Page Forge: Prepare EPUB for Kindle`.
3. Review each plan before confirming.
4. Confirm preparation.
5. Inspect the generated copies and compare source hashes.

Expected outcomes:

- Each plan lists exact findings, operations, unchanged issues, and predicted output basename.
- Outputs use `-kindle-ready.epub` and are separate from sources.
- Canonical `mimetype` is first, exact, and stored.
- Full reinspection runs from the written copy.
- Reports distinguish resolved, remaining, and introduced findings.
- Original hashes remain unchanged.

## Scenario 4: Collision-Safe Output

1. Place `book.epub`, `book-kindle-ready.epub`, and `book-kindle-ready-2.epub` in a writable test directory.
2. Prepare `book.epub`.

Expected outcomes:

- The planned and final path is `book-kindle-ready-3.epub`.
- Existing files remain byte-for-byte unchanged.
- No overwrite confirmation is offered because overwrite is never allowed.

## Scenario 5: Ambiguous Repairs

1. Inspect and prepare fixtures with multiple plausible OPFs, multiple cover candidates, missing editorial metadata, malformed XHTML, and ambiguous references.

Expected outcomes:

- Each item reports `Needs Review` unless a higher state applies.
- No OPF, cover, metadata, chapter, navigation, CSS, script, font, or ambiguous reference is chosen or changed.
- The report explains why no automatic repair is available.
- No final output is created.

## Scenario 6: Hostile Archive Boundaries

Run focused tests and command inspection for generated fixtures covering:

- traversal, absolute, backslash, NUL, and invalid names;
- exact duplicate, Unicode-folded collision, and file/directory conflict;
- symlink, special file, encrypted entry, unsupported method, invalid ZIP64, and CRC/size mismatch;
- values immediately below, at, and above source size, entry count, expanded entry, expanded aggregate, ratio, XML size, XML depth, and timeout limits;
- DTD, entity, local-file reference, executable content, and DRM/encryption.

Expected outcomes:

- Every above-limit or dangerous case is `Unsafe` with the stable catalog code.
- Boundary-equal permitted values do not fail solely for being equal to the maximum.
- No entry is extracted to the filesystem, no referenced resource is fetched, and no embedded content executes.
- No final output is created for unsafe input.

## Scenario 7: Repair Failure and Cancellation

1. Cancel during archive reconstruction.
2. Cancel during revalidation.
3. Simulate write failure and a newly introduced Error finding.

Expected outcomes:

- Sources, existing outputs, and previously completed batch items remain unchanged.
- Owned temporary files are removed when safe.
- No partial file is visible under a Kindle-ready final name.
- A new Error or Critical finding makes preparation unsuccessful.

## Scenario 8: Mixed Batch and Retry

1. Select 20 fixtures mixing healthy, repairable, needs-review, unsupported, unsafe, and unreadable cases.
2. Run inspect and prepare flows.
3. Retry only failed items.

Expected outcomes:

- Results remain in selection order and are isolated per item.
- One failure does not stop later items.
- At most one EPUB and one archive entry are active at a time.
- Retry excludes completed successful items.

## Scenario 9: SMTP Configuration and Submission

Use a controlled SMTP test account. Never use production credentials in fixtures, source, or test output.

1. Open the send command with no SMTP settings.
2. Confirm the manual Send to Kindle and reveal-file actions are available.
3. Configure implicit TLS or mandatory STARTTLS using Raycast command preferences.
4. Select one healthy fixture and confirm its details.
5. Explicitly submit it.

Expected outcomes:

- Missing settings do not block opening the command.
- No network connection occurs before confirmation.
- Exactly one EPUB is streamed as the only attachment.
- The transmitted bytes come from a private temporary snapshot whose digest matches the reviewed report, and that snapshot is removed after submission.
- Success says `Submitted to the SMTP server`, not delivered to Kindle.
- Password, raw server response, full path, and book metadata appear nowhere in logs or errors.

## Scenario 10: Delivery Failure, Unknown Result, and Batch

1. Validate wrong credentials, bad host, TLS failure, envelope rejection, size rejection, stream failure, and network timeout.
2. Cancel before connection and after message data begins.
3. Select multiple eligible EPUBs and confirm the reviewed batch.

Expected outcomes:

- Each failure maps to a sanitized category from [delivery.md](./contracts/delivery.md).
- Pre-connection cancellation is definitive.
- Ambiguous post-DATA interruption reports `delivery_unknown` and never retries automatically.
- Each batch item uses a separate SMTP transaction with one attachment.
- A failed item does not submit extra attachments or prevent later items unless cancellation is requested.

## Scenario 11: Privacy and Repository Replacement

Run static searches after migration:

```bash
rg -n "Calibre|ebook-convert|ebook-meta|ebook-polish|SwiftUI|xcodebuild|Sparkle|MOBI|AZW3|KFX" . \
  --glob '!specs/004-raycast-epub-workflow/**' \
  --glob '!.git/**'
rg --files . | rg "(^|/)(PageForge|PageForgeTests|legacy|PageForge\\.xcodeproj)(/|$)|appcast\\.xml$"
git diff --check
```

Expected outcomes:

- No production or current documentation references the removed product, engines, conversion, or unsupported formats.
- No legacy application, Xcode project, Python product, appcast, desktop installer, or desktop release artifact remains.
- `.specify/`, `.agents/`, and `specs/004-raycast-epub-workflow/` remain.
- Static diff checks report no whitespace errors.

## Scenario 12: Store Readiness

Before publication:

1. Confirm icon ownership and 512x512 PNG dimensions.
2. Confirm MIT license and package dependency licenses.
3. Review README instructions, privacy, repair boundaries, SMTP setup, approved-sender requirement, and manual fallback.
4. Run the complete local validation sequence.
5. Run the publish command only when intentionally creating the Raycast Store submission.

Expected outcomes:

- All local quality gates pass.
- The package contains one extension and three commands.
- Publication does not use npm distribution, Sparkle, GitHub desktop releases, or downloaded executables.

## Contract References

- Data and transitions: [data-model.md](./data-model.md)
- Command behavior: [contracts/commands.md](./contracts/commands.md)
- Engine boundaries: [contracts/engine.md](./contracts/engine.md)
- Finding codes: [contracts/findings.md](./contracts/findings.md)
- SMTP delivery: [contracts/delivery.md](./contracts/delivery.md)
