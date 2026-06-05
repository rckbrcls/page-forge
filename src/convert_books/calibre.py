from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

from .errors import DependencyError
from .models import CalibreStatus

APP_NAME = "convert-books"
EPUB_SUFFIX = ".epub"
MOBI_SUFFIX = ".mobi"
EBOOK_CONVERT_ENV_VAR = "EBOOK_CONVERT_PATH"
EBOOK_META_ENV_VAR = "EBOOK_META_PATH"

CALIBRE_DIRECTORIES = (
    Path("/Applications/calibre.app/Contents/MacOS"),
    Path.home() / "Applications/calibre.app/Contents/MacOS",
    Path("/opt/homebrew/bin"),
    Path("/usr/local/bin"),
)


def is_executable(path: Path) -> bool:
    return path.exists() and path.is_file() and os.access(path, os.X_OK)


def find_tool(name: str, env_var: str | None = None) -> Path | None:
    if env_var:
        configured = os.environ.get(env_var)
        if configured:
            configured_path = Path(configured).expanduser().resolve()
            if is_executable(configured_path):
                return configured_path
            raise DependencyError(f"{env_var} points to a missing file: {configured_path}")

    executable = shutil.which(name)
    if executable is not None:
        return Path(executable)

    for directory in CALIBRE_DIRECTORIES:
        candidate = directory / name
        if is_executable(candidate):
            return candidate

    return None


def get_calibre_status() -> CalibreStatus:
    return CalibreStatus(
        ebook_convert=find_tool("ebook-convert", EBOOK_CONVERT_ENV_VAR),
        ebook_meta=find_tool("ebook-meta", EBOOK_META_ENV_VAR),
    )


def require_ebook_convert() -> Path:
    status = get_calibre_status()
    if status.ebook_convert is None:
        raise DependencyError(
            "Calibre command not found. Install Calibre or run `convert-books setup`."
        )
    return status.ebook_convert


def require_ebook_meta() -> Path:
    status = get_calibre_status()
    if status.ebook_meta is None:
        raise DependencyError(
            "Calibre metadata command not found. Install Calibre or run "
            "`convert-books setup`."
        )
    return status.ebook_meta


def run_calibre_command(command: list[str]) -> str:
    completed = subprocess.run(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    output = "\n".join(
        part for part in (completed.stdout.strip(), completed.stderr.strip()) if part
    )
    if completed.returncode != 0:
        raise DependencyError(output or "Calibre failed without an error message.")
    return output
