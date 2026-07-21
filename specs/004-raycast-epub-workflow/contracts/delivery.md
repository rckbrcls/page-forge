# Kindle Delivery Contract

## Configuration

The send command validates command preferences before book intake:

| Preference     | Type      | Required before intake | Validation before SMTP                                          |
| -------------- | --------- | ---------------------- | --------------------------------------------------------------- |
| Sender Address | textfield | Yes                    | Valid email; no CR/LF                                           |
| SMTP Host      | textfield | Yes                    | Non-empty hostname; no control characters                       |
| SMTP Port      | textfield | No; secure default     | Integer `1...65535`                                             |
| Security Mode  | dropdown  | No; secure default     | `Implicit TLS` or `STARTTLS`                                    |
| Username       | textfield | Yes                    | Non-empty                                                       |
| App Password   | password  | Yes                    | Non-empty; never displayed or logged                            |
| Kindle Address | textfield | Yes                    | Valid email ending exactly in `@kindle.com`, case-insensitively |

Missing or invalid values show a dedicated setup screen before file selection, inspection, or preparation. Configuration failures are command-level setup issues and must never be attached to individual book results. The official Send to Kindle page remains a secondary action only after configured preparation.

## Security Modes

### Implicit TLS

- Default port: 465.
- Establish TLS before SMTP commands.
- Certificate validation enabled.
- Minimum TLS version 1.2.

### STARTTLS

- Default port: 587.
- Establish SMTP connection and require successful STARTTLS upgrade before authentication.
- Never continue if STARTTLS is unavailable or fails.
- Certificate validation enabled and minimum TLS version 1.2.

Plaintext, opportunistic downgrade, disabled certificate validation, and password-in-URL configuration are prohibited.

## Eligibility and Confirmation

1. Open each source read-only and validate with `fstat` that it is the reviewed regular `.epub`.
2. Before any network connection, copy from that descriptor to a random private mode-0600 delivery snapshot while hashing; close and verify that its digest equals the reviewed `HealthReport` or `PreparedEpub.outputSnapshot` digest.
3. Reopen and stream only the verified delivery snapshot, then remove it in `finally`; a digest mismatch blocks delivery as a changed-file failure.
4. Require `healthy` or a successful prepared result.
5. Reject `needs_review`, `unsupported`, and `unsafe`.
6. Offer prepare first for `repairable`.
7. Show basenames, sizes, sender, Kindle destination, security mode, and item count; never show password.
8. Require one explicit action that authorizes exactly the displayed eligible set.
9. Submit sequentially, one message and one EPUB attachment per item.

## Message Contract

- Envelope sender: configured sender address.
- Envelope recipient: configured Kindle address only.
- From: configured sender address.
- To: configured Kindle address.
- Subject/body: empty or minimal fixed Page Forge text; no book metadata or local path.
- Attachment filename: basename only.
- Attachment content type: `application/epub+zip`.
- Attachment source: controlled readable stream; never a URL and never an unconstrained library file lookup.
- File and URL access from message content are disabled.
- Logging/debug output from the SMTP library is disabled.

The adapter must never add other recipients, attachments, book excerpts, reports, or metadata.

## Timeouts

- DNS timeout: 10 seconds.
- Connection timeout: 20 seconds.
- SMTP greeting timeout: 20 seconds.
- Socket inactivity timeout: 120 seconds.
- A separate operation deadline may request interruption but cannot claim non-delivery once SMTP DATA may have begun.

## Cancellation Semantics

| Phase                                    | Required result                                                                           |
| ---------------------------------------- | ----------------------------------------------------------------------------------------- |
| Before connection                        | `cancelled`; no transmission started                                                      |
| DNS/connect/auth                         | Request socket closure; `cancelled` only when no message data was transmitted             |
| Attachment stream before DATA completion | Destroy stream and connection; `delivery_unknown` if server acceptance cannot be excluded |
| After DATA may have completed            | `delivery_unknown` unless a definitive SMTP response is received                          |
| After SMTP 2xx                           | `submitted`; cancellation cannot revoke it                                                |

No unknown or failed submission is retried automatically.

## Result Semantics

### `submitted`

The configured SMTP server returned success for the message. UI wording: `Submitted to the SMTP server.` This does not promise Amazon ingestion or Kindle delivery.

### `failed`

A definitive preflight or SMTP failure occurred before successful acceptance. Manual retry may be offered after correction.

### `delivery_unknown`

The connection ended after acceptance may have occurred but before a definitive response was retained. Retry requires a new explicit action and a duplicate-delivery warning.

### `cancelled`

Cancellation completed before any possible message acceptance.

## Sanitized Failure Mapping

| Internal category                  | Public message                                                           |
| ---------------------------------- | ------------------------------------------------------------------------ |
| Authentication                     | `Authentication failed. Check the username and app password.`            |
| TLS                                | `A secure connection could not be established.`                          |
| DNS                                | `The SMTP host could not be resolved.`                                   |
| Connection                         | `The SMTP server could not be reached.`                                  |
| Timeout before DATA                | `The SMTP connection timed out before submission.`                       |
| Timeout/connection loss after DATA | `Submission could not be confirmed. The message may have been accepted.` |
| Envelope                           | `The sender or Kindle address was rejected.`                             |
| Message/size                       | `The SMTP server rejected the message or attachment size.`               |
| File stream                        | `The EPUB could not be read completely.`                                 |
| Unknown                            | `The message could not be submitted.`                                    |

Raw exception messages, response text, stack traces, host, username, password, complete addresses, local paths, and message content must not cross the adapter boundary.

## Manual Handoff

- URL: `https://www.amazon.com/sendtokindle`.
- Open only after a user action.
- Never automate login, DOM interaction, upload, or account access.
- The extension may reveal the eligible EPUB in Finder so the user can choose it manually.
- Documentation may state the current web limit as informational and subject to change; it must not promise SMTP or Amazon acceptance.
