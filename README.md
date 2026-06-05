![PageForge hero](docs/assets/pageforge-hero.png)

# PageForge

PageForge is a macOS-only terminal app for repairing EPUB files, converting
EPUB/MOBI books, editing metadata, and sending ebooks to Kindle.

It is TUI-first: running `page-forge` without arguments opens the interactive
terminal app. Command-line shortcuts remain available for automation,
scripting, support, and fast one-off tasks.

## Table of Contents

- [macOS Only](#macos-only)
- [Features](#features)
- [Requirements](#requirements)
- [Install](#install)
- [Terminal UI](#terminal-ui)
- [Setup](#setup)
- [Update](#update)
- [Command-Line Shortcuts](#command-line-shortcuts)
- [Send to Kindle](#send-to-kindle)
- [Development](#development)
- [Repository Description](#repository-description)

## macOS Only

This app intentionally supports macOS only.

It depends on:

- Homebrew for installing and updating Calibre
- Calibre macOS app paths for `ebook-convert` and `ebook-meta`
- macOS Keychain through `keyring` for SMTP passwords or app tokens

## Features

- Interactive Textual TUI: `page-forge`
- EPUB repair workflow: `EPUB -> MOBI -> EPUB`
- Direct conversion: `MOBI -> EPUB` and `EPUB -> MOBI`
- Folder batch repair and conversion
- Metadata inspection and title/author updates
- Send to Kindle through SMTP and a configured Kindle email
- Calibre setup checks with visual feedback
- App and Calibre update commands
- Command-line shortcuts for automation

## Requirements

This project has two layers:

- `page-forge`: the Python TUI/CLI installed with `uv`
- Calibre: the native conversion engine that provides `ebook-convert` and
  `ebook-meta`

Calibre is required because EPUB and MOBI files contain structured HTML,
metadata, images, tables of contents, and format-specific quirks. The Python app
handles the experience and workflow; Calibre performs the actual ebook
conversion and metadata operations.

## Install

Install `uv` first if you do not already have it:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Then use the one-line installer:

```bash
curl -fsSL https://raw.githubusercontent.com/rckbrcls/page-forge/main/install.sh | sh
```

The installer does not install `uv` for you. If `uv` is missing, it prints the
official install command and exits.

You can also install directly with `uv`:

```bash
uv tool install --force git+https://github.com/rckbrcls/page-forge.git
```

For local editable development:

```bash
uv tool install --force --editable /Users/erickpatrickbarcelos/Documents/page-forge
```

## Terminal UI

Open the app:

```bash
page-forge
```

Or explicitly:

```bash
page-forge tui
```

The TUI includes:

- Dashboard
- Convert
- Batch
- Send to Kindle
- Metadata
- Settings
- Logs

The Dashboard is the main control center for Calibre status, Kindle profile
status, update actions, and recent logs.

## Setup

Check local dependencies:

```bash
page-forge doctor
```

Install Calibre with Homebrew and show installation feedback:

```bash
page-forge setup --install
```

If Calibre is already installed in a custom location, point the app to it:

```bash
export EBOOK_CONVERT_PATH="/path/to/ebook-convert"
export EBOOK_META_PATH="/path/to/ebook-meta"
```

## Update

Update only `page-forge`:

```bash
page-forge update
```

Update only Calibre:

```bash
page-forge update --calibre-only
```

Update both `page-forge` and Calibre:

```bash
page-forge update --include-calibre
```

Calibre is not updated by default because it is a separate native macOS app.

## Command-Line Shortcuts

Repair an EPUB for Send to Kindle:

```bash
page-forge repair-epub ./book.epub
```

Convert MOBI to EPUB:

```bash
page-forge to-epub ./book.mobi
```

Convert EPUB to MOBI:

```bash
page-forge to-mobi ./book.epub
```

Repair every EPUB in a folder:

```bash
page-forge repair-folder ./books --output ./fixed
```

Convert every MOBI in a folder to EPUB:

```bash
page-forge convert-folder ./books --output ./converted --to epub
```

Inspect metadata:

```bash
page-forge inspect ./book.epub
```

Update title or author:

```bash
page-forge metadata ./book.epub --title "Book Title" --author "Author Name"
```

## Send to Kindle

First, authorize your sender email in Amazon's Kindle personal document settings.
Then configure a local profile:

```bash
page-forge configure
```

The SMTP password or app token is stored through macOS Keychain via `keyring`;
it is not written to the config file.

Send a file:

```bash
page-forge send ./book.epub
```

Repair and send:

```bash
page-forge repair-and-send ./book.epub
```

Use a named profile:

```bash
page-forge send ./book.epub --profile personal
```

List profiles:

```bash
page-forge profiles
```

## Development

Install dependencies:

```bash
uv sync
```

Run command help locally:

```bash
uv run page-forge --help
```

## Repository Description

Use this GitHub description:

```text
macOS-only terminal app for repairing, converting, and sending ebooks to Kindle.
```
