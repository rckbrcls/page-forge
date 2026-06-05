#!/bin/sh
set -eu

REPO_URL="git+https://github.com/rckbrcls/convert-books.git"
UV_INSTALL_URL="https://astral.sh/uv/install.sh"

if [ "$(uname -s)" != "Darwin" ]; then
  cat <<EOF
convert-books is a macOS-only app.

It depends on Homebrew, Calibre macOS app paths, and macOS Keychain.

EOF
  exit 1
fi

if ! command -v uv >/dev/null 2>&1; then
  cat <<EOF
convert-books is a macOS-only app and requires uv before it can be installed.

Install uv with:

  curl -LsSf ${UV_INSTALL_URL} | sh

Then run this installer again:

  curl -fsSL https://raw.githubusercontent.com/rckbrcls/convert-books/main/install.sh | sh

EOF
  exit 1
fi

echo "Installing convert-books globally with uv on macOS..."
uv tool install --force "${REPO_URL}"

echo
echo "convert-books installed."
echo
echo "Checking Calibre setup..."
convert-books setup || true

cat <<EOF

Next steps:

  convert-books setup --install
  convert-books configure
  convert-books update
  convert-books

EOF
