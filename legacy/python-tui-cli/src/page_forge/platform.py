from __future__ import annotations

import platform

SUPPORTED_PLATFORM = "macOS"


def current_platform_name() -> str:
    return platform.system() or "Unknown"


def is_macos() -> bool:
    return current_platform_name() == "Darwin"


def platform_support_message() -> str:
    return (
        "page-forge is a macOS-only app because it uses Homebrew, Calibre "
        "macOS app paths, and macOS Keychain."
    )
