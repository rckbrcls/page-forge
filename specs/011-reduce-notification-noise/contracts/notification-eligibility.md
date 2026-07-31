# Contract: Notification Eligibility

## Purpose

Define the mandatory decision gate between typed semantic feedback and the
existing floating notification center.

## Eligibility predicate

A production card is allowed only when all three answers are `yes`:

1. Does a meaningful action have a terminal result the user needs to confirm or
   act upon?
2. Is the result absent from immediate durable contextual presentation?
3. Would omission leave uncertainty about an invisible side effect,
   consequential hidden failure, or required recovery location?

Any `no` means `contextual` and no card is published.

## Publication contract

- Semantic feedback is created and stored before eligibility is applied.
- Acknowledged and in-progress production states never publish.
- Contextual terminal states never publish, enqueue, announce, or schedule
  expiry.
- Floating terminal states require one approved reason.
- Card configuration is normalized only after eligibility succeeds.
- The notification center remains generic and does not infer product
  eligibility.
- UI-test component fixtures may publish directly and are outside production
  eligibility.

## Context evidence checklist

An outcome is contextual when any durable accessible element already carries
its meaning:

- field error or setup guidance;
- button loading/disabled state;
- route or visible screen change;
- batch list mutation;
- per-book preparation or delivery state;
- aggregate count or guidance;
- confirmation sheet or alert;
- history loading, unavailable, empty, list, or count state;
- shortcut recorder, switch, or registration state;
- standard auxiliary/system interface that visibly opened;
- inline failure detail or recovery control.

Scroll position alone does not make durable evidence absent. A row outside the
viewport remains contextual when it is retained in the scrollable batch and the
aggregate state communicates the outcome.

## Default and extension rule

- Every new feedback action defaults to contextual.
- Adding a floating reason requires a product specification explaining the
  invisible outcome and a test showing that no contextual evidence exists.
- Failure severity alone cannot make an event eligible.
- Success alone cannot make an event eligible.
- A notification cannot be used merely as reassurance for a visible change.

## Stale-card rule

Beginning a newer action removes the older floating presentation for the same
scope and destination even when the newer lifecycle is contextual. This removal
does not clear semantic feedback, diagnostic evidence, or workflow state.

## Accessibility rule

- Contextual events produce zero floating announcements.
- Eligible terminal events announce once when visible.
- Suppression cannot remove the accessible status or recovery of the contextual
  element that justified suppression.
- No runtime accessibility setting changes product eligibility; settings change
  only eligible card presentation.
