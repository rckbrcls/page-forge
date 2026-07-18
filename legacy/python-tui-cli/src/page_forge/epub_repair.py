from __future__ import annotations

import posixpath
import zipfile
from collections import OrderedDict
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import unquote, urlsplit
from xml.etree import ElementTree
from xml.sax.saxutils import escape

from .errors import ConversionError

EPUB_MIMETYPE = b"application/epub+zip"
CONTAINER_PATH = "META-INF/container.xml"
OPF_MEDIA_TYPE = "application/oebps-package+xml"

KNOWN_MEDIA_TYPES = {
    ".css": "text/css",
    ".gif": "image/gif",
    ".htm": "application/xhtml+xml",
    ".html": "application/xhtml+xml",
    ".jpeg": "image/jpeg",
    ".jpg": "image/jpeg",
    ".js": "text/javascript",
    ".ncx": "application/x-dtbncx+xml",
    ".otf": "font/otf",
    ".png": "image/png",
    ".svg": "image/svg+xml",
    ".ttf": "font/ttf",
    ".woff": "font/woff",
    ".woff2": "font/woff2",
    ".xhtml": "application/xhtml+xml",
}


@dataclass
class EpubEntry:
    info: zipfile.ZipInfo
    data: bytes


def repair_epub_structure(source: Path, output: Path) -> None:
    """Rewrite safe EPUB container structure without changing book content."""
    try:
        entries = _read_epub_entries(source)
    except zipfile.BadZipFile as error:
        raise ConversionError(f"Input EPUB is not a valid ZIP archive: {source}") from error
    except RuntimeError as error:
        raise ConversionError(f"Input EPUB contains unreadable ZIP entries: {error}") from error

    opf_path, container_data = _locate_package_document(entries)
    entries[CONTAINER_PATH] = EpubEntry(
        info=_zip_info(CONTAINER_PATH),
        data=container_data,
    )
    entries.move_to_end(CONTAINER_PATH, last=False)
    entries[opf_path].data = _normalize_and_validate_opf(
        opf_path=opf_path,
        opf_data=entries[opf_path].data,
        entry_names=set(entries),
    )

    _write_epub_entries(output, entries)


def _read_epub_entries(source: Path) -> OrderedDict[str, EpubEntry]:
    entries: OrderedDict[str, EpubEntry] = OrderedDict()
    with zipfile.ZipFile(source, "r") as archive:
        for info in archive.infolist():
            if info.is_dir():
                continue
            name = _normalize_archive_path(info.filename)
            if name == "mimetype":
                continue
            entries[name] = EpubEntry(info=info, data=archive.read(info))
            entries.move_to_end(name)
    if not entries:
        raise ConversionError(f"Input EPUB has no content entries: {source}")
    return entries


def _locate_package_document(
    entries: OrderedDict[str, EpubEntry],
) -> tuple[str, bytes]:
    opf_paths = sorted(name for name in entries if name.lower().endswith(".opf"))
    if not opf_paths:
        raise ConversionError("EPUB does not contain an OPF package document.")

    container = entries.get(CONTAINER_PATH)
    if container is not None:
        package_path = _package_path_from_container(container.data)
        if package_path is not None and package_path in entries:
            return package_path, container.data

    if len(opf_paths) == 1:
        package_path = opf_paths[0]
        return package_path, _container_xml(package_path)

    raise ConversionError(
        "EPUB container is missing or invalid and multiple OPF files were found."
    )


def _package_path_from_container(container_data: bytes) -> str | None:
    try:
        root = ElementTree.fromstring(container_data)
    except ElementTree.ParseError:
        return None

    for element in root.iter():
        if _local_name(element.tag) != "rootfile":
            continue
        full_path = element.get("full-path")
        media_type = element.get("media-type")
        if not full_path:
            continue
        try:
            package_path = _normalize_archive_path(full_path)
        except ConversionError:
            continue
        if package_path.lower().endswith(".opf") and (
            media_type in (None, OPF_MEDIA_TYPE)
        ):
            return package_path
    return None


def _container_xml(package_path: str) -> bytes:
    escaped_path = escape(package_path, {'"': "&quot;"})
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<container version="1.0" '
        'xmlns="urn:oasis:names:tc:opendocument:xmlns:container">\n'
        "  <rootfiles>\n"
        f'    <rootfile full-path="{escaped_path}" media-type="{OPF_MEDIA_TYPE}"/>\n'
        "  </rootfiles>\n"
        "</container>\n"
    ).encode("utf-8")


def _normalize_and_validate_opf(
    *,
    opf_path: str,
    opf_data: bytes,
    entry_names: set[str],
) -> bytes:
    try:
        root = ElementTree.fromstring(opf_data)
    except ElementTree.ParseError as error:
        raise ConversionError(f"OPF package document is invalid XML: {opf_path}") from error

    if _local_name(root.tag) != "package":
        raise ConversionError(f"OPF package document has an invalid root: {opf_path}")

    _register_root_namespace(root.tag)
    manifest = _first_child(root, "manifest")
    spine = _first_child(root, "spine")
    if manifest is None:
        raise ConversionError(f"OPF package document has no manifest: {opf_path}")
    if spine is None:
        raise ConversionError(f"OPF package document has no spine: {opf_path}")

    changed = False
    manifest_by_id: dict[str, ElementTree.Element] = {}
    for item in _children(manifest, "item"):
        item_id = item.get("id")
        href = item.get("href")
        if not item_id or not href:
            raise ConversionError(f"OPF manifest has an item without id or href: {opf_path}")
        manifest_by_id[item_id] = item
        expected_media_type = _known_media_type_for_href(opf_path, href)
        if expected_media_type and item.get("media-type") != expected_media_type:
            item.set("media-type", expected_media_type)
            changed = True

    for itemref in _children(spine, "itemref"):
        idref = itemref.get("idref")
        if not idref:
            raise ConversionError(f"OPF spine has an itemref without idref: {opf_path}")
        item = manifest_by_id.get(idref)
        if item is None:
            raise ConversionError(f"OPF spine references a missing manifest item: {idref}")
        content_path = _resolve_href(opf_path, item.get("href", ""))
        if content_path is None or content_path not in entry_names:
            raise ConversionError(f"OPF spine references missing content: {idref}")

    if not changed:
        return opf_data
    return ElementTree.tostring(root, encoding="utf-8", xml_declaration=True)


def _known_media_type_for_href(opf_path: str, href: str) -> str | None:
    content_path = _resolve_href(opf_path, href)
    if content_path is None:
        return None
    suffix = Path(content_path).suffix.lower()
    return KNOWN_MEDIA_TYPES.get(suffix)


def _resolve_href(opf_path: str, href: str) -> str | None:
    parsed = urlsplit(href)
    if parsed.scheme or parsed.netloc:
        return None
    href_path = unquote(parsed.path)
    if not href_path:
        raise ConversionError(f"OPF manifest href is empty: {opf_path}")
    _validate_relative_path(href_path)
    package_dir = posixpath.dirname(opf_path)
    return _normalize_archive_path(posixpath.normpath(posixpath.join(package_dir, href_path)))


def _write_epub_entries(output: Path, entries: OrderedDict[str, EpubEntry]) -> None:
    with zipfile.ZipFile(output, "w", allowZip64=True) as archive:
        archive.writestr(_mimetype_info(), EPUB_MIMETYPE)
        for name, entry in entries.items():
            if name == "mimetype":
                continue
            archive.writestr(_copy_info(entry.info, name), entry.data)


def _mimetype_info() -> zipfile.ZipInfo:
    info = _zip_info("mimetype")
    info.compress_type = zipfile.ZIP_STORED
    info.extra = b""
    return info


def _copy_info(source: zipfile.ZipInfo, name: str) -> zipfile.ZipInfo:
    info = _zip_info(name, date_time=source.date_time)
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = source.external_attr
    info.comment = source.comment
    return info


def _zip_info(
    name: str,
    *,
    date_time: tuple[int, int, int, int, int, int] = (1980, 1, 1, 0, 0, 0),
) -> zipfile.ZipInfo:
    info = zipfile.ZipInfo(name, date_time=date_time)
    info.compress_type = zipfile.ZIP_DEFLATED
    return info


def _normalize_archive_path(value: str) -> str:
    _validate_relative_path(value)
    normalized = posixpath.normpath(value)
    parts = normalized.split("/")
    if normalized in ("", ".") or any(part in ("", ".", "..") for part in parts):
        raise ConversionError(f"EPUB contains an unsafe path: {value}")
    return normalized


def _validate_relative_path(value: str) -> None:
    if "\\" in value or value.startswith("/"):
        raise ConversionError(f"EPUB contains an unsafe path: {value}")
    if any(part in ("", ".", "..") for part in value.split("/")):
        raise ConversionError(f"EPUB contains an unsafe path: {value}")


def _local_name(tag: str) -> str:
    if "}" in tag:
        return tag.rsplit("}", 1)[1]
    return tag


def _first_child(
    element: ElementTree.Element,
    name: str,
) -> ElementTree.Element | None:
    return next(iter(_children(element, name)), None)


def _children(
    element: ElementTree.Element,
    name: str,
) -> list[ElementTree.Element]:
    return [child for child in element if _local_name(child.tag) == name]


def _register_root_namespace(tag: str) -> None:
    if not tag.startswith("{"):
        return
    namespace = tag[1:].split("}", 1)[0]
    ElementTree.register_namespace("", namespace)
    ElementTree.register_namespace("dc", "http://purl.org/dc/elements/1.1/")
