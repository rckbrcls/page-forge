# Mock and Forbidden Runtime Absence

## Production source

The following production scans returned no matches:

```text
PreviewBook
isPreviewing
previewSendBook
Back to Setup
Preview Send Book
mock
demo
SMTP delivery is not available
Raycast
@raycast
Calibre
EPUBCheck
Process(
/usr/bin/zip
/usr/bin/unzip
child_process
```

Scope: `BookSender/`.

The wider repository scan has one reviewed contextual match: the active
specification path `specs/006-replace-mock-workflows/spec.md` in `README.md`.
The README also names removed historical runtimes while explicitly stating
that they are not supported fallbacks. Neither match is production behavior.

## UI-test configuration

All current UI-test launch arguments are consumed by
`AppDependencies.forCurrentInvocation`. Isolated setup storage, generated local
PDF inputs, and controlled terminal SMTP outcomes still enter the real intake,
preparation, confirmation, actor, and delivery-service path. No preview route,
forced ready row, or setup bypass is present.
