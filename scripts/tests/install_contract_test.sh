#!/bin/bash

set -euo pipefail

INSTALLER="scripts/install.sh"

bash -n "$INSTALLER"
grep -Eq 'APP_BUNDLE_NAME="BookSender\.app"' "$INSTALLER"
grep -Eq 'BUNDLE_IDENTIFIER="com\.rckbrcls\.BookSender"' "$INSTALLER"
grep -Eq 'SIGNING_CERTIFICATE_SHA1="[A-F0-9]{40}"' "$INSTALLER"
grep -Fq 'PINNED_DESIGNATED_REQUIREMENT=' "$INSTALLER"
grep -Eq 'ASSET_PREFIX="BookSender-macos-universal-v"' "$INSTALLER"
grep -Fq 'SIGNING_CERTIFICATE_URL=' "$INSTALLER"
grep -Fq 'asset.get("digest", "")' "$INSTALLER"
grep -Fq 'shasum -a 256 "$ZIP_PATH"' "$INSTALLER"
grep -Fq 'security default-keychain -d user' "$INSTALLER"
grep -Fq 'security find-certificate -a -Z "$USER_KEYCHAIN"' "$INSTALLER"
grep -Fq 'security import "$PINNED_CERTIFICATE_PATH"' "$INSTALLER"
grep -Fq -- '-t cert >/dev/null' "$INSTALLER"
grep -Fq 'Only the public code-signing certificate is stored' "$INSTALLER"
grep -Fq 'BOOKSENDER_INSTALLER_ARCHIVE_PATH' "$INSTALLER"
grep -Fq 'BOOKSENDER_INSTALLER_CERTIFICATE_PATH' "$INSTALLER"
grep -Fq 'BOOKSENDER_INSTALLER_KEYCHAIN_PATH' "$INSTALLER"
grep -Fq 'BOOKSENDER_INSTALLER_TARGET_DIRECTORY' "$INSTALLER"
grep -Fq 'BOOKSENDER_INSTALLER_ACCEPT_CERTIFICATE_REGISTRATION' "$INSTALLER"
grep -Fq 'Certificate registration was cancelled.' "$INSTALLER"
grep -Eq 'codesign --verify --deep --strict --verbose=2 "\$APP_PATH"' "$INSTALLER"
grep -Fq 'codesign --verify -R="$DESIGNATED_REQUIREMENT" "$APP_PATH"' "$INSTALLER"
grep -Fq 'Signature=adhoc' "$INSTALLER"
grep -Fq 'ACTUAL_REQUIREMENT' "$INSTALLER"
grep -Fq 'TeamIdentifier=not set' "$INSTALLER"
grep -Fq 'com.apple.security.cs.disable-library-validation' "$INSTALLER"
grep -Fq 'codesign -d --entitlements - --xml "$APP_PATH"' "$INSTALLER"
grep -Fq 'A nested app component has a forbidden library validation exception.' "$INSTALLER"
grep -Fq 'verify_pinned_component' "$INSTALLER"
grep -Eq 'ACTUAL_BUNDLE_IDENTIFIER' "$INSTALLER"
grep -Eq 'mktemp -d' "$INSTALLER"
grep -Eq 'trap cleanup EXIT' "$INSTALLER"

if grep -Fq 'add-trusted-cert' "$INSTALLER"; then
  echo "Installer must not add an Always Trust override."
  exit 1
fi
if grep -Eq 'security import .*-(A|w)( |$)' "$INSTALLER"; then
  echo "Installer must not import private-key access controls."
  exit 1
fi

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
  TEMP_KEYCHAIN="$TEMP_DIRECTORY/Consumer.keychain-db"
  TEMP_APPLICATIONS="$TEMP_DIRECTORY/Applications"
  TEMP_KEYCHAIN_PASSWORD=$(openssl rand -base64 32 | tr -d '\n')
  ORIGINAL_USER_KEYCHAINS=()
  while IFS= read -r keychain_entry; do
    keychain_entry="${keychain_entry#*\"}"
    keychain_entry="${keychain_entry%\"*}"
    if [ -n "$keychain_entry" ]; then
      ORIGINAL_USER_KEYCHAINS+=("$keychain_entry")
    fi
  done < <(security list-keychains -d user)
  cleanup_archive() {
    if [ "${#ORIGINAL_USER_KEYCHAINS[@]}" -gt 0 ]; then
      security list-keychains \
        -d user \
        -s "${ORIGINAL_USER_KEYCHAINS[@]}" >/dev/null 2>&1 || true
    fi
    security delete-keychain "$TEMP_KEYCHAIN" >/dev/null 2>&1 || true
    rm -rf "$TEMP_DIRECTORY"
  }
  trap cleanup_archive EXIT
  source scripts/signing/release-signing-policy.sh
  mkdir -p "$TEMP_APPLICATIONS"
  security create-keychain -p "$TEMP_KEYCHAIN_PASSWORD" "$TEMP_KEYCHAIN"
  security set-keychain-settings -lut 21600 "$TEMP_KEYCHAIN"
  security unlock-keychain -p "$TEMP_KEYCHAIN_PASSWORD" "$TEMP_KEYCHAIN"
  security list-keychains \
    -d user \
    -s "$TEMP_KEYCHAIN" "${ORIGINAL_USER_KEYCHAINS[@]}"

  if security find-certificate -a -Z "$TEMP_KEYCHAIN" 2>/dev/null \
    | grep -F "SHA-1 hash: $SIGNING_CERTIFICATE_SHA1" >/dev/null; then
    echo "Temporary consumer Keychain unexpectedly contains the pinned certificate."
    exit 1
  fi

  export BOOKSENDER_INSTALLER_ARCHIVE_PATH="$ZIP_PATH"
  export BOOKSENDER_INSTALLER_CERTIFICATE_PATH="$PWD/$SIGNING_CERTIFICATE_PATH"
  export BOOKSENDER_INSTALLER_KEYCHAIN_PATH="$TEMP_KEYCHAIN"
  export BOOKSENDER_INSTALLER_TARGET_DIRECTORY="$TEMP_APPLICATIONS"
  export BOOKSENDER_INSTALLER_ACCEPT_CERTIFICATE_REGISTRATION=1
  bash "$INSTALLER"

  if ! security find-certificate -a -Z "$TEMP_KEYCHAIN" 2>/dev/null \
    | grep -F "SHA-1 hash: $SIGNING_CERTIFICATE_SHA1" >/dev/null; then
    echo "Installer did not register the pinned public certificate."
    exit 1
  fi
  if security find-identity -p codesigning "$TEMP_KEYCHAIN" \
    | grep -Fq "$SIGNING_CERTIFICATE_SHA1"; then
    echo "Installer imported a private signing identity."
    exit 1
  fi

  REGISTERED_CERTIFICATE_COUNT=$(security find-certificate \
    -a \
    -Z \
    "$TEMP_KEYCHAIN" 2>/dev/null \
    | grep -Fc "SHA-1 hash: $SIGNING_CERTIFICATE_SHA1")
  bash "$INSTALLER"
  REPEATED_CERTIFICATE_COUNT=$(security find-certificate \
    -a \
    -Z \
    "$TEMP_KEYCHAIN" 2>/dev/null \
    | grep -Fc "SHA-1 hash: $SIGNING_CERTIFICATE_SHA1")
  if [ "$REPEATED_CERTIFICATE_COUNT" -ne "$REGISTERED_CERTIFICATE_COUNT" ]; then
    echo "Repeated installation duplicated the pinned public certificate."
    exit 1
  fi

  APP_PATH="$TEMP_APPLICATIONS/BookSender.app"
  EVALUATED_REQUIREMENT="anchor H\"$SIGNING_CERTIFICATE_SHA1\" and identifier \"$SIGNING_BUNDLE_IDENTIFIER\""
  codesign --verify --deep --strict --verbose=2 "$APP_PATH"
  codesign --verify -R="$EVALUATED_REQUIREMENT" "$APP_PATH"
  ACTUAL_REQUIREMENT=$(codesign -d -r- "$APP_PATH" 2>&1 \
    | sed -n 's/^designated => //p')
  if [ "$ACTUAL_REQUIREMENT" != "$SIGNING_DESIGNATED_REQUIREMENT" ]; then
    echo "Release archive has an unexpected designated requirement."
    exit 1
  fi

  SIGNING_DETAILS=$(codesign -dvvv "$APP_PATH" 2>&1)
  if ! printf "%s\n" "$SIGNING_DETAILS" \
    | grep -Eq '^CodeDirectory .*flags=.*\(.*runtime.*\)'; then
    echo "Release archive does not use the required hardened runtime."
    exit 1
  fi
  if ! printf "%s\n" "$SIGNING_DETAILS" \
    | grep -Fqx "TeamIdentifier=not set"; then
    echo "Release archive has an unexpected Team ID contract."
    exit 1
  fi

  SIGNED_ENTITLEMENTS="$TEMP_DIRECTORY/signed-entitlements.plist"
  codesign -d --entitlements - --xml "$APP_PATH" > "$SIGNED_ENTITLEMENTS"
  if [ "$(/usr/libexec/PlistBuddy \
    -c "Print :com.apple.security.cs.disable-library-validation" \
    "$SIGNED_ENTITLEMENTS")" != "true" ]; then
    echo "Release archive is missing its required library validation exception."
    exit 1
  fi

  SPARKLE_FRAMEWORK="$APP_PATH/Contents/Frameworks/Sparkle.framework"
  for component in \
    "$SPARKLE_FRAMEWORK/Versions/B/XPCServices/Installer.xpc" \
    "$SPARKLE_FRAMEWORK/Versions/B/XPCServices/Downloader.xpc" \
    "$SPARKLE_FRAMEWORK/Versions/B/Autoupdate" \
    "$SPARKLE_FRAMEWORK/Versions/B/Updater.app" \
    "$SPARKLE_FRAMEWORK"; do
    if [ -e "$component" ] \
      && codesign -d --entitlements - --xml "$component" 2>/dev/null \
        | grep -Fq "com.apple.security.cs.disable-library-validation"; then
      echo "A nested release component has a forbidden library validation exception."
      exit 1
    fi
  done
fi

echo "Installer contract passed."
