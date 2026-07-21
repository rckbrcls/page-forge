# V1 Finding Catalog

This catalog is the closed inspection scope for v1. Every code requires at least one focused test and fixture. “Complete inspection” means every applicable rule below ran; it does not mean EPUBCheck equivalence or visual Kindle rendering validation.

`Impact` is the minimum health state when the finding is present. `Conditional` repairability means automatic repair is allowed only when the catalogued unique-target precondition is proven.

## Input and ZIP Identity

| Code | Severity | Impact | Repairability | Meaning |
|------|----------|--------|---------------|---------|
| `INPUT_NOT_EPUB` | Error | Unsupported | None | Basename does not end in `.epub` case-insensitively |
| `INPUT_NOT_REGULAR_FILE` | Error | Unsupported | None | Selection is a directory, link, special file, or missing item |
| `INPUT_UNREADABLE` | Error | Unsupported | None | Source cannot be opened read-only |
| `INPUT_CHANGED` | Error | Needs Review | None | File identity, size, or modification evidence changed after review |
| `ZIP_INVALID` | Critical | Unsupported | None | Source is not a complete readable ZIP |
| `ZIP_EMPTY` | Error | Unsupported | None | Archive has no entries |
| `ZIP_MULTIDISK` | Critical | Unsafe | None | Multi-disk archive is unsupported and unsafe to process |
| `ZIP64_INVALID` | Critical | Unsafe | None | ZIP64 metadata is malformed or outside safe integer bounds |
| `ZIP_METHOD_UNSUPPORTED` | Critical | Unsafe | None | Entry uses a method other than STORE or DEFLATE |
| `ZIP_CRC_MISMATCH` | Critical | Unsafe | None | Streamed bytes do not match declared CRC |
| `ZIP_SIZE_MISMATCH` | Critical | Unsafe | None | Actual bytes do not match safe declared bounds |

## Archive Safety

| Code | Severity | Impact | Repairability | Meaning |
|------|----------|--------|---------------|---------|
| `ARCHIVE_SOURCE_TOO_LARGE` | Critical | Unsafe | None | Compressed source exceeds 200,000,000 bytes |
| `ARCHIVE_TOO_MANY_ENTRIES` | Critical | Unsafe | None | Entry count exceeds 10,000 |
| `ARCHIVE_ENTRY_TOO_LARGE` | Critical | Unsafe | None | One expanded entry exceeds 100,000,000 bytes |
| `ARCHIVE_EXPANDED_TOO_LARGE` | Critical | Unsafe | None | Expanded total exceeds 1,000,000,000 bytes |
| `ARCHIVE_COMPRESSION_RATIO` | Critical | Unsafe | None | Per-entry or aggregate expansion exceeds 100:1 |
| `ARCHIVE_TIMEOUT` | Critical | Unsafe | None | Inspection exceeds 120 seconds for one file; repair/revalidation timeouts are operation failures, not health findings |
| `ARCHIVE_PATH_ABSOLUTE` | Critical | Unsafe | None | Entry has POSIX, drive, or UNC absolute path |
| `ARCHIVE_PATH_TRAVERSAL` | Critical | Unsafe | None | Entry contains escaping or noncanonical path segments |
| `ARCHIVE_PATH_INVALID` | Critical | Unsafe | None | Entry has NUL, backslash, invalid encoding, empty, or forbidden name |
| `ARCHIVE_ENTRY_DUPLICATE` | Critical | Unsafe | None | Exact duplicate central-directory path exists |
| `ARCHIVE_CASE_COLLISION` | Critical | Unsafe | None | Canonical Unicode-folded path collision exists |
| `ARCHIVE_FILE_DIRECTORY_CONFLICT` | Critical | Unsafe | None | Paths conflict as file and directory ancestry |
| `ARCHIVE_SYMLINK` | Critical | Unsafe | None | Entry is a symbolic link or equivalent |
| `ARCHIVE_SPECIAL_FILE` | Critical | Unsafe | None | Entry is not a regular file or directory |
| `ARCHIVE_ENCRYPTED_ENTRY` | Critical | Unsafe | None | ZIP encryption flag is present |

## Mimetype

| Code | Severity | Impact | Repairability | Meaning |
|------|----------|--------|---------------|---------|
| `MIMETYPE_MISSING` | Error | Repairable | Automatic | Root `mimetype` entry is absent |
| `MIMETYPE_NOT_FIRST` | Error | Repairable | Automatic | `mimetype` is not physical entry zero |
| `MIMETYPE_COMPRESSED` | Error | Repairable | Automatic | `mimetype` is not STORE |
| `MIMETYPE_VALUE_INVALID` | Error | Repairable | Automatic | Content is not exactly `application/epub+zip` |
| `MIMETYPE_EXTRA_FIELD` | Warning | Repairable | Automatic | Local header contains disallowed extra data |

Duplicate `mimetype` entries are not repairable; the archive duplicate rule makes the file Unsafe.

## Container and Package Discovery

| Code | Severity | Impact | Repairability | Meaning |
|------|----------|--------|---------------|---------|
| `CONTAINER_MISSING` | Error | Repairable or Needs Review | Conditional | `META-INF/container.xml` absent; repairable only with exactly one valid unambiguous OPF |
| `CONTAINER_XML_INVALID` | Error | Repairable or Needs Review | Conditional | Container XML malformed; repairable only by replacement with exactly one valid unambiguous OPF and no unsafe XML condition |
| `CONTAINER_ROOTFILE_MISSING` | Error | Repairable or Needs Review | Conditional | No usable rootfile; same unique-OPF condition |
| `CONTAINER_ROOTFILE_MULTIPLE` | Warning | Needs Review | None | Multiple plausible package documents are declared |
| `CONTAINER_PACKAGE_MISSING` | Error | Repairable or Needs Review | Conditional | Referenced OPF missing; repairable only when exactly one other valid OPF exists |
| `PACKAGE_NOT_FOUND` | Error | Unsupported | None | No valid package document exists |
| `PACKAGE_AMBIGUOUS` | Error | Needs Review | None | Multiple plausible package documents exist |
| `PACKAGE_XML_INVALID` | Error | Needs Review | None | Selected OPF is malformed XML |
| `PACKAGE_VERSION_UNSUPPORTED` | Error | Unsupported | None | Package version is outside supported EPUB 2/3 scope |

## Package Metadata, Manifest, Spine, Navigation, and Cover

| Code | Severity | Impact | Repairability | Meaning |
|------|----------|--------|---------------|---------|
| `METADATA_TITLE_MISSING` | Warning | Needs Review | None | Essential title missing or empty |
| `METADATA_IDENTIFIER_MISSING` | Warning | Needs Review | None | Essential identifier missing or empty |
| `METADATA_LANGUAGE_MISSING` | Warning | Needs Review | None | Essential language missing or empty |
| `PACKAGE_UNIQUE_IDENTIFIER_INVALID` | Error | Needs Review | None | `package@unique-identifier` is absent, duplicated, or does not resolve to exactly one identifier |
| `MANIFEST_MISSING` | Error | Needs Review | None | Manifest absent or unusable |
| `MANIFEST_ID_DUPLICATE` | Error | Needs Review | None | Duplicate manifest ID |
| `MANIFEST_HREF_DUPLICATE` | Warning | Needs Review | None | Multiple manifest items ambiguously address one resource |
| `MANIFEST_RESOURCE_MISSING` | Error | Needs Review | None | Manifest target does not exist and has no unique equivalent target |
| `MANIFEST_MEDIA_TYPE_MISMATCH` | Warning | Repairable | Automatic | Declared media type conflicts with an unambiguous known extension |
| `MANIFEST_MEDIA_TYPE_UNKNOWN` | Warning | Needs Review | None | Type cannot be inferred safely |
| `SPINE_MISSING` | Error | Needs Review | None | Spine absent or unusable |
| `SPINE_ITEMREF_MISSING_ID` | Error | Needs Review | None | Spine itemref lacks idref |
| `SPINE_ITEM_NOT_IN_MANIFEST` | Error | Needs Review | None | Spine idref has no manifest item |
| `SPINE_READING_ORDER_INVALID` | Error | Needs Review | None | Reading order is structurally invalid or empty |
| `NAVIGATION_MISSING` | Warning | Needs Review | None | Required EPUB navigation document/NCX is absent |
| `NAVIGATION_AMBIGUOUS` | Warning | Needs Review | None | Multiple plausible navigation documents exist |
| `COVER_MISSING` | Warning | Needs Review | None | No identifiable cover where expected |
| `COVER_AMBIGUOUS` | Warning | Needs Review | None | Multiple plausible cover candidates exist |

## XML and Content References

| Code | Severity | Impact | Repairability | Meaning |
|------|----------|--------|---------------|---------|
| `XML_ENCODING_INVALID` | Error | Repairable or Needs Review | Conditional | Encoding is malformed; automatic normalization only when bytes decode unambiguously without semantic change |
| `XML_VERSION_UNSUPPORTED` | Critical | Unsafe | None | XML 1.1 or unsupported declaration encountered |
| `XML_DOCTYPE_FORBIDDEN` | Critical | Unsafe | None | Any DOCTYPE encountered under v1 safety policy |
| `XML_ENTITY_FORBIDDEN` | Critical | Unsafe | None | External or undeclared entity behavior encountered |
| `XML_TOO_LARGE` | Critical | Unsafe | None | XML exceeds 10,000,000 bytes |
| `XML_TOO_DEEP` | Critical | Unsafe | None | XML nesting exceeds 64 levels |
| `XHTML_MALFORMED` | Error | Needs Review | None | Content document cannot be parsed safely |
| `CONTENT_LINK_BROKEN` | Warning | Repairable or Needs Review | Conditional | Internal link missing; repairable only with exactly one equivalent target |
| `CONTENT_IMAGE_MISSING` | Error | Repairable or Needs Review | Conditional | Image target missing; same unique-target condition |
| `CONTENT_STYLESHEET_MISSING` | Warning | Repairable or Needs Review | Conditional | Stylesheet target missing; same unique-target condition |
| `CONTENT_FONT_MISSING` | Warning | Repairable or Needs Review | Conditional | Font target missing; same unique-target condition |
| `CONTENT_PATH_CASE_MISMATCH` | Warning | Repairable | Automatic | Reference differs only by canonical case and exactly one target exists |
| `CONTENT_REMOTE_RESOURCE` | Warning | Needs Review | None | HTTP(S) or other remote resource is referenced |
| `CONTENT_EXTERNAL_FILE_REFERENCE` | Critical | Unsafe | None | Local absolute/file reference escapes the EPUB |
| `CONTENT_RELEVANT_FILE_EMPTY` | Warning | Needs Review | None | Required content/resource file has zero useful bytes |
| `CONTENT_CHAPTER_EMPTY` | Warning | Needs Review | None | Spine chapter has no deterministic useful content |
| `CONTENT_SCRIPTED` | Warning | Needs Review | None | Script or active content may be Kindle-incompatible; never executed or removed |
| `CONTENT_EXECUTABLE_RESOURCE` | Critical | Unsafe | None | Executable/macro-like resource is present |
| `CONTENT_FIXED_LAYOUT` | Info | Healthy | None | Fixed-layout metadata may limit Kindle compatibility |
| `CONTENT_INTERACTIVE` | Warning | Needs Review | None | Interactive resource may not be supported on Kindle |
| `CONTENT_ENCRYPTED` | Critical | Unsafe | None | `encryption.xml` or protected resource indicates DRM/encryption |

## Severity and Repair Rules

1. Critical means processing is unsafe or integrity cannot be trusted.
2. Error means structural validity or required content is broken.
3. Warning means a concrete compatibility, completeness, or ambiguity issue exists.
4. Info communicates a bounded limitation without making the structure unhealthy.
5. `Conditional` becomes `Automatic` only when the report evidence proves exactly one deterministic target and the operation is in the repair allowlist; otherwise impact is `Needs Review`.
6. A code's UI title/description may improve, but its semantic meaning cannot change without a documented catalog migration.
