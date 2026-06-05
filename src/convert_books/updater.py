from __future__ import annotations

import shutil
import subprocess
from typing import Callable

from .errors import DependencyError
from .installer import homebrew_path
from .platform import platform_support_message

REPO_PACKAGE = "git+https://github.com/rckbrcls/convert-books.git"
UV_INSTALL_COMMAND = "curl -LsSf https://astral.sh/uv/install.sh | sh"

UpdateOutputCallback = Callable[[str], None]


def uv_path() -> str | None:
    return shutil.which("uv")


def build_app_update_command(uv_executable: str) -> list[str]:
    return [uv_executable, "tool", "install", "--force", REPO_PACKAGE]


def build_calibre_update_command(brew_executable: str) -> list[str]:
    return [brew_executable, "upgrade", "--cask", "calibre"]


def command_text(command: list[str]) -> str:
    return " ".join(command)


def _run_streaming_command(
    command: list[str],
    *,
    on_output: UpdateOutputCallback | None = None,
    failure_message: str,
) -> None:
    process = subprocess.Popen(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )

    lines: list[str] = []
    if process.stdout is not None:
        for raw_line in process.stdout:
            line = raw_line.strip()
            if not line:
                continue
            lines.append(line)
            if on_output is not None:
                on_output(line)

    returncode = process.wait()
    if returncode != 0:
        raise DependencyError("\n".join(lines[-8:]) or failure_message)


def update_app(on_output: UpdateOutputCallback | None = None) -> None:
    executable = uv_path()
    if executable is None:
        raise DependencyError(
            "uv command not found. Install uv first with: "
            f"`{UV_INSTALL_COMMAND}`"
        )

    _run_streaming_command(
        build_app_update_command(executable),
        on_output=on_output,
        failure_message="uv failed without an error message.",
    )


def update_calibre(on_output: UpdateOutputCallback | None = None) -> None:
    executable = homebrew_path()
    if executable is None:
        raise DependencyError(
            f"{platform_support_message()} Homebrew command not found. "
            "Install or update Calibre manually from "
            "https://calibre-ebook.com/download_osx"
        )

    _run_streaming_command(
        build_calibre_update_command(executable),
        on_output=on_output,
        failure_message="Homebrew failed without an error message.",
    )
