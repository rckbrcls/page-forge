# convert-books

A small local CLI for ebook conversion workflows that usually happen on online
converter websites.

It supports:

- `repair-epub`: converts `EPUB -> MOBI -> EPUB`
- `to-epub`: converts `MOBI -> EPUB`
- `to-mobi`: converts `EPUB -> MOBI`
- `doctor`: checks whether Calibre is available

## Requirements

Install Calibre first. The CLI calls Calibre's `ebook-convert` command, because
EPUB and MOBI conversion is more reliable through Calibre than through a small
pure-Python converter.

On macOS, after installing Calibre, make sure the command is available:

```bash
/Applications/calibre.app/Contents/MacOS/ebook-convert --version
```

If that works but `ebook-convert` is not found in your terminal, add this to
your shell profile:

```bash
export PATH="/Applications/calibre.app/Contents/MacOS:$PATH"
```

## Install dependencies

```bash
uv sync
```

## Install as a global CLI

For day-to-day use, install the project as a global `uv` tool:

```bash
uv tool install --editable /Users/erickpatrickbarcelos/Documents/convert-books
```

Then run it from anywhere:

```bash
convert-books repair-epub ./book.epub
convert-books to-epub ./book.mobi
convert-books to-mobi ./book.epub
```

If the command is not found after installing, make sure the `uv` tools
directory is on your shell `PATH`:

```bash
uv tool update-shell
```

After changing the shell configuration, restart the terminal.

To remove the global command:

```bash
uv tool uninstall convert-books
```

## Usage

Repair an EPUB for Send to Kindle:

```bash
uv run convert-books repair-epub ./book.epub
```

Write to a specific path:

```bash
uv run convert-books repair-epub ./book.epub --output ./book-fixed.epub
```

Convert MOBI to EPUB:

```bash
uv run convert-books to-epub ./book.mobi
```

Convert EPUB to MOBI:

```bash
uv run convert-books to-mobi ./book.epub
```

Overwrite an existing output file:

```bash
uv run convert-books repair-epub ./book.epub --force
```

Check local setup:

```bash
uv run convert-books doctor
```
