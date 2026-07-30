# Contract: Setup, Routing, and Storage

## Setup completeness

Setup is complete only when:

1. every non-secret field validates;
2. a protected credential reference exists and is readable;
3. the non-secret setup revision is persisted successfully.

No preview, demo, fallback, launch argument, or in-memory flag may satisfy this
contract.

## Save transaction

- Initial save creates one revision-scoped credential reference, then persists
  non-secret setup.
- A blank password during edit reuses the current credential reference.
- A replacement password creates a new reference before preferences are changed.
- Only after the new setup persists may the superseded reference be deleted.
- Failure removes only newly created material and leaves the last complete setup
  usable.
- Delivery settings cannot be committed while an active confirmed send depends
  on the current setup revision.

## Load and routing

- Complete setup routes to `Send Book`.
- Missing preferences, invalid decoded values, or an unreadable credential
  reference routes to `Delivery Setup`.
- Recoverable non-secret values may prefill the draft.
- Credential bytes never enter visible state.
- Successful initial save transitions to `Send Book`; failed save remains on
  `Delivery Setup`.

## Storage boundaries

`UserDefaults` may contain only non-secret setup values, setup revision, and
shortcut preference. It must not contain credential bytes, batch state, book
paths, findings, prepared files, delivery attempts, or history.

The credential is a generic-password item in the traditional file-based macOS
Keychain. Queries do not set `kSecUseDataProtectionKeychain`,
`kSecAttrAccessible`, or `kSecAttrSynchronizable`. There is no file,
`UserDefaults`, remote, or custom-encryption fallback. Diagnostic and UI output
contain only sanitized failure codes and actions.

If an obsolete credential is inaccessible, load preserves only non-secret draft
values and requests one password entry. Normal releases signed by the pinned
self-signed certificate and exact designated requirement retain access after
that first corrected save.

## Required evidence

- Create, load, blank-password edit, password replacement, and delete.
- Preference failure after credential creation.
- Credential failure before preference persistence.
- Missing credential on launch.
- Reread through a recreated store and across a same-identity app update.
- One-time re-entry for an inaccessible pre-migration credential.
- No secret in setup descriptions, preferences, events, errors, or reports.
- Route and field behavior for complete and incomplete setup.
