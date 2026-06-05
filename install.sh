#!/bin/sh
set -eu

REPO_URL="git+https://github.com/rckbrcls/convert-books.git"
UV_INSTALL_URL="https://astral.sh/uv/install.sh"

if ! command -v uv >/dev/null 2>&1; then
  cat <<EOF
convert-books requires uv before the global CLI can be installed.

Install uv with:

  curl -LsSf ${UV_INSTALL_URL} | sh

Then run this installer again:

  curl -fsSL https://raw.githubusercontent.com/rckbrcls/convert-books/main/install.sh | sh

EOF
  exit 1
fi

echo "Installing convert-books globally with uv..."
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
  convert-books

EOF
