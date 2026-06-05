from __future__ import annotations

import shutil
import subprocess
from typing import Callable

from .errors import DependencyError
from .platform import platform_support_message

InstallOutputCallback = Callable[[str], None]


def homebrew_path() -> str | None:
    return shutil.which("brew")


def calibre_explanation() -> str:
    return (
        "Calibre provides the `ebook-convert` engine used for reliable EPUB/MOBI "
        "conversion."
    )


def install_calibre_with_homebrew(on_output: InstallOutputCallback | None = None) -> None:
    brew = homebrew_path()
    if brew is None:
        raise DependencyError(
            f"{platform_support_message()} Homebrew command not found. "
            "Install Calibre manually from "
            "https://calibre-ebook.com/download_osx"
        )

    process = subprocess.Popen(
        [brew, "install", "--cask", "calibre"],
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
        raise DependencyError(
            "\n".join(lines[-8:]) or "Homebrew failed without an error message."
        )
