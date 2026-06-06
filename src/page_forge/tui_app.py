from __future__ import annotations

import shlex
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Literal, cast

from textual import on
from textual.app import App, ComposeResult
from textual.containers import Grid, Horizontal, Vertical
from textual.screen import ModalScreen
from textual.widgets import (
    Button,
    Checkbox,
    DirectoryTree,
    Footer,
    Header,
    Input,
    Label,
    Select,
    Static,
    TabPane,
    TabbedContent,
)

from .calibre import get_calibre_status
from .config import (
    load_config,
    profile_has_password,
    set_profile_password,
    upsert_profile,
)
from .conversion import RepairMode, convert_book, convert_folder, repair_epub, repair_folder
from .errors import PageForgeError
from .kindle import send_to_kindle
from .metadata import inspect_book, update_book_metadata
from .models import Profile, ReadinessReport
from .readiness import (
    audit_book,
    open_send_to_kindle_handoff,
    prepare_book_for_kindle,
    send_ready_book,
)
from .updater import update_app, update_calibre

PathPickerMode = Literal["file", "directory", "save_file"]
PathPickerConfig = tuple[str, PathPickerMode, str]
APP_COMMAND = "page-forge"


PATH_PICKER_BUTTONS: dict[str, PathPickerConfig] = {
    "convert-source-browse": ("convert-source", "file", "Select input file"),
    "convert-output-browse": ("convert-output", "save_file", "Select output file"),
    "batch-source-browse": ("batch-source", "directory", "Select input folder"),
    "batch-output-browse": ("batch-output", "directory", "Select output folder"),
    "readiness-source-browse": ("readiness-source", "file", "Select input file"),
    "readiness-output-dir-browse": (
        "readiness-output-dir",
        "directory",
        "Select output folder",
    ),
    "send-source-browse": ("send-source", "file", "Select input file"),
    "metadata-source-browse": ("metadata-source", "file", "Select input file"),
    "settings-output-dir-browse": (
        "settings-output-dir",
        "directory",
        "Select default output folder",
    ),
}

FINDER_PICKER_BUTTONS: dict[str, PathPickerConfig] = {
    "convert-source-finder": ("convert-source", "file", "Select input file"),
    "convert-output-finder": ("convert-output", "save_file", "Select output file"),
    "batch-source-finder": ("batch-source", "directory", "Select input folder"),
    "batch-output-finder": ("batch-output", "directory", "Select output folder"),
    "readiness-source-finder": ("readiness-source", "file", "Select input file"),
    "readiness-output-dir-finder": (
        "readiness-output-dir",
        "directory",
        "Select output folder",
    ),
    "send-source-finder": ("send-source", "file", "Select input file"),
    "metadata-source-finder": ("metadata-source", "file", "Select input file"),
    "settings-output-dir-finder": (
        "settings-output-dir",
        "directory",
        "Select default output folder",
    ),
}


class FinderSelectionError(RuntimeError):
    """Raised when the macOS Finder picker cannot be opened."""


def _applescript_string(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def _start_directory(path: Path | None) -> Path:
    if path is None:
        return Path.home()
    expanded = path.expanduser()
    if expanded.exists():
        return expanded if expanded.is_dir() else expanded.parent
    if expanded.parent.exists():
        return expanded.parent
    return Path.home()


def _initial_save_filename(path: Path | None) -> str:
    if path is None:
        return ""
    expanded = path.expanduser()
    if expanded.exists() and expanded.is_dir():
        return ""
    return expanded.name


def _app_command_path() -> str:
    return shutil.which(APP_COMMAND) or sys.argv[0]


def _schedule_app_relaunch(command_path: str) -> None:
    command = f"sleep 0.2; exec {shlex.quote(command_path)}"
    subprocess.Popen(["/bin/sh", "-c", command])


def choose_path_with_finder(
    mode: PathPickerMode,
    *,
    default_directory: Path,
) -> Path | None:
    if sys.platform != "darwin":
        raise FinderSelectionError("Finder picker is only available on macOS.")

    command = "choose file" if mode == "file" else "choose folder"
    default_location = _applescript_string(str(default_directory.expanduser()))
    script = f"POSIX path of ({command} default location POSIX file {default_location})"

    try:
        completed = subprocess.run(
            ["osascript", "-e", script],
            capture_output=True,
            check=False,
            text=True,
        )
    except FileNotFoundError as error:
        raise FinderSelectionError("osascript is not available.") from error

    if completed.returncode != 0:
        message = (completed.stderr or completed.stdout).strip()
        if "User canceled" in message:
            return None
        raise FinderSelectionError(message or "Finder picker failed.")

    output = completed.stdout.strip()
    return Path(output).expanduser() if output else None


class PathPickerScreen(ModalScreen[Path | None]):
    """Modal path picker backed by Textual's DirectoryTree."""

    BINDINGS = [("escape", "cancel", "Cancel")]

    def __init__(
        self,
        *,
        title: str,
        mode: PathPickerMode,
        initial_path: Path | None,
        open_finder_on_mount: bool = False,
    ) -> None:
        super().__init__()
        self.title = title
        self.mode = mode
        self.current_directory = _start_directory(initial_path)
        self.selected_path: Path | None = None
        self.filename = _initial_save_filename(initial_path) if mode == "save_file" else ""
        self.open_finder_on_mount = open_finder_on_mount

    def compose(self) -> ComposeResult:
        with Vertical(id="path-picker-dialog"):
            yield Label(self.title, id="path-picker-title")
            yield Static("", id="path-picker-status")
            if self.mode == "save_file":
                yield Label("Filename")
                yield Input(
                    value=self.filename,
                    placeholder="output.epub",
                    id="path-picker-filename",
                )
            yield DirectoryTree(self.current_directory, id="path-picker-tree")
            with Horizontal(classes="actions"):
                yield Button("Select", id="path-picker-select", variant="primary")
                if self.mode in ("directory", "save_file"):
                    yield Button("Use current folder", id="path-picker-current")
                yield Button("Finder", id="path-picker-finder")
                yield Button("Cancel", id="path-picker-cancel")

    def on_mount(self) -> None:
        self.update_status(f"Current folder: {self.current_directory}")
        if self.open_finder_on_mount:
            self.open_finder()

    def action_cancel(self) -> None:
        self.dismiss(None)

    def update_status(self, message: str) -> None:
        self.query_one("#path-picker-status", Static).update(message)

    @on(DirectoryTree.FileSelected)
    def handle_file_selected(self, event: DirectoryTree.FileSelected) -> None:
        if self.mode == "save_file":
            self.current_directory = event.path.parent
            self.selected_path = self.current_directory
            self.query_one("#path-picker-filename", Input).value = event.path.name
            self.update_status(f"Current folder: {self.current_directory}")
            return
        self.selected_path = event.path
        self.update_status(f"Selected file: {event.path}")

    @on(DirectoryTree.DirectorySelected)
    def handle_directory_selected(self, event: DirectoryTree.DirectorySelected) -> None:
        self.current_directory = event.path
        self.selected_path = event.path
        self.update_status(f"Selected folder: {event.path}")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        button_id = event.button.id
        if button_id == "path-picker-select":
            self.select_path()
        elif button_id == "path-picker-current":
            self.use_current_folder()
        elif button_id == "path-picker-finder":
            self.open_finder()
        elif button_id == "path-picker-cancel":
            self.dismiss(None)

    def select_path(self) -> None:
        if self.mode == "file":
            if self.selected_path is not None and self.selected_path.is_file():
                self.dismiss(self.selected_path)
                return
            self.update_status("Select a file.")
            return

        if self.mode == "directory":
            directory = self.selected_directory()
            self.dismiss(directory)
            return

        filename = self.query_one("#path-picker-filename", Input).value.strip()
        if not filename:
            self.update_status("Filename is required.")
            return
        filename_path = Path(filename)
        if filename_path.is_absolute() or len(filename_path.parts) != 1:
            self.update_status("Enter only a filename.")
            return
        self.dismiss(self.selected_directory() / filename)

    def use_current_folder(self) -> None:
        if self.mode == "directory":
            self.dismiss(self.current_directory)
            return
        self.selected_path = self.current_directory
        filename = self.query_one("#path-picker-filename", Input).value.strip()
        if not filename:
            self.update_status("Filename is required.")
            return
        filename_path = Path(filename)
        if filename_path.is_absolute() or len(filename_path.parts) != 1:
            self.update_status("Enter only a filename.")
            return
        self.dismiss(self.current_directory / filename)

    def selected_directory(self) -> Path:
        if self.selected_path is not None and self.selected_path.is_dir():
            return self.selected_path
        return self.current_directory

    def open_finder(self) -> None:
        try:
            selected = choose_path_with_finder(
                self.mode,
                default_directory=self.current_directory,
            )
        except FinderSelectionError as error:
            self.update_status(f"Finder error: {error}")
            return

        if selected is None:
            self.update_status("Finder selection canceled.")
            return

        if self.mode == "save_file":
            self.current_directory = selected if selected.is_dir() else selected.parent
            self.selected_path = self.current_directory
            self.update_status(f"Current folder: {self.current_directory}")
            return

        self.dismiss(selected)


class PageForgeApp(App[None]):
    """Interactive terminal app for page-forge."""

    CSS = """
    Screen {
        background: $surface;
    }

    #dashboard-grid {
        grid-size: 2 3;
        grid-gutter: 1 2;
        margin: 1;
    }

    .panel {
        border: solid $primary;
        padding: 1 2;
        height: auto;
    }

    .form {
        margin: 1;
        padding: 1 2;
        border: solid $primary;
    }

    .form Input, .form Select {
        margin-bottom: 1;
    }

    .path-row {
        height: auto;
        margin-bottom: 1;
    }

    .path-row Input {
        width: 1fr;
        margin-bottom: 0;
    }

    .path-row Button {
        width: 10;
        margin-left: 1;
    }

    .actions {
        height: auto;
        margin-top: 1;
    }

    #log-output {
        margin: 1;
        padding: 1 2;
        border: solid $accent;
        height: 1fr;
        overflow: auto;
    }

    #readiness-output {
        margin-top: 1;
        padding: 1 2;
        border: solid $accent;
        height: auto;
    }

    PathPickerScreen {
        align: center middle;
    }

    #path-picker-dialog {
        width: 90%;
        height: 85%;
        border: thick $primary;
        background: $surface;
        padding: 1 2;
    }

    #path-picker-title {
        text-style: bold;
        margin-bottom: 1;
    }

    #path-picker-status {
        margin-bottom: 1;
        color: $text-muted;
    }

    #path-picker-tree {
        height: 1fr;
        border: solid $accent;
        margin-bottom: 1;
    }
    """

    BINDINGS = [
        ("q", "quit", "Quit"),
        ("r", "refresh", "Refresh"),
    ]
    log_lines: list[str]

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)
        with TabbedContent(initial="dashboard"):
            with TabPane("Dashboard", id="dashboard"):
                with Grid(id="dashboard-grid"):
                    yield Static("", id="calibre-status", classes="panel")
                    yield Static("", id="kindle-status", classes="panel")
                    yield Static(
                        "Recent logs\nNo activity yet.",
                        id="recent-logs",
                        classes="panel",
                    )
                    yield Static("Quick actions", classes="panel")
                    with Vertical(classes="panel"):
                        yield Button("Refresh Status", id="refresh-status")
                        yield Button("Update App", id="update-app")
                        yield Button("Update Calibre", id="update-calibre")
                        yield Button("Open Logs", id="open-logs")

            with TabPane("Readiness", id="readiness"):
                with Vertical(classes="form"):
                    yield Label("Input file")
                    with Horizontal(classes="path-row"):
                        yield Input(
                            placeholder="/path/to/book.epub or .mobi",
                            id="readiness-source",
                        )
                        yield Button("Browse", id="readiness-source-browse")
                        yield Button("Finder", id="readiness-source-finder")
                    yield Label("Output folder (optional)")
                    with Horizontal(classes="path-row"):
                        yield Input(
                            placeholder="/path/to/ready-books",
                            id="readiness-output-dir",
                        )
                        yield Button("Browse", id="readiness-output-dir-browse")
                        yield Button("Finder", id="readiness-output-dir-finder")
                    yield Label("Profile")
                    yield Input(value="default", id="readiness-profile")
                    yield Checkbox("Apply Safe Fixes", id="readiness-fix")
                    yield Checkbox("Overwrite existing output", id="readiness-force")
                    yield Checkbox("Send after fixing", id="readiness-send")
                    yield Checkbox("Open Send to Kindle", id="readiness-open-handoff")
                    with Horizontal(classes="actions"):
                        yield Button("Run Doctor", id="run-readiness", variant="primary")
                        yield Button("Prepare for Kindle", id="prepare-readiness")
                        yield Button("Open Send to Kindle", id="open-send-to-kindle")
                    yield Static("No readiness report yet.", id="readiness-output")

            with TabPane("Convert", id="convert"):
                with Vertical(classes="form"):
                    yield Label("Operation")
                    yield Select(
                        [
                            ("Repair EPUB", "repair"),
                            ("MOBI/PDF to EPUB", "to-epub"),
                            ("EPUB to MOBI", "to-mobi"),
                        ],
                        id="convert-operation",
                        value="repair",
                    )
                    yield Label("Repair mode")
                    yield Select(
                        [
                            ("Safe", "safe"),
                            ("Aggressive", "aggressive"),
                        ],
                        id="convert-repair-mode",
                        value="safe",
                    )
                    yield Label("Input file")
                    with Horizontal(classes="path-row"):
                        yield Input(
                            placeholder="/path/to/book.epub, .mobi, or .pdf",
                            id="convert-source",
                        )
                        yield Button("Browse", id="convert-source-browse")
                        yield Button("Finder", id="convert-source-finder")
                    yield Label("Output file (optional)")
                    with Horizontal(classes="path-row"):
                        yield Input(placeholder="/path/to/output.epub", id="convert-output")
                        yield Button("Browse", id="convert-output-browse")
                        yield Button("Finder", id="convert-output-finder")
                    yield Checkbox("Overwrite existing output", id="convert-force")
                    with Horizontal(classes="actions"):
                        yield Button("Run Conversion", id="run-convert", variant="primary")

            with TabPane("Batch", id="batch"):
                with Vertical(classes="form"):
                    yield Label("Operation")
                    yield Select(
                        [
                            ("Repair EPUB files", "repair"),
                            ("MOBI/PDF files to EPUB", "to-epub"),
                            ("EPUB files to MOBI", "to-mobi"),
                        ],
                        id="batch-operation",
                        value="repair",
                    )
                    yield Label("Repair mode")
                    yield Select(
                        [
                            ("Safe", "safe"),
                            ("Aggressive", "aggressive"),
                        ],
                        id="batch-repair-mode",
                        value="safe",
                    )
                    yield Label("Input folder")
                    with Horizontal(classes="path-row"):
                        yield Input(placeholder="/path/to/folder", id="batch-source")
                        yield Button("Browse", id="batch-source-browse")
                        yield Button("Finder", id="batch-source-finder")
                    yield Label("Output folder")
                    with Horizontal(classes="path-row"):
                        yield Input(placeholder="/path/to/output", id="batch-output")
                        yield Button("Browse", id="batch-output-browse")
                        yield Button("Finder", id="batch-output-finder")
                    yield Checkbox("Overwrite existing outputs", id="batch-force")
                    with Horizontal(classes="actions"):
                        yield Button("Run Batch", id="run-batch", variant="primary")

            with TabPane("Send to Kindle", id="send"):
                with Vertical(classes="form"):
                    yield Label("Input file")
                    with Horizontal(classes="path-row"):
                        yield Input(placeholder="/path/to/book.epub", id="send-source")
                        yield Button("Browse", id="send-source-browse")
                        yield Button("Finder", id="send-source-finder")
                    yield Label("Profile")
                    yield Input(value="default", id="send-profile")
                    yield Checkbox("Overwrite repaired output", id="send-force")
                    yield Label("Repair mode")
                    yield Select(
                        [
                            ("Safe", "safe"),
                            ("Aggressive", "aggressive"),
                        ],
                        id="send-repair-mode",
                        value="safe",
                    )
                    with Horizontal(classes="actions"):
                        yield Button("Send", id="run-send", variant="primary")
                        yield Button("Repair and Send", id="run-repair-send")

            with TabPane("Metadata", id="metadata"):
                with Vertical(classes="form"):
                    yield Label("Input file")
                    with Horizontal(classes="path-row"):
                        yield Input(placeholder="/path/to/book.epub", id="metadata-source")
                        yield Button("Browse", id="metadata-source-browse")
                        yield Button("Finder", id="metadata-source-finder")
                    yield Label("Title")
                    yield Input(placeholder="Book title", id="metadata-title")
                    yield Label("Author")
                    yield Input(placeholder="Author name", id="metadata-author")
                    with Horizontal(classes="actions"):
                        yield Button("Inspect", id="run-inspect", variant="primary")
                        yield Button("Update Metadata", id="run-metadata")

            with TabPane("Settings", id="settings"):
                with Vertical(classes="form"):
                    yield Label("Profile")
                    yield Input(value="default", id="settings-profile")
                    yield Label("Sender email")
                    yield Input(placeholder="you@example.com", id="settings-sender")
                    yield Label("Kindle email")
                    yield Input(placeholder="name@kindle.com", id="settings-kindle")
                    yield Label("SMTP host")
                    yield Input(value="smtp.gmail.com", id="settings-smtp-host")
                    yield Label("SMTP port")
                    yield Input(value="587", id="settings-smtp-port")
                    yield Label("SMTP username")
                    yield Input(placeholder="Defaults to sender email", id="settings-smtp-user")
                    yield Label("SMTP password or app token")
                    yield Input(password=True, id="settings-password")
                    yield Label("Default output folder")
                    with Horizontal(classes="path-row"):
                        yield Input(placeholder="/path/to/books", id="settings-output-dir")
                        yield Button("Browse", id="settings-output-dir-browse")
                        yield Button("Finder", id="settings-output-dir-finder")
                    with Horizontal(classes="actions"):
                        yield Button("Save Profile", id="save-profile", variant="primary")

            with TabPane("Logs", id="logs"):
                yield Static("No activity yet.", id="log-output")
        yield Footer()

    def on_mount(self) -> None:
        self.log_lines = []
        self.refresh_dashboard()
        self.load_settings()

    def action_refresh(self) -> None:
        self.refresh_dashboard()
        self.write_log("Status refreshed.")

    def refresh_dashboard(self) -> None:
        try:
            status = get_calibre_status()
            if status.is_ready:
                calibre_text = (
                    "Calibre status: Ready\n"
                    "Platform: macOS-only\n"
                    f"ebook-convert: {status.ebook_convert}\n"
                    f"ebook-meta: {status.ebook_meta}\n"
                    f"ebook-polish: {status.ebook_polish}"
                )
            else:
                missing = ", ".join(status.missing_tools)
                calibre_text = (
                    "Calibre status: Setup required\n"
                    "Platform: macOS-only\n"
                    f"Missing: {missing}\n"
                    "Run: page-forge setup --install"
                )
        except PageForgeError as error:
            calibre_text = (
                "Calibre status: Setup required\n"
                "Platform: macOS-only\n"
                f"Error: {error}\n"
                "Check EBOOK_CONVERT_PATH, EBOOK_META_PATH, or EBOOK_POLISH_PATH."
            )
        self.query_one("#calibre-status", Static).update(calibre_text)

        config = load_config()
        profile = config.profiles.get(config.default_profile)
        if profile and profile.is_send_ready and profile_has_password(profile.name):
            kindle_text = (
                "Kindle profile: Ready\n"
                f"Default: {profile.name}\n"
                f"Kindle: {profile.kindle_email}"
            )
        else:
            kindle_text = (
                "Kindle profile: Incomplete\n"
                "Open Settings or run: page-forge configure"
            )
        self.query_one("#kindle-status", Static).update(kindle_text)

    def load_settings(self) -> None:
        config = load_config()
        profile = config.profiles.get(config.default_profile)
        if profile is None:
            return
        self.query_one("#settings-profile", Input).value = profile.name
        self.query_one("#settings-sender", Input).value = profile.sender_email
        self.query_one("#settings-kindle", Input).value = profile.kindle_email
        self.query_one("#settings-smtp-host", Input).value = profile.smtp_host
        self.query_one("#settings-smtp-port", Input).value = str(profile.smtp_port)
        self.query_one("#settings-smtp-user", Input).value = profile.smtp_username
        self.query_one("#settings-output-dir", Input).value = profile.default_output_dir

    def write_log(self, message: str) -> None:
        if not hasattr(self, "log_lines"):
            self.log_lines = []
        self.log_lines.append(message)
        self.query_one("#log-output", Static).update("\n".join(self.log_lines[-100:]))
        recent = "\n".join(self.log_lines[-5:])
        self.query_one("#recent-logs", Static).update(f"Recent logs\n{recent}")

    def read_path(self, widget_id: str, label: str) -> Path:
        value = self.query_one(widget_id, Input).value.strip()
        if not value:
            raise ValueError(f"{label} is required.")
        return Path(value).expanduser()

    def path_input_value(self, widget_id: str) -> Path | None:
        value = self.query_one(f"#{widget_id}", Input).value.strip()
        return Path(value).expanduser() if value else None

    def set_path_input(self, widget_id: str, path: Path) -> None:
        self.query_one(f"#{widget_id}", Input).value = str(path.expanduser())

    def read_repair_mode(self, widget_id: str) -> RepairMode:
        value = str(self.query_one(widget_id, Select).value)
        if value not in ("safe", "aggressive"):
            raise ValueError("Repair mode must be safe or aggressive.")
        return cast(RepairMode, value)

    def on_button_pressed(self, event: Button.Pressed) -> None:
        button_id = event.button.id
        try:
            if button_id == "refresh-status":
                self.action_refresh()
            elif button_id == "open-logs":
                self.query_one(TabbedContent).active = "logs"
            elif button_id == "update-app":
                self.start_app_update()
            elif button_id == "update-calibre":
                self.start_calibre_update()
            elif button_id == "run-readiness":
                self.run_readiness(force_fix=False)
            elif button_id == "prepare-readiness":
                self.run_readiness(force_fix=True)
            elif button_id == "open-send-to-kindle":
                self.open_send_to_kindle()
            elif button_id == "run-convert":
                self.run_convert()
            elif button_id == "run-batch":
                self.run_batch()
            elif button_id == "run-send":
                self.run_send()
            elif button_id == "run-repair-send":
                self.run_repair_send()
            elif button_id == "run-inspect":
                self.run_inspect()
            elif button_id == "run-metadata":
                self.run_metadata()
            elif button_id == "save-profile":
                self.save_profile()
            elif button_id in PATH_PICKER_BUTTONS:
                self.open_path_picker(*PATH_PICKER_BUTTONS[button_id])
            elif button_id in FINDER_PICKER_BUTTONS:
                self.open_finder_picker(*FINDER_PICKER_BUTTONS[button_id])
        except PageForgeError as error:
            self.write_log(f"Error: {error}")
        except ValueError as error:
            self.write_log(f"Error: {error}")

    def open_path_picker(
        self,
        widget_id: str,
        mode: PathPickerMode,
        title: str,
        *,
        open_finder_on_mount: bool = False,
    ) -> None:
        initial_path = self.path_input_value(widget_id)

        def apply_selection(selected: Path | None) -> None:
            if selected is None:
                return
            self.set_path_input(widget_id, selected)

        self.push_screen(
            PathPickerScreen(
                title=title,
                mode=mode,
                initial_path=initial_path,
                open_finder_on_mount=open_finder_on_mount,
            ),
            apply_selection,
        )

    def open_finder_picker(
        self,
        widget_id: str,
        mode: PathPickerMode,
        title: str,
    ) -> None:
        initial_path = self.path_input_value(widget_id)
        default_directory = _start_directory(initial_path)
        if mode == "save_file":
            self.open_path_picker(
                widget_id,
                mode,
                title,
                open_finder_on_mount=True,
            )
            return

        try:
            selected = choose_path_with_finder(mode, default_directory=default_directory)
        except FinderSelectionError as error:
            self.write_log(f"Finder error: {error}")
            return

        if selected is None:
            self.write_log("Finder selection canceled.")
            return
        self.set_path_input(widget_id, selected)

    def readiness_report_text(self, report: ReadinessReport) -> str:
        lines = [
            f"Status: {report.status.replace('_', ' ').title()}",
            f"Input: {report.input_path}",
        ]
        if report.output_path is not None:
            lines.append(f"Output: {report.output_path}")
        if report.converted_from is not None:
            lines.append(f"Converted from: {report.converted_from}")
        lines.append(f"Send to Kindle: {report.handoff_url}")
        if not report.issues:
            lines.append("Issues: none")
            return "\n".join(lines)

        lines.append("Issues:")
        for issue in report.issues[:12]:
            location = f" [{issue.path}]" if issue.path else ""
            lines.append(
                f"- {issue.severity}: {issue.code}{location} - {issue.message}"
            )
        if len(report.issues) > 12:
            lines.append(f"- {len(report.issues) - 12} more issue(s)")
        return "\n".join(lines)

    def update_readiness_output(self, report: ReadinessReport) -> None:
        self.query_one("#readiness-output", Static).update(
            self.readiness_report_text(report)
        )

    def run_readiness(self, *, force_fix: bool) -> None:
        source = self.read_path("#readiness-source", "Input file")
        output_dir_value = self.query_one("#readiness-output-dir", Input).value.strip()
        output_dir = Path(output_dir_value).expanduser() if output_dir_value else None
        profile = self.query_one("#readiness-profile", Input).value or "default"
        should_fix = force_fix or self.query_one("#readiness-fix", Checkbox).value
        force = self.query_one("#readiness-force", Checkbox).value

        if should_fix:
            report = prepare_book_for_kindle(
                source,
                output_dir=output_dir,
                force=force,
            )
        else:
            report = audit_book(source)
        self.update_readiness_output(report)
        self.write_log(f"Readiness: {report.status} - {report.input_path.name}")

        if self.query_one("#readiness-send", Checkbox).value:
            result = send_ready_book(report, profile_name=profile)
            self.write_log(f"Sent to Kindle: {result.input_path} -> {result.kindle_email}")

        if self.query_one("#readiness-open-handoff", Checkbox).value:
            self.open_send_to_kindle()

    def open_send_to_kindle(self) -> None:
        open_send_to_kindle_handoff()
        self.write_log("Opened Send to Kindle handoff.")

    def start_app_update(self) -> None:
        self.query_one(TabbedContent).active = "logs"
        self.write_log("Starting page-forge update.")
        self.run_worker(self.run_app_update_worker, thread=True)

    def relaunch_after_update(self) -> None:
        command_path = _app_command_path()
        self.write_log(f"Reopening page-forge from: {command_path}")
        try:
            _schedule_app_relaunch(command_path)
        except OSError as error:
            self.write_log(f"Relaunch error: {error}")
            return
        self.exit()

    def start_calibre_update(self) -> None:
        self.query_one(TabbedContent).active = "logs"
        self.write_log("Starting Calibre update.")
        self.run_worker(self.run_calibre_update_worker, thread=True)

    def run_app_update_worker(self) -> None:
        try:
            update_app(on_output=lambda line: self.call_from_thread(self.write_log, line))
            self.call_from_thread(self.write_log, "page-forge update finished.")
            self.call_from_thread(self.relaunch_after_update)
        except PageForgeError as error:
            self.call_from_thread(self.write_log, f"Update error: {error}")

    def run_calibre_update_worker(self) -> None:
        try:
            update_calibre(
                on_output=lambda line: self.call_from_thread(self.write_log, line)
            )
            self.call_from_thread(self.write_log, "Calibre update finished.")
            self.call_from_thread(self.refresh_dashboard)
        except PageForgeError as error:
            self.call_from_thread(self.write_log, f"Update error: {error}")

    def run_convert(self) -> None:
        operation = str(self.query_one("#convert-operation", Select).value)
        source = self.read_path("#convert-source", "Input file")
        output_value = self.query_one("#convert-output", Input).value.strip()
        output = Path(output_value) if output_value else None
        force = self.query_one("#convert-force", Checkbox).value
        if operation == "repair":
            mode = self.read_repair_mode("#convert-repair-mode")
            result = repair_epub(source, output=output, force=force, mode=mode)
        elif operation == "to-epub":
            result = convert_book(source, target_format="epub", output=output, force=force)
        else:
            result = convert_book(source, target_format="mobi", output=output, force=force)
        self.write_log(f"Converted: {result.output_path}")
        self.refresh_dashboard()

    def run_batch(self) -> None:
        operation = str(self.query_one("#batch-operation", Select).value)
        source = self.read_path("#batch-source", "Input folder")
        output = self.read_path("#batch-output", "Output folder")
        force = self.query_one("#batch-force", Checkbox).value
        if operation == "repair":
            mode = self.read_repair_mode("#batch-repair-mode")
            result = repair_folder(source, output_dir=output, force=force, mode=mode)
        elif operation == "to-epub":
            result = convert_folder(source, output_dir=output, target_format="epub", force=force)
        else:
            result = convert_folder(source, output_dir=output, target_format="mobi", force=force)
        self.write_log(
            f"Batch complete: {len(result.results)} converted, {len(result.skipped)} skipped."
        )

    def run_send(self) -> None:
        source = self.read_path("#send-source", "Input file")
        profile = self.query_one("#send-profile", Input).value or "default"
        result = send_to_kindle(source, profile_name=profile)
        self.write_log(f"Sent to Kindle: {result.input_path} -> {result.kindle_email}")

    def run_repair_send(self) -> None:
        source = self.read_path("#send-source", "Input file")
        profile = self.query_one("#send-profile", Input).value or "default"
        force = self.query_one("#send-force", Checkbox).value
        mode = self.read_repair_mode("#send-repair-mode")
        repaired = repair_epub(source, force=force, mode=mode)
        result = send_to_kindle(repaired.output_path, profile_name=profile)
        self.write_log(f"Repaired and sent: {result.input_path} -> {result.kindle_email}")

    def run_inspect(self) -> None:
        source = self.read_path("#metadata-source", "Input file")
        metadata = inspect_book(source)
        title = metadata.fields.get("Title", "Unknown title")
        author = metadata.fields.get("Author(s)", metadata.fields.get("Authors", "Unknown author"))
        self.write_log(f"Metadata: {title} / {author}")

    def run_metadata(self) -> None:
        source = self.read_path("#metadata-source", "Input file")
        title = self.query_one("#metadata-title", Input).value.strip() or None
        author = self.query_one("#metadata-author", Input).value.strip() or None
        metadata = update_book_metadata(source, title=title, author=author)
        updated_title = metadata.fields.get("Title", "Updated")
        self.write_log(f"Metadata updated: {updated_title}")

    def save_profile(self) -> None:
        name = self.query_one("#settings-profile", Input).value or "default"
        sender = self.query_one("#settings-sender", Input).value
        kindle = self.query_one("#settings-kindle", Input).value
        smtp_host = self.query_one("#settings-smtp-host", Input).value or "smtp.gmail.com"
        smtp_port = int(self.query_one("#settings-smtp-port", Input).value or "587")
        smtp_user = self.query_one("#settings-smtp-user", Input).value
        password = self.query_one("#settings-password", Input).value
        output_dir = self.query_one("#settings-output-dir", Input).value
        profile = Profile(
            name=name,
            sender_email=sender,
            kindle_email=kindle,
            smtp_host=smtp_host,
            smtp_port=smtp_port,
            smtp_username=smtp_user or sender,
            default_output_dir=output_dir,
        )
        upsert_profile(profile, make_default=True)
        if password:
            set_profile_password(name, password)
            self.query_one("#settings-password", Input).value = ""
        self.write_log(f"Profile saved: {name}")
        self.refresh_dashboard()


def run_tui() -> None:
    PageForgeApp().run()
