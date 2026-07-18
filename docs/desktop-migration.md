# Desktop Migration Notes

## Product surface

- Primary: native macOS SwiftUI app (`PageForge.xcodeproj`)
- Legacy: Python TUI/CLI under `legacy/python-tui-cli/` (reference only)
- Main window: one files-first document queue with multi-file intake
- Primary flow: add files → prepare sequentially → save or send
- Settings: separate native Settings window

The former Readiness, Convert, Batch, Send, Metadata, Settings, and Logs
destinations are not peer navigation surfaces. Their necessary capabilities are
either part of the main workflow, available contextually from a document, or
contained in Settings.

## Open in Xcode

1. Open `PageForge.xcodeproj`
2. Select the `PageForge` scheme
3. Run on My Mac

## Environment overrides

Optional Calibre tool overrides:

- `EBOOK_CONVERT_PATH`
- `EBOOK_META_PATH`
- `EBOOK_POLISH_PATH`

## Validation

Use `specs/002-simplify-document-workflow/quickstart.md` after local build/run is
allowed. The earlier migration guide in
`specs/001-desktop-app-migration/quickstart.md` remains historical context.

## Parity

See `legacy/notes/behavior-parity.md`. Parity is capability-oriented; it does not
require restoring the legacy mode-based navigation or folder-first workflows.
