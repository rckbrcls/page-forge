# Contract: Approved Production Notification Catalogue

## Purpose

Provide an exhaustive review of current `FeedbackAction` cases and the terminal
outcomes allowed to reach the floating notification center.

## Current action classification

| Feedback action | Classification | Eligible terminal outcome/reason | Contextual evidence |
|---|---|---|---|
| `restoreApplication` | contextual | none | route, setup screen, send screen, bootstrap state |
| `saveDeliverySetup` | mixed | succeeded / protected credential persistence | field errors, form failure detail, save-button progress; only secure persistence confirmation floats |
| `deleteDeliverySetup` | notify | succeeded or partial / protected credential deletion | reset form is visible; Keychain result is invisible |
| `saveShortcut` | contextual | none | recorder, switch, registration status, failure detail |
| `clearShortcut` | contextual | none | switch and registration status |
| `addBooks` | contextual | none | drop target, batch phase, rows, item details, aggregate result |
| `removeBook` | contextual | none | row disappears |
| `clearBatch` | contextual | none | list and primary action reset; failure remains contextual |
| `startAnotherSend` | contextual | none | terminal list resets and drop target becomes available |
| `confirmBatch` | contextual | none | confirmation sheet appears or remains absent |
| `prepareBook` | not applicable to floating production | none | per-book preparation state and detail |
| `sendBook` | not applicable to floating production | none | per-book delivery state and detail |
| `sendBatch` | contextual | none | aggregate and per-book delivery outcomes |
| `cancelOperation` | contextual | none | batch phase, row outcome, aggregate uncertainty guidance |
| `dismissConfirmation` | contextual | none | modal dismissal is visible |
| `copyErrorDetails` | notify | succeeded or failed / clipboard write | original diagnostic remains visible; clipboard result is invisible |
| `checkForUpdates` | contextual for current success | no current eligible producer | standard update interface; future typed open failure may use auxiliary-system failure |
| `loadHistory` | contextual | none | loading, unavailable, empty/list state, retry control |
| `recordHistory` | notify on failure only | partial or failed / submission-history persistence | delivery success remains visible; history persistence failure is otherwise hidden |
| `clearHistory` | contextual | none | alert, list/count, empty state, unavailable/failure context |

## Current approved producers

| Producer | Destination | Lifetime | Controls |
|---|---|---|---|
| Delivery setup save success | originating main or Settings | temporary, default four seconds, maximum five | close according to existing success policy; no required recovery |
| Delivery setup deletion success | Settings | temporary, default four seconds, maximum five | close according to existing success policy |
| Delivery setup deletion partial Keychain result | Settings | persistent | close; contextual setup state remains unchanged |
| Diagnostic-copy success | originating main or Settings | temporary, default four seconds, maximum five | close according to existing success policy |
| Diagnostic-copy failure | originating main or Settings | persistent | close; original diagnostic remains visible |
| Submission-history persistence failure | main | persistent | close; delivery success remains definitive and history is not retried automatically |

## Reserved reasons without current producers

- `consequentialHiddenFailure`: requires a future explicit call site and proof
  that no contextual evidence exists.
- `auxiliarySystemActionFailure`: requires a typed failure callback for an
  explicitly requested auxiliary/system interface. Successful opening remains
  contextual.

Reserved reasons do not authorize inference or fallback publication.

## Prohibited production cards

No production card may be emitted for:

- application opening or readiness;
- file-picker cancellation;
- adding, preparing, removing, or clearing books;
- readiness or needs-attention batch summaries;
- confirmation preparation, availability, or dismissal;
- send/retry progress or terminal delivery summary;
- cancellation or delivery unknown already shown in the batch;
- reset for another send;
- history load, refresh, clear success, or contextual clear failure;
- shortcut registration/change/disable/conflict;
- successful update-interface opening;
- field validation or inline failure detail.

## Review invariant

The number of approved categories may not exceed the six reasons in the model
without a later specification change. The number of current producers may be
smaller. Test-only cards do not count as production categories.
