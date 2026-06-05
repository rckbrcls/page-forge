from __future__ import annotations

from convert_books.config import load_config, save_config
from convert_books.models import AppConfig, Profile


def test_save_and_load_profile(monkeypatch, tmp_path):
    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path))
    config = AppConfig(
        default_profile="personal",
        profiles={
            "personal": Profile(
                name="personal",
                sender_email="sender@example.com",
                kindle_email="reader@kindle.com",
                smtp_host="smtp.example.com",
                smtp_port=2525,
                smtp_username="smtp-user",
                default_output_dir="/tmp/books",
            )
        },
    )

    save_config(config)
    loaded = load_config()

    assert loaded.default_profile == "personal"
    assert loaded.profiles["personal"].sender_email == "sender@example.com"
    assert loaded.profiles["personal"].kindle_email == "reader@kindle.com"
    assert loaded.profiles["personal"].smtp_port == 2525
