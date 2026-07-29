# Quickstart: Future Implementation Verification

This document is a verification plan for the future implementation. The current
planning work does not build, test, launch, sign, or delete the application.

## 1. Static repository gate

From the repository root:

```bash
git diff --check
rg -n "Raycast|@raycast|Calibre|EPUBCheck|child_process|Process\\(|/usr/bin/(zip|unzip)|Sparkle|update_appcast|\\.py\\b" \
  BookSender BookSenderTests BookSenderUITests BookSender.xcodeproj .github README.md docs
find . -type d -name xcuserdata -o -name node_modules -o -name dist -o -name .raycast -o -name coverage
```

Review the results rather than treating any textual match as automatically
wrong. After final cutover, confirm only the intended `BookSender` app/test
targets and no stale PageForge file reference in the Xcode project.

## 2. Compilation and unit contracts

These commands execute the future app/test project and therefore require
Erick's explicit authorization under the repository workflow:

```bash
xcodebuild \
  -project BookSender.xcodeproj \
  -scheme BookSender \
  -destination 'platform=macOS' \
  build

xcodebuild \
  -project BookSender.xcodeproj \
  -scheme BookSender \
  -destination 'platform=macOS' \
  test
```

Compilation must use Swift 6 mode with complete concurrency checking. Unit
results must separately identify domain/repair, hostile archive/XML, filesystem,
Keychain, pipeline/cancellation, and SMTP protocol contracts.

## 3. Manual product acceptance

On a supported macOS 26+ test account:

1. Launch without setup and verify only `Delivery Setup`.
2. Validate every field, save a test credential, quit/relaunch, and confirm the
   secret is neither displayed nor stored in preferences/logs.
3. Confirm launch now opens only `Send Book`.
4. Use `Edit Setup` to open Settings on the `Delivery` tab, verify saved
   non-secret values, save without replacing the existing password, then switch
   to the `Shortcut` tab and configure or disable the global shortcut.
5. Add the same mixed EPUB/PDF group through Finder and drag-and-drop; verify one
   shared behavior, duplicate handling, and minimal states.
6. Prepare healthy, repairable, ambiguous, unsafe, malicious, and oversized
   fixtures. Verify originals byte-for-byte before and after.
7. Confirm a batch of 20, verify stable ordering, one active item, independent
   outcomes, and later progress after one failure.
8. Cancel before SMTP DATA and during DATA; verify `cancelled` versus
   `delivery unknown`, no automatic retry, and preserved completed outcomes.
9. Test implicit TLS and STARTTLS against controlled SMTP fixtures, then a
   separately authorized real provider account without exposing credentials.
10. Close the window, invoke the configured shortcut from another app, and verify
   the same window/state returns within the performance target.
11. Complete all journeys with keyboard and VoiceOver and confirm Settings is
    auxiliary and there is no third primary workflow screen.
12. Inspect light and dark wallpapers with the window active and inactive, then
    repeat with Reduce Transparency and Increase Contrast. Confirm the desktop
    remains visible through the complete window, content remains legible, and
    window controls and dragging still work.

## 4. Original and temporary-file audit

For every success, failure, cancellation, unsafe, and delivery-unknown fixture:

- compare original size and cryptographic digest before/after;
- verify no sibling output or overwritten pre-existing file;
- inspect the private workspace for `.partial` cleanup;
- relaunch after an intentionally interrupted test and verify only old,
  marker-valid Book Sender workspaces are swept.

## 5. Distribution gate

Treat these as separate checks:

1. archive the Release configuration;
2. inspect sandbox entitlements and linked dependencies;
3. validate code signing;
4. notarize and staple;
5. inspect the packaged archive contents;
6. install and launch on a clean supported account;
7. publish through the chosen GitHub release workflow;
8. download the public artifact and verify checksum, signature, notarization,
   app identity, two-screen behavior, and absence of legacy runtime files.

No local build alone proves signing, notarization, installation, or public
release correctness.
