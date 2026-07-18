from __future__ import annotations

import pytest

import page_forge.updater as updater
from page_forge.errors import DependencyError


def test_build_app_update_command():
    command = updater.build_app_update_command("/usr/bin/uv")

    assert command == [
        "/usr/bin/uv",
        "tool",
        "install",
        "--force",
        "page-forge @ git+https://github.com/rckbrcls/page-forge.git",
    ]


def test_command_text_quotes_direct_reference():
    command = updater.command_text(updater.build_app_update_command("uv"))

    assert (
        command
        == "uv tool install --force 'page-forge @ git+https://github.com/rckbrcls/page-forge.git'"
    )


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
