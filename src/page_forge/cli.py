from __future__ import annotations

import time
from collections import deque
from pathlib import Path
from typing import Annotated, Callable, Literal, TypeVar

import typer
from rich.console import Console
from rich.live import Live
from rich.panel import Panel
from rich.progress import Progress, SpinnerColumn, TextColumn, TimeElapsedColumn
from rich.table import Table
from rich.text import Text

from .calibre import get_calibre_status
from .config import (
    config_path,
    load_config,
    profile_has_password,
    set_profile_password,
    upsert_profile,
)
from .conversion import (
    RepairMode,
    convert_book,
    convert_folder,
    repair_epub as repair_epub_service,
    repair_folder as repair_folder_service,
)
from .errors import PageForgeError
from .installer import calibre_explanation, install_calibre_with_homebrew
from .kindle import send_to_kindle
from .metadata import inspect_book, update_book_metadata
from .models import BatchResult, BookMetadata, ConversionResult, Profile, SendResult
from .platform import platform_support_message
from .updater import update_app, update_calibre

APP_NAME = "page-forge"
INSTALL_LOG_LINES = 8

app = typer.Typer(
    name=APP_NAME,
    help="macOS-only terminal app for repairing, converting, and sending ebooks.",
    no_args_is_help=False,
)
console = Console()
T = TypeVar("T")


def _render_rows(title: str, rows: list[tuple[str, str]], style: str = "green") -> None:
    table = Table(show_header=False, box=None, padding=(0, 1))
    table.add_column("Label", style="bold cyan", no_wrap=True)
    table.add_column("Value", overflow="fold")
    for label, value in rows:
        table.add_row(label, value)
    console.print()
    console.print(Panel(table, title=title, border_style=style))


def _render_error(title: str, error: Exception) -> None:
    console.print(Panel(str(error), title=title, border_style="red"))


def _run_with_progress(label: str, task: Callable[[Callable[[str], None]], T]) -> T:
    current_label = label

    def update_label(value: str) -> None:
        nonlocal current_label
        current_label = value
        progress.update(progress_task, description=current_label)

    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        TimeElapsedColumn(),
        console=console,
        transient=True,
    ) as progress:
        progress_task = progress.add_task(current_label, total=None)
        return task(update_label)


def _render_conversion(title: str, result: ConversionResult) -> None:
    rows = [("Input", str(result.input_path)), ("Output", str(result.output_path))]
    if result.intermediate_path is not None:
        rows.append(("Intermediate", str(result.intermediate_path)))
    _render_rows(title, rows)


def _render_batch(title: str, result: BatchResult) -> None:
    rows = [
        ("Converted", str(len(result.results))),
        ("Skipped", str(len(result.skipped))),
    ]
    for item in result.results[:10]:
        rows.append((item.input_path.name, str(item.output_path)))
    _render_rows(title, rows)


def _render_metadata(metadata: BookMetadata) -> None:
    rows = [("Path", str(metadata.path))]
    interesting = ("Title", "Author(s)", "Authors", "Publisher", "Tags", "Languages")
    for key in interesting:
        value = metadata.fields.get(key)
        if value:
            rows.append((key, value))
    if len(rows) == 1:
        rows.append(("Raw", metadata.raw or "No metadata returned."))
    _render_rows("Book metadata", rows)


def _render_send(result: SendResult) -> None:
    _render_rows(
        "Sent to Kindle",
        [
            ("Input", str(result.input_path)),
            ("Profile", result.profile_name),
            ("From", result.sender_email),
            ("To", result.kindle_email),
        ],
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
    table.add_row("Platform", "macOS-only")
    table.add_row("Why", calibre_explanation())
    table.add_row(
        "Output",
        Text("\n".join(lines) if lines else "Waiting for Homebrew output..."),
    )
    return Panel(table, title="Installing Calibre", border_style=border_style)


def _operation_panel(
    *,
    title: str,
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
    table.add_row("Platform", "macOS-only")
    table.add_row(
        "Output",
        Text("\n".join(lines) if lines else "Waiting for output..."),
    )
    return Panel(table, title=title, border_style=border_style)


def _run_live_update_step(
    *,
    title: str,
    command: str,
    started_at: float,
    lines: deque[str],
    live: Live,
    operation: Callable[[Callable[[str], None]], None],
) -> None:
    live.update(
        _operation_panel(
            title=title,
            status="Starting",
            command=command,
            started_at=started_at,
            lines=lines,
        )
    )

    def on_output(line: str) -> None:
        lines.append(line)
        live.update(
            _operation_panel(
                title=title,
                status="Running",
                command=command,
                started_at=started_at,
                lines=lines,
            )
        )

    operation(on_output)
    live.update(
        _operation_panel(
            title=title,
            status="Finished",
            command=command,
            started_at=started_at,
            lines=lines,
            border_style="green",
        )
    )


@app.callback(invoke_without_command=True)
def main(ctx: typer.Context) -> None:
    """Open the TUI when no command is provided."""
    if ctx.invoked_subcommand is not None:
        return
    from .tui_app import run_tui

    run_tui()


@app.command("doctor")
def doctor() -> None:
    """Check whether local conversion dependencies are available."""
    try:
        status = get_calibre_status()
    except PageForgeError as error:
        _render_error("Missing dependency", error)
        raise typer.Exit(code=1) from error

    rows = [
        ("Platform", "macOS-only"),
        ("ebook-convert", str(status.ebook_convert or "Missing")),
        ("ebook-meta", str(status.ebook_meta or "Missing")),
        ("ebook-polish", str(status.ebook_polish or "Missing")),
    ]
    if status.is_ready:
        _render_rows("Ready", rows)
        return

    rows.append(("Next step", "page-forge setup --install"))
    _render_rows("Setup required", rows, style="yellow")
    raise typer.Exit(code=1)


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
    status = get_calibre_status()
    if status.is_ready:
        _render_rows(
            "Setup complete",
            [
                ("Platform", "macOS-only"),
                ("ebook-convert", str(status.ebook_convert)),
                ("ebook-meta", str(status.ebook_meta)),
                ("ebook-polish", str(status.ebook_polish)),
            ],
        )
        return

    if not install:
        _render_rows(
            "Setup required",
            [
                ("Status", "Calibre is not installed or was not found."),
                ("Platform", platform_support_message()),
                ("Why", calibre_explanation()),
                ("Fast install", "page-forge setup --install"),
                ("Manual install", "brew install --cask calibre"),
                ("Manual download", "https://calibre-ebook.com/download_osx"),
            ],
            style="yellow",
        )
        raise typer.Exit(code=1)

    lines: deque[str] = deque(maxlen=INSTALL_LOG_LINES)
    started_at = time.monotonic()
    command_text = "brew install --cask calibre"

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

        def on_output(line: str) -> None:
            lines.append(line)
            live.update(
                _install_panel(
                    status="Installing Calibre",
                    command=command_text,
                    started_at=started_at,
                    lines=lines,
                )
            )

        try:
            install_calibre_with_homebrew(on_output=on_output)
        except PageForgeError as error:
            live.update(
                _install_panel(
                    status="Homebrew install failed",
                    command=command_text,
                    started_at=started_at,
                    lines=lines,
                    border_style="red",
                )
            )
            _render_error("Setup failed", error)
            raise typer.Exit(code=1) from error

        live.update(
            _install_panel(
                status="Homebrew install finished",
                command=command_text,
                started_at=started_at,
                lines=lines,
                border_style="green",
            )
        )

    doctor()


@app.command("update")
def update(
    include_calibre: Annotated[
        bool,
        typer.Option(
            "--include-calibre",
            help="Update page-forge, then update Calibre with Homebrew.",
        ),
    ] = False,
    calibre_only: Annotated[
        bool,
        typer.Option(
            "--calibre-only",
            help="Update only Calibre with Homebrew.",
        ),
    ] = False,
) -> None:
    """Update page-forge and optionally Calibre."""
    if include_calibre and calibre_only:
        _render_error(
            "Update failed",
            ValueError("Use either --include-calibre or --calibre-only, not both."),
        )
        raise typer.Exit(code=1)

    lines: deque[str] = deque(maxlen=INSTALL_LOG_LINES)
    started_at = time.monotonic()
    first_command = (
        "brew upgrade --cask calibre"
        if calibre_only
        else "uv tool install --force git+https://github.com/rckbrcls/page-forge.git"
    )
    completed_steps: list[str] = []

    with Live(
        _operation_panel(
            title="Updating",
            status="Preparing",
            command=first_command,
            started_at=started_at,
            lines=lines,
        ),
        console=console,
        refresh_per_second=6,
        transient=False,
    ) as live:
        try:
            if not calibre_only:
                _run_live_update_step(
                    title="Updating page-forge",
                    command="uv tool install --force git+https://github.com/rckbrcls/page-forge.git",
                    started_at=started_at,
                    lines=lines,
                    live=live,
                    operation=update_app,
                )
                completed_steps.append("page-forge")

            if include_calibre or calibre_only:
                _run_live_update_step(
                    title="Updating Calibre",
                    command="brew upgrade --cask calibre",
                    started_at=started_at,
                    lines=lines,
                    live=live,
                    operation=update_calibre,
                )
                completed_steps.append("Calibre")
        except PageForgeError as error:
            live.update(
                _operation_panel(
                    title="Updating",
                    status="Failed",
                    command=first_command,
                    started_at=started_at,
                    lines=lines,
                    border_style="red",
                )
            )
            _render_error("Update failed", error)
            raise typer.Exit(code=1) from error

    _render_rows(
        "Update complete",
        [("Updated", ", ".join(completed_steps) or "Nothing")],
    )


@app.command("configure")
def configure(
    profile: Annotated[str, typer.Option("--profile", "-p")] = "default",
    sender_email: Annotated[str | None, typer.Option("--sender-email")] = None,
    kindle_email: Annotated[str | None, typer.Option("--kindle-email")] = None,
    smtp_host: Annotated[str, typer.Option("--smtp-host")] = "smtp.gmail.com",
    smtp_port: Annotated[int, typer.Option("--smtp-port")] = 587,
    smtp_username: Annotated[str | None, typer.Option("--smtp-username")] = None,
    default_output_dir: Annotated[
        Path | None,
        typer.Option("--default-output-dir"),
    ] = None,
    skip_password: Annotated[
        bool,
        typer.Option("--skip-password", help="Do not prompt for the SMTP password."),
    ] = False,
) -> None:
    """Configure a Kindle delivery profile."""
    sender = sender_email or typer.prompt("Sender email")
    kindle = kindle_email or typer.prompt("Kindle email")
    username = smtp_username or sender
    saved_profile = Profile(
        name=profile,
        sender_email=sender,
        kindle_email=kindle,
        smtp_host=smtp_host,
        smtp_port=smtp_port,
        smtp_username=username,
        default_output_dir=str(default_output_dir.expanduser()) if default_output_dir else "",
    )
    path = upsert_profile(saved_profile, make_default=True)

    if not skip_password:
        password = typer.prompt("SMTP password or app token", hide_input=True)
        set_profile_password(profile, password)

    _render_rows(
        "Profile saved",
        [
            ("Profile", profile),
            ("Config", str(path)),
            ("Password", "Stored in Keychain" if not skip_password else "Skipped"),
        ],
    )


@app.command("to-epub")
def to_epub(
    source: Annotated[Path, typer.Argument(help="Path to the MOBI file to convert.")],
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
        result = _run_with_progress(
            "Converting MOBI to EPUB",
            lambda update: convert_book(
                source,
                target_format="epub",
                output=output,
                force=force,
                on_progress=update,
            ),
        )
        _render_conversion("Conversion complete", result)
    except PageForgeError as error:
        _render_error("Conversion failed", error)
        raise typer.Exit(code=1) from error


@app.command("to-mobi")
def to_mobi(
    source: Annotated[Path, typer.Argument(help="Path to the EPUB file to convert.")],
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
        result = _run_with_progress(
            "Converting EPUB to MOBI",
            lambda update: convert_book(
                source,
                target_format="mobi",
                output=output,
                force=force,
                on_progress=update,
            ),
        )
        _render_conversion("Conversion complete", result)
    except PageForgeError as error:
        _render_error("Conversion failed", error)
        raise typer.Exit(code=1) from error


@app.command("repair-epub")
def repair_epub(
    source: Annotated[Path, typer.Argument(help="Path to the EPUB file to repair.")],
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
        typer.Option(
            "--keep-temp",
            help="Keep the intermediate MOBI file when using --mode aggressive.",
        ),
    ] = False,
    mode: Annotated[
        RepairMode,
        typer.Option(
            "--mode",
            help="Repair mode: safe preserves EPUB; aggressive uses EPUB to MOBI to EPUB.",
        ),
    ] = "safe",
) -> None:
    """Repair an EPUB with safe structural repair by default."""
    try:
        result = _run_with_progress(
            "Repairing EPUB",
            lambda update: repair_epub_service(
                source,
                output=output,
                force=force,
                keep_temp=keep_temp,
                mode=mode,
                on_progress=update,
            ),
        )
        _render_conversion("EPUB repaired", result)
    except PageForgeError as error:
        _render_error("Repair failed", error)
        raise typer.Exit(code=1) from error


@app.command("repair-folder")
def repair_folder(
    folder: Annotated[Path, typer.Argument(help="Folder with EPUB files to repair.")],
    output: Annotated[
        Path,
        typer.Option("--output", "-o", help="Where to write repaired EPUB files."),
    ],
    force: Annotated[
        bool,
        typer.Option("--force", "-f", help="Overwrite output files if they exist."),
    ] = False,
    mode: Annotated[
        RepairMode,
        typer.Option(
            "--mode",
            help="Repair mode: safe preserves EPUB; aggressive uses EPUB to MOBI to EPUB.",
        ),
    ] = "safe",
) -> None:
    """Repair every EPUB file in a folder."""
    try:
        result = _run_with_progress(
            "Repairing folder",
            lambda update: repair_folder_service(
                folder,
                output_dir=output,
                force=force,
                mode=mode,
                on_progress=update,
            ),
        )
        _render_batch("Folder repaired", result)
    except PageForgeError as error:
        _render_error("Batch failed", error)
        raise typer.Exit(code=1) from error


@app.command("convert-folder")
def convert_folder_command(
    folder: Annotated[Path, typer.Argument(help="Folder with ebook files to convert.")],
    output: Annotated[
        Path,
        typer.Option("--output", "-o", help="Where to write converted files."),
    ],
    target: Annotated[
        Literal["epub", "mobi"],
        typer.Option("--to", help="Target format."),
    ] = "epub",
    force: Annotated[
        bool,
        typer.Option("--force", "-f", help="Overwrite output files if they exist."),
    ] = False,
) -> None:
    """Convert every supported ebook in a folder."""
    try:
        result = _run_with_progress(
            "Converting folder",
            lambda update: convert_folder(
                folder,
                output_dir=output,
                target_format=target,
                force=force,
                on_progress=update,
            ),
        )
        _render_batch("Folder converted", result)
    except PageForgeError as error:
        _render_error("Batch failed", error)
        raise typer.Exit(code=1) from error


@app.command("inspect")
def inspect(
    source: Annotated[Path, typer.Argument(help="Path to the ebook to inspect.")],
) -> None:
    """Inspect ebook metadata with Calibre."""
    try:
        _render_metadata(inspect_book(source))
    except PageForgeError as error:
        _render_error("Inspect failed", error)
        raise typer.Exit(code=1) from error


@app.command("metadata")
def metadata(
    source: Annotated[Path, typer.Argument(help="Path to the ebook to update.")],
    title: Annotated[str | None, typer.Option("--title")] = None,
    author: Annotated[str | None, typer.Option("--author")] = None,
) -> None:
    """Update ebook title or author metadata."""
    try:
        _render_metadata(update_book_metadata(source, title=title, author=author))
    except PageForgeError as error:
        _render_error("Metadata update failed", error)
        raise typer.Exit(code=1) from error


@app.command("send")
def send(
    source: Annotated[Path, typer.Argument(help="Path to the ebook to send.")],
    profile: Annotated[str | None, typer.Option("--profile", "-p")] = None,
) -> None:
    """Send an ebook to Kindle through the configured SMTP profile."""
    try:
        result = _run_with_progress(
            "Sending to Kindle",
            lambda _update: send_to_kindle(source, profile_name=profile),
        )
        _render_send(result)
    except PageForgeError as error:
        _render_error("Send failed", error)
        raise typer.Exit(code=1) from error


@app.command("repair-and-send")
def repair_and_send(
    source: Annotated[Path, typer.Argument(help="Path to the EPUB file to repair/send.")],
    output: Annotated[
        Path | None,
        typer.Option("--output", "-o", help="Where to write the repaired EPUB file."),
    ] = None,
    profile: Annotated[str | None, typer.Option("--profile", "-p")] = None,
    force: Annotated[
        bool,
        typer.Option("--force", "-f", help="Overwrite the output file if it exists."),
    ] = False,
    mode: Annotated[
        RepairMode,
        typer.Option(
            "--mode",
            help="Repair mode: safe preserves EPUB; aggressive uses EPUB to MOBI to EPUB.",
        ),
    ] = "safe",
) -> None:
    """Repair an EPUB, then send the repaired file to Kindle."""
    try:
        result = _run_with_progress(
            "Repairing EPUB",
            lambda update: repair_epub_service(
                source,
                output=output,
                force=force,
                mode=mode,
                on_progress=update,
            ),
        )
        _render_conversion("EPUB repaired", result)
        send_result = _run_with_progress(
            "Sending to Kindle",
            lambda _update: send_to_kindle(result.output_path, profile_name=profile),
        )
        _render_send(send_result)
    except PageForgeError as error:
        _render_error("Repair and send failed", error)
        raise typer.Exit(code=1) from error


@app.command("tui")
def tui() -> None:
    """Open the interactive terminal interface."""
    from .tui_app import run_tui

    run_tui()


@app.command("profiles")
def profiles() -> None:
    """List configured Kindle delivery profiles."""
    config = load_config()
    rows = [("Config", str(config_path())), ("Default", config.default_profile)]
    for name, profile in sorted(config.profiles.items(), key=lambda item: item[0]):
        status = "Ready" if profile.is_send_ready and profile_has_password(name) else "Incomplete"
        rows.append((name, status))
    _render_rows("Profiles", rows)


if __name__ == "__main__":
    app()
