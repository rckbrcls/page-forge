from __future__ import annotations

import pytest

from page_forge.conversion import default_output_path, require_suffix
from page_forge.errors import ConversionError


def test_default_output_path_adds_marker(tmp_path):
    source = tmp_path / "book.epub"

    output = default_output_path(source, ".epub", marker="repaired")

    assert output == tmp_path / "book-repaired.epub"


def test_require_suffix_accepts_matching_suffix(tmp_path):
    require_suffix(tmp_path / "book.EPUB", ".epub")


def test_require_suffix_rejects_wrong_suffix(tmp_path):
    with pytest.raises(ConversionError):
        require_suffix(tmp_path / "book.pdf", ".epub")
