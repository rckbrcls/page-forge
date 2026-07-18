from __future__ import annotations

from page_forge.metadata import parse_ebook_meta_output


def test_parse_ebook_meta_output_extracts_fields():
    raw = """
Title               : Example Book
Author(s)           : Example Author
Languages           : eng
"""

    fields = parse_ebook_meta_output(raw)

    assert fields["Title"] == "Example Book"
    assert fields["Author(s)"] == "Example Author"
    assert fields["Languages"] == "eng"
