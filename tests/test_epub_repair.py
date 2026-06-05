from __future__ import annotations

import zipfile
from pathlib import Path

import pytest

from page_forge.epub_repair import CONTAINER_PATH, EPUB_MIMETYPE, repair_epub_structure
from page_forge.errors import ConversionError


def container_xml(package_path: str = "OEBPS/content.opf") -> bytes:
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<container version="1.0" '
        'xmlns="urn:oasis:names:tc:opendocument:xmlns:container">\n'
        "  <rootfiles>\n"
        f'    <rootfile full-path="{package_path}" '
        'media-type="application/oebps-package+xml"/>\n'
        "  </rootfiles>\n"
        "</container>\n"
    ).encode("utf-8")


def package_xml(chapter_href: str = "chapter.xhtml") -> bytes:
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" '
        'unique-identifier="book-id">\n'
        "  <metadata/>\n"
        "  <manifest>\n"
        f'    <item id="chapter" href="{chapter_href}" media-type="text/html"/>\n'
        "  </manifest>\n"
        "  <spine>\n"
        '    <itemref idref="chapter"/>\n'
        "  </spine>\n"
        "</package>\n"
    ).encode("utf-8")


def chapter_xml() -> bytes:
    return (
        b'<?xml version="1.0" encoding="UTF-8"?>\n'
        b'<html xmlns="http://www.w3.org/1999/xhtml"><body>Chapter</body></html>\n'
    )


def write_zip(path: Path, entries: list[tuple[str, bytes, int]]) -> None:
    with zipfile.ZipFile(path, "w") as archive:
        for name, data, compression in entries:
            archive.writestr(name, data, compress_type=compression)


def test_repair_epub_structure_rewrites_mimetype_first_and_stored(tmp_path):
    source = tmp_path / "book.epub"
    output = tmp_path / "book-repaired.epub"
    write_zip(
        source,
        [
            ("OEBPS/content.opf", package_xml(), zipfile.ZIP_DEFLATED),
            ("OEBPS/chapter.xhtml", chapter_xml(), zipfile.ZIP_DEFLATED),
            (CONTAINER_PATH, container_xml(), zipfile.ZIP_DEFLATED),
            ("mimetype", EPUB_MIMETYPE, zipfile.ZIP_DEFLATED),
        ],
    )

    repair_epub_structure(source, output)

    with zipfile.ZipFile(output) as archive:
        first = archive.infolist()[0]
        assert first.filename == "mimetype"
        assert first.compress_type == zipfile.ZIP_STORED
        assert archive.read("mimetype") == EPUB_MIMETYPE
        assert b'media-type="application/xhtml+xml"' in archive.read("OEBPS/content.opf")


def test_repair_epub_structure_generates_missing_container_for_single_opf(tmp_path):
    source = tmp_path / "book.epub"
    output = tmp_path / "book-repaired.epub"
    write_zip(
        source,
        [
            ("mimetype", EPUB_MIMETYPE, zipfile.ZIP_STORED),
            ("OEBPS/content.opf", package_xml(), zipfile.ZIP_DEFLATED),
            ("OEBPS/chapter.xhtml", chapter_xml(), zipfile.ZIP_DEFLATED),
        ],
    )

    repair_epub_structure(source, output)

    with zipfile.ZipFile(output) as archive:
        container = archive.read(CONTAINER_PATH)
        assert b'full-path="OEBPS/content.opf"' in container


def test_repair_epub_structure_repairs_invalid_container_when_single_opf(tmp_path):
    source = tmp_path / "book.epub"
    output = tmp_path / "book-repaired.epub"
    write_zip(
        source,
        [
            ("mimetype", EPUB_MIMETYPE, zipfile.ZIP_STORED),
            (CONTAINER_PATH, container_xml("missing.opf"), zipfile.ZIP_DEFLATED),
            ("OEBPS/content.opf", package_xml(), zipfile.ZIP_DEFLATED),
            ("OEBPS/chapter.xhtml", chapter_xml(), zipfile.ZIP_DEFLATED),
        ],
    )

    repair_epub_structure(source, output)

    with zipfile.ZipFile(output) as archive:
        container = archive.read(CONTAINER_PATH)
        assert b'full-path="OEBPS/content.opf"' in container


def test_repair_epub_structure_deduplicates_entries_by_last_occurrence(tmp_path):
    source = tmp_path / "book.epub"
    output = tmp_path / "book-repaired.epub"
    with pytest.warns(UserWarning, match="Duplicate name"):
        write_zip(
            source,
            [
                ("mimetype", EPUB_MIMETYPE, zipfile.ZIP_STORED),
                (CONTAINER_PATH, container_xml(), zipfile.ZIP_DEFLATED),
                ("OEBPS/content.opf", package_xml(), zipfile.ZIP_DEFLATED),
                ("OEBPS/chapter.xhtml", b"old", zipfile.ZIP_DEFLATED),
                ("OEBPS/chapter.xhtml", chapter_xml(), zipfile.ZIP_DEFLATED),
            ],
        )

    repair_epub_structure(source, output)

    with zipfile.ZipFile(output) as archive:
        names = archive.namelist()
        assert names.count("OEBPS/chapter.xhtml") == 1
        assert archive.read("OEBPS/chapter.xhtml") == chapter_xml()


def test_repair_epub_structure_rejects_missing_container_with_multiple_opfs(tmp_path):
    source = tmp_path / "book.epub"
    output = tmp_path / "book-repaired.epub"
    write_zip(
        source,
        [
            ("OEBPS/content.opf", package_xml(), zipfile.ZIP_DEFLATED),
            ("OPS/alternate.opf", package_xml(), zipfile.ZIP_DEFLATED),
            ("OEBPS/chapter.xhtml", chapter_xml(), zipfile.ZIP_DEFLATED),
            ("OPS/chapter.xhtml", chapter_xml(), zipfile.ZIP_DEFLATED),
        ],
    )

    with pytest.raises(ConversionError, match="multiple OPF"):
        repair_epub_structure(source, output)


def test_repair_epub_structure_rejects_spine_that_references_missing_content(tmp_path):
    source = tmp_path / "book.epub"
    output = tmp_path / "book-repaired.epub"
    write_zip(
        source,
        [
            ("mimetype", EPUB_MIMETYPE, zipfile.ZIP_STORED),
            (CONTAINER_PATH, container_xml(), zipfile.ZIP_DEFLATED),
            ("OEBPS/content.opf", package_xml("missing.xhtml"), zipfile.ZIP_DEFLATED),
        ],
    )

    with pytest.raises(ConversionError, match="missing content"):
        repair_epub_structure(source, output)
