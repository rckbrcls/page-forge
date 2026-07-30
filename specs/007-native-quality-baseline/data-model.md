# Data Model: Native Quality Baseline

## Overview

The feature introduces transient ownership and feedback models plus a release
signing policy. It does not add a database, remote record, preference key, or
secret storage surface; it corrects the existing credential adapter's Keychain
selection.

## SMTP Reply Waiter

An internal adapter-owned record representing one suspended request for the next
SMTP reply.

### Fields

| Field | Type | Rules |
|---|---|---|
| `id` | `UUID` or private monotonic token | Unique within the queue lifetime. |
| `continuation` | Checked throwing continuation | Runtime-only and never leaves the queue actor. |
| `state` | `pending`, `resumed`, or `cancelled` | Exactly one terminal transition. |

### State transitions

```text
pending -> resumed(reply)
pending -> resumed(queueFailure)
pending -> cancelled(callerCancellation)
pending -> cancelled(timeoutCancellation)
```

No transition is valid after `resumed` or `cancelled`. Queue finish drains all
pending waiters once. A late reply cannot resume a removed waiter.

## Intake Transfer Attempt

A transient application value that accounts for one Finder or drag-and-drop
operation before the accepted URLs enter the shared validation path.

### Fields

| Field | Type | Rules |
|---|---|---|
| `id` | `UUID` | Unique for the transient operation. |
| `source` | `finder` or `drop` | Used to select concise presentation copy, not analytics. |
| `attemptedCount` | `Int` | Non-negative; equals accepted plus transfer failures before shared validation. |
| `acceptedURLs` | `[URL]` | Stable source order; transient; never logged or persisted. |
| `failures` | `[IntakeTransferFailure]` | Sanitized and bounded by attempted count. |

### Validation

- `attemptedCount == acceptedURLs.count + failures.count`.
- Accepted URLs are forwarded once to the existing shared intake service.
- An empty Finder cancellation is not an `IntakeTransferAttempt` failure.
- One failed provider does not discard valid peers.

## Intake Transfer Failure

A transient sanitized explanation for an item that could not be converted into a
URL or imported.

### Fields

| Field | Type | Rules |
|---|---|---|
| `code` | Typed enum | Stable application-owned reason such as `unreadableItem` or `importFailed`. |
| `source` | `finder` or `drop` | Matches the originating attempt. |
| `displayName` | `String?` | Optional sanitized leaf name only when safely available. |
| `message` | `String` | Concise English UI message; no raw exception, secret, or full path. |

### Presentation

Failures may be summarized as a count when multiple items fail. Detailed text is
shown only when it explains a blocked item or next action.

## Confirmed Batch Summary

The existing stable, sendable confirmation snapshot remains the source of truth
for the confirmation sheet.

### Presentation rule

```text
confirmation == nil     -> sheet absent
confirmation != nil     -> sheet presented for that exact snapshot
```

`isShowingConfirmation`, if retained as a computed compatibility property, is
derived from `confirmation != nil` and is never independently set.

### State transitions

```text
no confirmation -> prepared snapshot
prepared snapshot -> send accepted -> consumed
prepared snapshot -> cancel/dismiss -> released
```

Dismiss, cancel, and send must release or consume the same snapshot exactly once.

## Window Attachment

A presentation-only lifecycle relationship between the main hosting backdrop and
the application window coordinator.

### Fields

| Field | Type | Rules |
|---|---|---|
| `window` | Weak `NSWindow?` reference | Never persisted and never used to discover Settings globally. |
| `attachmentState` | `detached` or `attached` | Driven by AppKit view lifecycle. |

### Rules

- Attaching the same window is idempotent.
- Detachment clears only the coordinator reference owned by that view.
- The main `Window` scene remains the sole primary window instance.

## Quality Evidence

A documentation/test concept used to keep validation claims distinct.

| Field | Type | Rules |
|---|---|---|
| `scenario` | String | Names the user or adapter contract. |
| `gate` | `static`, `unit`, `ui`, `manual`, `provider`, or `release` | One gate per result. |
| `status` | `pending`, `passed`, `failed`, or `blocked` | Never infer a stronger gate from a weaker one. |
| `duration` | Optional duration | Required for timeout/cancellation release assertions. |
| `expectedOutcome` | Typed or visible result | Must be observable and deterministic. |

Evidence must not contain SMTP credentials, raw provider errors, full local
paths, email contents, or book contents.

## Release Signing Policy

A repository-owned public contract shared by release automation and the
installer.

| Field | Value | Rule |
|---|---|---|
| `identityName` | `Book Sender Release Signing` | Stable across normal releases. |
| `certificateSHA1` | `51F0C83093408095C09F3CF5359EB7C83B7F6B38` | Must match the versioned DER certificate and imported PKCS#12. |
| `bundleIdentifier` | `com.rckbrcls.BookSender` | Must match the built main app. |
| `designatedRequirement` | Certificate anchor plus bundle identifier | Must be byte-for-byte stable after normalization. |

The private key is not a model or repository asset. It exists only in the local
Keychain, encrypted backup, and GitHub Actions secrets.

## Credential Continuity State

The existing `CredentialReference` remains unchanged.

```text
legacy inaccessible -> non-secret draft + password required once
traditional item present -> setup complete
same-identity update -> traditional item remains readable
authorized identity rotation -> migration notice + possible one-time re-entry
```
