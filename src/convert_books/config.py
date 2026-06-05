from __future__ import annotations

import json
import os
from dataclasses import asdict
from pathlib import Path
from typing import Any

import keyring

from .errors import ConfigurationError
from .models import AppConfig, Profile

KEYRING_SERVICE = "convert-books"


def config_dir() -> Path:
    root = os.environ.get("XDG_CONFIG_HOME")
    if root:
        return Path(root).expanduser().resolve() / "convert-books"
    return Path.home() / ".config" / "convert-books"


def config_path() -> Path:
    return config_dir() / "config.json"


def _profile_from_dict(name: str, data: dict[str, Any]) -> Profile:
    return Profile(
        name=name,
        sender_email=str(data.get("sender_email", "")),
        kindle_email=str(data.get("kindle_email", "")),
        smtp_host=str(data.get("smtp_host", "smtp.gmail.com")),
        smtp_port=int(data.get("smtp_port", 587)),
        smtp_username=str(data.get("smtp_username", "")),
        use_tls=bool(data.get("use_tls", True)),
        default_output_dir=str(data.get("default_output_dir", "")),
    )


def load_config() -> AppConfig:
    path = config_path()
    if not path.exists():
        return AppConfig()

    with path.open("r", encoding="utf-8") as file:
        raw = json.load(file)

    profiles = {
        name: _profile_from_dict(name, data)
        for name, data in raw.get("profiles", {}).items()
    }
    if not profiles:
        profiles = {"default": Profile()}

    default_profile = str(raw.get("default_profile", "default"))
    if default_profile not in profiles:
        default_profile = next(iter(profiles))

    return AppConfig(default_profile=default_profile, profiles=profiles)


def save_config(config: AppConfig) -> Path:
    path = config_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "default_profile": config.default_profile,
        "profiles": {
            name: asdict(profile)
            for name, profile in sorted(config.profiles.items(), key=lambda item: item[0])
        },
    }
    with path.open("w", encoding="utf-8") as file:
        json.dump(payload, file, indent=2, sort_keys=True)
        file.write("\n")
    return path


def get_profile(name: str | None = None) -> Profile:
    config = load_config()
    profile_name = name or config.default_profile
    profile = config.profiles.get(profile_name)
    if profile is None:
        raise ConfigurationError(f"Profile not found: {profile_name}")
    return profile


def upsert_profile(profile: Profile, *, make_default: bool = True) -> Path:
    config = load_config()
    config.profiles[profile.name] = profile
    if make_default:
        config.default_profile = profile.name
    return save_config(config)


def secret_name(profile_name: str) -> str:
    return f"smtp:{profile_name}"


def set_profile_password(profile_name: str, password: str) -> None:
    try:
        keyring.set_password(KEYRING_SERVICE, secret_name(profile_name), password)
    except Exception as error:  # pragma: no cover - depends on local keyring backend
        raise ConfigurationError(f"Could not store password in Keychain: {error}") from error


def get_profile_password(profile_name: str) -> str:
    try:
        password = keyring.get_password(KEYRING_SERVICE, secret_name(profile_name))
    except Exception as error:  # pragma: no cover - depends on local keyring backend
        raise ConfigurationError(f"Could not read password from Keychain: {error}") from error
    if not password:
        raise ConfigurationError(
            f"SMTP password is missing for profile `{profile_name}`. "
            "Run `convert-books configure`."
        )
    return password


def profile_has_password(profile_name: str) -> bool:
    try:
        return bool(keyring.get_password(KEYRING_SERVICE, secret_name(profile_name)))
    except Exception:
        return False
