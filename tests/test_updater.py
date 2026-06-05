from __future__ import annotations

import pytest

import convert_books.updater as updater
from convert_books.errors import DependencyError


def test_build_app_update_command():
    command = updater.build_app_update_command("/usr/bin/uv")

    assert command == [
        "/usr/bin/uv",
        "tool",
        "install",
        "--force",
        "git+https://github.com/rckbrcls/convert-books.git",
    ]


def test_build_calibre_update_command():
    command = updater.build_calibre_update_command("/opt/homebrew/bin/brew")

    assert command == [
        "/opt/homebrew/bin/brew",
        "upgrade",
        "--cask",
        "calibre",
    ]


def test_update_app_missing_uv(monkeypatch):
    monkeypatch.setattr(updater, "uv_path", lambda: None)

    with pytest.raises(DependencyError, match="uv command not found"):
        updater.update_app()


def test_update_calibre_missing_homebrew(monkeypatch):
    monkeypatch.setattr(updater, "homebrew_path", lambda: None)

    with pytest.raises(DependencyError, match="Homebrew command not found"):
        updater.update_calibre()
