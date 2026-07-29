# Release Readiness

## Constitution recheck

The implementation keeps exactly two primary screens and one auxiliary
two-tab Settings window. SwiftUI remains presentation-only; the actor-owned
pipeline calls domain audit/repair and archive, XML, filesystem, credential,
and SMTP adapters in the required dependency direction.

Originals are never overwritten. EPUB work is staged, bounded, deterministic,
reopened, and revalidated. PDF delivery uses a staged immutable snapshot. Batch
work and SMTP attempts are sequential with independent outcomes. Secrets remain
in Data Protection Keychain and transient delivery scope. The repository
contains no processing helper, executable download, browser automation,
Calibre, EPUBCheck, Python/Java runtime dependency, Docker service, DRM removal,
or conversion path.

## Readiness matrix

| Layer | Status | Evidence |
| --- | --- | --- |
| Source implementation | Implemented | focused production and test sources |
| Static repository gate | Passed | `static-gate.md` |
| Swift 6 compilation | Pending authorization | no compiler executed |
| Unit/integration tests | Pending authorization | test sources not executed |
| UI/accessibility/performance | Pending authorization | app not launched |
| Controlled TLS/SMTP | Pending authorization | no loopback server executed |
| Authenticated provider SMTP | Pending separate authorization | no account used |
| Signing and ZIP contents | Pending release build | no bundle produced |
| Sparkle update | Pending N-to-N+1 artifact | appcast contract only |
| Clean-account install | Pending manual acceptance | installer source only |
| Public release | Not ready | release claims remain experimental |

README and release notes intentionally retain the current experimental and
unavailable disclosure until the controlled, authenticated, packaging, update,
and clean-account gates provide evidence.
