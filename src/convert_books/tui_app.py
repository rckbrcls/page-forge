from __future__ import annotations

from pathlib import Path

from textual.app import App, ComposeResult
from textual.containers import Grid, Horizontal, Vertical
from textual.widgets import (
    Button,
    Checkbox,
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
from .conversion import convert_book, convert_folder, repair_epub, repair_folder
from .errors import ConvertBooksError
from .kindle import send_to_kindle
from .metadata import inspect_book, update_book_metadata
from .models import Profile
from .updater import update_app, update_calibre


class ConvertBooksApp(App[None]):
    """Interactive terminal app for convert-books."""

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

            with TabPane("Convert", id="convert"):
                with Vertical(classes="form"):
                    yield Label("Operation")
                    yield Select(
                        [
                            ("Repair EPUB", "repair"),
                            ("MOBI to EPUB", "to-epub"),
                            ("EPUB to MOBI", "to-mobi"),
                        ],
                        id="convert-operation",
                        value="repair",
                    )
                    yield Label("Input file")
                    yield Input(placeholder="/path/to/book.epub", id="convert-source")
                    yield Label("Output file (optional)")
                    yield Input(placeholder="/path/to/output.epub", id="convert-output")
                    yield Checkbox("Overwrite existing output", id="convert-force")
                    with Horizontal(classes="actions"):
                        yield Button("Run Conversion", id="run-convert", variant="primary")

            with TabPane("Batch", id="batch"):
                with Vertical(classes="form"):
                    yield Label("Operation")
                    yield Select(
                        [
                            ("Repair EPUB files", "repair"),
                            ("MOBI files to EPUB", "to-epub"),
                            ("EPUB files to MOBI", "to-mobi"),
                        ],
                        id="batch-operation",
                        value="repair",
                    )
                    yield Label("Input folder")
                    yield Input(placeholder="/path/to/folder", id="batch-source")
                    yield Label("Output folder")
                    yield Input(placeholder="/path/to/output", id="batch-output")
                    yield Checkbox("Overwrite existing outputs", id="batch-force")
                    with Horizontal(classes="actions"):
                        yield Button("Run Batch", id="run-batch", variant="primary")

            with TabPane("Send to Kindle", id="send"):
                with Vertical(classes="form"):
                    yield Label("Input file")
                    yield Input(placeholder="/path/to/book.epub", id="send-source")
                    yield Label("Profile")
                    yield Input(value="default", id="send-profile")
                    yield Checkbox("Overwrite repaired output", id="send-force")
                    with Horizontal(classes="actions"):
                        yield Button("Send", id="run-send", variant="primary")
                        yield Button("Repair and Send", id="run-repair-send")

            with TabPane("Metadata", id="metadata"):
                with Vertical(classes="form"):
                    yield Label("Input file")
                    yield Input(placeholder="/path/to/book.epub", id="metadata-source")
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
                    yield Input(placeholder="/path/to/books", id="settings-output-dir")
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
                    f"ebook-meta: {status.ebook_meta}"
                )
            else:
                missing = ", ".join(status.missing_tools)
                calibre_text = (
                    "Calibre status: Setup required\n"
                    "Platform: macOS-only\n"
                    f"Missing: {missing}\n"
                    "Run: convert-books setup --install"
                )
        except ConvertBooksError as error:
            calibre_text = (
                "Calibre status: Setup required\n"
                "Platform: macOS-only\n"
                f"Error: {error}\n"
                "Check EBOOK_CONVERT_PATH or EBOOK_META_PATH."
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
                "Open Settings or run: convert-books configure"
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
        except ConvertBooksError as error:
            self.write_log(f"Error: {error}")
        except ValueError as error:
            self.write_log(f"Error: {error}")

    def start_app_update(self) -> None:
        self.query_one(TabbedContent).active = "logs"
        self.write_log("Starting convert-books update.")
        self.run_worker(self.run_app_update_worker, thread=True)

    def start_calibre_update(self) -> None:
        self.query_one(TabbedContent).active = "logs"
        self.write_log("Starting Calibre update.")
        self.run_worker(self.run_calibre_update_worker, thread=True)

    def run_app_update_worker(self) -> None:
        try:
            update_app(on_output=lambda line: self.call_from_thread(self.write_log, line))
            self.call_from_thread(self.write_log, "convert-books update finished.")
        except ConvertBooksError as error:
            self.call_from_thread(self.write_log, f"Update error: {error}")

    def run_calibre_update_worker(self) -> None:
        try:
            update_calibre(
                on_output=lambda line: self.call_from_thread(self.write_log, line)
            )
            self.call_from_thread(self.write_log, "Calibre update finished.")
            self.call_from_thread(self.refresh_dashboard)
        except ConvertBooksError as error:
            self.call_from_thread(self.write_log, f"Update error: {error}")

    def run_convert(self) -> None:
        operation = str(self.query_one("#convert-operation", Select).value)
        source = self.read_path("#convert-source", "Input file")
        output_value = self.query_one("#convert-output", Input).value.strip()
        output = Path(output_value) if output_value else None
        force = self.query_one("#convert-force", Checkbox).value
        if operation == "repair":
            result = repair_epub(source, output=output, force=force)
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
            result = repair_folder(source, output_dir=output, force=force)
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
        repaired = repair_epub(source, force=force)
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
    ConvertBooksApp().run()
