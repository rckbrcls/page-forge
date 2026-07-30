# Contract: Local Recording and Copy

## Purpose

Make failed and uncertain operations diagnosable after restart and easy to share
manually without creating app-owned diagnostic storage or exposing private data.

## Recording port

`DiagnosticRecording` exposes one operation:

```swift
func record(_ event: DiagnosticEvent) async
```

It accepts no raw string, error, dictionary, file URL, address, credential, or
provider response.

Recording failure must not replace the original application outcome or block the
user's recovery controls.

## Unified logging adapter

`UnifiedDiagnosticRecorder` is the only production file allowed to construct or
use `OSLog.Logger`.

Required properties:

- one Book Sender subsystem based on the stable bundle identifier;
- fixed categories selected from a closed enum;
- static log message templates;
- `.error` records for failed and uncertain terminal outcomes and `.fault` only
  for critical startup/fatal outcomes, so required terminal evidence uses
  system-persisted levels;
- interpolated values limited to validated enum raw values, stable codes,
  numbers, booleans, UUIDs, and version values already present in
  `DiagnosticEvent`;
- only those validated fields may be explicitly marked public for correlation;
  no value is made public merely because a recorder call received it;
- one terminal record per failed or uncertain operation;
- no success/progress noise unless a future specification explicitly requires
  it;
- no custom file, rotating archive, database, upload, or analytics sink.

The operating system controls retention and availability through standard macOS
diagnostic tools. Book Sender promises local best-effort correlation after
restart, not indefinite retention.

## Event contents

The record includes, when present:

- event and operation identifiers;
- app version;
- timestamp supplied by the event;
- action;
- failed or uncertain outcome;
- stable diagnostic code;
- family;
- phase;
- severity;
- retry disposition;
- numeric/enhanced provider status;
- setup revision;
- batch counts;
- transmission-started state;
- safety-limit identifier;
- occurrence count.

No additional fields may be interpolated directly at the recording call site.

## Startup and fatal correlation

Startup restoration and fatal application boundaries create a
`DiagnosticEvent` before presenting their safe failure. The event must contain a
stable startup/fatal code, bootstrap or preference/credential phase, app
version, and event identifier. The same identifier is available in expanded
details so a support session can correlate the visible error with standard
local system diagnostics.

## Copied details port

`DiagnosticClipboard` exposes one explicit operation:

```swift
@MainActor
func write(_ copy: DiagnosticCopy) throws
```

The AppKit adapter:

1. receives already formatted safe text;
2. clears the general pasteboard;
3. writes one plain-text representation;
4. does not read existing clipboard data;
5. returns a typed clipboard failure without including pasteboard contents.

Copying occurs only after the user invokes `Copy Error Details`.

## Formatter

`DiagnosticFormatter` is pure and deterministic. It accepts one
`DiagnosticEvent` and produces `DiagnosticCopy`.

The format uses fixed English labels and stable ordering. It omits unavailable
optional fields and never calls `String(describing:)` on raw errors.

Example shape:

```text
Book Sender 0.3.0
Time: 2026-07-30T15:10:00Z
Action: Send book
Outcome: Failed
Code: smtp.authentication-rejected
Subsystem: Delivery
Phase: Authenticating
Provider status: 535 5.7.8
Next step: Edit Setup and verify the app password.
```

The example is a format contract, not a claim about a real provider response.

## Copy feedback

After a successful write, the current action feedback reports
`Error details copied.` without dismissing the underlying failure. A clipboard
write failure presents a specific copy failure and keeps the original diagnostic
details available for manual reading.

Repeated copy actions are allowed and each explicit action receives its own
terminal feedback.

## Privacy and validation

- Recorder and formatter tests use the same redaction canary matrix.
- A recorder spy verifies exact event fields; tests do not query the user's
  unified log.
- Clipboard tests use a fake port for application behavior and a focused AppKit
  adapter test for plain-text write behavior.
- Static checks enforce that `Logger` appears only in the vetted adapter.
- No test fixture includes personal credentials or real user addresses.
- Runtime inspection of Console/log output is a distinct authorized validation
  gate.
