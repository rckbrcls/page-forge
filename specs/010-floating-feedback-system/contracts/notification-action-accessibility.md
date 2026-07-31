# Contract: Notification Actions and Accessibility

## Purpose

Keep floating feedback understandable and operable by pointer, keyboard, and
assistive technology without storing unsafe closures or stealing workflow
focus.

## Typed action contract

`NotificationActionDescriptor` contains:

- stable action identifier;
- non-empty English label;
- one existing typed `RecoveryAction`;
- post-activation policy (`keep`, `hide`, or `awaitReplacement`).

It contains no closure, arbitrary selector, URL, script, serialized command, or
untyped string action.

## Scene-root dispatch

The host reports the typed action to its owning scene root on the main actor.
The root resolves it through an exhaustive switch:

| Action family | Expected owner |
|---|---|
| Edit delivery setup | Main/Settings root plus Settings selection/open action |
| Choose another shortcut | Settings root plus shortcut focus request |
| Choose/review another book | Main root and current batch UI |
| Retry failed | Main `AppModel` batch command |
| Confirm unknown retry | Existing explicit main confirmation path |
| Retry history load/clear | Main `AppModel` history command |

Unsupported commands for a destination perform no unrelated fallback and leave
the card available.

## Focus request contract

Actions needing a view-local focus target publish a
`NotificationFocusRequest`:

- request has a fresh identity;
- destination and `RecoveryAction` are explicit;
- only the matching visible view consumes it;
- consumption moves focus intentionally and exactly once;
- a stale request cannot refocus after navigation;
- no notification appearance itself publishes a focus request.

## Close contract

Close is presentation-only:

- label is `Dismiss notification`;
- it closes/hides only the owning card;
- it never invokes the card action;
- it never cancels pipeline work;
- it never clears history, setup, credentials, batch, diagnostics, or failure;
- it never retries or reclassifies delivery.

## Keyboard contract

- Card itself is not a focus stop unless it has interactive controls.
- Action precedes close in deterministic tab order.
- Each interactive control has visible focus.
- Return/Space activates the focused control once.
- Key repeat cannot bypass `isActionInFlight`.
- Removing another card does not reset current workflow focus.
- When a focused card is removed, focus returns to the nearest valid workflow
  context rather than disappearing into an off-screen host.

## Announcement contract

On first visible publication of a meaningful state:

- announce action outcome once;
- combine title and safe supporting message;
- expose semantic state as accessibility value;
- omit technical codes unless the user opens contextual details;
- do not announce color or icon name;
- do not announce queue position/count.

Do not announce:

- acknowledged placeholder state;
- queued entries before they become visible;
- unchanged reconciliation;
- expiry or manual close;
- stack reorder alone.

Replacement is announced only when identity or semantic state independently
warrants it.

## Reading order

Within one card:

1. icon is hidden when text already supplies meaning;
2. title;
3. supporting message;
4. occurrence count;
5. action;
6. close.

Within the host, cards follow visible visual order. Host itself is a container,
not a redundant announced status.

## Appearance accessibility

### Reduce Motion

- no trailing slide;
- no spring/bounce;
- use identity or restrained opacity;
- state replacement remains textual and immediate.

### Reduce Transparency

- adaptive fallback surface preserves text/control contrast;
- no meaning depends on seeing content through the card.

### Increase Contrast

- border, controls, focus, icon, and text remain distinguishable;
- divider and card border do not overpower warning/error state.

## Temporary action rule

A temporary card may expose an action only when:

- the action is nonessential;
- the same required recovery or next step remains in contextual UI;
- expiry does not leave the user blocked;
- the card still disappears by five seconds.

Essential recovery always uses a persistent/explicit card.

## Delivery-unknown safety

An unknown card:

- uses uncertainty text/icon;
- remains persistent or explicit;
- may offer review/check/confirmation only;
- never offers automatic retry;
- never says submitted, delivered to Kindle, processed, or available;
- closing the card does not clear the per-book unknown result or bypass the
  existing acknowledgement required before another send.

## Test requirements

- one announcement per meaningful identity/state;
- no announcement on expiry;
- unchanged feedback is silent;
- close/action labels are English and meaningful;
- keyboard activation is single-shot;
- focus is not stolen on appearance;
- local focus request is intentional and consumed once;
- main actions do not execute in Settings and vice versa;
- temporary actions have a durable alternate path;
- unknown actions cannot trigger retry or success reclassification.
