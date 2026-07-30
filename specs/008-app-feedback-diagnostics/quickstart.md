# Quickstart: App Feedback and Diagnostics Verification

This is a future implementation and verification guide. The planning workflow
does not build, test, launch, send mail, inspect the user's unified logs, or
publish Book Sender.

## 1. Implement from the shared sanitized boundary

Recommended order:

1. Add `FeedbackModels`, `DiagnosticModels`, and diagnostic ports.
2. Add presentation catalog, formatter, deduplication, and recording service
   tests before wiring UI.
3. Add the unified-logging and AppKit clipboard adapters.
4. Migrate adapter failure sites, starting with Keychain and SMTP.
5. Integrate terminal recording and feedback lifecycle in `AppModel` and the
   pipeline event consumer.
6. Render shared inline feedback/details in setup, send, and Settings.
7. Add accessibility announcements and UI coverage.

At every step, preserve the rule:

```text
raw adapter failure
  -> SanitizedFailure + DiagnosticEvidence
  -> one DiagnosticEvent
  -> presentation + local recording + copied details
```

Do not create separate "verbose" strings for the recorder or clipboard.

## 2. Static repository gate

From the repository root:

```bash
git diff --check
jq empty .specify/feature.json
plutil -lint BookSender.xcodeproj/project.pbxproj
plutil -lint BookSender/Info.plist
plutil -lint BookSender/BookSender.entitlements

rg -n 'Logger\\(|os_log\\(' BookSender --glob '*.swift'
rg -n -i \
  'analytics|telemetry|sentry|datadog|segment|mixpanel' \
  BookSender BookSenderTests BookSenderUITests BookSender.xcodeproj

rg -n \
  'localizedDescription|String\\(describing:.*Error|\\[String: String\\]' \
  BookSender/Adapters BookSender/Application BookSender/Domain

rg -n \
  'SMTPReply|reply\\.lines|App Password|password|senderAddress|kindleAddress|fileURL|path' \
  BookSender/Adapters/Diagnostics BookSender/Application/Diagnostics
```

Expected after implementation:

- `Logger` appears only in
  `BookSender/Adapters/Diagnostics/UnifiedDiagnosticRecorder.swift`;
- no production `os_log` call;
- no telemetry/analytics integration;
- no arbitrary diagnostic metadata or raw error description;
- any sensitive-term match in diagnostics is a reviewed redaction assertion,
  type-level prohibition, or non-value identifier;
- valid project and property-list syntax.

Review the project diff and `Package.resolved` to confirm there is no new source
dependency and no third primary screen, diagnostic-history view, diagnostic log
file, diagnostic archive, or diagnostic database. The bounded `History` tab
defined by Feature 009 is a separate product capability.

## 3. Deterministic model and privacy gate

Required Swift Testing coverage:

- `ActionFeedback` transition validity and terminal immutability;
- unchanged-state deduplication and occurrence counts;
- diagnostic code validation and catalog completeness;
- safe-context validation;
- provider reply/enhanced-status parsing and raw-prose discard;
- retry disposition before and after SMTP message data begins;
- deterministic `DiagnosticFormatter` output;
- record-once behavior at startup, setup, shortcut, pipeline, and delivery
  terminal boundaries;
- setup success feedback after password draft clearing;
- batch aggregate outcomes for success, failure, cancellation, partial, and
  unknown;
- clipboard success/failure behavior through a fake port;
- redaction canaries across presentation, recorder spy, and copied text;
- privacy source scan permitting `Logger` only in the vetted adapter.

Canary data must include synthetic passwords, sender/recipient addresses, SMTP
host, full paths, filenames, book text, message bytes, provider prose, Keychain
data, and raw platform error descriptions. No personal value may appear in a
fixture.

## 4. Compilation gate

This command builds the project and requires Erick's explicit authorization:

```bash
xcodebuild \
  -project BookSender.xcodeproj \
  -scheme BookSender \
  -destination 'platform=macOS' \
  build
```

Expected:

- Swift 6 complete concurrency checking succeeds;
- main-actor feedback and clipboard calls are isolated correctly;
- the recorder does not block UI state transitions;
- filesystem-synchronized source files belong to the intended targets;
- exact existing package resolution remains unchanged.

Compilation does not prove tests, runtime announcements, unified-log output,
authenticated provider behavior, or distribution.

## 5. Unit and controlled integration gate

With separate authorization:

```bash
xcodebuild \
  -project BookSender.xcodeproj \
  -scheme BookSender \
  -destination 'platform=macOS' \
  test \
  -only-testing:BookSenderTests
```

The controlled SMTP suite must cover every phase and certainty rule in
`contracts/smtp-provider-diagnostics.md`. A recorder spy proves typed event
content; unit tests do not scrape the user's unified log store.

## 6. UI and accessibility gate

With separate authorization:

```bash
xcodebuild \
  -project BookSender.xcodeproj \
  -scheme BookSender \
  -destination 'platform=macOS' \
  test \
  -only-testing:BookSenderUITests
```

Required journeys:

1. Save setup with a new app password; verify the field clears and
   `Setup saved. App password stored securely.` remains visible.
2. Edit setup without replacing the stored password; verify specific success.
3. Trigger controlled preference and credential failures; verify action, cause,
   phase, recovery, code, and `Copy Error Details`.
4. Copy details; verify success feedback while the original failure remains
   readable.
5. Exercise add, remove, clear, confirm, prepare, send, cancel, partial batch,
   and retry feedback.
6. Exercise controlled SMTP failures for connection, TLS, authentication,
   sender, recipient, DATA, and final acceptance.
7. Verify delivery uncertainty after message transmission begins.
8. Save and clear the global shortcut, including conflict feedback.
9. Invoke Sparkle's standard update check and verify Book Sender does not add a
   competing update-feedback surface.
10. Verify keyboard access, labels, hints, focus order, increased contrast,
    reduced motion, and one announcement per important state transition.

UI-test composition must use isolated preferences, fake credentials, a fake
clipboard, and controlled SMTP fixtures.

## 7. Manual local diagnostics gate

After build/test authorization, use a non-personal test account:

1. Trigger one controlled startup or delivery failure.
2. Relaunch Book Sender.
3. Use standard macOS Console or log tooling to locate the Book Sender subsystem
   and correlate the stable event/code shown in expanded details.
4. Verify the record contains only the allowed fields in
   `contracts/local-recording-and-copy.md`.
5. Copy current error details and compare the same safe code, phase, and retry
   disposition.
6. Search both outputs for the complete redaction canary matrix.

System logging has system-managed retention. This gate proves current local
availability and redaction, not indefinite diagnostic history.

## 8. Authorized provider gate

Use dedicated non-personal SMTP and Kindle test destinations only after the
controlled fixture suite passes and Erick explicitly authorizes the attempt.

Verify separately:

- implicit TLS connection and authentication rejection;
- STARTTLS connection and authentication rejection;
- sender and recipient rejection where safely reproducible;
- one successful EPUB and PDF;
- network loss before message data;
- network loss after message data and `delivery_unknown`;
- no automatic retry of uncertain delivery.

Evidence may record app version, timestamp, stable code, phase, numeric/enhanced
provider status, retry disposition, and pass/fail. It must not record
credentials, addresses, paths, filenames, book content, message bytes, or raw
provider replies.

A controlled or local pass does not prove current Gmail account eligibility,
Kindle acceptance policy, release signing, packaging, or public distribution.

## 9. Release regression gate

The feature must not change:

- pinned release signing identity and designated requirement;
- Sparkle EdDSA verification;
- hardened runtime and approved entitlement set;
- clean-runner installation and launch requirements;
- exact dependency policy;
- Keychain credential continuity.

Release verification remains governed by the existing release workflow and is
not satisfied by feature tests.
