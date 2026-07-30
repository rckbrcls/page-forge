# Contract: Credential and Release Continuity

## Credential storage

1. SMTP passwords use `kSecClassGenericPassword` in the traditional file-based
   macOS Keychain.
2. Queries preserve the existing service, revision-scoped account, transaction,
   public port/model, and sanitized-failure contracts.
3. Queries do not set `kSecUseDataProtectionKeychain`, `kSecAttrAccessible`, or
   `kSecAttrSynchronizable`.
4. No file, `UserDefaults`, remote, custom-encryption, or embedded-key fallback
   exists.
5. An inaccessible legacy credential preserves only non-secret draft fields and
   requires one password entry without unsafe migration.

## Stable release identity

1. Every distributed app and nested executable uses
   `Book Sender Release Signing`.
2. The imported PKCS#12 certificate must exactly match
   `scripts/signing/BookSenderReleaseSigning.cer`.
3. The main app designated requirement is anchored to certificate SHA-1
   `51F0C83093408095C09F3CF5359EB7C83B7F6B38` and identifier
   `com.rckbrcls.BookSender`.
4. Ad-hoc and unsigned distributed artifacts are forbidden.
5. Missing secrets, invalid PKCS#12, certificate drift, requirement drift, or
   invalid nested signatures stop release before packaging without fallback.
6. Temporary runner Keychains, decoded PKCS#12 files, Sparkle private keys, and
   imported certificate material are removed on step exit.

## Installer and update

1. The installer verifies strict main and nested signatures, the pinned
   certificate, and the exact main designated requirement before replacement.
2. Unsigned, ad-hoc, differently signed, or requirement-divergent archives are
   rejected even when their bytes are otherwise intact.
3. Sparkle EdDSA remains an independent mandatory archive signature.
4. Version N to N+1 signed under the same policy must retain credential access.

## Rotation and disclosure

Identity rotation requires Erick's explicit authorization, a migration plan,
and notice that one-time credential re-entry may be required. The self-signed
identity is not Developer ID, does not enable notarization, and does not provide
normal Gatekeeper trust for manual installation.
