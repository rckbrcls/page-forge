# Intake and Toolbar Contract

**Feature**: `002-simplify-document-workflow`  
**Audience**: App shell, Workflow feature, and document intake domain code

## Main Window

- The main window contains one workflow and no sidebar destination list.
- Empty queue: the preserved large `FileDropIntakeView` is the dominant element.
- Non-empty queue: the document list is dominant; intake remains available from
  the toolbar, File menu, keyboard, and an appropriately quiet in-content action.
- Adding files never starts preparation automatically.

## Toolbar

The standard window toolbar contains only:

1. `Add Files` — clickable, keyboard-accessible, and drop-capable.
2. `Settings` — a `SettingsLink` to the native Settings scene.

`Add Files` requirements:

- The complete label/control is the drop target, not only the symbol glyph.
- A valid drag produces targeted visual feedback.
- Click opens a multi-file importer.
- Drop appends files to the current queue.
- Help text and an accessibility label describe both click and drop behavior.
- The command is also available as `File > Add Files…` with a keyboard shortcut.
- If toolbar space is constrained, the command remains available through toolbar
  overflow and the File menu.

The toolbar is a secondary convenience. The main drop component remains required.

## File Importer

- Allows multiple selection.
- System filtering includes EPUB, MOBI, and PDF content types.
- The returned collection is passed to the shared intake contract once.
- Security-scoped access is acquired and balanced for sandboxed URLs.
- Cancellation changes no queue state and is not reported as an error.

## Drop Handling

- Large area and toolbar accept all provided file URLs, not only the first.
- Provider callbacks may resolve asynchronously; outcomes return in original
  provider order.
- A partial provider failure does not discard resolved files.
- File promises, aliases, and remote placeholders are accepted only after they
  resolve to a readable local regular file.

## Domain Intake Interface

```text
DocumentIntakeService.intake(
    urls: [URL],
    existingIdentities: Set<String>
) -> IntakeSummary
```

For every URL, the service:

1. Resolves a local standardized/canonical identity.
2. Checks existence, regular-file status, and readability.
3. Determines EPUB, MOBI, or PDF.
4. Rejects unsupported types and directories.
5. Rejects identities already queued or duplicated inside the same intake.
6. Returns a `DocumentItem` or an explicit rejection.

No valid item is discarded because another item fails validation.

## Canonical Identity

Identity resolution uses, in order:

1. File resource identifier when available.
2. Standardized absolute file URL with symlinks resolved.
3. Case-normalized path fallback appropriate to the local volume.

The original user URL remains available for display and security-scoped access.

## Queue Mutation

- Accepted items append in stable intake order.
- Existing selection and progress do not reset.
- New items added during processing remain `queued` and are not silently included
  in the already-started selected operation.
- Remove deletes only the queue record; it never deletes a source or output file.
- Select All affects current rows only.

## Feedback

After intake, show a concise accepted/rejected count. Rejections must name the
affected entry and one reason. Routine partial rejection does not use a blocking
alert.

## Accessibility

- Drag-and-drop always has chooser, menu, and keyboard alternatives.
- Status never relies only on color or an icon.
- Icon-only compact representations retain accessible labels and help.
- Focus remains visible for Add Files, Settings, queue rows, and primary actions.
