from __future__ import annotations

import convert_books.platform as app_platform


def test_is_macos_when_platform_is_darwin(monkeypatch):
    monkeypatch.setattr(app_platform.platform, "system", lambda: "Darwin")

    assert app_platform.is_macos()


def test_is_macos_rejects_other_platforms(monkeypatch):
    monkeypatch.setattr(app_platform.platform, "system", lambda: "Linux")

    assert not app_platform.is_macos()


def test_platform_support_message_mentions_macos():
    assert "macOS-only" in app_platform.platform_support_message()
