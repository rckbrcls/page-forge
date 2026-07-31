# Contract: Contextual Feedback Preservation

## Purpose

Ensure notification suppression reduces noise without hiding operation truth,
failure evidence, recovery, or accessibility meaning.

## Ownership contract

- `ActionFeedback` remains application semantic state.
- `FloatingNotificationCenter` owns only optional card presentation.
- Feature views obtain durable failure content from semantic feedback and domain
  presentation state, not from card existence.
- Closing, expiry, replacement, queue promotion, or host detachment cannot erase
  contextual feedback.

## Context mapping

### Delivery Setup

Retain:

- field-level errors beside the affected field;
- save-button progress and disabled state;
- safe setup message;
- typed failure detail and copy/recovery controls.

Only protected persistence/deletion outcomes may float. A validation or storage
failure already shown in the form remains contextual.

### Send

Retain:

- drop-target availability;
- batch list mutations;
- per-book checking, preparing, ready, needs-attention, sending, submitted,
  failed, cancelled, and unknown states;
- aggregate progress/counts;
- expanded item diagnostics;
- retry and send-more actions;
- delivery-unknown warning and reset confirmation.

No normal send lifecycle card is required.

### History

Retain:

- loading state;
- unavailable state and retry;
- centered empty state;
- newest-first list and count;
- clear confirmation and resulting content state;
- typed failure detail.

Only failure to persist a record after SMTP acceptance may float because it is
separate from the visible delivery result.

### Shortcut Settings

Retain:

- recorder value;
- enabled switch;
- registered, disabled, or conflict state;
- typed failure detail and alternate-shortcut recovery.

Changing the control must not produce a card.

## Failure-detail contract

- A contextual failure remains queryable after any card is closed or expires.
- Copying its sanitized details may produce an independent `diagnosticCopy`
  card without replacing the failure scope.
- A card action may focus/reveal the detail but cannot become its only storage.
- Raw exceptions, provider text, credentials, paths, and book content remain
  prohibited.

## Accessibility contract

- Contextual controls and states retain meaningful labels and values.
- Status changes remain understandable without color or card presence.
- Suppressed actions produce no redundant floating announcement.
- Eligible invisible outcomes announce once without stealing focus.
- Delivery uncertainty remains announced through durable batch content and is
  never reclassified as success.

## Acceptance invariant

For every suppressed event, a test must identify the contextual element that
communicates the result. If no such element exists and omission would be
consequential, the event must either gain durable contextual evidence or receive
an explicitly reviewed floating reason.
