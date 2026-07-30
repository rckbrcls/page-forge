#!/bin/bash

set -euo pipefail

source scripts/signing/release-signing-policy.sh

P12_PATH=""
PASSWORD_SERVICE="Book Sender Release Signing PKCS12 Password"

usage() {
  echo "Usage: local_signing_smoke_test.sh --p12 <absolute-path>"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --p12)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --p12."
        exit 1
      fi
      P12_PATH="$2"
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

if [[ "$P12_PATH" != /* ]] || [ ! -f "$P12_PATH" ]; then
  echo "The PKCS#12 backup path must be an existing absolute path."
  exit 1
fi

TEMP_DIRECTORY=$(mktemp -d)
TEMP_KEYCHAIN="$TEMP_DIRECTORY/release-signing.keychain-db"
cleanup() {
  security delete-keychain "$TEMP_KEYCHAIN" >/dev/null 2>&1 || true
  rm -f "$TEMP_KEYCHAIN"
  rm -f "$TEMP_DIRECTORY/signing-probe"
  rm -f "$TEMP_DIRECTORY/imported-certificate.pem"
  rm -f "$TEMP_DIRECTORY/imported-certificate.cer"
  rmdir "$TEMP_DIRECTORY" 2>/dev/null || true
}
trap cleanup EXIT

KEYCHAIN_PASSWORD=$(openssl rand -base64 32 | tr -d '\n')
P12_PASSWORD=$(security find-generic-password \
  -s "$PASSWORD_SERVICE" \
  -w \
  "$HOME/Library/Keychains/login.keychain-db")

security create-keychain -p "$KEYCHAIN_PASSWORD" "$TEMP_KEYCHAIN"
security set-keychain-settings -lut 900 "$TEMP_KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$TEMP_KEYCHAIN"
security import "$P12_PATH" \
  -k "$TEMP_KEYCHAIN" \
  -P "$P12_PASSWORD" \
  -T /usr/bin/codesign \
  -T /usr/bin/security
security set-key-partition-list \
  -S apple-tool:,apple:,codesign: \
  -s \
  -k "$KEYCHAIN_PASSWORD" \
  "$TEMP_KEYCHAIN" >/dev/null

security find-certificate \
  -c "$SIGNING_IDENTITY_NAME" \
  -p \
  "$TEMP_KEYCHAIN" > "$TEMP_DIRECTORY/imported-certificate.pem"
openssl x509 \
  -in "$TEMP_DIRECTORY/imported-certificate.pem" \
  -outform DER \
  -out "$TEMP_DIRECTORY/imported-certificate.cer"
cmp -s \
  "$SIGNING_CERTIFICATE_PATH" \
  "$TEMP_DIRECTORY/imported-certificate.cer"

IMPORTED_IDENTITY_SHA1=$(security find-identity \
  -p codesigning \
  "$TEMP_KEYCHAIN" \
  | grep -F "\"$SIGNING_IDENTITY_NAME\"" \
  | awk 'NR == 1 {print $2}')
if [ "$IMPORTED_IDENTITY_SHA1" != "$SIGNING_CERTIFICATE_SHA1" ]; then
  echo "The imported signing identity has an unexpected fingerprint."
  exit 1
fi

PROBE="$TEMP_DIRECTORY/signing-probe"
cp /usr/bin/true "$PROBE"
chmod 755 "$PROBE"

codesign \
  --force \
  --keychain "$TEMP_KEYCHAIN" \
  --sign "$IMPORTED_IDENTITY_SHA1" \
  --identifier "$SIGNING_BUNDLE_IDENTIFIER" \
  --timestamp=none \
  -r="designated => anchor H\"$SIGNING_CERTIFICATE_SHA1\" and identifier \"$SIGNING_BUNDLE_IDENTIFIER\"" \
  "$PROBE"

codesign --verify --strict --verbose=2 "$PROBE"
codesign \
  --verify \
  -R="anchor H\"$SIGNING_CERTIFICATE_SHA1\" and identifier \"$SIGNING_BUNDLE_IDENTIFIER\"" \
  "$PROBE"

EXPECTED_REQUIREMENT="$SIGNING_DESIGNATED_REQUIREMENT"
ACTUAL_REQUIREMENT=$(codesign -d -r- "$PROBE" 2>&1 \
  | sed -n 's/^designated => //p')
if [ "$ACTUAL_REQUIREMENT" != "$EXPECTED_REQUIREMENT" ]; then
  echo "The signing probe has an unexpected designated requirement."
  echo "Expected: $EXPECTED_REQUIREMENT"
  echo "Actual: $ACTUAL_REQUIREMENT"
  exit 1
fi

if codesign -dvvv "$PROBE" 2>&1 | grep -Fq "Signature=adhoc"; then
  echo "The signing probe unexpectedly uses an ad-hoc signature."
  exit 1
fi

echo "Local release signing smoke test passed."
