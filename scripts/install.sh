#!/bin/bash

set -euo pipefail

APP_DISPLAY_NAME="Book Sender"
APP_BUNDLE_NAME="BookSender.app"
BUNDLE_IDENTIFIER="com.rckbrcls.BookSender"
ASSET_PREFIX="BookSender-macos-universal-v"
REPO="rckbrcls/page-forge"
GITHUB_API="https://api.github.com/repos/${REPO}/releases"

usage() {
  cat << EOF
Usage: install.sh [--version <version>]

Options:
  --version <version>  Install a specific version (for example: 0.2.0)
  -h, --help           Show this help
EOF
}

VERSION=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --version."
        exit 1
      fi
      VERSION="${2#v}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [ "$(uname -s)" != "Darwin" ]; then
  echo "This installer only supports macOS."
  exit 1
fi

if [ -n "$VERSION" ]; then
  RELEASE_URL="${GITHUB_API}/tags/v${VERSION}"
else
  RELEASE_URL="${GITHUB_API}/latest"
fi

TMP_DIR=$(mktemp -d)
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

RELEASE_JSON=$(curl -fsSL \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "$RELEASE_URL")

ASSET_JSON=$(printf "%s" "$RELEASE_JSON" | python3 -c '
import json
import sys

prefix = sys.argv[1]
data = json.load(sys.stdin)
matches = [
    asset
    for asset in data.get("assets", [])
    if asset.get("name", "").startswith(prefix)
    and asset.get("name", "").endswith(".zip")
]

if len(matches) != 1:
    print(
        f"ERROR: Expected one Book Sender universal ZIP, found {len(matches)}.",
        file=sys.stderr,
    )
    sys.exit(1)

asset = matches[0]
print(json.dumps({
    "name": asset["name"],
    "url": asset["browser_download_url"],
    "size": asset["size"],
}))
' "$ASSET_PREFIX")

ASSET_NAME=$(printf "%s" "$ASSET_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["name"])')
ASSET_URL=$(printf "%s" "$ASSET_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["url"])')
ASSET_SIZE=$(printf "%s" "$ASSET_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["size"])')
ZIP_PATH="$TMP_DIR/$ASSET_NAME"

echo "Downloading $ASSET_NAME..."
curl -fL "$ASSET_URL" -o "$ZIP_PATH"

DOWNLOADED_SIZE=$(stat -f%z "$ZIP_PATH")
if [ "$DOWNLOADED_SIZE" -ne "$ASSET_SIZE" ]; then
  echo "Downloaded file size mismatch (expected $ASSET_SIZE, got $DOWNLOADED_SIZE)."
  exit 1
fi

EXTRACT_DIR="$TMP_DIR/extract"
mkdir -p "$EXTRACT_DIR"
ditto -x -k "$ZIP_PATH" "$EXTRACT_DIR"

APP_PATH="$EXTRACT_DIR/$APP_BUNDLE_NAME"
if [ ! -d "$APP_PATH" ]; then
  echo "$APP_BUNDLE_NAME was not found in the release archive."
  exit 1
fi

INFO_PLIST="$APP_PATH/Contents/Info.plist"
ACTUAL_BUNDLE_IDENTIFIER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$INFO_PLIST")
if [ "$ACTUAL_BUNDLE_IDENTIFIER" != "$BUNDLE_IDENTIFIER" ]; then
  echo "Unexpected bundle identifier: $ACTUAL_BUNDLE_IDENTIFIER"
  exit 1
fi

if [ -n "$VERSION" ]; then
  ACTUAL_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST")
  if [ "$ACTUAL_VERSION" != "$VERSION" ]; then
    echo "Unexpected app version: $ACTUAL_VERSION"
    exit 1
  fi
fi

codesign --verify --deep --strict "$APP_PATH"

TARGET_DIR="/Applications"
if [ ! -w "$TARGET_DIR" ]; then
  TARGET_DIR="$HOME/Applications"
  mkdir -p "$TARGET_DIR"
fi

TARGET_PATH="$TARGET_DIR/$APP_BUNDLE_NAME"
if [ -d "$TARGET_PATH" ]; then
  echo "Removing existing $TARGET_PATH"
  rm -rf "$TARGET_PATH"
fi

echo "Installing to $TARGET_DIR"
ditto "$APP_PATH" "$TARGET_PATH"

if command -v xattr >/dev/null 2>&1; then
  xattr -dr com.apple.quarantine "$TARGET_PATH" 2>/dev/null || true
fi

echo "$APP_DISPLAY_NAME installed at $TARGET_PATH"
if [ "$TARGET_DIR" != "/Applications" ]; then
  echo "Installed to $TARGET_DIR because /Applications is not writable."
fi

echo "Open with: open \"$TARGET_PATH\""
