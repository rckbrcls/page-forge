# Implementation Baseline

**Captured**: 2026-07-29  
**Branch**: `main`  
**Validation boundary**: repository inspection and static checks only

## Preserved checkout state

The feature started from a dirty checkout. The following pre-existing Swift
changes were treated as user-owned until their feature ownership was established:

- `BookSender/App/AppModel.swift`
- `BookSender/Features/SendBook/BatchItemRow.swift`
- `BookSender/Features/SendBook/SendBookView.swift`
- `BookSender/Features/SendBook/PreviewBookItem.swift`
- `BookSenderTests/Application/PreviewBookIntakeTests.swift`

The preview files and their consumers are in feature scope because the approved
specification explicitly requires their deletion. Unrelated changes remain
untouched.

## Runtime baseline

- `AppModel` and `PipelineActor` both mutate batch items.
- Delivery setup loads non-secret preferences without checking that the Keychain
  credential still exists.
- Credential replacement reuses the SMTP username as the Keychain account and
  is not revision-scoped.
- Intake silently drops duplicate, unsupported, unreadable, and failed inputs.
- PDF readiness is based on extension and size and has no signature or digest
  evidence.
- Healthy EPUBs may be returned from the staged snapshot without writing and
  revalidating a separate delivery copy.
- The archive writer rebuilds `mimetype` but does not execute the complete
  preparation plan.
- The SMTP production adapter and delivery service do not exist.
- `confirmSend()` displays an unavailable-protocol placeholder instead of
  creating delivery attempts.
- Preview navigation can enter `Send Book` without a complete setup and can mark
  files ready by extension.

## Validation status at capture

- Project, `Info.plist`, and entitlement plist syntax: passed.
- Ignore-file coverage for Swift/Xcode and universal local artifacts: present.
- Swift compilation: not run.
- Automated tests: not run.
- App/UI behavior: not run.
- Authenticated SMTP behavior: not run.
- Signing, update, installation, and public release: not run.

