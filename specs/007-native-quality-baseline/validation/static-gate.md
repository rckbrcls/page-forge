# Static Gate: Credential and Release Continuity

**Date**: 2026-07-30

## Passed

- `git diff --check`
- Shell syntax for installer, bootstrap, policy, and contract scripts
- `scripts/tests/signing_contract_test.sh`
- `scripts/tests/install_contract_test.sh`
- `scripts/tests/appcast_contract_test.py`
- Property-list syntax for the Xcode project, Info.plist, and entitlements
- YAML parsing for `.github/workflows/release.yml`
- Production credential-query scan excluding Data Protection, accessibility,
  and synchronization attributes
- Release-workflow scan excluding `--sign -`
- Public DER certificate fingerprint, Code Signing extended usage, and validity
- Isolated signing smoke test using the encrypted PKCS#12, an ephemeral Keychain,
  a temporary copy of `/usr/bin/true`, strict signature verification, and the
  canonical designated requirement
- GitHub repository-secret name check for
  `BOOKSENDER_CODESIGN_P12_BASE64` and
  `BOOKSENDER_CODESIGN_P12_PASSWORD`; secret values were not read

## Pinned public evidence

- Identity: `Book Sender Release Signing`
- Certificate SHA-1:
  `51F0C83093408095C09F3CF5359EB7C83B7F6B38`
- Validity: 2026-07-30 through 2036-07-27
- Bundle identifier: `com.rckbrcls.BookSender`
- Canonical designated requirement:
  `certificate root = H"51f0c83093408095c09f3cf5359eb7c83b7f6b38" and identifier "com.rckbrcls.BookSender"`
- Encrypted backup permissions: owner read/write only
- Repository signing directory contains the bootstrap script, public policy, and
  public DER certificate only; no PKCS#12 or private key

## Not executed

- Xcode build
- Swift unit or UI tests
- Book Sender launch or runtime inspection
- First corrected-version credential save and relaunch
- Signed Book Sender archive creation
- Same-identity N-to-N+1 replacement
- Sparkle update
- Provider SMTP delivery
- GitHub Release, Pages deployment, or public artifact verification

These remain distinct gates and are not implied by the passed source and
isolated-signing checks.
