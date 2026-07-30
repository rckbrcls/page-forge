#!/bin/bash

set -euo pipefail

INSTALLER="scripts/install.sh"

bash -n "$INSTALLER"
grep -Eq 'APP_BUNDLE_NAME="BookSender\.app"' "$INSTALLER"
grep -Eq 'BUNDLE_IDENTIFIER="com\.rckbrcls\.BookSender"' "$INSTALLER"
grep -Eq 'SIGNING_CERTIFICATE_SHA1="[A-F0-9]{40}"' "$INSTALLER"
grep -Fq 'PINNED_DESIGNATED_REQUIREMENT=' "$INSTALLER"
grep -Eq 'ASSET_PREFIX="BookSender-macos-universal-v"' "$INSTALLER"
grep -Eq 'codesign --verify --deep --strict --verbose=2 "\$APP_PATH"' "$INSTALLER"
grep -Fq 'codesign --verify -R="$DESIGNATED_REQUIREMENT" "$APP_PATH"' "$INSTALLER"
grep -Fq 'Signature=adhoc' "$INSTALLER"
grep -Fq 'ACTUAL_REQUIREMENT' "$INSTALLER"
grep -Fq 'verify_pinned_component' "$INSTALLER"
grep -Eq 'ACTUAL_BUNDLE_IDENTIFIER' "$INSTALLER"
grep -Eq 'mktemp -d' "$INSTALLER"
grep -Eq 'trap cleanup EXIT' "$INSTALLER"

if grep -Eqi 'PageForge|Raycast|Calibre|Electron|Tauri' "$INSTALLER"; then
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
  if printf "%s\n" "$ZIP_ENTRIES" | grep -Ev '^BookSender\.app/'; then
    echo "Release archive contains files outside BookSender.app."
    exit 1
  fi
  if printf "%s\n" "$ZIP_ENTRIES" \
    | grep -Eqi '(^|/)(Fixtures|Preview|BookSenderTests|BookSenderUITests|.*\.xctest)(/|$)'; then
    echo "Release archive contains test or preview material."
    exit 1
  fi

  TEMP_DIRECTORY=$(mktemp -d)
  cleanup_archive() {
    rm -rf "$TEMP_DIRECTORY"
  }
  trap cleanup_archive EXIT
  ditto -x -k "$ZIP_PATH" "$TEMP_DIRECTORY"
  APP_PATH="$TEMP_DIRECTORY/BookSender.app"
  source scripts/signing/release-signing-policy.sh
  EVALUATED_REQUIREMENT="anchor H\"$SIGNING_CERTIFICATE_SHA1\" and identifier \"$SIGNING_BUNDLE_IDENTIFIER\""
  codesign --verify --deep --strict --verbose=2 "$APP_PATH"
  codesign --verify -R="$EVALUATED_REQUIREMENT" "$APP_PATH"
  ACTUAL_REQUIREMENT=$(codesign -d -r- "$APP_PATH" 2>&1 \
    | sed -n 's/^designated => //p')
  if [ "$ACTUAL_REQUIREMENT" != "$SIGNING_DESIGNATED_REQUIREMENT" ]; then
    echo "Release archive has an unexpected designated requirement."
    exit 1
  fi
fi

echo "Installer contract passed."
