from __future__ import annotations

from pathlib import Path

from page_forge.models import CalibreStatus


def test_calibre_status_requires_ebook_polish():
    status = CalibreStatus(
        ebook_convert=Path("/bin/ebook-convert"),
        ebook_meta=Path("/bin/ebook-meta"),
        ebook_polish=None,
    )

    assert not status.is_ready
    assert status.missing_tools == ["ebook-polish"]
