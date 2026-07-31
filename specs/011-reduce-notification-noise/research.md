# Research: Essential Notification Feedback

## Scope and evidence

Research covered Feature 011, Book Sender Constitution 8.0.0, Feature 010's
notification contracts, every production feedback action, `AppModel` lifecycle
helpers, `ActionFeedbackService`, `FloatingNotificationCenter`, the four feature
views that consume notification feedback, shortcut publication, application and
UI tests, UI-test launch fixtures, README, desktop migration guidance, and
troubleshooting documentation.

Two read-only repository inspections were independently verified against
representative source and test files. The inventory found twenty typed feedback
actions, sixteen redundant production paths, and four current action paths that
meet the reduced invisible-side-effect policy. All planning unknowns are
resolved below.

## Decision 1: Preserve semantic feedback and reduce only its floating projection

**Decision**: Continue creating and reconciling `ActionFeedback` for every
existing workflow action. Suppress only the projection into
`FloatingNotificationCenter`.

**Rationale**: `feedbackByScope`, sanitized failures, diagnostics, and terminal
state are part of application truth and existing tests. Removing entire
lifecycles would erase contextual failure details and complicate diagnostics.

**Alternatives considered**:

- Delete redundant `beginFeedback` and `finishFeedback` calls: rejected because
  semantic failure, occurrence, diagnostic, and contextual state would be lost.
- Keep publishing and hide cards in the host: rejected because hidden events
  would still consume queue capacity, schedule tasks, and produce accessibility
  work.
- Filter inside the card: rejected because presentation would already have been
  enqueued and announced.

## Decision 2: Use an explicit publication intent with contextual default

**Decision**: Add a typed publication intent with `.contextual` as the default
and `.floating(reason)` as an explicit opt-in. Require a bounded reason for every
floating publication.

**Rationale**: An explicit opt-in makes the approved catalogue reviewable and
prevents future actions from inheriting notifications automatically. A reason
also provides a stable unit-test and documentation contract for FR-026/FR-027.

**Alternatives considered**:

- Infer from `FeedbackState`: rejected because visible failures and successes
  are still redundant.
- Infer only from `FeedbackAction`: rejected because one action may have a
  visible validation failure but an invisible successful side effect.
- Detect whether a view or row is visible at runtime: rejected because scroll,
  window, and accessibility state would make product meaning unstable.
- Maintain an untyped allowlist of strings: rejected because it is not
  exhaustive or concurrency-safe.

## Decision 3: Publish approved outcomes only when terminal

**Decision**: Never publish `acknowledged` or `inProgress` production feedback.
Only an explicitly opted-in terminal result may enter the floating center.

**Rationale**: Every current active operation already has contextual state: save
button progress, batch phase and rows, confirmation sheets, history loading,
shortcut controls, or update UI. Showing only the terminal invisible result
eliminates the noisy progress-to-terminal card lifecycle.

**Alternatives considered**:

- Show progress for approved clipboard/setup actions: rejected because these
  operations are short and their controls already communicate activation.
- Publish all failures: rejected because field errors, row failures, unavailable
  history, and delivery uncertainty are already durable and actionable.
- Publish all successes for reassurance: rejected because most successes are
  directly visible as a changed list, route, control, row, or modal.

## Decision 4: Decouple durable contextual evidence from the floating center

**Decision**: Feature views retrieve contextual `ActionFeedback` from
`AppModel.feedback(for:)`. They do not depend on
`FloatingNotificationCenter.feedback` for failure evidence.

**Rationale**: The current views use notification entries to populate
`FailureDetailView`. If a redundant card is suppressed, expired, closed, or its
host detaches, the same lookup may disappear even though the contextual failure
must remain. Semantic state and presentation visibility need independent
lifecycles.

**Alternatives considered**:

- Keep duplicate notification entries hidden indefinitely: rejected because it
  preserves the wrong ownership and leaves queue/state complexity.
- Copy failures into view-local state: rejected because views would own business
  lifecycle and diverge between main and Settings.
- Let the center keep a second semantic store: rejected because
  `feedbackByScope` already provides that source without duplication.

## Decision 5: Keep four current production action paths eligible

**Decision**: The implementation opts in only:

1. successful setup/credential persistence;
2. setup deletion success or partial Keychain outcome;
3. diagnostic-copy success or failure;
4. history persistence failure after definitive SMTP acceptance.

**Rationale**: Clipboard and protected credential changes are invisible. A
history write failure after accepted SMTP delivery is a separate hidden failure
whose omission could mislead the user. All other current actions have contextual
evidence.

**Alternatives considered**:

- Keep batch delivery completion: rejected because per-book states, aggregate
  count, retry controls, and send-more state already communicate it.
- Keep shortcut success/conflict: rejected because the recorder, switch, and
  registration status communicate the result.
- Keep history load/clear results: rejected because loading, unavailable, list,
  count, alert, and empty state communicate them.
- Keep update-check acknowledgement: rejected because the standard update
  interface is the visible result.

## Decision 6: Clear stale cards when a newer contextual action begins

**Decision**: Starting a new action removes any older floating presentation for
the same scope and destination even when the new action is contextual and will
not publish a replacement card.

**Rationale**: Otherwise a short-lived setup-save success or persistent hidden
failure could remain visually associated with a newer validation attempt or
contextual action. Semantic feedback remains stored independently.

**Alternatives considered**:

- Wait only for temporary expiry: rejected because stale content can contradict
  a new visible state.
- Remove all cards in the window: rejected because independent invisible
  outcomes must retain their own identity.
- Reuse the old card for contextual progress: rejected because it recreates the
  notification noise being removed.

## Decision 7: Preserve synthetic component tests outside production policy

**Decision**: Existing UI-test launch scenarios for configuration matrix,
stack/queue, and appearance continue publishing directly to the center. They do
not pass through production eligibility.

**Rationale**: The component still promises configurable icons, actions, close
controls, lifetime, queueing, window isolation, accessibility, and Liquid Glass
appearance even though normal production traffic becomes sparse.

**Alternatives considered**:

- Delete broad component tests: rejected because it would weaken the reusable
  contract.
- Route fixtures through production policy: rejected because synthetic states
  would either be suppressed or silently expand the catalogue.
- Keep workflow tests expecting noisy cards: rejected because they would encode
  the behavior Feature 011 explicitly removes.

## Decision 8: Test the classification exhaustively

**Decision**: Add a table-driven unit test covering all twenty
`FeedbackAction` cases and relevant terminal states. Pair it with AppModel and UI
journeys that assert semantic/contextual evidence plus absence or presence of a
floating entry.

**Rationale**: The main regression risk is not component rendering; it is an
unreviewed producer becoming eligible or suppression accidentally erasing
meaning. Exhaustive classification and end-to-end silence checks address both.

**Alternatives considered**:

- Rely on a small set of screenshots: rejected because queued or invisible
  entries and accessibility announcements could remain unnoticed.
- Test only `FloatingNotificationCenter`: rejected because the center correctly
  accepts whatever it is given and does not own product eligibility.
- Use real time in unit tests: rejected because existing controlled sleepers and
  state inspection are deterministic.

## Decision 9: Add no dependency, storage, or pipeline change

**Decision**: Keep the current package set, project structure, in-memory center,
Keychain contract, history store, diagnostic system, preparation pipeline, SMTP
state machine, and release configuration unchanged.

**Rationale**: Feature 011 is an application-presentation policy correction.
Broader changes would add risk without contributing to notification reduction.

**Alternatives considered**:

- Add user notification preferences: rejected as product expansion and because
  eligibility should be a product rule, not an end-user burden.
- Persist notification decisions/history: rejected by privacy and lightweight
  product constraints.
- Replace the component or add a toast package: rejected because Feature 010's
  reusable native component already satisfies presentation needs.

## Resolved technical context

- Swift language mode: 6.0 with complete concurrency checking.
- Platform: macOS 26.0+.
- Product hosts: main window and Settings, sharing one `AppModel`.
- Policy owner: application presentation, not SwiftUI views or domain/adapters.
- Production default: contextual silence.
- Production progress notifications: none.
- Current eligible paths: four action paths, bounded by six possible reasons.
- Persistent storage: none added.
- Dependencies/project membership: unchanged.
- Component fixtures: retained behind existing UI-test launch arguments.
- Agent context: `.specify/feature.json` plus plan artifacts; installed Spec Kit
  0.12.9 Codex integration has no update-agent-context script.
