# Contract: Batch and SMTP Delivery

## Stable confirmation

Confirmation freezes:

- the validated setup revision and opaque credential reference;
- the displayed Kindle destination;
- ordered value copies of every eligible prepared book;
- the excluded-item count and identifiers;
- the confirmation kind and timestamp.

The actor leaves editing before returning the snapshot. Later append, remove,
clear, setup edit, or item mutation cannot alter the approved set.

## Sequential attempts

One prepared book is active at a time. Each receives a new independent SMTP
connection and `DeliveryAttempt`. One rejection or uncertain outcome does not
prevent a later eligible item unless the user cancels.

Every confirmed item ends `Submitted`, `Failed`, `Cancelled`, or
`Delivery Unknown`. Missing internal data is a typed failure, never a silently
skipped item.

## SMTP security

Implicit TLS secures the connection before the SMTP greeting.

STARTTLS:

1. receives the greeting;
2. issues EHLO;
3. requires advertised STARTTLS;
4. expects `220`;
5. upgrades the same connection;
6. validates certificate chain and hostname with TLS 1.2 or later;
7. issues a second EHLO;
8. permits authentication only after TLS succeeds.

AUTH PLAIN or LOGIN may be used only when advertised and protected. There is no
certificate, hostname, TLS-version, or plaintext-authentication bypass.

## Message and reply behavior

- Commands and replies enforce line and multiline-count limits.
- Envelope and headers reject CR/LF injection.
- Non-ASCII attachment filenames are standards-compliant and sanitized.
- MIME/base64 and dot-stuffing stream bounded data.
- Each stage has an explicit timeout.
- Credentials, paths, filenames when avoidable, transcripts, and message bytes
  are not logged.

## Acceptance boundary

- Before the first DATA body byte: cancellation produces `Cancelled`; definitive
  failures produce `Failed`.
- After the server accepts DATA and the first body byte is written:
  `dataTransmissionStarted` is true.
- Final `250` after the DATA terminator produces `Submitted`.
- Definitive provider rejection produces `Failed`.
- Timeout, channel loss, or cancellation after DATA starts without a definitive
  final reply produces `Delivery Unknown`.

## Cancellation and retry

Cancellation stops pending scheduling, cooperatively closes active streams and
the active channel, preserves completed results, and marks remaining confirmed
items cancelled.

`Retry Failed` requires a new explicit confirmation and includes only definitive
failures. `Delivery Unknown` is never automatically retried or included in the
failed-only snapshot.

## Required evidence

Deterministic tests cover implicit TLS, STARTTLS and second EHLO, missing
capability, bad certificate, hostname mismatch, TLS version, both AUTH modes,
multiline replies, command/reply limits, timeouts, injection, filename/base64
boundaries, dot-stuffing, provider rejection, cancellation before DATA,
loss/cancellation after DATA, final `250`, stable ordering, one active attempt,
failure isolation, and failed-only retry.
