from __future__ import annotations

import posixpath
import tempfile
import webbrowser
import zipfile
from pathlib import Path
from typing import Callable
from urllib.parse import unquote, urlsplit
from xml.etree import ElementTree

from .calibre import EPUB_SUFFIX, MOBI_SUFFIX
from .conversion import (
    ProgressCallback,
    convert_book,
    prepare_output_path,
    repair_epub,
    require_existing_directory,
    require_existing_file,
)
from .epub_repair import (
    CONTAINER_PATH,
    EPUB_MIMETYPE,
    KNOWN_MEDIA_TYPES,
    OPF_MEDIA_TYPE,
)
from .errors import ConfigurationError, ConversionError
from .kindle import send_to_kindle
from .models import (
    ReadinessBatchResult,
    ReadinessIssue,
    ReadinessReport,
    ReadinessStatus,
    SendResult,
)

SEND_TO_KINDLE_URL = "https://www.amazon.com/sendtokindle"
MAX_SEND_TO_KINDLE_BYTES = 200 * 1024 * 1024
MAX_HTML_ENTRY_BYTES = 30 * 1024 * 1024
MAX_HTML_FILE_COUNT = 300
HTML_SUFFIXES = (".htm", ".html", ".xhtml")
FONT_SUFFIXES = (".otf", ".ttf", ".woff", ".woff2")
SUPPORTED_INPUT_SUFFIXES = (EPUB_SUFFIX, MOBI_SUFFIX)


def default_kindle_ready_output_path(source: Path) -> Path:
    return source.with_name(f"{source.stem}-kindle-ready{EPUB_SUFFIX}")


def audit_book(source: Path) -> ReadinessReport:
    input_path = require_existing_file(source)
    suffix = input_path.suffix.lower()
    if suffix == MOBI_SUFFIX:
        return _report(
            input_path=input_path,
            issues=[
                ReadinessIssue(
                    code="mobi_conversion_needed",
                    severity="fixable",
                    message="MOBI files must be converted to EPUB before Kindle readiness can be audited.",
                    path=input_path.name,
                )
            ],
        )
    if suffix != EPUB_SUFFIX:
        return _report(
            input_path=input_path,
            issues=[
                ReadinessIssue(
                    code="unsupported_format",
                    severity="error",
                    message="Readiness Doctor supports EPUB and MOBI files.",
                    path=input_path.name,
                )
            ],
        )
    return _audit_epub(input_path)


def prepare_book_for_kindle(
    source: Path,
    *,
    output: Path | None = None,
    output_dir: Path | None = None,
    force: bool = False,
    on_progress: ProgressCallback | None = None,
) -> ReadinessReport:
    input_path = require_existing_file(source)
    if input_path.suffix.lower() not in SUPPORTED_INPUT_SUFFIXES:
        return _report(
            input_path=input_path,
            issues=[
                ReadinessIssue(
                    code="unsupported_format",
                    severity="error",
                    message="Readiness Doctor supports EPUB and MOBI files.",
                    path=input_path.name,
                )
            ],
        )

    if output is not None and output_dir is not None:
        raise ConversionError("Use either --output or --output-dir, not both.")

    if input_path.suffix.lower() == MOBI_SUFFIX:
        return _prepare_mobi_for_kindle(
            input_path,
            output=output,
            output_dir=output_dir,
            force=force,
            on_progress=on_progress,
        )

    initial_report = audit_book(input_path)
    if initial_report.status == "blocked":
        return initial_report

    output_path = _prepare_kindle_ready_output(
        input_path,
        output=output,
        output_dir=output_dir,
        force=force,
    )
    if on_progress:
        on_progress("Repairing EPUB for Kindle")
    repair_epub(
        input_path,
        output=output_path,
        force=True,
        mode="safe",
        on_progress=on_progress,
    )
    final_report = audit_book(output_path)
    return _with_output(final_report, input_path=input_path, output_path=output_path)


def readiness_folder(
    folder: Path,
    *,
    output_dir: Path,
    fix: bool = False,
    force: bool = False,
    on_progress: ProgressCallback | None = None,
) -> ReadinessBatchResult:
    input_dir = require_existing_directory(folder)
    destination = output_dir.expanduser().resolve()
    if fix:
        destination.mkdir(parents=True, exist_ok=True)

    reports: list[ReadinessReport] = []
    skipped: list[Path] = []
    for source in sorted(input_dir.iterdir()):
        if not source.is_file() or source.suffix.lower() not in SUPPORTED_INPUT_SUFFIXES:
            skipped.append(source)
            continue
        if fix:
            reports.append(
                prepare_book_for_kindle(
                    source,
                    output_dir=destination,
                    force=force,
                    on_progress=on_progress,
                )
            )
            continue
        reports.append(audit_book(source))

    return ReadinessBatchResult(reports=reports, skipped=skipped)


def send_ready_book(
    report: ReadinessReport,
    *,
    profile_name: str | None = None,
    sender: Callable[..., SendResult] = send_to_kindle,
) -> SendResult:
    if report.status != "ready":
        raise ConfigurationError("Book is not ready for Kindle delivery.")
    source = report.output_path or report.input_path
    return sender(source, profile_name=profile_name)


def open_send_to_kindle_handoff() -> None:
    webbrowser.open(SEND_TO_KINDLE_URL)


def _prepare_mobi_for_kindle(
    input_path: Path,
    *,
    output: Path | None,
    output_dir: Path | None,
    force: bool,
    on_progress: ProgressCallback | None,
) -> ReadinessReport:
    with tempfile.TemporaryDirectory(prefix="page-forge-readiness-") as temp_dir:
        converted_epub = Path(temp_dir) / f"{input_path.stem}{EPUB_SUFFIX}"
        if on_progress:
            on_progress("Converting MOBI to EPUB")
        convert_book(
            input_path,
            target_format="epub",
            output=converted_epub,
            force=True,
            on_progress=on_progress,
        )
        converted_report = audit_book(converted_epub)
        if converted_report.status == "blocked":
            return _report(
                input_path=input_path,
                issues=converted_report.issues,
                converted_from=input_path,
            )

        output_path = _prepare_kindle_ready_output(
            input_path,
            output=output,
            output_dir=output_dir,
            force=force,
        )
        if on_progress:
            on_progress("Repairing converted EPUB for Kindle")
        repair_epub(
            converted_epub,
            output=output_path,
            force=True,
            mode="safe",
            on_progress=on_progress,
        )
        final_report = audit_book(output_path)
        return _with_output(
            final_report,
            input_path=input_path,
            output_path=output_path,
            converted_from=input_path,
        )


def _prepare_kindle_ready_output(
    source: Path,
    *,
    output: Path | None,
    output_dir: Path | None,
    force: bool,
) -> Path:
    default_path = default_kindle_ready_output_path(source)
    raw_output = output or (output_dir / default_path.name if output_dir else default_path)
    return prepare_output_path(raw_output, force=force)


def _audit_epub(input_path: Path) -> ReadinessReport:
    issues: list[ReadinessIssue] = []
    try:
        with zipfile.ZipFile(input_path, "r") as archive:
            infos = [info for info in archive.infolist() if not info.is_dir()]
            entries: dict[str, bytes] = {}
            info_by_name: dict[str, zipfile.ZipInfo] = {}
            ordered_names: list[str] = []

            for info in infos:
                raw_name = info.filename
                if _is_unsafe_archive_path(raw_name):
                    issues.append(
                        ReadinessIssue(
                            code="unsafe_path",
                            severity="error",
                            message="EPUB archive contains an unsafe path.",
                            path=raw_name,
                        )
                    )
                    continue
                name = posixpath.normpath(raw_name)
                ordered_names.append(name)
                entries[name] = archive.read(info)
                info_by_name[name] = info
    except zipfile.BadZipFile:
        return _report(
            input_path=input_path,
            issues=[
                ReadinessIssue(
                    code="invalid_zip",
                    severity="error",
                    message="Input EPUB is not a valid ZIP archive.",
                    path=input_path.name,
                )
            ],
        )
    except RuntimeError as error:
        return _report(
            input_path=input_path,
            issues=[
                ReadinessIssue(
                    code="unreadable_zip_entry",
                    severity="error",
                    message=f"Input EPUB contains unreadable ZIP entries: {error}",
                    path=input_path.name,
                )
            ],
        )

    if not ordered_names:
        issues.append(
            ReadinessIssue(
                code="empty_epub",
                severity="error",
                message="EPUB archive has no content entries.",
                path=input_path.name,
            )
        )
        return _report(input_path=input_path, issues=issues)

    _audit_mimetype(ordered_names, entries, info_by_name, issues)
    opf_path = _select_opf(entries, issues)
    if opf_path is not None:
        _audit_opf(opf_path, entries[opf_path], set(entries), issues)
    _audit_kindle_heuristics(input_path, entries, issues)
    return _report(input_path=input_path, issues=issues)


def _audit_mimetype(
    ordered_names: list[str],
    entries: dict[str, bytes],
    info_by_name: dict[str, zipfile.ZipInfo],
    issues: list[ReadinessIssue],
) -> None:
    if "mimetype" not in entries:
        issues.append(
            ReadinessIssue(
                code="mimetype_missing",
                severity="fixable",
                message="EPUB mimetype entry is missing.",
                path="mimetype",
            )
        )
        return

    if ordered_names[0] != "mimetype":
        issues.append(
            ReadinessIssue(
                code="mimetype_position",
                severity="fixable",
                message="EPUB mimetype entry should be the first archive entry.",
                path="mimetype",
            )
        )

    if info_by_name["mimetype"].compress_type != zipfile.ZIP_STORED:
        issues.append(
            ReadinessIssue(
                code="mimetype_compression",
                severity="fixable",
                message="EPUB mimetype entry should be stored without compression.",
                path="mimetype",
            )
        )

    if entries["mimetype"] != EPUB_MIMETYPE:
        issues.append(
            ReadinessIssue(
                code="mimetype_value",
                severity="fixable",
                message="EPUB mimetype entry has the wrong value.",
                path="mimetype",
            )
        )


def _select_opf(
    entries: dict[str, bytes],
    issues: list[ReadinessIssue],
) -> str | None:
    opf_paths = sorted(name for name in entries if name.lower().endswith(".opf"))
    if not opf_paths:
        issues.append(
            ReadinessIssue(
                code="opf_missing",
                severity="error",
                message="EPUB does not contain an OPF package document.",
            )
        )
        return None

    container_data = entries.get(CONTAINER_PATH)
    if container_data is not None:
        package_path = _package_path_from_container(container_data)
        if package_path is not None and package_path in entries:
            return package_path
        if len(opf_paths) == 1:
            issues.append(
                ReadinessIssue(
                    code="container_invalid",
                    severity="fixable",
                    message="EPUB container is invalid but a single OPF document was found.",
                    path=CONTAINER_PATH,
                )
            )
            return opf_paths[0]
        issues.append(
            ReadinessIssue(
                code="container_ambiguous",
                severity="error",
                message="EPUB container is missing or invalid and multiple OPF documents were found.",
                path=CONTAINER_PATH,
            )
        )
        return None

    if len(opf_paths) == 1:
        issues.append(
            ReadinessIssue(
                code="container_missing",
                severity="fixable",
                message="EPUB container is missing but a single OPF document was found.",
                path=CONTAINER_PATH,
            )
        )
        return opf_paths[0]

    issues.append(
        ReadinessIssue(
            code="container_ambiguous",
            severity="error",
            message="EPUB container is missing and multiple OPF documents were found.",
            path=CONTAINER_PATH,
        )
    )
    return None


def _audit_opf(
    opf_path: str,
    opf_data: bytes,
    entry_names: set[str],
    issues: list[ReadinessIssue],
) -> None:
    try:
        root = ElementTree.fromstring(opf_data)
    except ElementTree.ParseError:
        issues.append(
            ReadinessIssue(
                code="opf_invalid_xml",
                severity="error",
                message="OPF package document is invalid XML.",
                path=opf_path,
            )
        )
        return

    if _local_name(root.tag) != "package":
        issues.append(
            ReadinessIssue(
                code="opf_invalid_root",
                severity="error",
                message="OPF package document has an invalid root element.",
                path=opf_path,
            )
        )
        return

    manifest = _first_child(root, "manifest")
    spine = _first_child(root, "spine")
    metadata = _first_child(root, "metadata")
    if manifest is None:
        issues.append(
            ReadinessIssue(
                code="manifest_missing",
                severity="error",
                message="OPF package document has no manifest.",
                path=opf_path,
            )
        )
    if spine is None:
        issues.append(
            ReadinessIssue(
                code="spine_missing",
                severity="error",
                message="OPF package document has no spine.",
                path=opf_path,
            )
        )
    if manifest is None or spine is None:
        return

    manifest_items = _children(manifest, "item")
    manifest_by_id: dict[str, ElementTree.Element] = {}
    has_cover = False
    for item in manifest_items:
        item_id = item.get("id")
        href = item.get("href")
        if not item_id or not href:
            issues.append(
                ReadinessIssue(
                    code="manifest_item_incomplete",
                    severity="error",
                    message="OPF manifest has an item without id or href.",
                    path=opf_path,
                )
            )
            continue
        manifest_by_id[item_id] = item
        properties = set((item.get("properties") or "").split())
        if "cover-image" in properties or item_id.lower() in ("cover", "cover-image"):
            has_cover = True
        try:
            content_path = _resolve_href(opf_path, href)
        except ConversionError as error:
            issues.append(
                ReadinessIssue(
                    code="manifest_unsafe_href",
                    severity="error",
                    message=str(error),
                    path=href,
                )
            )
            continue
        expected_media_type = _known_media_type_for_path(content_path)
        if expected_media_type and item.get("media-type") != expected_media_type:
            issues.append(
                ReadinessIssue(
                    code="opf_media_type",
                    severity="fixable",
                    message="OPF manifest item has a media type that does not match its file extension.",
                    path=content_path,
                )
            )
        if content_path not in entry_names:
            issues.append(
                ReadinessIssue(
                    code="manifest_missing_content",
                    severity="error",
                    message="OPF manifest references missing content.",
                    path=content_path,
                )
            )

    for itemref in _children(spine, "itemref"):
        idref = itemref.get("idref")
        if not idref:
            issues.append(
                ReadinessIssue(
                    code="spine_itemref_missing_idref",
                    severity="error",
                    message="OPF spine has an itemref without idref.",
                    path=opf_path,
                )
            )
            continue
        item = manifest_by_id.get(idref)
        if item is None:
            issues.append(
                ReadinessIssue(
                    code="spine_missing_manifest_item",
                    severity="error",
                    message="OPF spine references a missing manifest item.",
                    path=idref,
                )
            )
            continue
        try:
            content_path = _resolve_href(opf_path, item.get("href", ""))
        except ConversionError as error:
            issues.append(
                ReadinessIssue(
                    code="spine_unsafe_href",
                    severity="error",
                    message=str(error),
                    path=item.get("href", ""),
                )
            )
            continue
        if content_path not in entry_names:
            issues.append(
                ReadinessIssue(
                    code="spine_missing_content",
                    severity="error",
                    message="OPF spine references missing content.",
                    path=content_path,
                )
            )

    _audit_metadata(metadata, opf_path, issues)
    if not has_cover:
        issues.append(
            ReadinessIssue(
                code="cover_missing",
                severity="warning",
                message="No cover image was declared in the OPF manifest.",
                path=opf_path,
            )
        )


def _audit_metadata(
    metadata: ElementTree.Element | None,
    opf_path: str,
    issues: list[ReadinessIssue],
) -> None:
    if metadata is None:
        title = ""
        creator = ""
    else:
        title = _first_descendant_text(metadata, "title")
        creator = _first_descendant_text(metadata, "creator")

    if not title:
        issues.append(
            ReadinessIssue(
                code="metadata_title_missing",
                severity="warning",
                message="Book title metadata is missing.",
                path=opf_path,
            )
        )
    if not creator:
        issues.append(
            ReadinessIssue(
                code="metadata_author_missing",
                severity="warning",
                message="Book author metadata is missing.",
                path=opf_path,
            )
        )


def _audit_kindle_heuristics(
    input_path: Path,
    entries: dict[str, bytes],
    issues: list[ReadinessIssue],
) -> None:
    if input_path.stat().st_size > MAX_SEND_TO_KINDLE_BYTES:
        issues.append(
            ReadinessIssue(
                code="send_to_kindle_size",
                severity="warning",
                message="File is larger than the 200 MB Send to Kindle wireless transfer limit.",
                path=input_path.name,
            )
        )

    html_count = 0
    for name, data in entries.items():
        suffix = Path(name).suffix.lower()
        if suffix in HTML_SUFFIXES:
            html_count += 1
            if len(data) > MAX_HTML_ENTRY_BYTES:
                issues.append(
                    ReadinessIssue(
                        code="html_entry_size",
                        severity="warning",
                        message="HTML content file is larger than Amazon's 30 MB guidance.",
                        path=name,
                    )
                )
        if suffix in FONT_SUFFIXES and len(data) == 0:
            issues.append(
                ReadinessIssue(
                    code="empty_font_file",
                    severity="warning",
                    message="Font file is empty.",
                    path=name,
                )
            )

    if html_count > MAX_HTML_FILE_COUNT:
        issues.append(
            ReadinessIssue(
                code="html_file_count",
                severity="warning",
                message="EPUB contains more than 300 HTML/XHTML files.",
            )
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
        if not full_path or _is_unsafe_archive_path(full_path):
            continue
        package_path = posixpath.normpath(full_path)
        if package_path.lower().endswith(".opf") and media_type in (None, OPF_MEDIA_TYPE):
            return package_path
    return None


def _resolve_href(opf_path: str, href: str) -> str:
    parsed = urlsplit(href)
    if parsed.scheme or parsed.netloc:
        raise ConversionError(f"OPF manifest href is external: {href}")
    href_path = unquote(parsed.path)
    if not href_path:
        raise ConversionError(f"OPF manifest href is empty: {opf_path}")
    if _is_unsafe_archive_path(href_path):
        raise ConversionError(f"OPF manifest href is unsafe: {href}")
    package_dir = posixpath.dirname(opf_path)
    content_path = posixpath.normpath(posixpath.join(package_dir, href_path))
    if _is_unsafe_archive_path(content_path):
        raise ConversionError(f"OPF manifest href resolves to an unsafe path: {href}")
    return content_path


def _is_unsafe_archive_path(value: str) -> bool:
    if "\\" in value or value.startswith("/"):
        return True
    parts = value.split("/")
    if any(part in ("", ".", "..") for part in parts):
        return True
    normalized = posixpath.normpath(value)
    normalized_parts = normalized.split("/")
    return normalized in ("", ".") or any(
        part in ("", ".", "..") for part in normalized_parts
    )


def _known_media_type_for_path(path: str) -> str | None:
    return KNOWN_MEDIA_TYPES.get(Path(path).suffix.lower())


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


def _first_descendant_text(element: ElementTree.Element, name: str) -> str:
    for descendant in element.iter():
        if _local_name(descendant.tag) != name:
            continue
        value = (descendant.text or "").strip()
        if value:
            return value
    return ""


def _report(
    *,
    input_path: Path,
    issues: list[ReadinessIssue],
    output_path: Path | None = None,
    converted_from: Path | None = None,
) -> ReadinessReport:
    return ReadinessReport(
        input_path=input_path.resolve(),
        status=_status_for(issues),
        issues=issues,
        output_path=output_path.resolve() if output_path is not None else None,
        converted_from=converted_from.resolve() if converted_from is not None else None,
        handoff_url=SEND_TO_KINDLE_URL,
    )


def _with_output(
    report: ReadinessReport,
    *,
    input_path: Path,
    output_path: Path,
    converted_from: Path | None = None,
) -> ReadinessReport:
    return ReadinessReport(
        input_path=input_path.resolve(),
        status=report.status,
        issues=report.issues,
        output_path=output_path.resolve(),
        converted_from=converted_from.resolve() if converted_from is not None else None,
        handoff_url=SEND_TO_KINDLE_URL,
    )


def _status_for(issues: list[ReadinessIssue]) -> ReadinessStatus:
    if any(issue.severity == "error" for issue in issues):
        return "blocked"
    if any(issue.severity == "fixable" for issue in issues):
        return "needs_fixes"
    return "ready"
