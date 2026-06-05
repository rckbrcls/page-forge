from __future__ import annotations

import shutil
import tempfile
from pathlib import Path
from typing import Callable, Literal

from .calibre import (
    APP_NAME,
    EPUB_SUFFIX,
    MOBI_SUFFIX,
    require_ebook_convert,
    require_ebook_polish,
    run_calibre_command,
)
from .errors import ConversionError
from .epub_repair import repair_epub_structure
from .models import BatchResult, ConversionResult

ProgressCallback = Callable[[str], None]
TargetFormat = Literal["epub", "mobi"]
RepairMode = Literal["safe", "aggressive"]
BatchOperation = Literal["repair", "to-epub", "to-mobi"]


def require_existing_file(path: Path) -> Path:
    resolved = path.expanduser().resolve()
    if not resolved.exists():
        raise ConversionError(f"Input file does not exist: {resolved}")
    if not resolved.is_file():
        raise ConversionError(f"Input path is not a file: {resolved}")
    return resolved


def require_existing_directory(path: Path) -> Path:
    resolved = path.expanduser().resolve()
    if not resolved.exists():
        raise ConversionError(f"Input directory does not exist: {resolved}")
    if not resolved.is_dir():
        raise ConversionError(f"Input path is not a directory: {resolved}")
    return resolved


def require_suffix(path: Path, expected_suffix: str) -> None:
    if path.suffix.lower() != expected_suffix:
        raise ConversionError(
            f"Expected a {expected_suffix.upper()} file, got: {path.name}"
        )


def default_output_path(source: Path, suffix: str, marker: str | None = None) -> Path:
    stem = source.stem if marker is None else f"{source.stem}-{marker}"
    return source.with_name(f"{stem}{suffix}")


def prepare_output_path(path: Path, force: bool) -> Path:
    resolved = path.expanduser().resolve()
    resolved.parent.mkdir(parents=True, exist_ok=True)
    if resolved.exists():
        if resolved.is_dir():
            raise ConversionError(f"Output path is a directory: {resolved}")
        if not force:
            raise ConversionError(
                f"Output file already exists: {resolved}. Use --force to overwrite it."
            )
        resolved.unlink()
    return resolved


def run_ebook_convert(source: Path, output: Path) -> None:
    executable = require_ebook_convert()
    run_calibre_command([str(executable), str(source), str(output)])


def run_ebook_polish(source: Path, output: Path) -> None:
    executable = require_ebook_polish()
    run_calibre_command([str(executable), "--upgrade-book", str(source), str(output)])


def convert_book(
    source: Path,
    *,
    target_format: TargetFormat,
    output: Path | None = None,
    output_dir: Path | None = None,
    force: bool = False,
    on_progress: ProgressCallback | None = None,
) -> ConversionResult:
    input_path = require_existing_file(source)
    suffix = f".{target_format}"

    if target_format == "epub":
        require_suffix(input_path, MOBI_SUFFIX)
    elif target_format == "mobi":
        require_suffix(input_path, EPUB_SUFFIX)
    else:
        raise ConversionError(f"Unsupported target format: {target_format}")

    if output is not None and output_dir is not None:
        raise ConversionError("Use either --output or --output-dir, not both.")

    default_path = default_output_path(input_path, suffix)
    raw_output = output or (output_dir / default_path.name if output_dir else default_path)
    output_path = prepare_output_path(raw_output, force=force)

    if on_progress:
        on_progress(f"Converting {input_path.name} to {target_format.upper()}")
    run_ebook_convert(input_path, output_path)
    return ConversionResult(input_path=input_path, output_path=output_path)


def repair_epub(
    source: Path,
    *,
    output: Path | None = None,
    output_dir: Path | None = None,
    force: bool = False,
    keep_temp: bool = False,
    mode: RepairMode = "safe",
    on_progress: ProgressCallback | None = None,
) -> ConversionResult:
    input_path = require_existing_file(source)
    require_suffix(input_path, EPUB_SUFFIX)

    if output is not None and output_dir is not None:
        raise ConversionError("Use either --output or --output-dir, not both.")
    if mode not in ("safe", "aggressive"):
        raise ConversionError(f"Unsupported repair mode: {mode}")
    if keep_temp and mode != "aggressive":
        raise ConversionError("--keep-temp is only available with --mode aggressive.")

    default_path = default_output_path(input_path, EPUB_SUFFIX, marker="repaired")
    raw_output = output or (output_dir / default_path.name if output_dir else default_path)
    output_path = prepare_output_path(raw_output, force=force)

    if mode == "safe":
        with tempfile.TemporaryDirectory(prefix=f"{APP_NAME}-") as temp_dir:
            structured_epub = Path(temp_dir) / f"{input_path.stem}-structured.epub"
            if on_progress:
                on_progress("Step 1/2: Repairing EPUB structure")
            repair_epub_structure(input_path, structured_epub)
            if on_progress:
                on_progress("Step 2/2: Polishing EPUB")
            run_ebook_polish(structured_epub, output_path)
        return ConversionResult(input_path=input_path, output_path=output_path)

    return repair_epub_aggressive(
        input_path=input_path,
        output_path=output_path,
        force=force,
        keep_temp=keep_temp,
        on_progress=on_progress,
    )


def repair_epub_aggressive(
    *,
    input_path: Path,
    output_path: Path,
    force: bool = False,
    keep_temp: bool = False,
    on_progress: ProgressCallback | None = None,
) -> ConversionResult:
    kept_mobi = None
    if keep_temp:
        kept_mobi = prepare_output_path(output_path.with_suffix(MOBI_SUFFIX), force=force)

    with tempfile.TemporaryDirectory(prefix=f"{APP_NAME}-") as temp_dir:
        temp_mobi = Path(temp_dir) / f"{input_path.stem}.mobi"
        if on_progress:
            on_progress("Step 1/2: EPUB to MOBI")
        run_ebook_convert(input_path, temp_mobi)
        if on_progress:
            on_progress("Step 2/2: MOBI to EPUB")
        run_ebook_convert(temp_mobi, output_path)

        if kept_mobi is not None:
            shutil.copy2(temp_mobi, kept_mobi)

    return ConversionResult(
        input_path=input_path,
        output_path=output_path,
        intermediate_path=kept_mobi,
    )


def repair_folder(
    folder: Path,
    *,
    output_dir: Path,
    force: bool = False,
    mode: RepairMode = "safe",
    on_progress: ProgressCallback | None = None,
) -> BatchResult:
    input_dir = require_existing_directory(folder)
    destination = output_dir.expanduser().resolve()
    destination.mkdir(parents=True, exist_ok=True)

    results: list[ConversionResult] = []
    skipped: list[Path] = []
    for source in sorted(input_dir.iterdir()):
        if not source.is_file() or source.suffix.lower() != EPUB_SUFFIX:
            skipped.append(source)
            continue
        results.append(
            repair_epub(
                source,
                output_dir=destination,
                force=force,
                mode=mode,
                on_progress=on_progress,
            )
        )
    return BatchResult(results=results, skipped=skipped)


def convert_folder(
    folder: Path,
    *,
    output_dir: Path,
    target_format: TargetFormat,
    force: bool = False,
    on_progress: ProgressCallback | None = None,
) -> BatchResult:
    input_dir = require_existing_directory(folder)
    destination = output_dir.expanduser().resolve()
    destination.mkdir(parents=True, exist_ok=True)
    expected_suffix = MOBI_SUFFIX if target_format == "epub" else EPUB_SUFFIX

    results: list[ConversionResult] = []
    skipped: list[Path] = []
    for source in sorted(input_dir.iterdir()):
        if not source.is_file() or source.suffix.lower() != expected_suffix:
            skipped.append(source)
            continue
        results.append(
            convert_book(
                source,
                target_format=target_format,
                output_dir=destination,
                force=force,
                on_progress=on_progress,
            )
        )
    return BatchResult(results=results, skipped=skipped)
