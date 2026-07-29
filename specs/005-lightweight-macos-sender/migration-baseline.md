# Migration Baseline

Recorded on 2026-07-28 before native implementation. This inventory is a
behavioral reference, not permission to copy obsolete implementation wholesale.

> Superseded on 2026-07-28: the user explicitly authorized immediate legacy
> removal. The referenced legacy paths no longer exist in the working tree.

## Worktree boundary

- Continue on `main`; do not branch, stage, commit, restore, or discard.
- Preserve all pre-existing `.pi`, `.pi-subagents`, governance, documentation,
  TypeScript, Raycast, test, and declaration-file changes.
- Keep `PageForge.xcodeproj`, `PageForge/`, `PageForgeTests/`, `src/`, `tests/`,
  and `legacy/` until native parity and the cutover gates are proven.
- New implementation is confined to `BookSender.xcodeproj`, `BookSender/`,
  `BookSenderTests/`, `BookSenderUITests/`, and this specification until the
  gated cutover tasks explicitly own other files.

## TypeScript behavioral references

- Audit vocabulary and derivation: `src/domain/audit/`, especially stable
  finding codes, archive identity/path rules, container/package discovery,
  manifest/reference rules, active content, and health derivation.
- Deterministic repair behavior: `src/domain/repair/`, including candidate
  derivation, permitted repairs, XML transformations, application, and
  revalidation comparison.
- Safety adapters: `src/adapters/archive/`, `src/adapters/xml/`, and
  `src/adapters/filesystem/`.
- Delivery behavior: `src/adapters/delivery/smtp-client.ts`,
  `smtp-result.ts`, and the application send orchestration.
- Typed orchestration: `src/application/` and `src/domain/models/`.

## Fixture and test references

- Valid, malformed, ambiguous, encrypted, repairable, and malicious fixture
  definitions live under `tests/fixtures/`.
- Required behavior matrices live under `tests/acceptance/`, `tests/domain/`,
  `tests/adapters/`, and `tests/application/`.
- The native fixture manifest must retain source mapping, expected stable finding
  codes, expected automatic actions, and original digests.

## Reusable Swift patterns

- Semantic colors and icon inputs: `PageForge/Assets.xcassets/`.
- Main-actor observable state and SwiftUI composition:
  `PageForge/App/AppState.swift` and `PageForge/App/PageForgeApp.swift`.
- Shared URL intake and drop affordance:
  `PageForge/Features/Shared/FileDropIntakeView.swift` and
  `PageForge/Domain/Services/DocumentIntakeService.swift`.
- Keychain shape: `PageForge/Integrations/Keychain/KeychainSecretStore.swift`.
- Collision-safe temporary-file and prepared-output ideas:
  `PageForge/Integrations/FileSystem/PreparedOutputExporter.swift`.

These are design references only. Calibre, conversion, subprocess ZIP, Sparkle,
extra settings/workflow screens, and legacy SMTP behavior are forbidden in the
new product.

## Release inputs pending replacement

- `.github/workflows/`
- `scripts/install.sh`
- `scripts/update_appcast.py`
- `appcast.xml`
- `PageForge.xcodeproj` signing, scheme, Sparkle package, and bundle settings
- Raycast `package.json`, assets, and Node configuration

## Native cutover invariant

Deletion starts only after the native app, unit tests, UI tests, fixture parity,
two-screen boundary, secure credentials, sequential batch pipeline, SMTP
uncertainty behavior, accessibility, signing inputs, and manual acceptance have
separate recorded evidence.
