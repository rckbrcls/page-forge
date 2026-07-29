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
| GitHub secret | `SPARKLE_EDDSA_PRIVATE_KEY` |

## Release flow

```text
GitHub Actions
-> universal Release build
-> sandbox-compatible ad-hoc signing
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
then signs the main app with the expanded App Sandbox entitlements. The release
ZIP contains only `BookSender.app`.

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
and the app's code signature before replacing an existing Book Sender install.

## Security boundary

Update archives are authenticated with Sparkle EdDSA and served over HTTPS.
The app remains sandboxed and grants Sparkle only the installer-service
mach-lookup exception required for self-updates.

The release uses ad-hoc signing and is not notarized by Apple. The installer
removes the quarantine attribute after validation, matching the approved
distribution model. This channel does not provide Developer ID or Gatekeeper
trust.

## Release verification

- Confirm the workflow `headSha`, tag target, and release target are identical.
- Confirm the ZIP contains both `arm64` and `x86_64`.
- Confirm nested and main app code signatures pass strict verification.
- Confirm the appcast reports the expected short version, build, URL, size, and
  EdDSA signature.
- Confirm the Pages appcast and canonical proxy return the same item.
- Confirm the installer endpoint references only Book Sender.
- Verify installation and launch on a clean supported Mac separately.
- Verify a real Sparkle `N -> N+1` update when the next release exists.

Compilation in GitHub Actions does not prove local tests, authenticated SMTP,
clean-account installation, or an end-to-end update.
