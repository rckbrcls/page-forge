# Contract: Failure Diagnostics and Redaction

## Purpose

Guarantee that expected and unexpected failures remain specific enough to act
on while display, local recording, and copied details contain only allow-listed
evidence.

## Adapter translation

Every adapter catch boundary must translate its raw technical failure into:

- `FailureFamily`;
- stable `DiagnosticCode`;
- specific `DiagnosticPhase`;
- `DiagnosticSeverity`;
- `RetryDisposition`;
- existing `RecoveryAction`;
- optional typed `ProviderStatus`;
- optional closed `DiagnosticContext`.

Raw platform errors remain inside the adapter. Production code may not attach
`Error`, `NSError`, `localizedDescription`, `userInfo`, archive/XML input,
provider reply lines, or free-form metadata to a returned diagnostic value.

## Presentation catalog

`FailurePresentationService` is the single code-to-presentation catalog.

For every expected failure code it must provide:

- affected action or item;
- concise user-readable summary;
- safe expanded explanation;
- subsystem/family;
- phase;
- impact;
- retry disposition;
- recovery action and control title;
- stable code;
- safe provider status when present.

A known specific code may not use a broad family-only message. Unknown codes
must use an explicit `unexpected.<family>` entry and preserve safe family and
phase context.

Catalog output must not depend on raw exception wording or provider-controlled
text.

## Allowed diagnostic fields

The diagnostic path may contain:

- Book Sender app version;
- event timestamp;
- random operation identifier;
- stable diagnostic code;
- failure family;
- phase;
- severity;
- retry disposition;
- recovery action identifier;
- setup revision;
- aggregate batch total and completed count;
- message-transmission-started boolean;
- named safety-limit identifier;
- SMTP three-digit reply code;
- validated SMTP enhanced status code;
- repeated occurrence count.

## Forbidden diagnostic fields

The diagnostic path must reject or omit:

- SMTP app password or any credential;
- sender, username, recipient, or Kindle address;
- SMTP hostname;
- full path or URL;
- filename, display name, or book title;
- EPUB/PDF content or metadata;
- message headers, body, attachment bytes, or MIME output;
- raw SMTP command, reply line, transcript, or provider prose;
- raw Keychain data;
- raw archive or XML input;
- `Error`, `NSError`, localized description, stack description, or user info;
- clipboard contents;
- arbitrary dictionaries, arbitrary strings, or remote identifiers.

## One sanitized snapshot

For one failed or uncertain operation:

1. the adapter creates `SanitizedFailure`;
2. the application creates one `DiagnosticEvent`;
3. presentation derives `FailurePresentation` from the event failure;
4. local recording accepts that same event;
5. copying formats that same event.

No layer reparses raw data to create a "more verbose" display, log, or copied
version.

## Deduplication

Repeated identical failures within one active operation are equal when action,
code, phase, provider status, retry disposition, and safe context match.

Equal repetitions:

- increment `occurrenceCount`;
- do not create another visible banner;
- do not create another accessibility announcement;
- may create at most one terminal diagnostic record for that operation.

A retry receives a new operation and event identity.

## Privacy test contract

Automated privacy checks must:

- allow `Logger` only in
  `BookSender/Adapters/Diagnostics/UnifiedDiagnosticRecorder.swift`;
- fail if logging APIs appear elsewhere in production source;
- fail on direct telemetry/analytics dependencies or calls;
- fail if a diagnostic type gains an arbitrary metadata field;
- inject canary secrets, addresses, paths, filenames, content, raw replies, and
  raw error descriptions at adapter boundaries;
- assert that canaries appear in none of presentation, recorder-spy payloads, or
  copied text;
- assert catalog completeness for all expected failure codes;
- assert formatter output is deterministic.

Tests inspect typed recorder values through a spy. They do not scrape the user's
unified log store.

## Acceptance checks

- Every expected failure fixture yields action, cause, impact, phase, recovery,
  and stable code.
- Every unexpected boundary yields an explicit `unexpected.*` code with safe
  family and phase.
- Redaction canaries are absent from all three diagnostic consumers.
- No raw provider reply or platform error description reaches SwiftUI.

