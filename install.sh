#!/bin/sh
set -eu

REPO_PACKAGE="page-forge @ git+https://github.com/rckbrcls/page-forge.git"
UV_INSTALL_URL="https://astral.sh/uv/install.sh"

if [ "$(uname -s)" != "Darwin" ]; then
  cat <<EOF
page-forge is a macOS-only app.

It depends on Homebrew, Calibre macOS app paths, and macOS Keychain.

EOF
  exit 1
fi

if ! command -v uv >/dev/null 2>&1; then
  cat <<EOF
page-forge is a macOS-only app and requires uv before it can be installed.

Install uv with:

  curl -LsSf ${UV_INSTALL_URL} | sh

Then run this installer again:

  curl -fsSL https://raw.githubusercontent.com/rckbrcls/page-forge/main/install.sh | sh

EOF
  exit 1
fi

echo "Installing page-forge globally with uv on macOS..."
uv tool install --force "${REPO_PACKAGE}"
APP_PATH="$(uv tool dir --bin)/page-forge"

echo
echo "page-forge installed."
echo "App path: ${APP_PATH}"
echo
echo "Checking Calibre setup..."
"${APP_PATH}" setup || true

cat <<EOF

Next steps:

  "${APP_PATH}" setup --install
  "${APP_PATH}" configure
  "${APP_PATH}" update
  "${APP_PATH}"

EOF
