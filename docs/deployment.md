# Book Sender Distribution

Book Sender for macOS is distributed through GitHub Releases, Sparkle, GitHub
Pages, and the `rckbrcls.com` proxy.

## Channel

| Item | Value |
| --- | --- |
| Repository | `rckbrcls/page-forge` |
| Branch | `main` |
| Project | `BookSender.xcodeproj` |
| Scheme | `BookSender` |
| Product | `BookSender.app` |
| Bundle identifier | `com.rckbrcls.BookSender` |
| Release asset | `BookSender-macos-universal-vX.Y.Z.zip` |
| Appcast source | `appcast.xml` |
| Pages appcast | `https://rckbrcls.github.io/page-forge/book-sender/appcast.xml` |
| Canonical appcast | `https://rckbrcls.com/api/book-sender/appcast.xml` |
| Installer | `https://rckbrcls.com/api/book-sender/install` |
| Signing identity | `Book Sender Release Signing` |
| Public certificate | `scripts/signing/BookSenderReleaseSigning.cer` |
| Certificate SHA-1 | `51F0C83093408095C09F3CF5359EB7C83B7F6B38` |
| GitHub secrets | `BOOKSENDER_CODESIGN_P12_BASE64`, `BOOKSENDER_CODESIGN_P12_PASSWORD`, `SPARKLE_EDDSA_PRIVATE_KEY` |

## Release flow

```text
GitHub Actions
-> approved unit and UI suites
-> installer and appcast contract suites
-> universal Release build
-> pinned self-signed release signing
-> signed-app launch smoke test
-> BookSender-macos-universal-vX.Y.Z.zip
-> Sparkle EdDSA signature
-> appcast.xml commit
-> GitHub Release at the build source SHA
-> GitHub Pages
-> rckbrcls.com proxy
```

Run the `Release` workflow manually with an unused `X.Y.Z` version. The workflow
rejects an existing tag or release instead of replacing published history. Its
build number is the GitHub Actions run number.

The workflow signs Sparkle's nested update components from the inside out and
then signs the main app with the expanded App Sandbox entitlements and the
explicit designated requirement anchored to the pinned certificate. Missing
secrets, an invalid PKCS#12, certificate drift, ad-hoc signing, a changed
requirement, or an invalid nested signature blocks the release before packaging.
The release ZIP contains only `BookSender.app`.

The pinned self-signed certificate has no Apple Team ID. The main executable
therefore retains the hardened runtime with only
`com.apple.security.cs.disable-library-validation` enabled so that the pinned
Sparkle framework can load. Nested Sparkle executables remain signed and checked
against the same certificate. After signing, the workflow runs the executable
for five seconds and blocks packaging if dyld rejects a framework or the process
exits early.

The private key is stored only in the local login Keychain, the encrypted
PKCS#12 backup, and GitHub Actions secrets. Only the public DER certificate is
versioned. The one-time bootstrap command is:

```bash
scripts/signing/bootstrap_release_identity.sh \
  --backup-directory /absolute/private/backup/directory
```

Do not regenerate or rotate the identity during a normal release. Rotation
requires explicit authorization, a migration plan, and notice that users may
need to enter their SMTP password once.

To verify the encrypted backup and requirement without building or opening the
app, run:

```bash
scripts/tests/local_signing_smoke_test.sh \
  --p12 /absolute/private/backup/BookSenderReleaseSigning.p12
```

The test imports into an ephemeral Keychain, signs only a temporary system-binary
copy, verifies the pinned requirement, and removes the temporary material.

## Install

Review the installer, then run:

```bash
curl -fsSL https://rckbrcls.com/api/book-sender/install | bash
```

Install a specific release:

```bash
curl -fsSL https://rckbrcls.com/api/book-sender/install | bash -s -- --version 0.2.0
```

The installer accepts only the Book Sender universal ZIP, validates
`BookSender.app`, `com.rckbrcls.BookSender`, the requested version when present,
the pinned certificate, exact designated requirement, and nested signatures
before replacing an existing Book Sender install.

## Security boundary

Update archives are authenticated with Sparkle EdDSA and served over HTTPS.
The app remains sandboxed and grants Sparkle only the installer-service
mach-lookup exception required for self-updates.

The corrected release workflow uses a stable self-signed identity and does not
notarize the app. This continuity lets the traditional Keychain recognize
normally signed corrected updates, but it is not Developer ID and does not
provide normal Gatekeeper trust. The installer removes the quarantine attribute
after validating the pinned identity. Sparkle EdDSA remains a separate mandatory
archive-authentication boundary.

## Release verification

- Confirm the workflow `headSha`, tag target, and release target are identical.
- Confirm the ZIP contains both `arm64` and `x86_64`.
- Confirm nested and main app code signatures pass strict verification.
- Confirm the main app retains hardened runtime, has no Team ID, and carries
  only the required library-validation runtime exception.
- Confirm the certificate fingerprint and exact main-app designated requirement
  match `scripts/signing/release-signing-policy.sh`.
- Confirm the signed-app launch smoke test survives its bounded five-second
  gate before packaging.
- Confirm the appcast reports the expected short version, build, URL, size, and
  EdDSA signature.
- Confirm the Pages appcast and canonical proxy return the same item.
- Confirm the installer endpoint references only Book Sender.
- Verify installation and launch on a clean supported Mac separately.
- Verify a real Sparkle `N -> N+1` update when the next release exists.
- Verify the SMTP credential remains readable across that same-identity update.

Compilation in GitHub Actions does not prove local tests, authenticated SMTP,
clean-account installation, or an end-to-end update. Publication is blocked
unless the automated unit, UI, installer, and appcast contract suites pass;
authenticated provider delivery and clean-account acceptance remain separate
manual gates.
