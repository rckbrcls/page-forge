# US2 Real Send Validation

## Static implementation evidence

- Finder and drop input share `AppModel.addBooks` and the actor-owned pipeline.
- Intake returns one ordered accepted, excluded, or cancelled outcome per URL.
- PDF readiness requires staged size, signature, complete ending, and digest.
- EPUB readiness requires archive preflight, bounded XML audit, planned
  deterministic write, reopen, revalidation, comparison, and promoted digest.
- Originals are read-only inputs; working files are collision-safe staged
  copies.
- Confirmation summaries contain no private paths while the value snapshot
  remains actor-owned.
- Delivery reads the credential only after confirmation and performs one
  independent SwiftNIO/NIOSSL SMTP attempt per book.
- SMTP supports implicit TLS, STARTTLS with a second EHLO, TLS-only AUTH PLAIN
  or LOGIN, streamed MIME/base64, dot-stuffing, bounded replies, stage
  timeouts, and post-DATA uncertainty.
- Controlled UI-test outcomes traverse the same production pipeline and
  delivery service.

## Validation boundary

Fixture schema, plist/project syntax, installer/appcast contracts, and source
absence checks passed. Compilation, fixture execution, NIO loopback TLS,
UI automation, and authenticated provider delivery were not executed.
