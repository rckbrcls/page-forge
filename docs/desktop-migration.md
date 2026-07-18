# Desktop Migration Notes

## Product surface

- Primary: native macOS SwiftUI app (`PageForge.xcodeproj`)
- Legacy: Python TUI/CLI under `legacy/python-tui-cli/` (reference only)

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

Use `specs/001-desktop-app-migration/quickstart.md` slices A–G after local build/run is allowed.

## Parity

See `legacy/notes/behavior-parity.md`.
