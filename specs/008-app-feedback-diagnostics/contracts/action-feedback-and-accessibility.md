# Contract: Action Feedback and Accessibility

## Purpose

Define observable feedback for every accepted action without adding a primary
screen, global activity center, or persistent feedback or diagnostic history.
The bounded send history defined by Feature 009 is outside this contract.

## General lifecycle contract

For every supported action:

1. acceptance creates or updates one `ActionFeedback`;
2. noticeable work exposes `inProgress` with an honest action label;
3. completion produces one terminal state;
4. the terminal message identifies what completed or what did not;
5. the same unchanged state does not create a duplicate notice or
   accessibility announcement;
6. a retry starts a new lifecycle identity.

Immediate actions may acknowledge and complete in the same main-actor update,
but the resulting terminal feedback must remain perceivable.

## Action coverage

| Action | Acknowledgement/progress | Required terminal feedback |
|---|---|---|
| Restore application | Loading saved setup | Ready, setup required, or actionable startup failure |
| Save new setup | Saving setup | `Setup saved. App password stored securely.` or specific save failure |
| Edit setup | Saving setup | Updated secure-save confirmation or specific failure |
| Delete setup | Removing setup | Setup removed or specific preference/credential failure |
| Save shortcut | Saving shortcut | Shortcut saved, conflict, or registration failure |
| Clear shortcut | Clearing shortcut | Shortcut cleared or specific failure |
| Add books | Checking selected books | Count accepted plus per-item blocked outcomes |
| Remove book | Immediate | Book removed |
| Clear batch | Immediate | Batch cleared |
| Confirm batch | Confirming batch | Batch confirmed or explanation of blocked items |
| Prepare EPUB | Checking/preparing/revalidating | Ready, needs attention, blocked, cancelled, or failed |
| Validate PDF | Checking PDF | Ready, blocked, cancelled, or failed |
| Send one book | Connecting/securing/authenticating/sending | Submitted, rejected, cancelled, failed, or delivery uncertain |
| Send batch | Aggregate plus per-item progress | Submitted count and all non-success outcomes |
| Cancel operation | Cancelling | Cancelled, already completed, or delivery uncertain |
| Dismiss confirmation | Immediate | Return to editable batch state without stale success/failure banner |
| Copy error details | Copying | `Error details copied.` or clipboard write failure |
| Check for updates | Sparkle standard UI | Standard no-update, available-update, progress, or error state |

Exact visible wording beyond the required setup and copy confirmations is owned
by the presentation catalog and localized UI copy, not adapters.

## Batch contract

- The aggregate state is derived from the stable set of confirmed items.
- Every item preserves one understandable terminal outcome.
- One item failure does not erase completed results or stop later items unless a
  batch-level safety or cancellation rule requires it.
- Aggregate progress reports completed count and total count.
- A mixed batch terminal state is `partial`.
- Repeated identical failure presentation may group occurrences, but the user
  can still identify which items need attention.
- Cancellation stops pending scheduling and waits for the active item's
  cooperative terminal outcome.

## Visibility and dismissal

- Success may not disappear in the same update that clears or resets input.
- Setup save success remains until another setup action or explicit dismissal.
- Error and unknown feedback remains until recovery, replacement, or explicit
  dismissal.
- Progress is replaced by terminal feedback, not stacked with it.
- Routine healthy pipeline detail stays collapsed.
- Expanded evidence is available only when it explains a failure, blocked item,
  restoration, uncertainty, or decision.

## Controls

Every actionable control must expose:

- default, hover, focus, pressed, disabled, and loading behavior;
- a visible and accessible name;
- a non-obvious disabled reason through help text and accessibility hint;
- one obvious primary action and quieter secondary actions;
- keyboard reachability without changing existing shortcut behavior.

Controls cannot rely on color alone for status or severity.

## Accessibility announcements

Announce important transitions:

- noticeable in-progress work;
- setup/shortcut save success;
- failure;
- cancellation;
- partial completion;
- delivery uncertainty.

Each announcement:

- identifies the affected action or item;
- states the current outcome;
- includes a recovery direction when the state requires user action;
- is emitted once per feedback identity/state pair;
- does not include stable codes or technical detail unless the user opens
  details;
- respects bounded batch behavior by preferring aggregate progress and terminal
  per-item failures over announcing every routine item transition.

The visual feedback remains present even when an accessibility announcement is
posted. Announcements are supplemental, not the only representation.

## Acceptance checks

- Every action in the coverage table has a deterministic lifecycle test.
- Setup-save UI tests observe the success confirmation after the secret field is
  cleared.
- Repeated observation of one failure emits one notice and one announcement.
- A 20-item mixed batch preserves all item outcomes and understandable aggregate
  progress.
- UI tests verify labels, hints, focus order, and readable text under supported
  accessibility settings.
