#!/bin/bash

set -euo pipefail

INSTALLER="scripts/install.sh"

bash -n "$INSTALLER"
rg -q 'APP_BUNDLE_NAME="BookSender\.app"' "$INSTALLER"
rg -q 'BUNDLE_IDENTIFIER="com\.rckbrcls\.BookSender"' "$INSTALLER"
rg -q 'ASSET_PREFIX="BookSender-macos-universal-v"' "$INSTALLER"
rg -q 'codesign --verify --deep --strict "\$APP_PATH"' "$INSTALLER"
rg -q 'ACTUAL_BUNDLE_IDENTIFIER' "$INSTALLER"
rg -q 'mktemp -d' "$INSTALLER"
rg -q 'trap cleanup EXIT' "$INSTALLER"

if rg -qi 'PageForge|Raycast|Calibre|Electron|Tauri' "$INSTALLER"; then
  echo "Installer references a forbidden legacy product or runtime."
  exit 1
fi

if [ -n "${ZIP_PATH:-}" ]; then
  if [ ! -f "$ZIP_PATH" ]; then
    echo "ZIP_PATH does not reference a release archive."
    exit 1
  fi
  ZIP_ENTRIES=$(zipinfo -1 "$ZIP_PATH")
  if [ -z "$ZIP_ENTRIES" ]; then
    echo "Release archive is empty."
    exit 1
  fi
  if printf "%s\n" "$ZIP_ENTRIES" | rg -v '^BookSender\.app/'; then
    echo "Release archive contains files outside BookSender.app."
    exit 1
  fi
  if printf "%s\n" "$ZIP_ENTRIES" \
    | rg -qi '(^|/)(Fixtures|Preview|BookSenderTests|BookSenderUITests|.*\.xctest)(/|$)'; then
    echo "Release archive contains test or preview material."
    exit 1
  fi
fi

echo "Installer contract passed."
