from __future__ import annotations

from pathlib import Path

from .calibre import require_ebook_meta, run_calibre_command
from .conversion import require_existing_file
from .errors import ConversionError
from .models import BookMetadata


def parse_ebook_meta_output(raw: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for line in raw.splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        fields[key.strip()] = value.strip()
    return fields


def inspect_book(source: Path) -> BookMetadata:
    input_path = require_existing_file(source)
    executable = require_ebook_meta()
    raw = run_calibre_command([str(executable), str(input_path)])
    return BookMetadata(
        path=input_path,
        raw=raw,
        fields=parse_ebook_meta_output(raw),
    )


def update_book_metadata(
    source: Path,
    *,
    title: str | None = None,
    author: str | None = None,
) -> BookMetadata:
    input_path = require_existing_file(source)
    if not title and not author:
        raise ConversionError("Provide at least --title or --author.")

    executable = require_ebook_meta()
    command = [str(executable), str(input_path)]
    if title:
        command.extend(["--title", title])
    if author:
        command.extend(["--authors", author])
    run_calibre_command(command)
    return inspect_book(input_path)
