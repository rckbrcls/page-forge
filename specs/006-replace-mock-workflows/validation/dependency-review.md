# Dependency Review

## Source and project evidence

- The application links `KeyboardShortcuts`, `ZIPFoundation`, `NIOCore`,
  `NIOPosix`, `NIOSSL`, and `Sparkle`.
- The unit-test target additionally links `NIOEmbedded` and `ZIPFoundation`.
- `Package.resolved` pins KeyboardShortcuts 3.0.1, ZIPFoundation 0.9.19,
  swift-nio 2.86.0, swift-nio-ssl 2.35.0, Sparkle 2.9.2,
  swift-atomics 1.3.1, swift-collections 1.6.0, and swift-system 1.7.5.
- `THIRD_PARTY_NOTICES.md` records the direct and resolved transitive package
  licenses.
- The sandbox entitlements remain limited to App Sandbox, user-selected
  read-only files, outgoing network client access, and Sparkle installer
  service mach-lookup names.
- No new source dependency was added for the real workflow.

## Binary boundary

No application build was authorized during this implementation pass. Actual
bundle frameworks, architectures, embedded license files, code signatures, and
entitlements remain unverified until the authorized build and release gates.
