# Research: Simplified Document Workflow

**Feature**: `002-simplify-document-workflow`  
**Date**: 2026-07-18

## Decision 1: Use the standard SwiftUI toolbar with a drop-capable Add Files control

**Decision**: Add a standard toolbar item that acts as both an Add Files button
and a file drop target. Give the complete label/control a deliberate hit area,
targeted highlight, help text, and accessibility label. Keep the large drop area
and a File menu command with keyboard shortcut as equivalent entry paths.

**Rationale**: A toolbar item is feasible without a custom `NSToolbar`, matches
the requested macOS behavior, and keeps the toolbar to two responsibilities: Add
Files and Settings. Toolbars can be hidden, customized, or compressed, so they
cannot be the only intake path.

**Alternatives considered**:

- Custom AppKit toolbar: rejected because SwiftUI already provides the native
  contract and a custom bridge increases lifecycle and accessibility work.
- Icon-only drop target: rejected because it is less discoverable and creates a
  needlessly small target.
- Toolbar as the only intake: rejected because drag-and-drop must have chooser,
  menu, and keyboard alternatives.

**Implementation note**: Use the drop API available in the installed macOS 26
SDK. Do not raise the deployment target only to adopt a newer `DropSession`
overload. The existing `.onDrop(of: [.fileURL])` remains a valid fallback.

**Primary sources**:

- [SwiftUI toolbars](https://developer.apple.com/documentation/swiftui/toolbars)
- [Human Interface Guidelines: Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars)
- [SwiftUI drop destination](https://developer.apple.com/documentation/swiftui/view/dropdestination%28for%3Aisenabled%3Aaction%3A%29)
- [Human Interface Guidelines: Drag and drop](https://developer.apple.com/design/human-interface-guidelines/drag-and-drop)

## Decision 2: Funnel every intake channel through one multi-URL service

**Decision**: The large drop zone, toolbar drop, file importer, and File menu all
produce `[URL]` and call `DocumentIntakeService`. The service normalizes identity,
validates local readable regular files and EPUB/MOBI/PDF types, detects duplicates,
and returns one accepted or rejected outcome per input.

**Rationale**: The current `FileDropIntakeView` chooser permits only one selection
and drop handling reads only `providers.first`. Centralizing intake prevents those
channels from applying different rules and makes partial acceptance testable.

**Alternatives considered**:

- Keep `NSOpenPanel.runModal`: functional, but a multi-file SwiftUI importer fits
  the new view state better and avoids a blocking modal path.
- Separate validators in the large area and toolbar: rejected because duplicate,
  type, and readability behavior would drift.
- Accept broad `.data` values: rejected because it delays useful filtering and
  makes feedback less precise.

**Security-scoped URLs**: The implementation must call
`startAccessingSecurityScopedResource()` when needed and either retain valid
access for the operation or create a security-scoped bookmark before the importer
callback releases the URL. Drop/file-provider callbacks must preserve stable input
order even when values resolve asynchronously.

**Primary sources**:

- [SwiftUI multi-file importer](https://developer.apple.com/documentation/swiftui/view/fileimporter%28ispresented%3Aallowedcontenttypes%3Aallowsmultipleselection%3Aoncompletion%3Aoncancellation%3A%29)
- [Uniform Type Identifiers](https://developer.apple.com/documentation/uniformtypeidentifiers/)
- [Adopting drag and drop using SwiftUI](https://developer.apple.com/documentation/swiftui/adopting-drag-and-drop-using-swiftui)

## Decision 3: Use the native Settings scene and SettingsLink

**Decision**: Declare `Settings { SettingsView() }` in `PageForgeApp` and place a
`SettingsLink` in the main toolbar.

**Rationale**: On macOS this opens the Settings scene or brings its existing
window forward, satisfying the separate single-instance requirement without a
window registry. It also preserves the standard app-menu command and shortcut.

**Alternatives considered**:

- `WindowGroup`: rejected because it permits multiple Settings windows.
- Sheet: rejected because Settings must be independent from the main window.
- `Window(id:)` plus `openWindow`: usable fallback, but it recreates behavior
  already owned by the Settings scene.

**Primary sources**:

- [SwiftUI Settings scene](https://developer.apple.com/documentation/swiftui/settings)
- [SwiftUI SettingsLink](https://developer.apple.com/documentation/swiftui/settingslink)
- [OpenSettingsAction](https://developer.apple.com/documentation/swiftui/opensettingsaction)

## Decision 4: Process the queue sequentially with independent item results

**Decision**: The main-actor view model schedules selected items in stable order,
one at a time, on background work. An item failure becomes that item's result and
does not stop the queue.

**Rationale**: Existing conversion and readiness services are synchronous and
invoke external processes. Sequential orchestration is the smallest reliable
design, avoids multiple Calibre processes competing for resources, and still
satisfies responsiveness and failure isolation.

**Alternatives considered**:

- Unbounded task group: rejected due to resource spikes, result ordering, and
  cancellation complexity.
- Reuse `BatchJobRunner`: rejected because it accepts folders, instantiates its
  own services, and cannot represent the new item lifecycle.
- Put routing in the view model: rejected because format behavior must remain
  independently testable domain logic.

## Decision 5: Route PDF through conversion and then readiness preparation

**Decision**:

- EPUB → `ReadinessService.prepare`.
- MOBI → `ReadinessService.prepare`, which already converts before readiness.
- PDF → `ConversionService.convertToEPUB` in a unique temporary directory, then
  `ReadinessService.prepare` with a final path derived from the original PDF.

**Rationale**: Current readiness behavior accepts only EPUB and MOBI. Directly
passing PDF would produce an unsupported report, while conversion alone would
skip safe preparation and final readiness verification.

**Alternatives considered**:

- Expand `ReadinessService` to know every document format: rejected because it
  blurs readiness and general conversion boundaries.
- Return the converted PDF EPUB without preparation: rejected because all queue
  outputs promise the same Kindle-ready contract.

**Risk controls**: Temporary content is unique per operation, cleaned with `defer`
or equivalent best effort, never exposed as the user result, and accompanied by a
no-OCR warning for PDF inputs.

## Decision 6: Keep preparation, save, and delivery as separate state axes

**Decision**: Each document has a preparation state and independent save/delivery
results. Save copies an existing prepared output. Delivery sends the same output
through an explicitly selected profile.

**Rationale**: One monolithic state enum cannot accurately represent a document
that is prepared, saved successfully, and later fails delivery. Independent axes
also prevent output-action errors from invalidating preparation.

**Alternatives considered**:

- One combined state enum: rejected due to combinatorial cases and lost history.
- Move prepared output into the chosen save folder: rejected because move
  semantics make retry/send behavior fragile and violate source/output safety.

## Decision 7: Use narrow side-effect protocols only where tests need fakes

**Decision**: Define small preparation, export, and delivery contracts consumed by
the workflow view model. Existing concrete services conform directly or through
small adapters. Do not introduce a repository layer or general dependency
container.

**Rationale**: Current tests cover readiness, repair, and config secrets but not
queue behavior, PDF routing, export, or delivery continuation. Deterministic fakes
are needed at Calibre, filesystem, and SMTP boundaries, not throughout the app.

**Alternatives considered**:

- Inject only concrete services: rejected because failures would require real
  processes, network, and filesystem state.
- Protocolize every service: rejected because it creates abstraction without a
  test or substitution need.

## Decision 8: Preserve advanced capabilities without restoring primary navigation

**Decision**: Multi-file selection replaces a separate Batch destination. Safe
repair happens inside preparation. Metadata editing and aggressive repair remain
per-item advanced actions. Logs, dependency diagnostics, update guidance, and the
Amazon handoff remain in Settings or contextual disclosure.

**Rationale**: This preserves the constitution's capability intent while honoring
the explicit single-screen product direction. Keeping the old views merely hidden
would preserve maintenance cost and contradictory navigation concepts.

**Alternatives considered**:

- Keep the sidebar but collapse sections: rejected because it does not solve the
  requested complexity.
- Delete all supporting domain capabilities: rejected because the request targets
  interface and workflow complexity, not the ebook engine baseline.

## Resolved Risks

| Risk | Resolution |
|------|------------|
| Toolbar drop API availability | Select the compatible overload against macOS 26 SDK; retain `.onDrop` fallback |
| Tiny or hidden toolbar target | Full label hit area, targeted highlight, help, menu/keyboard action, large drop zone retained |
| Async provider order | Collect provider results by original index before intake |
| Duplicate aliases/symlinks | Canonical URL plus resource identifier when available |
| Source moves after intake | Revalidate existence/readability immediately before preparation |
| PDF support gap | Two-stage conversion and readiness preparation |
| Output collision | Never overwrite silently; return per-item attention result |
| Active Calibre cancellation | Cancel pending scheduling first; do not claim hard process cancellation |
| AppState service duplication | Construct shared service instances once and inject them into composed services |
| Dead feature screens | Remove obsolete views/view models from target after contextual behavior is relocated |

