# Release 0.2.2 Runtime Incident

**Date**: 2026-07-30

## Observed production behavior

The v0.2.2 installer downloaded, verified, and installed the universal archive.
Launching `/Applications/BookSender.app` then terminated before application
startup with `EXC_CRASH (SIGABRT)`, `Namespace DYLD`, and a library-validation
rejection for `Sparkle.framework`.

Read-only inspection confirmed:

- Book Sender version `0.2.2` build `19` was installed.
- The main app and Sparkle framework passed strict static signature checks.
- Both were signed by the pinned certificate.
- Both reported `TeamIdentifier=not set`.
- The main app retained hardened runtime.
- dyld rejected Sparkle because hardened-runtime library validation requires an
  Apple-issued matching Team ID, which a self-signed identity does not provide.

The repeated installer invocation was harmless but could not change this
runtime incompatibility.

## Corrective contract

Constitution 7.1.0 keeps hardened runtime and permits only
`com.apple.security.cs.disable-library-validation` on the main executable.
Every Sparkle executable remains signed and verified against the pinned
certificate, and Sparkle EdDSA remains mandatory.

The release workflow must launch the signed executable for five seconds before
packaging. A dyld rejection or early exit blocks publication even when
`codesign --verify --deep --strict` passes.

## Validation boundary

This record proves the v0.2.2 failure diagnosis from the installed artifact. It
does not claim that the correction launches successfully until the v0.2.3
workflow and installed-artifact checks complete.
