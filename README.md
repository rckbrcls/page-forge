# Book Sender

Book Sender is being rebuilt as a lightweight native macOS application for
preparing and sending local EPUB and PDF books to Kindle.

## Product Surface

The final product has exactly two primary screens:

```text
Delivery Setup
Send Book
```

`Delivery Setup` stores SMTP and Kindle delivery settings locally. `Send Book`
accepts one or more books through drag and drop or Finder and shows concise
per-book readiness and delivery states.

## Background Pipeline

EPUB preparation remains advanced but does not become a separate interface:

```text
Safety Check
-> Structural Audit
-> Deterministic Cleanup or Restoration
-> Write Separate Working Copy
-> Revalidate
-> Ready
-> Confirm
-> Send through SMTP
```

- Healthy and successfully prepared books show minimal default feedback.
- Actionable details appear inline only for blocked, failed, or restored books.
- PDF files are checked and delivered without conversion or content modification.
- Originals and existing files are never modified or overwritten.
- Batch preparation and delivery are sequential, with independent per-book results.
- Delivery never begins without explicit user confirmation.
- DRM removal, conversion, Amazon login automation, and browser upload automation
  are out of scope.

## Repository

The active implementation specification is
[`specs/006-replace-mock-workflows/spec.md`](specs/006-replace-mock-workflows/spec.md),
built on the product baseline in
[`specs/005-lightweight-macos-sender/spec.md`](specs/005-lightweight-macos-sender/spec.md),
and governed by
[`.specify/memory/constitution.md`](.specify/memory/constitution.md).

The repository contains one application project:

```text
BookSender.xcodeproj
BookSender/
BookSenderTests/
BookSenderUITests/
```

Previous Raycast, Node, PageForge, Calibre, conversion, and historical
implementation trees have been removed. They are not supported fallbacks.

## Install on Mac

Book Sender is distributed through GitHub Releases:

```bash
curl -fsSL https://rckbrcls.com/api/book-sender/install | bash
```

The installer selects the universal Book Sender archive, validates the app
identity and ad-hoc code signature, and installs `BookSender.app` into
`/Applications` or `~/Applications`. Review
[`scripts/install.sh`](scripts/install.sh) before running it.

The app uses Sparkle for daily update checks and exposes
**Check for Updates…** in the application menu. Releases and appcast archives
are protected with Sparkle EdDSA signatures.

Current releases use ad-hoc code signing and are not notarized by Apple. The
installer removes the downloaded quarantine attribute; users installing
manually may need Finder's **Open** action. SMTP delivery remains experimental
and unavailable in version `0.2.0`.

See [`docs/deployment.md`](docs/deployment.md) for the release workflow and
validation boundaries.

## Development and Verification

Static checks, compilation, automated tests, runtime inspection, authenticated
SMTP delivery, ad-hoc signing, update installation, and production release are
separate validation claims. Build and test commands require explicit
authorization under the repository workflow. The release workflow now requires
the approved unit, UI, installer, and appcast contract suites before it can
publish an artifact.
