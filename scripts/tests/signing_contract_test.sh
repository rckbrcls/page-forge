#!/bin/bash

set -euo pipefail

WORKFLOW=".github/workflows/release.yml"
INSTALLER="scripts/install.sh"
POLICY="scripts/signing/release-signing-policy.sh"
CERTIFICATE="scripts/signing/BookSenderReleaseSigning.cer"

bash -n "$INSTALLER"
bash -n "$POLICY"
bash -n scripts/signing/bootstrap_release_identity.sh
bash -n scripts/tests/local_signing_smoke_test.sh
bash -n scripts/tests/signed_app_launch_smoke_test.sh
test -x scripts/tests/signed_app_launch_smoke_test.sh
source "$POLICY"

REQUIREMENT_BINARY=$(mktemp)
cleanup_requirement() {
  rm -f "$REQUIREMENT_BINARY"
}
trap cleanup_requirement EXIT
csreq \
  -r="designated => anchor H\"$SIGNING_CERTIFICATE_SHA1\" and identifier \"$SIGNING_BUNDLE_IDENTIFIER\"" \
  -b "$REQUIREMENT_BINARY"
test -s "$REQUIREMENT_BINARY"

if [ ! -f "$CERTIFICATE" ]; then
  echo "The pinned public release certificate is missing."
  exit 1
fi

ACTUAL_CERTIFICATE_SHA1=$(openssl x509 \
  -inform DER \
  -in "$CERTIFICATE" \
  -noout \
  -fingerprint \
  -sha1 \
  | cut -d= -f2 \
  | tr -d ':')
if [ "$ACTUAL_CERTIFICATE_SHA1" != "$SIGNING_CERTIFICATE_SHA1" ]; then
  echo "The public certificate does not match the pinned fingerprint."
  exit 1
fi

openssl x509 -inform DER -in "$CERTIFICATE" -noout -subject \
  | grep -Fq "CN=Book Sender Release Signing"
openssl x509 -inform DER -in "$CERTIFICATE" -noout -text \
  | grep -Fq "Code Signing"
openssl x509 -inform DER -in "$CERTIFICATE" -checkend 31536000 -noout

grep -Fq 'BOOKSENDER_CODESIGN_P12_BASE64' "$WORKFLOW"
grep -Fq 'BOOKSENDER_CODESIGN_P12_PASSWORD' "$WORKFLOW"
grep -Fq 'source scripts/signing/release-signing-policy.sh' "$WORKFLOW"
grep -Fq 'security create-keychain' "$WORKFLOW"
grep -Fq 'security import "$P12_PATH"' "$WORKFLOW"
grep -Fq 'security list-keychains' "$WORKFLOW"
grep -Fq 'cmp -s "$SIGNING_CERTIFICATE_PATH" "$IMPORTED_CERTIFICATE_DER"' "$WORKFLOW"
grep -Fq 'Signature=adhoc' "$WORKFLOW"
grep -Fq 'ACTUAL_REQUIREMENT' "$WORKFLOW"
grep -Fq 'TeamIdentifier=not set' "$WORKFLOW"
grep -Fq 'com.apple.security.cs.disable-library-validation' "$WORKFLOW"
grep -Fq 'Only the main executable may disable library validation.' "$WORKFLOW"
grep -Fq 'scripts/tests/signed_app_launch_smoke_test.sh' "$WORKFLOW"
grep -Fq 'trap cleanup_signing_material EXIT' "$WORKFLOW"

if [ "$(/usr/libexec/PlistBuddy \
  -c "Print :com.apple.security.cs.disable-library-validation" \
  BookSender/BookSender.entitlements)" != "true" ]; then
  echo "The release library validation exception is missing."
  exit 1
fi

if grep -Fq -- '--sign -' "$WORKFLOW"; then
  echo "The release workflow contains an ad-hoc signing fallback."
  exit 1
fi

INSTALLER_SHA1=$(sed -n \
  's/^SIGNING_CERTIFICATE_SHA1="\([A-F0-9]\{40\}\)"$/\1/p' \
  "$INSTALLER")
if [ "$INSTALLER_SHA1" != "$SIGNING_CERTIFICATE_SHA1" ]; then
  echo "The installer signing pin does not match the release policy."
  exit 1
fi

INSTALLER_REQUIREMENT=$(sed -n \
  "s/^PINNED_DESIGNATED_REQUIREMENT='\\(.*\\)'$/\\1/p" \
  "$INSTALLER")
if [ "$INSTALLER_REQUIREMENT" != "$SIGNING_DESIGNATED_REQUIREMENT" ]; then
  echo "The installer designated requirement does not match the release policy."
  exit 1
fi

echo "Release signing contract passed."
