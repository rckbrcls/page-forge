# Delivery and Config Contract

**Feature**: `001-desktop-app-migration`  
**Audience**: config, keychain, SMTP send, handoff

## Config storage

- Non-secret configuration lives in the app’s Application Support directory.
- Suggested file: `config.json` (or equivalent structured local file).
- Config contains:
  - `defaultProfile`
  - `profiles[name] -> DeliveryProfile fields`
- Config MUST NOT store SMTP password/token values.

## Profile fields

Required logical fields:

- `name`
- `senderEmail`
- `kindleEmail`
- `smtpHost` (default `smtp.gmail.com`)
- `smtpPort` (default `587`)
- `smtpUsername` (optional)
- `useTLS` (default `true`)
- `defaultOutputDir` (optional)

Derived:
- `loginUsername = smtpUsername` if non-empty else `senderEmail`
- `isSendReady` requires sender/kindle/host/port/loginUsername and keychain secret present

## Keychain secrets

- Service name should be app-scoped (for example `page-forge` / `PageForge`).
- Account/key should be profile-scoped (for example profile name).
- API:
  - set secret
  - get secret
  - check existence
  - delete secret
- Missing secret => delivery configuration error, not crash.

## SMTP send contract

Preconditions:
1. Source file exists and is readable
2. Selected profile exists
3. Profile is send-ready
4. Secret exists in Keychain

Behavior:
- Send the selected file to `kindleEmail` from `senderEmail` through configured SMTP settings
- On success, return `SendResult`
- On failure, return/throw actionable delivery error (auth, network, recipient, attachment)

Forbidden:
- Storing plaintext password in config
- Logging secret values
- Automating Amazon website login

## Handoff contract

- Provide action to open Amazon Send to Kindle handoff URL/app path
- Default URL baseline from current product: `https://www.amazon.com/sendtokindle`
- Handoff does not upload the file automatically
- User remains responsible for Amazon-side authorization and transfer

## Settings UX obligations

Settings MUST show:
- whether each profile is send-ready
- whether secret is present (boolean only)
- Calibre dependency status
- separate app update vs Calibre update guidance

## Migration note from legacy

Legacy behavior to preserve:
- named profiles
- default profile
- Keychain-backed secret by profile
- SMTP send plus handoff dual path
- no Amazon automation

Legacy packaging/install via `uv` is not part of the desktop product runtime after migration.
