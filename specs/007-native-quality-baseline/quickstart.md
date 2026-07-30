# Quickstart: Native Quality Baseline Validation

## Validation boundary

Repository policy forbids build, test, app launch, and UI execution unless the
user explicitly authorizes them. Run the static section during planning and
implementation. Treat every later section as pending until separately
authorized and executed.

## Static validation

From the repository root:

```bash
git diff --check
jq empty .specify/feature.json
plutil -lint BookSender.xcodeproj/project.pbxproj
plutil -lint BookSender/Info.plist
plutil -lint BookSender/BookSender.entitlements
openssl x509 -inform DER -in scripts/signing/BookSenderReleaseSigning.cer -noout -subject -fingerprint -sha1
bash scripts/tests/signing_contract_test.sh
bash scripts/tests/install_contract_test.sh
bash -n scripts/tests/signed_app_launch_smoke_test.sh
rg -n 'DispatchQueue|\.tabItem\(|loadItem\(forTypeIdentifier|sheet\(isPresented: \$model\.isShowingConfirmation|font\(\.system\(size:|\.caption2' BookSender --glob '*.swift'
rg -n 'kSecUseDataProtectionKeychain|kSecAttrAccessible|kSecAttrSynchronizable|--sign -' BookSender .github scripts
```

Expected result:

- No whitespace or JSON/plist syntax failures.
- No retained target patterns without a reviewed, documented reason.
- The public certificate, signing policy, workflow, and installer use one
  fingerprint and exact designated requirement with no distribution fallback.
- The release requires hardened runtime, the bounded main-executable
  library-validation exception, pinned nested Sparkle signatures, and signed
  launch gates in both the signing and clean-consumer jobs.
- The installer verifies the GitHub asset digest, imports only the pinned public
  certificate when absent, and never invokes `security add-trusted-cert`.
- No new dependency, primary screen, executable helper, runtime service, or
  persistence surface.

Review the focused diff:

```bash
git diff -- BookSender BookSenderTests BookSenderUITests specs/007-native-quality-baseline
git status --short
```

## Build gate — requires explicit authorization

```bash
xcodebuild \
  -project BookSender.xcodeproj \
  -scheme BookSender \
  -destination 'platform=macOS' \
  build
```

This confirms compilation and project integration only. It is not UI, SMTP
provider, signing, notarization, or release acceptance.

## Unit and integration gate — requires explicit authorization

```bash
xcodebuild \
  -project BookSender.xcodeproj \
  -scheme BookSender \
  -destination 'platform=macOS' \
  test \
  -only-testing:BookSenderTests
```

Required focused evidence:

- SMTP waiter cancellation and exactly-once resumption.
- Timeout/cancellation release within one second after the trigger.
- Archive and XML losing-race cleanup.
- Mixed-success Finder/drop intake with sanitized feedback.
- Confirmation snapshot consumption and release.
- No secret, raw exception, or full path in presentation state.
- Traditional Keychain create, reread through a recreated store, exists,
  replacement rollback, and delete behavior.

## UI and accessibility gate — requires explicit authorization

```bash
xcodebuild \
  -project BookSender.xcodeproj \
  -scheme BookSender \
  -destination 'platform=macOS' \
  test \
  -only-testing:BookSenderUITests
```

Required observable outcomes:

- `Delivery Setup` and `Send Book` remain the only primary screens.
- Settings exposes only `Delivery` and `Shortcut`.
- Finder and drag-and-drop failures are visible and sanitized.
- Confirmation send, cancel, and dismiss use the same snapshot.
- Keyboard actions cause their intended visible state change.
- Enlarged text, increased contrast, and reduced transparency remain usable.

## Manual runtime gate — requires explicit authorization

1. Launch the app with a clean local state.
2. Verify first-run setup and saved-delivery flows.
3. Import a mixed EPUB/PDF batch through Finder and drag-and-drop.
4. Confirm, cancel, reselect, prepare, and send without stale sheet state.
5. Exercise failure, cancellation, and recovery without changing originals.
6. Open and close Settings repeatedly and confirm one main window.
7. Repeat with enlarged text, increased contrast, and reduced transparency.
8. Save the SMTP password, quit, reopen, and confirm `Send Book` opens without
   another prompt.

## Provider and release gates

Run separately from local test acceptance:

1. Validate implicit TLS and STARTTLS against approved SMTP test accounts.
2. Verify typed `delivery_unknown` behavior after message data begins.
3. Confirm sandbox, pinned certificate, exact designated requirement,
   traditional Keychain, Sparkle EdDSA, appcast, and release artifacts through
   the release process.
4. Confirm the separate clean-consumer runner received no PKCS#12, registered
   only the public certificate, installed the candidate, and passed strict
   signature plus launch validation before publication.
5. Replace corrected version N with N+1 signed by the same identity and confirm
   the credential remains readable; then verify a real Sparkle update when two
   corrected versions exist.

The self-signed identity is not Developer ID and provides no Apple notarization
or normal Gatekeeper trust for manual installation.

Do not include credentials, email contents, book contents, full paths, or raw
provider errors in evidence.
