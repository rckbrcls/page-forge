# Contract: Transient Feedback Lifecycle

## Purpose

Remove stale successful and informational acknowledgements after a perceivable
interval while preserving active work and every outcome that remains actionable
or uncertain.

## Classification

| Feedback class | Dismissal behavior |
|---|---|
| Successful acknowledgement | Automatic after four seconds |
| Informational acknowledgement | Automatic after four seconds |
| Active progress | Remains until replaced by newer operation state |
| Validation guidance | Remains until input or action changes |
| Blocked outcome | Remains until resolved, replaced, or explicitly cleared |
| Failed outcome | Remains until recovery, replacement, or explicit dismissal |
| Cancelled outcome | Remains until replacement or deliberate clear |
| Partial outcome | Remains until recovery, replacement, or deliberate clear |
| Delivery unknown | Remains until deliberate clear or state replacement |

No automatic dismissal interval may exceed five seconds from the time the
feedback identity becomes visible.

## Scheduling contract

For every delayed feedback value:

1. publish the feedback on the main actor;
2. announce it once when its identity/state requires accessibility
   announcement;
3. cancel any expiry task for the same feedback scope;
4. create a cancellation-aware task keyed by scope and feedback identity;
5. wait four seconds through the injected sleeper;
6. return to main-actor state;
7. remove the feedback only if scope, identity, and delayed policy still match.

Task cancellation is normal control flow and creates no visible failure or
diagnostic.

## Replacement

- A newer feedback value in the same scope replaces the current value.
- Replacement cancels the current expiry task.
- The replacement receives a full independent four-second interval when it is
  also delayed.
- An old task cannot dismiss a replacement, even if cancellation races with
  wake-up.
- Equivalent lifecycle deduplication may reuse a visible feedback identity only
  when it intentionally represents the same unchanged state. A newly completed
  action receives a new lifecycle identity and interval.
- Feedback in distinct scopes expires independently.

## Navigation and application activity

- Navigating between `Delivery Setup` and `Send Book` does not convert expired
  feedback into durable state.
- Switching between `Send` and `History` does not restart visible feedback.
- If the application is inactive when the interval ends, feedback is absent on
  reactivation.
- No placeholder, reserved frame, empty banner, success icon, or stale
  accessibility value remains after removal.

## Accessibility

- Important feedback is announced once at publication.
- The announcement includes the affected action and outcome, not a technical
  code.
- Automatic visual removal does not post a second announcement.
- Replacement feedback is announced only when its identity/state transition is
  independently important.
- Status does not depend on color.

## Action coverage

Delayed success/info behavior applies to at least:

- new setup save;
- settings delivery save;
- shortcut save or clear;
- book addition acknowledgement;
- book removal;
- batch clear;
- definitive batch submission summary;
- error-detail copy success;
- history clear success.

The exact catalogue may include other successful or informational action
acknowledgements, but it cannot classify a failure or uncertainty as delayed
success merely to reduce visible state.

## Deterministic acceptance checks

- Before four seconds, the matching feedback remains visible.
- At four seconds, the matching feedback becomes eligible for removal.
- At five seconds, it is absent.
- Replacing at 3.9 seconds prevents the old task from removing the replacement.
- A replacement remains for its own full interval.
- A failed value replacing success remains after both old and new timing
  intervals.
- Two scopes may expire in either order without affecting one another.
- View recreation and tab changes do not create duplicate tasks or
  announcements.
