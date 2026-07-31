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
per-book readiness and delivery states. Inside `Send Book`, the `Send` tab owns
the active batch and the `History` tab shows a simple newest-first record of
definitive SMTP submissions.

Concise action feedback appears in a shared top-trailing floating notification
host instead of moving forms, lists, empty states, or primary actions.
Successful and informational acknowledgements disappear after four seconds.
Active work remains until its state changes. Failures, cancellations, mixed
results, and `Delivery Unknown` remain until replaced or dismissed. Dismissing
a notification hides only that presentation; field validation, batch states,
failure evidence, delivery uncertainty, and send history remain unchanged.

Each window owns an independent stack of at most three visible notifications.
Additional relevant results wait without evicting persistent recovery. A card
may expose one typed action and an optional close control. Notification state is
ephemeral and is never written to send history, preferences, diagnostics, or
another persistence surface.

A terminal batch exposes `Send More Books`, which clears only its temporary
books and presentation state before the next intake. Adjacent book rows use
near-full-width native dividers inside the existing batch card; the final row
has no divider.

Send history remains local, retains at most 500 records, and stores only a local
identifier, the original book display name, and the provider-acceptance
timestamp. It can be cleared explicitly and cannot resend, retry, open, locate,
preview, export, or manage books. A history row means the SMTP provider
definitively accepted the submission; it does not claim Kindle receipt,
processing, availability, or library presence.

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
with transient feedback, repeated sends, and bounded local history defined by
[`specs/009-transient-feedback-history/spec.md`](specs/009-transient-feedback-history/spec.md),
with the reusable floating-feedback and batch-divider behavior defined by
[`specs/010-floating-feedback-system/spec.md`](specs/010-floating-feedback-system/spec.md),
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

The installer selects the universal Book Sender archive, validates its GitHub
Release SHA-256 digest and pinned public certificate, registers only that public
code-signing certificate in the user's Keychain when absent, and then validates
the app identity, designated requirement, and nested code signatures. It
installs `BookSender.app` into
`/Applications` or `~/Applications`. Review
[`scripts/install.sh`](scripts/install.sh) before running it.
The first corrected installation asks for explicit terminal confirmation before
registering the public certificate.

The app uses Sparkle for daily update checks and exposes
**Check for Updates…** in the application menu. Releases and appcast archives
are protected with Sparkle EdDSA signatures.

Releases produced under the corrected contract use one stable self-signed
`Book Sender Release Signing` identity and are not notarized by Apple. This
preserves Keychain access across normally signed corrected updates but is not
Developer ID and does not provide normal Gatekeeper trust. The installer removes
the downloaded quarantine attribute after verification. Certificate
registration is idempotent, stores no private key or email password, and does
not install an explicit Always Trust override. Users installing manually may
need Finder's **Open** action.

The self-signed identity has no Apple Team ID. Release builds keep the hardened
runtime and use only its library-validation exception on the main executable so
the pinned Sparkle framework can load. The release pipeline and installer still
require every bundled Sparkle executable to use the pinned certificate. After
packaging, a separate clean macOS runner receives no private signing material,
installs the candidate through the real certificate bootstrap, and must launch
the installed app before publication.

SMTP passwords are stored only in the traditional macOS Keychain. The first
version using this corrected storage contract asks for the password once;
updates signed with the same pinned identity retain access without asking again.

See [`docs/deployment.md`](docs/deployment.md) for the release workflow and
validation boundaries. For safe current-error copying, local macOS diagnostic
lookup, privacy guarantees, and support guidance, see
[`docs/troubleshooting.md`](docs/troubleshooting.md).

## Development and Verification

Static checks, compilation, automated tests, runtime inspection, authenticated
SMTP delivery, release signing, update installation, and production release are
separate validation claims. Build and test commands require explicit
authorization under the repository workflow. The release workflow now requires
the approved unit, UI, installer, and appcast contract suites before it can
publish an artifact.
