# Contract: SMTP Provider Diagnostics

## Purpose

Preserve enough SMTP state to distinguish connection, security,
authentication, envelope, transmission, and final-acceptance failures without
retaining provider prose or private message data.

## Delivery phases

Every SMTP failure maps to exactly one phase:

| Internal state | Diagnostic phase |
|---|---|
| Connection attempt or channel closure before greeting | `smtpConnecting` |
| Greeting, EHLO, STARTTLS, TLS negotiation, post-TLS EHLO | `smtpSecuring` |
| AUTH command and challenge/response | `smtpAuthenticating` |
| MAIL FROM | `smtpSender` |
| RCPT TO | `smtpRecipient` |
| DATA command and streamed message body | `smtpData` |
| Reply after message terminator | `smtpFinalAcceptance` |

Implicit TLS failures before a usable secured session map to `smtpSecuring`, even
when they occur during socket setup.

## Provider response extraction

From a syntactically valid provider response, the adapter may retain only:

- three-digit reply code in `200...599`;
- the first syntactically valid enhanced status code with shape
  `[245].[0-9]{1,3}.[0-9]{1,3}`.

The decoder may use reply text transiently to locate an enhanced code, then must
discard all reply lines before creating `SanitizedFailure`. Provider prose,
hostnames, addresses, identifiers, challenge content, and protocol transcript
cannot enter the failure or event model.

Malformed reply framing maps to the existing reply-format/reply-count/reply-line
diagnostic family with the active phase and no raw lines.

## Failure mapping

The diagnostic code must encode stable cause, not provider prose. Phase remains
a separate typed field.

Minimum controlled cases:

| Condition | Required guidance |
|---|---|
| DNS/socket connection failure | Explain connection failure; safe retry when no data began |
| TLS negotiation or certificate failure | Explain secure-channel failure; do not suggest changing the book |
| 530, 534, or 535 during authentication | `Edit Setup`; explain credential/account authentication rejection |
| Other 4xx before message data | Transient provider failure; retry may be safe |
| Sender rejection | Explain sender-envelope rejection and direct user to setup/provider policy |
| Recipient rejection | Explain Kindle-recipient rejection and direct user to address/allow-list checks |
| DATA command rejection before streaming | Explain provider refusal; retry based on numeric class |
| Channel failure while streaming data | `delivery_unknown`; check destination before retry |
| Rejection after message terminator | Explain final-acceptance rejection; preserve numeric/enhanced code |
| Channel failure awaiting final acceptance | `delivery_unknown`; check destination before retry |
| Timeout | Preserve active phase and derive certainty from transmission state |
| User cancellation | Cancelled before data; possibly `delivery_unknown` after data begins |

The same three-digit code in different phases may produce different
presentations and recovery actions.

## Retry and certainty

`transmissionStarted` becomes true only when application message data begins
streaming after DATA acceptance.

- Before transmission starts, a transient transport/provider failure may use
  `retrySafe`.
- Authentication and account failures use `editSetup`.
- Permanent file-independent sender/recipient policy failures are not
  automatically retryable.
- After transmission starts, a missing conclusive provider reply uses
  `checkBeforeRetry` and terminal outcome `uncertain`.
- A conclusive rejection after transmission may be failed rather than uncertain,
  but its provider status and final-acceptance phase must be retained.

The application never automatically retries an uncertain delivery.

## Stable codes

Existing stable codes remain when they identify a specific cause. Generic
provider codes should migrate from `smtp.provider-<replyCode>` to a stable cause
code plus typed `ProviderStatus`.

Illustrative catalog entries:

- `smtp.connection`
- `smtp.secure-channel`
- `smtp.authentication-rejected`
- `smtp.sender-rejected`
- `smtp.recipient-rejected`
- `smtp.data-rejected`
- `smtp.final-acceptance-rejected`
- `smtp.transport`
- `smtp.timeout`
- `smtp.delivery-unknown`
- `smtp.reply-format`

The numeric reply code is evidence, not part of the stable catalog key.

## Acceptance matrix

Fixture/state-machine tests must cover:

- every delivery phase;
- authentication codes 530, 534, and 535;
- at least one 4xx and one 5xx response in sender, recipient, DATA, and final
  acceptance phases;
- enhanced status present, absent, and malformed;
- multi-line replies;
- malformed and over-limit replies;
- connection closure and timeout before data;
- connection closure, timeout, and cancellation after data begins;
- redaction of raw reply prose, addresses, challenge text, and message bytes.

Live Gmail or Kindle behavior is a separate explicitly authorized acceptance
gate and cannot be claimed from fixture tests.

