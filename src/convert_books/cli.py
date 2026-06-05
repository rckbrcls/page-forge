from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
import time
from collections import deque
from pathlib import Path
from typing import Annotated

import typer
from rich.console import Console
from rich.live import Live
from rich.panel import Panel
from rich.progress import Progress, SpinnerColumn, TextColumn, TimeElapsedColumn
from rich.table import Table
from rich.text import Text

APP_NAME = "convert-books"
EPUB_SUFFIX = ".epub"
MOBI_SUFFIX = ".mobi"
EBOOK_CONVERT_ENV_VAR = "EBOOK_CONVERT_PATH"
INSTALL_LOG_LINES = 8
EBOOK_CONVERT_CANDIDATES = (
    Path("/Applications/calibre.app/Contents/MacOS/ebook-convert"),
    Path.home() / "Applications/calibre.app/Contents/MacOS/ebook-convert",
    Path("/opt/homebrew/bin/ebook-convert"),
    Path("/usr/local/bin/ebook-convert"),
)

app = typer.Typer(
    name=APP_NAME,
    help="Repair EPUB files and convert ebooks locally with Calibre.",
    no_args_is_help=True,
)
console = Console()


class ConversionError(RuntimeError):
    """Raised when the external converter cannot finish the requested work."""


def _is_executable(path: Path) -> bool:
    return path.exists() and path.is_file() and os.access(path, os.X_OK)


def _ebook_convert_path() -> Path:
    configured = os.environ.get(EBOOK_CONVERT_ENV_VAR)
    if configured:
        configured_path = Path(configured).expanduser().resolve()
        if _is_executable(configured_path):
            return configured_path
        raise ConversionError(
            f"{EBOOK_CONVERT_ENV_VAR} points to a missing file: {configured_path}"
        )

    executable = shutil.which("ebook-convert")
    if executable is not None:
        return Path(executable)

    for candidate in EBOOK_CONVERT_CANDIDATES:
        if _is_executable(candidate):
            return candidate

    raise ConversionError(
        "Calibre command not found. Install Calibre or run `convert-books setup`."
    )


def _require_existing_file(path: Path) -> Path:
    resolved = path.expanduser().resolve()
    if not resolved.exists():
        raise ConversionError(f"Input file does not exist: {resolved}")
    if not resolved.is_file():
        raise ConversionError(f"Input path is not a file: {resolved}")
    return resolved


def _require_suffix(path: Path, expected_suffix: str) -> None:
    if path.suffix.lower() != expected_suffix:
        raise ConversionError(
            f"Expected a {expected_suffix.upper()} file, got: {path.name}"
        )


def _default_output_path(source: Path, suffix: str, marker: str | None = None) -> Path:
    stem = source.stem if marker is None else f"{source.stem}-{marker}"
    return source.with_name(f"{stem}{suffix}")


def _prepare_output_path(path: Path, force: bool) -> Path:
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


def _run_ebook_convert(source: Path, output: Path) -> None:
    executable = _ebook_convert_path()
    command = [str(executable), str(source), str(output)]
    completed = subprocess.run(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    if completed.returncode != 0:
        details = completed.stderr.strip() or completed.stdout.strip()
        raise ConversionError(details or "Calibre failed without an error message.")


def _render_success(title: str, rows: list[tuple[str, Path]]) -> None:
    table = Table(show_header=False, box=None, padding=(0, 1))
    table.add_column("Label", style="bold cyan")
    table.add_column("Path", overflow="fold")
    for label, path in rows:
        table.add_row(label, str(path))

    console.print()
    console.print(Panel(table, title=title, border_style="green"))


def _convert_with_progress(source: Path, output: Path, label: str) -> None:
    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        TimeElapsedColumn(),
        console=console,
        transient=True,
    ) as progress:
        task = progress.add_task(label, total=None)
        _run_ebook_convert(source, output)
        progress.update(task, completed=1)


def _homebrew_path() -> str | None:
    return shutil.which("brew")


def _calibre_explanation() -> str:
    return (
        "Calibre provides the `ebook-convert` engine used for reliable EPUB/MOBI "
        "conversion."
    )


def _install_panel(
    *,
    status: str,
    command: str,
    started_at: float,
    lines: deque[str],
    border_style: str = "cyan",
) -> Panel:
    elapsed = time.monotonic() - started_at
    table = Table(show_header=False, box=None, padding=(0, 1))
    table.add_column("Label", style="bold cyan", no_wrap=True)
    table.add_column("Value", overflow="fold")
    table.add_row("Status", status)
    table.add_row("Command", command)
    table.add_row("Elapsed", f"{elapsed:0.1f}s")
    table.add_row("Why", _calibre_explanation())
    table.add_row(
        "Output",
        Text("\n".join(lines) if lines else "Waiting for Homebrew output..."),
    )
    return Panel(table, title="Installing Calibre", border_style=border_style)


def _install_calibre_with_homebrew() -> None:
    brew = _homebrew_path()
    if brew is None:
        raise ConversionError(
            "Homebrew command not found. Install Calibre manually from "
            "https://calibre-ebook.com/download_osx"
        )

    command = [brew, "install", "--cask", "calibre"]
    command_text = "brew install --cask calibre"
    lines: deque[str] = deque(maxlen=INSTALL_LOG_LINES)
    started_at = time.monotonic()

    process = subprocess.Popen(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )

    with Live(
        _install_panel(
            status="Starting Homebrew",
            command=command_text,
            started_at=started_at,
            lines=lines,
        ),
        console=console,
        refresh_per_second=6,
        transient=False,
    ) as live:
        if process.stdout is not None:
            for raw_line in process.stdout:
                line = raw_line.strip()
                if line:
                    lines.append(line)
                live.update(
                    _install_panel(
                        status="Installing Calibre",
                        command=command_text,
                        started_at=started_at,
                        lines=lines,
                    )
                )

        returncode = process.wait()
        if returncode == 0:
            live.update(
                _install_panel(
                    status="Homebrew install finished",
                    command=command_text,
                    started_at=started_at,
                    lines=lines,
                    border_style="green",
                )
            )
            return

        live.update(
            _install_panel(
                status="Homebrew install failed",
                command=command_text,
                started_at=started_at,
                lines=lines,
                border_style="red",
            )
        )
        details = "\n".join(lines)
        raise ConversionError(details or "Homebrew failed without an error message.")


@app.command("doctor")
def doctor() -> None:
    """Check whether local conversion dependencies are available."""
    try:
        executable = _ebook_convert_path()
    except ConversionError as error:
        console.print(Panel(str(error), title="Missing dependency", border_style="red"))
        raise typer.Exit(code=1) from error

    _render_success("Ready", [("ebook-convert", Path(executable))])


@app.command("setup")
def setup(
    install: Annotated[
        bool,
        typer.Option(
            "--install",
            help="Install Calibre with Homebrew when it is missing.",
        ),
    ] = False,
) -> None:
    """Help install and verify external conversion dependencies."""
    try:
        executable = _ebook_convert_path()
    except ConversionError:
        if not install:
            table = Table(show_header=False, box=None, padding=(0, 1))
            table.add_column("Label", style="bold cyan")
            table.add_column("Value", overflow="fold")
            table.add_row("Status", "Calibre is not installed or was not found.")
            table.add_row("Why", _calibre_explanation())
            table.add_row("Fast install", "convert-books setup --install")
            table.add_row("Manual install", "brew install --cask calibre")
            table.add_row(
                "Manual download",
                "https://calibre-ebook.com/download_osx",
            )
            console.print()
            console.print(Panel(table, title="Setup required", border_style="yellow"))
            raise typer.Exit(code=1)

        try:
            _install_calibre_with_homebrew()
            executable = _ebook_convert_path()
        except ConversionError as error:
            console.print(Panel(str(error), title="Setup failed", border_style="red"))
            raise typer.Exit(code=1) from error

    _render_success("Setup complete", [("ebook-convert", Path(executable))])


@app.command("to-epub")
def to_epub(
    source: Annotated[
        Path,
        typer.Argument(help="Path to the MOBI file to convert."),
    ],
    output: Annotated[
        Path | None,
        typer.Option("--output", "-o", help="Where to write the EPUB file."),
    ] = None,
    force: Annotated[
        bool,
        typer.Option("--force", "-f", help="Overwrite the output file if it exists."),
    ] = False,
) -> None:
    """Convert a MOBI file to EPUB."""
    try:
        input_path = _require_existing_file(source)
        _require_suffix(input_path, MOBI_SUFFIX)
        output_path = _prepare_output_path(
            output or _default_output_path(input_path, EPUB_SUFFIX),
            force=force,
        )
        _convert_with_progress(input_path, output_path, "Converting MOBI to EPUB")
        _render_success(
            "Conversion complete",
            [("Input", input_path), ("Output", output_path)],
        )
    except ConversionError as error:
        console.print(Panel(str(error), title="Conversion failed", border_style="red"))
        raise typer.Exit(code=1) from error


@app.command("to-mobi")
def to_mobi(
    source: Annotated[
        Path,
        typer.Argument(help="Path to the EPUB file to convert."),
    ],
    output: Annotated[
        Path | None,
        typer.Option("--output", "-o", help="Where to write the MOBI file."),
    ] = None,
    force: Annotated[
        bool,
        typer.Option("--force", "-f", help="Overwrite the output file if it exists."),
    ] = False,
) -> None:
    """Convert an EPUB file to MOBI."""
    try:
        input_path = _require_existing_file(source)
        _require_suffix(input_path, EPUB_SUFFIX)
        output_path = _prepare_output_path(
            output or _default_output_path(input_path, MOBI_SUFFIX),
            force=force,
        )
        _convert_with_progress(input_path, output_path, "Converting EPUB to MOBI")
        _render_success(
            "Conversion complete",
            [("Input", input_path), ("Output", output_path)],
        )
    except ConversionError as error:
        console.print(Panel(str(error), title="Conversion failed", border_style="red"))
        raise typer.Exit(code=1) from error


@app.command("repair-epub")
def repair_epub(
    source: Annotated[
        Path,
        typer.Argument(help="Path to the EPUB file to repair."),
    ],
    output: Annotated[
        Path | None,
        typer.Option("--output", "-o", help="Where to write the repaired EPUB file."),
    ] = None,
    force: Annotated[
        bool,
        typer.Option("--force", "-f", help="Overwrite the output file if it exists."),
    ] = False,
    keep_temp: Annotated[
        bool,
        typer.Option("--keep-temp", help="Keep the intermediate MOBI file."),
    ] = False,
) -> None:
    """Repair an EPUB by converting EPUB -> MOBI -> EPUB."""
    try:
        input_path = _require_existing_file(source)
        _require_suffix(input_path, EPUB_SUFFIX)
        output_path = _prepare_output_path(
            output or _default_output_path(input_path, EPUB_SUFFIX, marker="repaired"),
            force=force,
        )
        kept_mobi = None
        if keep_temp:
            kept_mobi = _prepare_output_path(
                output_path.with_suffix(MOBI_SUFFIX),
                force=force,
            )

        with tempfile.TemporaryDirectory(prefix=f"{APP_NAME}-") as temp_dir:
            temp_mobi = Path(temp_dir) / f"{input_path.stem}.mobi"
            _convert_with_progress(input_path, temp_mobi, "Step 1/2: EPUB to MOBI")
            _convert_with_progress(temp_mobi, output_path, "Step 2/2: MOBI to EPUB")

            rows = [("Input", input_path), ("Output", output_path)]
            if kept_mobi is not None:
                shutil.copy2(temp_mobi, kept_mobi)
                rows.append(("Intermediate", kept_mobi))

        _render_success("EPUB repaired", rows)
    except ConversionError as error:
        console.print(Panel(str(error), title="Repair failed", border_style="red"))
        raise typer.Exit(code=1) from error


if __name__ == "__main__":
    app()
