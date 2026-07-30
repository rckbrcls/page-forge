# Release 0.2.3 Consumer Trust Incident

**Date**: 2026-07-30

## Observed production behavior

The v0.2.3 workflow completed its signing-runner launch gate and published the
universal archive. The downloaded archive matched the GitHub Release SHA-256
digest, but a clean Apple Silicon environment without the release certificate
in its Keychain produced:

- `CSSMERR_TP_NOT_TRUSTED` during strict signature verification;
- `AppleMobileFileIntegrityError Code=-423` for an unknown certificate chain;
- process termination before the five-second launch gate.

The signing workflow had imported the private release identity before its launch
check. Deleting the temporary signing Keychain at step exit did not make that
runner equivalent to a fresh consumer environment.

## Confirmed minimum correction

An isolated temporary Keychain was created with only
`BookSenderReleaseSigning.cer`; no PKCS#12 or private key was imported and no
explicit trust override was configured. With that Keychain on the user search
list:

- strict main and nested signature verification passed;
- the exact designated requirement passed;
- the installed app remained alive through the five-second Apple Silicon launch
  gate;
- deleting the temporary Keychain and restoring the original search list
  removed the test state.

The production installer therefore registers only the fingerprint-pinned public
certificate when absent. Registration is idempotent and does not invoke
`security add-trusted-cert`.

## Release correction

Constitution 7.2.0 requires three sequential jobs:

1. build, sign, package, and Sparkle-sign the candidate;
2. install and launch that ZIP on a separate clean macOS runner that receives no
   private signing material;
3. publish the GitHub Release, appcast, installer, and Pages artifact only after
   clean-consumer validation succeeds.

This record does not claim v0.2.4 production acceptance. Publication, public
endpoint checks, downloaded-artifact verification, installed-app launch, first
credential save/relaunch, and the first same-identity Sparkle update remain
separate evidence gates.
