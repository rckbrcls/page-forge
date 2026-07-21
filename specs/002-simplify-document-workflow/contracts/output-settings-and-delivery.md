# Output, Settings, and Delivery Contract

**Feature**: `002-simplify-document-workflow`  
**Audience**: Workflow UI, filesystem integration, Settings, and delivery services

## Primary Output Actions

The main workflow exposes exactly two primary post-preparation actions:

- `Save Files`
- `Send to Kindle`

Both operate only on selected rows with readable prepared outputs. Ineligible rows
remain unchanged and are not silently substituted with source files.

## Save Files

### Interface

```text
PreparedOutputExporting.export(
    outputs: [PreparedOutput],
    destinationDirectory: URL,
    conflictPolicy: OutputConflictPolicy
) -> [ExportResult]
```

### Behavior

1. Ask the user for one local destination directory.
2. Revalidate every selected prepared output.
3. Copy each output into that directory using its existing filename.
4. Report success or failure per file.
5. Never move or delete the source or prepared output.

### Conflicts

- Default is `failIfExists`.
- Existing files are never overwritten silently.
- Non-conflicting files still copy when another output conflicts.
- A conflict returns `needsAttention`-style feedback with Choose Another Folder,
  Reveal File, or an explicit replace-and-retry path.
- Replace is allowed only after user confirmation and applies only to identified
  conflicts.

## Send to Kindle

### Preconditions

Before the first attachment is sent:

1. A profile is explicitly selected.
2. The profile exists and is structurally valid.
3. Its Keychain secret exists.
4. At least one selected prepared output is readable and eligible.

If profile preflight fails, no file is sent and the recovery action opens Settings.

### Execution

- Send selected outputs in stable queue order through existing
  `DeliveryService.send` calls.
- Return one `DocumentDeliveryResult` per output.
- Continue after per-file network or SMTP failures unless the user cancels pending
  sends.
- Preserve earlier successful results when a later send fails.
- Never log SMTP passwords, tokens, raw Keychain data, or secret-bearing commands.
- Oversized attachments fail with a specific message before network submission
  when the configured delivery limit is known.

## Settings Scene

`PageForgeApp` declares one native `Settings` scene. The main toolbar uses
`SettingsLink`.

Requirements:

- Activating Settings opens the window or focuses the existing instance.
- Standard app-menu Settings behavior and shortcut remain available.
- Settings receives the shared app services and theme manager.
- Queue rows, selection, progress, and outputs are owned by the main workflow and
  are neither recreated nor transferred into Settings.
- Opening or closing Settings does not cancel work.

## Settings Content

The separate window contains:

- Appearance preference.
- Calibre tool status and recovery guidance.
- Named delivery profile management and default profile selection.
- Boolean secret-presence status; never the stored secret value.
- Relevant default output preference.
- App and Calibre update guidance as separate concerns.
- Troubleshooting/log access.
- Secondary Amazon Send to Kindle handoff without login/upload automation.

## Secret Contract

- SMTP password/token values remain in Keychain under a profile-scoped key.
- App config stores only non-secret profile fields.
- UI may show whether a secret exists, not its value after save.
- Errors, progress, logs, test fixtures, and debug descriptions must redact
  credential content.

## Queue Preservation

Settings may update config used by later actions. It does not mutate active queue
state. If a default profile changes while preparation is running, a future send
uses the profile explicitly selected at send time.

## Accessibility and Feedback

- Save and Send expose accurate disabled states.
- Progress and result text identify the affected filename.
- Success/failure never relies only on color.
- A profile error includes an Open Settings action accessible by keyboard.
- Routine per-file failures appear inline; blocking alerts are reserved for
  destructive replace confirmation or an action that cannot otherwise continue.
