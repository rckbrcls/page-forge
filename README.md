![PageForge hero](docs/assets/pageforge-hero.png)

# PageForge

PageForge is a **macOS desktop app** for preparing ebook files for Kindle.

Add EPUB, MOBI, and PDF files to one queue, prepare them with a single action,
then save the Kindle-ready EPUB files locally or send them through a configured
SMTP profile.

Under the hood, PageForge orchestrates Calibre-powered EPUB, MOBI, and PDF
operations while owning Kindle readiness diagnosis, safe structural repair, and
a focused files-first desktop experience.

## Product Status

- **Primary surface**: native SwiftUI macOS app (`PageForge.xcodeproj`)
- **Legacy reference**: former Python TUI/CLI under `legacy/python-tui-cli/`
- Legacy code is inspiration/parity oracle only — not the product surface

## Table of Contents

- [macOS Only](#macos-only)
- [Features](#features)
- [Requirements](#requirements)
- [Open / Develop](#open--develop)
- [Prepare Files](#prepare-files)
- [Send to Kindle](#send-to-kindle)
- [Legacy Python Surface](#legacy-python-surface)
- [Repository Description](#repository-description)

## macOS Only

This app intentionally supports macOS only.

It depends on:

- Calibre macOS tools: `ebook-convert`, `ebook-meta`, `ebook-polish`
- macOS Keychain for SMTP passwords/tokens
- Optional Homebrew for Calibre install/update guidance

## Features

- One files-first queue for EPUB, MOBI, and PDF documents
- Multi-file drag-and-drop, file picker, toolbar, and File menu intake
- Sequential Kindle preparation with independent per-file results
- Kindle-ready EPUB output using the `*-kindle-ready.epub` convention
- Local Save Files export with explicit conflict handling
- Send to Kindle through configured SMTP profiles or explicit Amazon handoff
- Native Settings window for Calibre status, delivery profiles, and preferences
- Contextual readiness details, metadata, repair, and troubleshooting actions

## Requirements

Two layers:

1. **PageForge desktop app** (SwiftUI)
2. **Calibre** external engine

The desktop app requires macOS 26 or later and Xcode 26 or later for development.

Calibre is required because conversion/metadata/polish are delegated to its tools.
PageForge owns workflow UX, readiness diagnosis, and safe structural repair.

## Open / Develop

```bash
open PageForge.xcodeproj
```

Then run the `PageForge` scheme on **My Mac**.

Optional tool path overrides:

```bash
export EBOOK_CONVERT_PATH="/path/to/ebook-convert"
export EBOOK_META_PATH="/path/to/ebook-meta"
export EBOOK_POLISH_PATH="/path/to/ebook-polish"
```

More notes: `docs/desktop-migration.md`

## Prepare Files

The main window contains one document queue. Add any supported local files,
select the items to process, and choose **Prepare Files**.

- EPUB is diagnosed and safely prepared.
- MOBI is converted to EPUB before readiness preparation.
- PDF is converted to EPUB before readiness preparation; OCR is not performed.
- Processing is sequential, failures are isolated per file, and pending work can
  be cancelled without claiming that an active Calibre subprocess stopped.
- Status vocabulary: `ready`, `needs_fixes`, `blocked`
- Issue severities: `info`, `warning`, `error`, `fixable`

Advanced metadata and repair capabilities remain contextual. Structural repair
outputs stay distinct as `*-repaired.epub` and never replace the primary prepare
result.

## Send to Kindle

Two paths:

1. SMTP through local profiles (secret in Keychain)
2. Explicit handoff to Amazon Send to Kindle

PageForge does **not** automate Amazon login or upload.
DRM removal is out of scope.
PDF conversion does **not** promise OCR.

## Legacy Python Surface

Archived under:

- `legacy/python-tui-cli/`
- `legacy/README.md`
- `legacy/notes/behavior-parity.md`

Do not add new product features there.

## Repository Description

```text
macOS app for preparing EPUB, MOBI, and PDF files for Kindle from one simple queue.
```
