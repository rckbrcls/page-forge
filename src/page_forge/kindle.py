from __future__ import annotations

import mimetypes
import smtplib
from email.message import EmailMessage
from pathlib import Path

from .config import get_profile, get_profile_password
from .conversion import require_existing_file
from .errors import ConfigurationError
from .models import SendResult


def send_to_kindle(source: Path, *, profile_name: str | None = None) -> SendResult:
    input_path = require_existing_file(source)
    profile = get_profile(profile_name)
    if not profile.is_send_ready:
        raise ConfigurationError(
            f"Profile `{profile.name}` is incomplete. Run `page-forge configure`."
        )

    password = get_profile_password(profile.name)
    message = EmailMessage()
    message["From"] = profile.sender_email
    message["To"] = profile.kindle_email
    message["Subject"] = input_path.stem
    message.set_content("Attached ebook sent by page-forge.")

    content_type, _ = mimetypes.guess_type(input_path.name)
    maintype, subtype = (content_type or "application/octet-stream").split("/", 1)
    message.add_attachment(
        input_path.read_bytes(),
        maintype=maintype,
        subtype=subtype,
        filename=input_path.name,
    )

    try:
        if profile.smtp_port == 465:
            with smtplib.SMTP_SSL(profile.smtp_host, profile.smtp_port) as smtp:
                smtp.login(profile.login_username, password)
                smtp.send_message(message)
        else:
            with smtplib.SMTP(profile.smtp_host, profile.smtp_port) as smtp:
                if profile.use_tls:
                    smtp.starttls()
                smtp.login(profile.login_username, password)
                smtp.send_message(message)
    except (OSError, smtplib.SMTPException) as error:
        raise ConfigurationError(f"Could not send email: {error}") from error

    return SendResult(
        input_path=input_path,
        sender_email=profile.sender_email,
        kindle_email=profile.kindle_email,
        profile_name=profile.name,
    )
