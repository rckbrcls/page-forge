# US1 Real Setup Validation

## Static implementation evidence

- The setup route is derived only from `SetupLoadResult`.
- Preference decoding distinguishes absent, valid, and invalid state.
- Completeness requires the referenced credential to exist.
- New credentials use revision-scoped identities and Data Protection Keychain
  attributes with device-only, non-synchronizing accessibility.
- Setup replacement commits preferences before deleting an old credential and
  removes a newly created credential on rollback.
- Password bytes are absent from saved setup values and presentation models.
- Production source contains no setup-to-send preview route or control.
- UI-test storage arguments are consumed only by isolated dependency
  composition.

## Validation boundary

Source inspection and static repository checks passed. Compilation, unit tests,
UI tests, relaunch behavior, and Security.framework runtime behavior were not
executed because explicit build/run authorization was not provided.
