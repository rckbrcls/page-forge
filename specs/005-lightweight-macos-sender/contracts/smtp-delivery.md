# Contract: SMTP Delivery

## Security modes

`implicitTLS` secures the channel before SMTP. `startTLS` permits only the initial
greeting and EHLO in plaintext, requires advertised STARTTLS, expects `220`,
inserts NIOSSL into the same channel, validates the TLS peer, and issues a new
EHLO before authentication.

TLS requires version 1.2 or later, trusted certificate chain, and matching
hostname. There is no user bypass. AUTH PLAIN or LOGIN is permitted only after
TLS succeeds.

## Protocol behavior

The state machine supports multiline replies, bounded line lengths and reply
counts, explicit per-stage timeouts, sanitized envelope values, and only expected
reply codes. Unexpected replies and raw framework errors map to stable sanitized
failure codes.

MIME headers reject CR/LF injection. Filename and display values are safely
encoded. Attachment base64, SMTP line boundaries, and dot-stuffing are streamed
without reading an entire large book into memory.

## Independent attempts

Each book uses a new independent attempt. One rejection or unknown result does
not alter another item. Credentials, raw message bytes, source paths, and book
metadata are never logged.

## Acceptance boundary

- Before sending the DATA body, cancellation can produce `cancelled`.
- Once any DATA body byte is written, `dataTransmissionStarted` is true.
- A final SMTP `250` after terminating DATA produces `submitted`.
- A definitive rejection produces `failed`.
- Connection loss, timeout, or cancellation after DATA starts but before a
  definitive final response produces `deliveryUnknown`.

Unknown delivery is never automatically retried.

## Required tests

Implicit TLS, STARTTLS upgrade and second EHLO, missing STARTTLS, bad certificate,
hostname mismatch, TLS version, AUTH PLAIN/LOGIN within TLS, multiline replies,
timeouts, CR/LF injection, encoded filenames, base64 boundaries, dot-stuffing,
provider rejection, cancellation before DATA, cancellation/connection loss after
DATA, and independent batch attempts.
