# Release Readiness: Credential and Stable Signing Amendment

**Date**: 2026-07-30

## Current status

The source implementation, public signing policy, local signing identity,
encrypted backup, GitHub secret names, fail-closed workflow, installer pin,
governance, and documentation are present. The amendment is source-complete but
not release-accepted because the project workflow forbids build and app
execution without separate authorization.

| Gate | Status | Evidence |
|---|---|---|
| Constitution 7.0.0 | Passed | `.specify/memory/constitution.md` |
| Traditional Keychain source contract | Passed static review | `BookSender/Adapters/Credentials/KeychainCredentialStore.swift` |
| Keychain and privacy test source | Present, not executed | `BookSenderTests/Adapters/KeychainCredentialStoreTests.swift`, `BookSenderTests/Privacy/PrivacyAuditTests.swift` |
| Public certificate and policy | Passed static and isolated signing checks | `scripts/signing/BookSenderReleaseSigning.cer`, `scripts/signing/release-signing-policy.sh` |
| Encrypted backup | Present outside repository with mode `600` | Local operator evidence only; no secret recorded |
| GitHub signing secrets | Names confirmed | Repository settings; values not read |
| Release workflow | Passed source/YAML contracts | `.github/workflows/release.yml`, `scripts/tests/signing_contract_test.sh` |
| Installer identity pin | Passed source contract | `scripts/install.sh`, `scripts/tests/install_contract_test.sh` |
| Sparkle EdDSA contract | Passed existing appcast contract | `scripts/tests/appcast_contract_test.py` |
| Swift compilation and tests | Pending authorization | Not run |
| First corrected-version credential relaunch | Pending authorization | Not run |
| Signed Book Sender archive | Pending release/build gate | Not produced |
| Same-identity N-to-N+1 credential continuity | Pending two corrected versions | Not run |
| Real Sparkle update | Pending two corrected versions | Not run |
| Provider delivery | Pending separate authorized account gate | Not run |
| Production publication | Pending all required release gates | Not run |

## Release law

Publication must stop for missing or invalid signing secrets, certificate drift,
designated requirement drift, ad-hoc or unsigned distributed code, or invalid
nested signatures. There is no release fallback. Identity rotation remains an
exception requiring Erick's explicit authorization, a migration plan, and
one-time credential re-entry disclosure.

The self-signed identity supplies stable code identity but is not Developer ID,
does not enable Apple notarization, and does not provide normal Gatekeeper trust
for manual installation.
