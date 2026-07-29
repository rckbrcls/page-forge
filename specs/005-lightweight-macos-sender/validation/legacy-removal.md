# Legacy Removal Record

**Date**: 2026-07-28

The user explicitly authorized immediate removal of all legacy surfaces before
the originally planned build, test, and manual-acceptance gates.

## Removed

- Raycast and Node production source, tests, manifests, locks, tool
  configuration, declaration files, assets, and generated dependencies.
- The previous PageForge application, tests, Xcode project, icons, signing
  references, Calibre/conversion code, and Sparkle package resolution.
- Python/TUI history, installer and appcast scripts, old release workflow, and
  appcast inputs.
- Historical product specifications 001 through 004.
- Generated output, Xcode user data, `.DS_Store` files, duplicate generated
  images, and obsolete documentation imagery.

## Preserved

- `BookSender.xcodeproj`
- `BookSender/`
- `BookSenderTests/`
- `BookSenderUITests/`
- `specs/005-lightweight-macos-sender/`
- Spec Kit governance, templates, workflows, and agent skills
- Current product documentation

## Recovery

Tracked legacy files remain recoverable from Git history until repository
history is rewritten. Untracked legacy edits and generated artifacts removed
during this operation are not recoverable from Git.

## Validation boundary

This record proves repository removal only. It does not prove Swift compilation,
test success, runtime behavior, SMTP delivery, signing, notarization, or release.
