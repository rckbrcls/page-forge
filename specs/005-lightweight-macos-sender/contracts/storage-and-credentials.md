# Contract: Storage, Credentials, and Cleanup

## Secret storage

The SMTP app password is one generic-password Data Protection Keychain item
scoped by Book Sender service and username:

- `kSecUseDataProtectionKeychain = true`
- `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- `kSecAttrSynchronizable = false`

Create, read, update, and delete operations use Security.framework. Keychain work
does not block the main actor. A successful setup save requires successful secret
storage. Presentation receives only an opaque credential reference.

## Non-secret preferences

`UserDefaults` may hold sender address, host, port, security mode, username,
Kindle address, setup revision, and shortcut preference. It does not hold
credentials, book paths, findings, batch state, prepared files, or delivery
history.

## Temporary data

User-selected files are opened read-only and copied by streaming into the exact
Book Sender temporary root using app-generated UUID components. Original
filenames never select a write location. Originals and pre-existing files remain
byte-for-byte unchanged in success, failure, cancellation, unsafe, and unknown
delivery cases.

Incomplete writes use `.partial`. Only revalidated output is promoted. Item
terminal cleanup removes extraction and partial artifacts; clear/quit removes the
batch. Startup cleanup only removes marker-valid orphan workspaces older than the
documented threshold inside the exact app root.

## Privacy

No analytics or telemetry exists. Logs and errors exclude complete credentials,
book bytes, source paths, filenames when avoidable, and raw SMTP payloads. The
only book egress is a user-confirmed SMTP attempt to the configured destination.
