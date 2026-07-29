# Final Absence Scan

**Date**: 2026-07-28

## Confirmed statically

- Exactly one `.xcodeproj` directory exists: `BookSender.xcodeproj`.
- Production source is confined to `BookSender/**/*.swift`.
- No Node package manifest, lockfile, TypeScript/JavaScript source, Raycast
  declaration, Python application runtime, PageForge project, historical
  implementation directory, generated dependency directory, or obsolete
  PageForge appcast/release script remains in the working tree.
- No `xcuserdata`, `.DS_Store`, `dist`, `.raycast`, `coverage`, or legacy asset
  directory remains outside Git internals.
- Production and test scans contain no `@raycast`, `child_process`, `Process(`,
  `/usr/bin/zip`, `/usr/bin/unzip`, Calibre integration, or installed EPUBCheck
  invocation. Sparkle imports are confined to app composition, and the Python
  appcast updater is confined to GitHub Actions.
- `BookSender.xcodeproj/project.pbxproj` and
  `BookSender/BookSender.entitlements` pass property-list linting.
- The shared scheme is well-formed XML.
- All current Swift source and test files pass frontend syntax parsing.
- `Package.resolved` contains the five intended direct packages and their
  source-only transitive package pins.

## Not proven

- Swift type checking, package compilation, test execution, and runtime behavior
- Fixture parity and byte-for-byte original preservation
- SMTP protocol behavior and authenticated delivery
- Archive contents, code signing, sandbox behavior at runtime, Sparkle update
  installation, clean-account installation, or public artifact integrity

These require the separately authorized build, test, manual, and distribution
gates.
