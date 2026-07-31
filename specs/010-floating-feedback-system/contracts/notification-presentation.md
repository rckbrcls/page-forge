# Contract: Floating Notification Presentation

## Purpose

Define one reusable in-window presentation for concise action feedback without
moving underlying content or creating a third product surface.

## Host contract

Book Sender exposes exactly two hosts:

| Host identifier | Destination | Composition root |
|---|---|---|
| `notification.host.main` | `main` | `MainWindowContent` |
| `notification.host.settings` | `settings` | `BookSenderSettingsView` |

Each host:

- is an overlay aligned to the upper trailing content edge below the toolbar;
- remains inside its own window bounds;
- does not participate in form, list, tab, or primary-action layout;
- renders only entries matching its exact destination;
- displays at most three cards;
- appears below native sheets and alerts in interaction priority;
- attaches/detaches its destination lifecycle on scene appearance/disappearance;
- adds no route, scene, Settings tab, notification center, or persisted history.

## Card contract

Each `FloatingNotificationCard` renders, in order:

1. optional icon or progress indicator;
2. title and/or supporting message;
3. optional occurrence count;
4. optional single action button;
5. optional close button.

At least one of title or supporting message must be non-empty.

### Accessibility identifiers

| Element | Identifier |
|---|---|
| Host | `notification.host.<destination>` |
| Card | `notification.<scope accessibility identifier>` |
| Close control | `notification.close.<scope accessibility identifier>` |
| Action control | `notification.action.<scope accessibility identifier>` |
| Occurrence count | `notification.count.<scope accessibility identifier>` |

The existing `feedback.*` identifiers are removed after UI tests migrate.

## Visual contract

- Use a compact native adaptive material.
- Use semantic primary/secondary foreground styles.
- Use a subtle system-adaptive border and restrained elevation.
- Do not use a fixed light/dark background or bespoke theme.
- Do not give the card a prominent primary-action glass treatment.
- Keep card width bounded so it does not extend into the central workflow.
- Wrap essential title/message text; cap nonessential supporting lines.
- Keep stack spacing consistent and prevent card overlap.
- The newest visible card is closest to the upper trailing anchor.
- Reduce Motion removes spatial movement.
- Reduce Transparency and Increase Contrast retain readable surfaces, controls,
  borders, and focus indicators.

## Eligible feedback

Floating notification coverage includes:

- main application action acknowledgements;
- onboarding or Settings delivery setup actions;
- shortcut registration/change/disable/failure;
- book intake, add, remove, and clear acknowledgements;
- batch-level preparation/confirmation/delivery summaries;
- history clear/load/record action feedback;
- diagnostic-copy success/failure;
- update-check acknowledgement.

## Contextual feedback that remains inline

The host MUST NOT replace:

- delivery field validation;
- blocking form guidance;
- active setup save progress in its button;
- batch preparation/sending progress;
- `BatchItemRow` state;
- aggregate counts and delivery-unknown guidance;
- `FailureDetailView`;
- history loading/unavailable/empty/list states;
- confirmation sheets and alerts;
- the delayed bootstrap placeholder.

## No-layout-shift acceptance

For each host, record the frames of representative underlying controls before,
during, and after a card:

- main drop target;
- batch card;
- main primary action;
- Settings delivery field;
- shortcut recorder and switch;
- history empty/list content and clear action.

Frame origin and size must remain equal within normal test precision.

## Modal precedence

When a native sheet or alert is present:

- modal controls remain hittable;
- card controls behind the modal cannot become the active decision path;
- keyboard focus remains in the modal;
- the card is not duplicated into the modal;
- dismissing the modal does not restart notification lifetime.

## Completion conditions

The presentation contract is complete when:

- both roots have one host each;
- no feature view embeds `ActionFeedbackView`;
- all eligible scopes appear in the correct host;
- underlying content does not move;
- contextual state and modal presentation remain unchanged.
