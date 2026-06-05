# convert-books

Local CLI and terminal UI for repairing EPUB files, converting EPUB/MOBI books,
editing metadata, and sending ebooks to Kindle.

## Features

- Interactive terminal UI: `convert-books`
- EPUB repair workflow: `EPUB -> MOBI -> EPUB`
- Direct conversion: `MOBI -> EPUB` and `EPUB -> MOBI`
- Folder batch repair and conversion
- Metadata inspection and title/author updates
- Send to Kindle through SMTP and a configured Kindle email
- Calibre setup checks with visual feedback
- Global installation with `uv tool install`

## Requirements

This project has two layers:

- `convert-books`: the Python CLI/TUI installed with `uv`
- Calibre: the native conversion engine that provides `ebook-convert` and
  `ebook-meta`

Calibre is required because EPUB and MOBI files contain structured HTML,
metadata, images, tables of contents, and format-specific quirks. The Python app
handles the user experience and workflow; Calibre performs the actual ebook
conversion and metadata operations.

## Install

Install `uv` first if you do not already have it:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Then use the one-line installer:

```bash
curl -fsSL https://raw.githubusercontent.com/rckbrcls/convert-books/main/install.sh | sh
```

The installer does not install `uv` for you. If `uv` is missing, it prints the
official install command and exits.

You can also install directly with `uv`:

```bash
uv tool install --force git+https://github.com/rckbrcls/convert-books.git
```

For local editable development:

```bash
uv tool install --force --editable /Users/erickpatrickbarcelos/Documents/convert-books
```

## Setup

Check local dependencies:

```bash
convert-books doctor
```

Install Calibre with Homebrew and show installation feedback:

```bash
convert-books setup --install
```

If Calibre is already installed in a custom location, point the CLI to it:

```bash
export EBOOK_CONVERT_PATH="/path/to/ebook-convert"
export EBOOK_META_PATH="/path/to/ebook-meta"
```

## Terminal UI

Open the interactive terminal interface:

```bash
convert-books
```

Or explicitly:

```bash
convert-books tui
```

The TUI includes:

- Dashboard
- Convert
- Batch
- Send to Kindle
- Metadata
- Settings
- Logs

## Conversion Commands

Repair an EPUB for Send to Kindle:

```bash
convert-books repair-epub ./book.epub
```

Convert MOBI to EPUB:

```bash
convert-books to-epub ./book.mobi
```

Convert EPUB to MOBI:

```bash
convert-books to-mobi ./book.epub
```

Write to a specific output path:

```bash
convert-books repair-epub ./book.epub --output ./book-fixed.epub
```

Overwrite an existing output file:

```bash
convert-books repair-epub ./book.epub --force
```

## Batch Commands

Repair every EPUB in a folder:

```bash
convert-books repair-folder ./books --output ./fixed
```

Convert every MOBI in a folder to EPUB:

```bash
convert-books convert-folder ./books --output ./converted --to epub
```

Convert every EPUB in a folder to MOBI:

```bash
convert-books convert-folder ./books --output ./converted --to mobi
```

## Metadata Commands

Inspect metadata:

```bash
convert-books inspect ./book.epub
```

Update title or author:

```bash
convert-books metadata ./book.epub --title "Book Title" --author "Author Name"
```

## Send to Kindle

First, authorize your sender email in Amazon's Kindle personal document settings.
Then configure a local profile:

```bash
convert-books configure
```

The SMTP password or app token is stored through the system Keychain via
`keyring`; it is not written to the config file.

Send a file:

```bash
convert-books send ./book.epub
```

Repair and send:

```bash
convert-books repair-and-send ./book.epub
```

Use a named profile:

```bash
convert-books send ./book.epub --profile personal
```

List profiles:

```bash
convert-books profiles
```

## Development

Install dependencies:

```bash
uv sync
```

Run commands locally:

```bash
uv run convert-books --help
```
