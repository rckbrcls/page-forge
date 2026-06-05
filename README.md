# convert-books

A small local CLI for ebook conversion workflows that usually happen on online
converter websites.

It supports:

- `repair-epub`: converts `EPUB -> MOBI -> EPUB`
- `to-epub`: converts `MOBI -> EPUB`
- `to-mobi`: converts `EPUB -> MOBI`
- `doctor`: checks whether Calibre is available
- `setup`: helps install or verify Calibre

## Requirements

Calibre is the conversion engine. This CLI provides the friendly command-line
experience, file checks, output naming, and repair workflow, while Calibre's
`ebook-convert` does the actual EPUB/MOBI conversion.

This split matters because EPUB and MOBI files contain structured HTML,
metadata, images, tables of contents, and format-specific quirks. Calibre is a
mature native tool for that conversion work; the Python package keeps the usage
simple.

The global `uv` install includes the Python dependencies for this CLI. Calibre is
a native macOS app, so it must be installed separately.

The easiest setup path is:

```bash
convert-books setup --install
```

That shows an installation panel, uses Homebrew to install Calibre, then
verifies that `ebook-convert` can be found.

If you prefer to install Calibre yourself:

```bash
brew install --cask calibre
```

You can also download it manually from:

```text
https://calibre-ebook.com/download_osx
```

After installing Calibre, check the setup:

```bash
convert-books doctor
```

The CLI also searches for Calibre in common macOS locations, so you usually do
not need to edit your shell `PATH`.

If you want to check Calibre manually, run:

```bash
/Applications/calibre.app/Contents/MacOS/ebook-convert --version
```

If Calibre is in a custom location, point the CLI to it:

```bash
export EBOOK_CONVERT_PATH="/path/to/ebook-convert"
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

Install or verify Calibre:

```bash
uv run convert-books setup --install
```
