from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Literal


@dataclass(frozen=True)
class CalibreStatus:
    ebook_convert: Path | None
    ebook_meta: Path | None
    ebook_polish: Path | None

    @property
    def is_ready(self) -> bool:
        return (
            self.ebook_convert is not None
            and self.ebook_meta is not None
            and self.ebook_polish is not None
        )

    @property
    def missing_tools(self) -> list[str]:
        missing: list[str] = []
        if self.ebook_convert is None:
            missing.append("ebook-convert")
        if self.ebook_meta is None:
            missing.append("ebook-meta")
        if self.ebook_polish is None:
            missing.append("ebook-polish")
        return missing


@dataclass(frozen=True)
class ConversionResult:
    input_path: Path
    output_path: Path
    intermediate_path: Path | None = None


@dataclass(frozen=True)
class BatchResult:
    results: list[ConversionResult]
    skipped: list[Path] = field(default_factory=list)


@dataclass(frozen=True)
class BookMetadata:
    path: Path
    raw: str
    fields: dict[str, str]


@dataclass
class Profile:
    name: str = "default"
    sender_email: str = ""
    kindle_email: str = ""
    smtp_host: str = "smtp.gmail.com"
    smtp_port: int = 587
    smtp_username: str = ""
    use_tls: bool = True
    default_output_dir: str = ""

    @property
    def login_username(self) -> str:
        return self.smtp_username or self.sender_email

    @property
    def is_send_ready(self) -> bool:
        return bool(
            self.sender_email
            and self.kindle_email
            and self.smtp_host
            and self.smtp_port
            and self.login_username
        )


@dataclass
class AppConfig:
    default_profile: str = "default"
    profiles: dict[str, Profile] = field(default_factory=lambda: {"default": Profile()})


@dataclass(frozen=True)
class SendResult:
    input_path: Path
    sender_email: str
    kindle_email: str
    profile_name: str


IssueSeverity = Literal["info", "warning", "error", "fixable"]
ReadinessStatus = Literal["ready", "needs_fixes", "blocked"]


@dataclass(frozen=True)
class ReadinessIssue:
    code: str
    severity: IssueSeverity
    message: str
    path: str | None = None


@dataclass(frozen=True)
class ReadinessReport:
    input_path: Path
    status: ReadinessStatus
    issues: list[ReadinessIssue] = field(default_factory=list)
    output_path: Path | None = None
    converted_from: Path | None = None
    handoff_url: str = ""

    @property
    def fixable_issues(self) -> list[ReadinessIssue]:
        return [issue for issue in self.issues if issue.severity == "fixable"]

    @property
    def warning_issues(self) -> list[ReadinessIssue]:
        return [issue for issue in self.issues if issue.severity == "warning"]

    @property
    def blocking_issues(self) -> list[ReadinessIssue]:
        return [issue for issue in self.issues if issue.severity == "error"]

    @property
    def is_ready(self) -> bool:
        return self.status == "ready"


@dataclass(frozen=True)
class ReadinessBatchResult:
    reports: list[ReadinessReport]
    skipped: list[Path] = field(default_factory=list)

    @property
    def ready_count(self) -> int:
        return sum(1 for report in self.reports if report.status == "ready")

    @property
    def needs_fixes_count(self) -> int:
        return sum(1 for report in self.reports if report.status == "needs_fixes")

    @property
    def blocked_count(self) -> int:
        return sum(1 for report in self.reports if report.status == "blocked")
