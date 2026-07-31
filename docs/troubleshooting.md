# Troubleshooting Book Sender

Book Sender shows concise action feedback in floating notifications at the top
trailing edge of the owning window. Successful and informational
acknowledgements remain visible for four seconds after appearing and then
disappear without moving the workflow. Failed, cancelled, partial, and
uncertain results remain until replaced or dismissed.

Use a notification action for its stated recovery step, or use
**Dismiss notification** to hide only that card. Dismissal does not clear field
errors, per-book results, expanded diagnostics, delivery uncertainty, setup,
credentials, or send history. The app does not persist notifications or create
a notification-history screen.

## Start another send

After every book in a batch reaches a terminal result, choose
**Send More Books** to clear the temporary batch and return to empty intake.
This keeps delivery setup, credentials, shortcut preferences, and send history.

If the batch contains `Delivery Unknown`, Book Sender asks before discarding the
visible result. Cancel to keep reviewing it. Confirm only after considering
whether the provider may already have accepted the message; resetting does not
retry or retract anything.

## Send history

Open the `History` tab inside `Send Book` to review the newest 500 definitive
SMTP submissions. Each row contains only the original display name and local
date/time presentation. It does not prove Kindle receipt, processing,
availability, or library presence.

**Clear History** removes only this local submission record after confirmation.
It does not change the current batch or delivery setup. If history is
unavailable or clearing fails, use the shown retry action; Book Sender preserves
the delivery result and does not silently repair or overwrite unreadable
history.

## Copy the current error

1. Expand **Show Error Details** under the affected setup, shortcut, batch, or
   book result.
2. Review the action, impact, code, subsystem, phase, retry guidance, and any
   numeric provider status.
3. Choose **Copy Error Details**.
4. Wait for the floating **Error details copied.** acknowledgement.

The copy action writes plain text only after explicit user interaction. If the
clipboard write fails, Book Sender leaves the original error visible.

The copied block may contain:

- app version and timestamp;
- event and operation identifiers;
- action and failed or uncertain outcome;
- stable code, subsystem, phase, severity, and retry guidance;
- numeric and enhanced SMTP provider status, when available;
- setup revision, bounded batch counts, transmission state, safety-limit
  identifier, and occurrence count;
- the primary next step.

## Privacy boundary

The contextual details, copied block, and local diagnostic record do not
include:

- app passwords or Keychain values;
- sender, SMTP username, or Kindle addresses;
- SMTP host values;
- full paths or filenames;
- book text or attachment bytes;
- raw provider reply text;
- raw archive, XML, filesystem, Keychain, AppKit, or Swift error descriptions.

Book Sender does not create a diagnostic file, diagnostic-history screen,
diagnostic database, telemetry stream, analytics event, or automatic support
upload. The separate bounded send history contains only definitive submission
records and never receives diagnostic evidence.

## Find the matching local record

Book Sender records failed and uncertain terminal operations in the standard
macOS unified logging system under subsystem
`com.rckbrcls.BookSender`. The operating system owns this store.

In Console:

1. Open **Console** and select the current Mac.
2. Start streaming before reproducing the issue, or search recent retained
   records.
3. Filter for subsystem `com.rckbrcls.BookSender`.
4. Match the `event` or `operation` UUID shown in Book Sender's expanded error
   details.

For a bounded command-line lookup:

```bash
log show \
  --last 15m \
  --style compact \
  --predicate 'subsystem == "com.rckbrcls.BookSender"'
```

The record uses fixed categories: `application`, `setup`, `intake`,
`preparation`, `delivery`, and `shortcut`. Only sanitized identifiers, enum
values, numbers, booleans, UUIDs, and a validated app version are public
correlation fields.

macOS controls unified-log retention and may remove or omit older records.
Book Sender provides best-effort local diagnostic correlation after restart,
not an indefinite diagnostic history.

## Share a useful support report

Use a non-personal test account when reproducing delivery problems. Share the
copied diagnostic block plus:

- the action you attempted;
- whether the error appeared before or after book transmission began;
- whether the same stable code repeats;
- whether setup was newly created, edited, or restored after launch.

Do not share screenshots containing addresses or an app password. Do not add
raw SMTP transcripts, book files, Keychain exports, Console archives, or
unredacted filesystem paths.

For `Delivery result unknown`, check the Kindle destination before retrying.
Book Sender does not automatically retry after message transmission starts
because the original delivery may have succeeded.
