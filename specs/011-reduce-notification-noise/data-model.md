# Data Model: Essential Notification Feedback

## Overview

Feature 011 adds no durable data. It introduces one typed application-
presentation decision that controls whether an existing semantic
`ActionFeedback` is projected into the existing floating notification system.

Existing Feature 010 notification entries, configuration, destinations, queue,
timers, focus requests, and card actions remain unchanged after publication.

## `NotificationPublicationIntent`

Represents the product decision for one terminal semantic feedback result.

| Case | Associated value | Meaning |
|---|---|---|
| `contextual` | none | Store semantic feedback and rely on existing durable UI; do not enqueue or announce a card |
| `floating` | `NotificationReason` | Store semantic feedback and publish one terminal card at the originating destination |

### Validation rules

- Default value is `contextual`.
- `acknowledged` and `inProgress` production feedback always behaves as
  `contextual`, regardless of a malformed request.
- A floating intent is valid only for a terminal feedback state.
- The reason is mandatory for floating intent and is never displayed as raw
  text.
- The intent is ephemeral and is not stored in preferences, history,
  diagnostics, files, Keychain, logs, analytics, or remote systems.
- A contextual result creates no notification entry, queue key, expiry task,
  close state, action state, or accessibility announcement.

## `NotificationReason`

An exhaustive audit label explaining why the result cannot rely solely on
contextual presentation.

| Case | Eligible meaning | Current producer |
|---|---|---|
| `protectedCredentialPersistence` | Protected setup/credential storage succeeded without independently visible proof | successful delivery setup save |
| `protectedCredentialDeletion` | Protected credential deletion succeeded or completed partially outside the visible form | delivery setup deletion terminal outcome |
| `clipboardWrite` | Clipboard content changed or failed to change invisibly | diagnostic copy terminal outcome |
| `submissionHistoryPersistence` | SMTP acceptance succeeded but the separate local history write failed | history persistence failure event |
| `consequentialHiddenFailure` | A consequential failure has no immediately visible durable representation | no current additional producer |
| `auxiliarySystemActionFailure` | A requested auxiliary/system interface failed to appear | no current producer; successful update opening is contextual |

### Validation rules

- A reason does not itself imply success, failure, duration, icon, close, or
  action; those remain derived from the terminal `ActionFeedback`.
- Every production `.floating` call site identifies one reason explicitly.
- Every reason has at least one acceptance test or is documented as reserved
  with no current producer.
- A new reason requires specification review; unknown actions default to
  contextual.

## Existing `ActionFeedback`

Feature 011 preserves all fields and state transitions from the existing model:

| Field | Role after Feature 011 |
|---|---|
| `id` | Stable semantic lifecycle identity independent of card visibility |
| `scope` | Current semantic slot for application, setup, shortcut, batch, item, delivery, update, history, or diagnostic copy |
| `action` | Typed operation used in exhaustive eligibility review |
| `state` | Acknowledged, in progress, succeeded, failed, cancelled, partial, or unknown |
| `title` / `message` | Sanitized user-facing meaning used contextually and, when eligible, by the card |
| `startedAt` / `updatedAt` | Semantic lifecycle chronology |
| `dismissal` | Existing terminal presentation compatibility when a card is eligible |
| `failure` | Sanitized typed recovery and evidence presentation |
| `occurrenceCount` | Repeated equivalent semantic occurrence count |

### Semantic state transition

```text
acknowledged
    -> inProgress
    -> succeeded | failed | cancelled | partial | unknown
```

Feature 011 does not change this transition. It changes only the optional
terminal projection:

```text
semantic transition
    -> always update feedbackByScope
    -> always preserve diagnostics/context
    -> contextual intent: stop
    -> floating intent: publish normalized terminal card
```

## Contextual feedback projection

The feature views consume semantic feedback independently from notification
entries.

| Context | Semantic source | Durable presentation |
|---|---|---|
| Delivery Setup | `deliverySetup` feedback, field errors, setup message | field validation and failure detail |
| Send | `batch` feedback plus item/delivery models | batch phase, rows, aggregate status, failure detail |
| History | `history` feedback plus history load state and snapshot | loading, unavailable, empty/list state, failure detail |
| Shortcut Settings | `shortcut` feedback plus shortcut preference | recorder, switch, registration state, failure detail |

### Validation rules

- Closing, expiring, replacing, suppressing, or detaching a notification cannot
  remove contextual feedback.
- A card may route the user to contextual evidence but does not own that
  evidence.
- Send does not use application/setup success acknowledgements as failure
  content.
- Delivery uncertainty remains a row/aggregate outcome even with zero card.

## Existing notification entities

The following Feature 010 entities are unchanged for approved and test-only
publications:

- `NotificationDestination`
- `NotificationKey`
- `NotificationIcon`
- `NotificationLifetime`
- `NotificationClosePolicy`
- `NotificationActionDescriptor`
- `FloatingNotificationConfiguration`
- `FloatingNotificationEntry`
- `NotificationDestinationSnapshot`
- `NotificationTaskKey`
- `NotificationFocusRequest`

Their existing queue, visible limit, replacement, expiry, close, action,
destination, focus, and accessibility invariants continue to apply after an
entry is published.

## Stale-presentation transition

When a new action starts for one scope and destination:

```text
old floating entry exists
    -> cancel its expiry if any
    -> remove its visible/queued/hidden presentation
    -> preserve prior semantic/diagnostic record as required
    -> start new semantic lifecycle
    -> publish nothing until an approved terminal intent exists
```

Only the matching scope and destination are affected. Independent cards retain
their identity and lifetime.

## Privacy and persistence

No entity introduced by Feature 011 is persisted. Publication reasons must not
contain credentials, addresses, source paths, filenames, book content, provider
text, diagnostic evidence, or remote identifiers. Existing sanitized
`ActionFeedback` content remains the only card content.
