# Contract: Legacy Migration and Cutover

## Rule

Legacy deletion is a final migration task, not the first implementation task.
Every behavior used as a reference must first exist in the new native target with
fixture or acceptance evidence. No obsolete product remains after cutover.

## Preserve as behavioral references until ported

- TypeScript audit, repair, typed models, archive/XML/filesystem/SMTP adapters,
  tests, and malicious/valid EPUB fixtures.
- Existing Swift design tokens/assets, Keychain storage patterns, configuration,
  shared intake, and collision-safe temporary-file patterns.

These patterns are reviewed and reimplemented; files containing Calibre,
conversion, subprocess ZIP, extra screens, or incorrect SMTP security are not
copied wholesale.

## Cutover gate

Before deletion:

- `BookSender.xcodeproj` has one app, unit-test, and UI-test target.
- The two-screen, shortcut, intake, pipeline, SMTP, credential, cancellation,
  safety, accessibility, and original-preservation contracts pass independently.
- Release configuration names and signs Book Sender.
- All fixtures required by the native tests have been translated.
- A review confirms no remaining behavior depends on an old runtime.

## Delete after the gate

- `src/`, old TypeScript `tests/`, Node/Raycast manifests, locks, configs,
  generated output, and Raycast assets.
- `PageForge/`, `PageForgeTests/`, and `PageForge.xcodeproj`.
- `legacy/`.
- Calibre, conversion, MOBI/AZW metadata, subprocess ZIP/EPUB, obsolete
  PageForge Sparkle/appcast/installer inputs, and old release assets.
- `node_modules/`, `dist/`, `.raycast/`, `coverage/`, Xcode user data,
  `.DS_Store`, and duplicate generated images.

Unrelated user or agent worktree changes are never restored or rewritten by the
migration.

## Final absence criteria

- Exactly one native macOS application product named Book Sender plus tests.
- Production implementation only in `BookSender/**/*.swift`.
- No TypeScript/JavaScript runtime, Raycast, Calibre, EPUBCheck executable,
  processing helper, Python or Java runtime, Docker, conversion, or `Process`
  call.
- No `/usr/bin/zip`, `/usr/bin/unzip`, `child_process`, executable download,
  or stale PageForge target/reference. Sparkle is limited to the Book Sender
  update path.
- Exactly two primary screens and one shared intake path.
- Release archive contains only the ad-hoc signed app; appcast and installer
  remain separate distribution files.
