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

The active product direction is specified in
[`specs/005-lightweight-macos-sender/spec.md`](specs/005-lightweight-macos-sender/spec.md)
and governed by
[`.specify/memory/constitution.md`](.specify/memory/constitution.md).

The repository contains one application project:

```text
BookSender.xcodeproj
BookSender/
BookSenderTests/
BookSenderUITests/
```

Previous Raycast, Node, PageForge, Calibre, Python, Sparkle, appcast, and
historical implementation trees have been removed. They are not supported
fallbacks.

## Development and Verification

Static checks, compilation, automated tests, runtime inspection, authenticated
SMTP delivery, signing, notarization, and production release are separate
validation claims. Build and test commands require explicit authorization under
the repository workflow.
