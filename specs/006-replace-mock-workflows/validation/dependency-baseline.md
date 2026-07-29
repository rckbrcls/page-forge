# Dependency Baseline

**Captured**: 2026-07-29  
**Decision**: preserve the resolved dependency graph; add no package

## Direct products

| Package | Resolved version | Products used | Purpose |
|---|---:|---|---|
| KeyboardShortcuts | 3.0.1 | `KeyboardShortcuts` | Configurable global shortcut |
| ZIPFoundation | 0.9.19 | `ZIPFoundation` | Bounded in-process EPUB ZIP access |
| swift-nio | 2.86.0 | `NIOCore`, `NIOPosix`, `NIOEmbedded` | SMTP transport and deterministic protocol tests |
| swift-nio-ssl | 2.35.0 | `NIOSSL` | Verified implicit TLS and STARTTLS |
| Sparkle | 2.9.2 | `Sparkle` | Signed application updates |

`swift-atomics` 1.3.1, `swift-collections` 1.6.0, and `swift-system` 1.7.5
are resolved transitive dependencies.

## Targets and platform

- `BookSender`: one macOS application target.
- `BookSenderTests`: one unit-test bundle.
- `BookSenderUITests`: one UI-test bundle.
- macOS deployment target: 26.0.
- Swift language mode: 6.0 with complete concurrency checking.

## Sandbox impact

The app retains only:

- App Sandbox;
- user-selected read-only files;
- outgoing network client access;
- Sparkle installer-service mach lookup exceptions.

No dependency may introduce ebook processing outside the app process, executable
downloads, a helper runtime, hidden network requests, or credential storage.
Sparkle's embedded update services remain the sole distribution exception.

## License and release boundary

The repository already carries `BookSender/Resources/THIRD_PARTY_NOTICES.md`.
Version/license reconciliation, linked-binary inspection, test execution, signing,
and release acceptance remain separate gates and are not established by this
static baseline.

