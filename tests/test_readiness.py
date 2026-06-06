from __future__ import annotations

import zipfile
from pathlib import Path

import pytest

import page_forge.readiness as readiness
from page_forge.errors import ConfigurationError
from page_forge.models import ConversionResult, SendResult
from page_forge.readiness import (
    SEND_TO_KINDLE_URL,
    audit_book,
    default_kindle_ready_output_path,
    prepare_book_for_kindle,
    readiness_folder,
    send_ready_book,
)


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


def package_xml(
    *,
    title: str = "Example Book",
    creator: str = "Example Author",
    chapter_href: str = "chapter.xhtml",
    chapter_media_type: str = "application/xhtml+xml",
    include_cover: bool = True,
) -> bytes:
    cover_item = (
        '    <item id="cover-image" href="cover.jpg" '
        'media-type="image/jpeg" properties="cover-image"/>\n'
        if include_cover
        else ""
    )
    metadata = (
        "  <metadata>\n"
        f"    <dc:title>{title}</dc:title>\n"
        f"    <dc:creator>{creator}</dc:creator>\n"
        "  </metadata>\n"
    )
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<package xmlns="http://www.idpf.org/2007/opf" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" version="3.0" '
        'unique-identifier="book-id">\n'
        f"{metadata}"
        "  <manifest>\n"
        f'    <item id="chapter" href="{chapter_href}" '
        f'media-type="{chapter_media_type}"/>\n'
        f"{cover_item}"
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


def write_epub(
    path: Path,
    entries: list[tuple[str, bytes, int]] | None = None,
) -> None:
    default_entries = [
        ("mimetype", readiness.EPUB_MIMETYPE, zipfile.ZIP_STORED),
        ("META-INF/container.xml", container_xml(), zipfile.ZIP_DEFLATED),
        ("OEBPS/content.opf", package_xml(), zipfile.ZIP_DEFLATED),
        ("OEBPS/chapter.xhtml", chapter_xml(), zipfile.ZIP_DEFLATED),
        ("OEBPS/cover.jpg", b"cover", zipfile.ZIP_DEFLATED),
    ]
    with zipfile.ZipFile(path, "w") as archive:
        for name, data, compression in entries or default_entries:
            archive.writestr(name, data, compress_type=compression)


def issue_codes(report) -> set[str]:
    return {issue.code for issue in report.issues}


def test_audit_book_reports_valid_epub_as_ready(tmp_path):
    source = tmp_path / "book.epub"
    write_epub(source)

    report = audit_book(source)

    assert report.status == "ready"
    assert report.input_path == source.resolve()
    assert report.output_path is None
    assert report.handoff_url == SEND_TO_KINDLE_URL
    assert report.blocking_issues == []


def test_audit_book_reports_fixable_epub_structure_issues(tmp_path):
    source = tmp_path / "book.epub"
    write_epub(
        source,
        [
            ("OEBPS/content.opf", package_xml(chapter_media_type="text/html"), zipfile.ZIP_DEFLATED),
            ("OEBPS/chapter.xhtml", chapter_xml(), zipfile.ZIP_DEFLATED),
            ("OEBPS/cover.jpg", b"cover", zipfile.ZIP_DEFLATED),
            ("mimetype", readiness.EPUB_MIMETYPE, zipfile.ZIP_DEFLATED),
        ],
    )

    report = audit_book(source)

    assert report.status == "needs_fixes"
    assert {
        "mimetype_position",
        "mimetype_compression",
        "container_missing",
        "opf_media_type",
    }.issubset(issue_codes(report))
    assert all(issue.severity == "fixable" for issue in report.fixable_issues)


def test_audit_book_blocks_invalid_zip(tmp_path):
    source = tmp_path / "book.epub"
    source.write_bytes(b"not a zip")

    report = audit_book(source)

    assert report.status == "blocked"
    assert issue_codes(report) == {"invalid_zip"}


def test_audit_book_blocks_multiple_opfs_without_container(tmp_path):
    source = tmp_path / "book.epub"
    write_epub(
        source,
        [
            ("mimetype", readiness.EPUB_MIMETYPE, zipfile.ZIP_STORED),
            ("OEBPS/content.opf", package_xml(), zipfile.ZIP_DEFLATED),
            ("OEBPS/chapter.xhtml", chapter_xml(), zipfile.ZIP_DEFLATED),
            ("OPS/alternate.opf", package_xml(), zipfile.ZIP_DEFLATED),
            ("OPS/chapter.xhtml", chapter_xml(), zipfile.ZIP_DEFLATED),
        ],
    )

    report = audit_book(source)

    assert report.status == "blocked"
    assert "container_ambiguous" in issue_codes(report)


def test_audit_book_blocks_spine_references_missing_content(tmp_path):
    source = tmp_path / "book.epub"
    write_epub(
        source,
        [
            ("mimetype", readiness.EPUB_MIMETYPE, zipfile.ZIP_STORED),
            ("META-INF/container.xml", container_xml(), zipfile.ZIP_DEFLATED),
            (
                "OEBPS/content.opf",
                package_xml(chapter_href="missing.xhtml"),
                zipfile.ZIP_DEFLATED,
            ),
        ],
    )

    report = audit_book(source)

    assert report.status == "blocked"
    assert "spine_missing_content" in issue_codes(report)


def test_audit_book_blocks_unsafe_archive_paths(tmp_path):
    source = tmp_path / "book.epub"
    write_epub(
        source,
        [
            ("mimetype", readiness.EPUB_MIMETYPE, zipfile.ZIP_STORED),
            ("../content.opf", package_xml(), zipfile.ZIP_DEFLATED),
        ],
    )

    report = audit_book(source)

    assert report.status == "blocked"
    assert "unsafe_path" in issue_codes(report)


def test_audit_book_reports_kindle_heuristic_warnings(tmp_path, monkeypatch):
    monkeypatch.setattr(readiness, "MAX_SEND_TO_KINDLE_BYTES", 10)
    monkeypatch.setattr(readiness, "MAX_HTML_ENTRY_BYTES", 20)
    monkeypatch.setattr(readiness, "MAX_HTML_FILE_COUNT", 1)
    source = tmp_path / "book.epub"
    write_epub(
        source,
        [
            ("mimetype", readiness.EPUB_MIMETYPE, zipfile.ZIP_STORED),
            ("META-INF/container.xml", container_xml(), zipfile.ZIP_DEFLATED),
            (
                "OEBPS/content.opf",
                package_xml(title="", creator="", include_cover=False),
                zipfile.ZIP_DEFLATED,
            ),
            ("OEBPS/chapter.xhtml", b"<html>" + (b"a" * 25) + b"</html>", zipfile.ZIP_DEFLATED),
            ("OEBPS/extra.xhtml", chapter_xml(), zipfile.ZIP_DEFLATED),
            ("OEBPS/font.woff2", b"", zipfile.ZIP_DEFLATED),
        ],
    )

    report = audit_book(source)

    assert report.status == "ready"
    assert {
        "send_to_kindle_size",
        "html_entry_size",
        "html_file_count",
        "empty_font_file",
        "metadata_title_missing",
        "metadata_author_missing",
        "cover_missing",
    }.issubset(issue_codes(report))
    assert all(issue.severity == "warning" for issue in report.warning_issues)


def test_default_kindle_ready_output_path_uses_kindle_ready_marker(tmp_path):
    source = tmp_path / "book.epub"

    output = default_kindle_ready_output_path(source)

    assert output == tmp_path / "book-kindle-ready.epub"


def test_prepare_book_for_kindle_repairs_epub_to_kindle_ready_output(tmp_path, monkeypatch):
    source = tmp_path / "book.epub"
    write_epub(
        source,
        [
            ("OEBPS/content.opf", package_xml(chapter_media_type="text/html"), zipfile.ZIP_DEFLATED),
            ("OEBPS/chapter.xhtml", chapter_xml(), zipfile.ZIP_DEFLATED),
            ("OEBPS/cover.jpg", b"cover", zipfile.ZIP_DEFLATED),
            ("mimetype", readiness.EPUB_MIMETYPE, zipfile.ZIP_DEFLATED),
        ],
    )
    calls: list[tuple[str, str]] = []

    def fake_repair_epub(input_path, *, output, force, mode, on_progress):
        calls.append((input_path.name, output.name))
        write_epub(output)
        return ConversionResult(input_path=input_path, output_path=output)

    monkeypatch.setattr(readiness, "repair_epub", fake_repair_epub)

    report = prepare_book_for_kindle(source, force=True)

    assert calls == [("book.epub", "book-kindle-ready.epub")]
    assert report.status == "ready"
    assert report.output_path == (tmp_path / "book-kindle-ready.epub").resolve()


def test_prepare_book_for_kindle_converts_mobi_before_doctor(tmp_path, monkeypatch):
    source = tmp_path / "book.mobi"
    source.write_bytes(b"mobi")
    calls: list[tuple[str, str]] = []

    def fake_convert_book(input_path, *, target_format, output, force, on_progress):
        calls.append((input_path.name, target_format))
        write_epub(output)
        return ConversionResult(input_path=input_path, output_path=output)

    def fake_repair_epub(input_path, *, output, force, mode, on_progress):
        calls.append((input_path.name, mode))
        write_epub(output)
        return ConversionResult(input_path=input_path, output_path=output)

    monkeypatch.setattr(readiness, "convert_book", fake_convert_book)
    monkeypatch.setattr(readiness, "repair_epub", fake_repair_epub)

    report = prepare_book_for_kindle(source, force=True)

    assert calls == [("book.mobi", "epub"), ("book.epub", "safe")]
    assert report.status == "ready"
    assert report.converted_from == source.resolve()
    assert report.output_path == (tmp_path / "book-kindle-ready.epub").resolve()


def test_readiness_folder_aggregates_reports_and_skips_unsupported_files(tmp_path, monkeypatch):
    folder = tmp_path / "books"
    folder.mkdir()
    write_epub(folder / "ready.epub")
    write_epub(
        folder / "fixable.epub",
        [
            ("OEBPS/content.opf", package_xml(chapter_media_type="text/html"), zipfile.ZIP_DEFLATED),
            ("OEBPS/chapter.xhtml", chapter_xml(), zipfile.ZIP_DEFLATED),
            ("OEBPS/cover.jpg", b"cover", zipfile.ZIP_DEFLATED),
            ("mimetype", readiness.EPUB_MIMETYPE, zipfile.ZIP_DEFLATED),
        ],
    )
    (folder / "notes.txt").write_text("notes")
    output_dir = tmp_path / "ready"

    def fake_repair_epub(input_path, *, output, force, mode, on_progress):
        write_epub(output)
        return ConversionResult(input_path=input_path, output_path=output)

    monkeypatch.setattr(readiness, "repair_epub", fake_repair_epub)

    result = readiness_folder(folder, output_dir=output_dir, fix=True, force=True)

    assert result.ready_count == 2
    assert result.blocked_count == 0
    assert result.skipped == [folder / "notes.txt"]
    assert [report.output_path.name for report in result.reports if report.output_path] == [
        "fixable-kindle-ready.epub",
        "ready-kindle-ready.epub",
    ]


def test_send_ready_book_only_sends_ready_reports(tmp_path):
    source = tmp_path / "book.epub"
    write_epub(source)
    report = audit_book(source)
    calls: list[tuple[Path, str | None]] = []

    def fake_send(path, *, profile_name=None):
        calls.append((path, profile_name))
        return SendResult(
            input_path=path,
            sender_email="sender@example.com",
            kindle_email="reader@kindle.com",
            profile_name=profile_name or "default",
        )

    result = send_ready_book(report, profile_name="personal", sender=fake_send)

    assert calls == [(source.resolve(), "personal")]
    assert result.profile_name == "personal"


def test_send_ready_book_rejects_blocked_reports(tmp_path):
    source = tmp_path / "book.epub"
    source.write_bytes(b"not a zip")
    report = audit_book(source)

    with pytest.raises(ConfigurationError, match="not ready"):
        send_ready_book(report)
