from __future__ import annotations

import pytest

from page_forge import conversion
from page_forge.conversion import (
    convert_book,
    convert_folder,
    default_output_path,
    repair_folder,
    repair_epub,
    require_suffix,
)
from page_forge.errors import ConversionError
from page_forge.models import ConversionResult


def test_default_output_path_adds_marker(tmp_path):
    source = tmp_path / "book.epub"

    output = default_output_path(source, ".epub", marker="repaired")

    assert output == tmp_path / "book-repaired.epub"


def test_require_suffix_accepts_matching_suffix(tmp_path):
    require_suffix(tmp_path / "book.EPUB", ".epub")


def test_require_suffix_rejects_wrong_suffix(tmp_path):
    with pytest.raises(ConversionError):
        require_suffix(tmp_path / "book.pdf", ".epub")


def test_convert_book_accepts_pdf_to_epub(tmp_path, monkeypatch):
    source = tmp_path / "book.pdf"
    source.write_bytes(b"pdf")
    calls: list[tuple[str, str]] = []

    def fake_convert(input_path, output_path):
        calls.append((input_path.name, output_path.name))
        output_path.write_bytes(b"epub")

    monkeypatch.setattr(conversion, "run_ebook_convert", fake_convert)

    result = convert_book(source, target_format="epub")

    assert calls == [("book.pdf", "book.epub")]
    assert result.output_path == (tmp_path / "book.epub").resolve()
    assert result.output_path.read_bytes() == b"epub"


def test_convert_book_accepts_uppercase_pdf_suffix(tmp_path, monkeypatch):
    source = tmp_path / "Book.PDF"
    source.write_bytes(b"pdf")

    def fake_convert(input_path, output_path):
        output_path.write_bytes(b"epub")

    monkeypatch.setattr(conversion, "run_ebook_convert", fake_convert)

    result = convert_book(source, target_format="epub")

    assert result.output_path == (tmp_path / "Book.epub").resolve()


def test_convert_book_rejects_unsupported_source_for_epub(tmp_path):
    source = tmp_path / "notes.txt"
    source.write_text("notes")

    with pytest.raises(ConversionError, match="MOBI.*PDF"):
        convert_book(source, target_format="epub")


def test_convert_book_to_mobi_still_requires_epub(tmp_path):
    source = tmp_path / "book.pdf"
    source.write_bytes(b"pdf")

    with pytest.raises(ConversionError, match="EPUB"):
        convert_book(source, target_format="mobi")


def test_convert_folder_to_epub_accepts_mobi_and_pdf(tmp_path, monkeypatch):
    folder = tmp_path / "books"
    folder.mkdir()
    (folder / "book.mobi").write_bytes(b"mobi")
    (folder / "manual.pdf").write_bytes(b"pdf")
    (folder / "notes.txt").write_text("notes")
    (folder / "source.epub").write_bytes(b"epub")
    output_dir = tmp_path / "converted"
    calls: list[str] = []

    def fake_convert_book(source_path, *, target_format, output_dir, force, on_progress):
        calls.append(source_path.name)
        return ConversionResult(
            input_path=source_path,
            output_path=output_dir / f"{source_path.stem}.{target_format}",
        )

    monkeypatch.setattr(conversion, "convert_book", fake_convert_book)

    result = convert_folder(folder, output_dir=output_dir, target_format="epub")

    assert calls == ["book.mobi", "manual.pdf"]
    assert [item.output_path.name for item in result.results] == [
        "book.epub",
        "manual.epub",
    ]
    assert [item.name for item in result.skipped] == ["notes.txt", "source.epub"]


def test_repair_epub_safe_invokes_structural_repair_then_polish(tmp_path, monkeypatch):
    source = tmp_path / "book.epub"
    output = tmp_path / "book-repaired.epub"
    source.write_bytes(b"raw")
    calls: list[tuple[str, str]] = []

    def fake_structure(input_path, structured_epub):
        calls.append(("structure", input_path.name))
        structured_epub.write_bytes(b"structured")

    def fake_polish(structured_epub, output_path):
        calls.append(("polish", structured_epub.name))
        output_path.write_bytes(b"polished")

    monkeypatch.setattr(conversion, "repair_epub_structure", fake_structure)
    monkeypatch.setattr(conversion, "run_ebook_polish", fake_polish)

    result = repair_epub(source, output=output)

    assert calls == [
        ("structure", "book.epub"),
        ("polish", "book-structured.epub"),
    ]
    assert result.output_path == output.resolve()
    assert output.read_bytes() == b"polished"


def test_repair_epub_safe_rejects_keep_temp(tmp_path):
    source = tmp_path / "book.epub"
    source.write_bytes(b"raw")

    with pytest.raises(ConversionError, match="--keep-temp"):
        repair_epub(source, keep_temp=True)


def test_repair_epub_aggressive_preserves_mobi_roundtrip(tmp_path, monkeypatch):
    source = tmp_path / "book.epub"
    output = tmp_path / "book-repaired.epub"
    source.write_bytes(b"raw")
    calls: list[tuple[str, str]] = []

    def fake_convert(input_path, output_path):
        calls.append((input_path.suffix, output_path.suffix))
        output_path.write_bytes(b"converted")

    monkeypatch.setattr(conversion, "run_ebook_convert", fake_convert)

    result = repair_epub(source, output=output, mode="aggressive")

    assert calls == [(".epub", ".mobi"), (".mobi", ".epub")]
    assert result.output_path == output.resolve()
    assert result.intermediate_path is None


def test_repair_folder_passes_repair_mode(tmp_path, monkeypatch):
    folder = tmp_path / "books"
    folder.mkdir()
    source = folder / "book.epub"
    source.write_bytes(b"raw")
    output_dir = tmp_path / "fixed"
    calls: list[str] = []

    def fake_repair_epub(source_path, *, output_dir, force, mode, on_progress):
        calls.append(mode)
        return ConversionResult(
            input_path=source_path,
            output_path=output_dir / "book-repaired.epub",
        )

    monkeypatch.setattr(conversion, "repair_epub", fake_repair_epub)

    result = repair_folder(output_dir=output_dir, folder=folder, mode="aggressive")

    assert calls == ["aggressive"]
    assert result.results[0].output_path == output_dir.resolve() / "book-repaired.epub"
