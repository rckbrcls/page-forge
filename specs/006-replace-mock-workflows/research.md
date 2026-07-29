# Research: Replace Mock Workflows

## Evidence baseline

The existing native target already contains real setup validation, protected
credential storage, shared `[URL]` intake, UUID workspaces, partial archive/XML
boundaries, typed batch models, an actor skeleton, Settings, shortcut
registration, and MIME streaming. The remaining preview route bypasses those
services, while confirmed delivery is still a placeholder.

Repository evidence was inspected directly. A requested AGY Relay exploration
timed out without returning evidence, so two bounded native read-only research
passes covered runtime/architecture and tests/configuration/documentation. Every
material conclusion below was checked against representative source files.

## Decision 1: Finish the current native target in place

**Decision**: Treat feature 006 as an incremental production cutover inside the
existing `BookSender` app/test targets. Add no package, target, service, helper,
or alternative product.

**Rationale**: The project already pins every approved dependency and uses
filesystem-synchronized groups. The missing work is behavioral completeness and
test evidence, not project scaffolding.

**Alternatives considered**: Rebuilding another target would duplicate the
product; retaining a preview mode would preserve false behavior; a third-party
SMTP or ebook engine would weaken the required protocol and safety boundaries.

## Decision 2: Delete preview behavior rather than feature-flag it

**Decision**: Remove `isPreviewingSendBook`, preview items/intake, setup bypass,
return navigation, alternate row initializer, accessibility identifiers, and
preview-only tests. Do not keep preview behind launch arguments or debug flags.

**Rationale**: Preview marks files ready by extension alone and bypasses setup,
local preparation, and delivery. Keeping it in production source risks state
divergence and violates the two-screen route contract.

**Alternatives considered**: Hiding the button leaves dead mock logic and tests;
converting it to a developer mode creates a second behavior path; screenshots can
use deterministic UI-test stores without production preview state.

## Decision 3: Make setup persistence revision-safe

**Decision**: A usable setup requires valid non-secret preferences and a readable
credential reference. Password replacement creates a new revision-scoped
Keychain reference, commits preferences, then deletes the old reference. Blank
password edits reuse the old reference.

**Rationale**: The current Keychain-first update can overwrite an existing item
and then delete it if preference persistence fails. Unique references make
rollback one-directional and preserve the last valid setup.

**Alternatives considered**: Preference-first persistence can leave a reference
to a missing secret; testing SMTP during Save conflates local configuration with
network/provider availability; storing the secret in preferences is prohibited.

## Decision 4: Keep one actor-owned batch source of truth

**Decision**: `PipelineActor` owns intake, preparation scheduling, confirmed
snapshots, delivery, cancellation, and retry. `AppModel` only projects typed actor
state to SwiftUI and sends commands back.

**Rationale**: The current actor and `AppModel.items` can diverge; delivery events
are not projected into rows. One authoritative actor makes sequencing,
cancellation, stable confirmation, and completed-result preservation testable.

**Alternatives considered**: Continuing dual mutation requires manual
reconciliation; moving domain work into views violates the dependency boundary;
parallel task groups violate ordered bounded execution.

## Decision 5: Return typed intake outcomes and byte evidence

**Decision**: Shared intake returns one ordered outcome per selected URL. Accepted
files receive a staged-byte digest; duplicates, unsupported inputs, access
failures, source changes, size failures, and capacity failures become sanitized
excluded items or aggregate actions rather than disappearing silently. PDF
eligibility checks signature, size, snapshot stability, and attachment limit
without modifying content.

**Rationale**: Real selection must explain why an item did not become eligible
and prove that the prepared attachment is the staged immutable bytes.

**Alternatives considered**: Extension-only acceptance is insufficient; hashing
the original outside the security-scoped copy can race; silently dropping files
prevents one outcome per selection and weakens accessibility.

## Decision 6: Always write and revalidate an EPUB delivery copy

**Decision**: Healthy and deterministically repairable EPUBs are written to a
separate bounded working copy, reopened through the same safety adapter,
re-audited, compared, digested, and promoted. Blocked or unsafe EPUBs are never
written or sent.

**Rationale**: The feature specification requires separate-copy writing and
revalidation before EPUB eligibility. It also makes the actual attachment
evidence explicit and keeps the original immutable.

**Alternatives considered**: Sending the staged original after the first audit
skips the required post-write gate; full extraction is unsafe; marking applied
actions verified without checking postconditions is not evidence.

## Decision 7: Ship only fixture-proven repair rules

**Decision**: Implement the complete audit vocabulary, but enable an automatic
repair action only when the writer executes it and a focused native fixture
proves precondition, transformation, non-application to ambiguous input, and
postcondition. Unproven actions remain blocked.

**Rationale**: The current enum advertises more rules than the audit implements,
and the writer ignores its plan except for rebuilding `mimetype`. A rule must not
ship merely because its enum case exists.

**Alternatives considered**: Broad best-effort repair violates determinism;
retaining unused automatic cases misrepresents capability; external EPUBCheck or
Calibre is forbidden.

## Decision 8: Use the pinned NIO stack for an explicit SMTP state machine

**Decision**: Add a narrow one-attempt-per-connection client over the already
pinned swift-nio and swift-nio-ssl products. Support implicit TLS, STARTTLS with a
second EHLO, TLS-only AUTH PLAIN/LOGIN, bounded replies, timeouts, streamed MIME,
dot-stuffing, and typed stage/outcome events.

**Rationale**: The repository already links NIOCore, NIOPosix, NIOSSL, and
NIOEmbedded. A purpose-built state machine preserves the exact DATA boundary
needed for `Delivery Unknown` and keeps tests deterministic.

**Alternatives considered**: A general SMTP package would hide critical protocol
state; Network.framework does not match the approved STARTTLS design; curl,
OpenSSL executables, Python, helpers, and services violate the native boundary.

## Decision 9: Keep credentials outside presentation and snapshots

**Decision**: `BookDeliveryService` reads the credential transiently only after a
confirmed snapshot exists, passes it directly to the SMTP adapter, and discards
it after the attempt. Snapshots carry setup values and an opaque reference, never
the secret.

**Rationale**: `AppModel` currently owns a credential store but does not use it.
Putting a plaintext secret in UI state, events, or long-lived snapshots would
expand the exposure surface.

**Alternatives considered**: Reading during launch or setup save retains a secret
without need; embedding it in `DeliveryAttempt` or `PipelineEvent` violates the
privacy contract.

## Decision 10: Freeze value snapshots before sending

**Decision**: Confirmation copies ordered prepared items and validated setup into
an immutable snapshot and immediately changes the batch phase. Delivery consumes
those values, not later lookups by mutable item ID.

**Rationale**: The current snapshot stores IDs while the actor remains editable,
so removal can make a confirmed item disappear silently.

**Alternatives considered**: Locking only the UI leaves actor commands callable;
looking up mutable items during send weakens explicit consent; copying book bytes
into memory is unnecessary because immutable staged references and digests are
sufficient.

## Decision 11: Separate failed retry from uncertain delivery

**Decision**: Cancellation before DATA is `Cancelled`; after DATA starts without
a definitive final reply it is `Delivery Unknown`. `Retry Failed` creates a new
explicit snapshot from definitive failures only. Unknown items require user
review and are never included automatically.

**Rationale**: Retrying uncertain delivery can create duplicate Kindle documents.
The distinction must be derived from protocol progress, not network error text.

**Alternatives considered**: Retrying all non-submitted items is unsafe; treating
every cancellation as failed loses uncertainty; automatic retry violates the
specification.

## Decision 12: Replace documentation promises with executable evidence

**Decision**: Create native deterministic fixture bytes, local source provenance,
original digests, expected findings/actions, and target-access tests. Isolate
UI-test stores instead of relying on launch arguments that production does not
consume. Add the approved suite to release gating before removing experimental
SMTP wording.

**Rationale**: Current fixture directories contain only READMEs and a manifest
pointing to removed TypeScript paths. Current UI tests depend on launch arguments
that `AppModel` does not interpret. The release workflow builds but does not run
tests.

**Alternatives considered**: Documentation-only fixture claims provide no
coverage; residual user state makes UI tests nondeterministic; publishing before
controlled and authenticated delivery gates would overstate readiness.

## Dependency acceptance

No dependency change is planned. Implementation must preserve the exact versions
already recorded in `BookSender.xcodeproj` and `Package.resolved`. Any future
version change is separate work requiring license, Swift 6, sandbox, privacy,
binary-content, and protocol-regression review.
