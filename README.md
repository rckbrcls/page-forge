![PageForge hero](docs/assets/pageforge-hero.png)

# PageForge

PageForge is a **macOS desktop app** for preparing and managing ebook workflows.

It helps turn scattered ebook files into clean, ready-to-use books through
conversion, repair, metadata cleanup, batch processing, and Kindle delivery.

Under the hood, PageForge orchestrates Calibre-powered EPUB, MOBI, and PDF
operations while owning Kindle readiness diagnosis, safe structural repair, and
a focused desktop experience.

## Product Status

- **Primary surface**: native SwiftUI macOS app (`PageForge.xcodeproj`)
- **Legacy reference**: former Python TUI/CLI under `legacy/python-tui-cli/`
- Legacy code is inspiration/parity oracle only — not the product surface

## Table of Contents

- [macOS Only](#macos-only)
- [Features](#features)
- [Requirements](#requirements)
- [Open / Develop](#open--develop)
- [Readiness Doctor](#readiness-doctor)
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

- Readiness-first desktop workspace
- Drag-and-drop intake for local ebooks
- Kindle Readiness Doctor (audit + prepare)
- Safe EPUB repair and optional aggressive repair
- Conversion: `MOBI -> EPUB`, `PDF -> EPUB`, `EPUB -> MOBI`
- Folder batch readiness/repair/conversion
- Metadata inspect + title/author updates
- Send to Kindle via SMTP profiles or handoff
- Settings for Calibre status, profiles, and update guidance
- In-app operation logs

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

## Readiness Doctor

Default home screen.

- **Audit**: diagnose without writing a new file
- **Prepare / Fix**: write `*-kindle-ready.epub`
- Status vocabulary: `ready`, `needs_fixes`, `blocked`
- Issue severities: `info`, `warning`, `error`, `fixable`
- MOBI is legacy input and may be converted before preparation

Structural repair outputs remain distinct: `*-repaired.epub`

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
macOS desktop app for preparing ebooks: readiness diagnosis, conversion, repair, and Kindle delivery.
```
