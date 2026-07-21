# Domain Services Contract

**Feature**: `001-desktop-app-migration`  
**Audience**: Swift domain layer and feature view models

## Principles

- Views call services; views do not implement readiness/repair/conversion rules.
- Services are synchronous or async function APIs over value models.
- Long work is cancelable where practical and emits progress/log events.
- Legacy Python modules are behavioral oracles, not runtime dependencies.

## Service interfaces

### ReadinessService

```text
audit(source: Path) -> ReadinessReport
prepare(source: Path, output: Path?, overwrite: Bool) -> ReadinessReport
auditFolder(folder: Path, prepare: Bool, outputDir: Path?, overwrite: Bool) -> ReadinessBatchResult
```

Behavioral rules:

- Audit never writes output.
- Prepare writes default `*-kindle-ready.epub` when output omitted.
- MOBI may be converted first; report may set `convertedFrom`.
- Status vocabulary fixed.
- Blocking issues prevent unsafe prepare completion.

### ConversionService

```text
convertToEPUB(source: Path, output: Path?, overwrite: Bool) -> ConversionResult
convertToMOBI(source: Path, output: Path?, overwrite: Bool) -> ConversionResult
convertFolder(folder: Path, target: ConversionTarget, outputDir: Path?, overwrite: Bool) -> BatchResult<ConversionResult>
```

Behavioral rules:

- Supported transforms only: MOBI/PDF → EPUB, EPUB → MOBI.
- PDF conversion does not claim OCR.
- Requires Calibre convert tool.

### RepairService

```text
repair(source: Path, mode: RepairMode, output: Path?, overwrite: Bool) -> RepairResult
repairFolder(folder: Path, mode: RepairMode, outputDir: Path?, overwrite: Bool) -> BatchResult<RepairResult>
```

Behavioral rules:

- Default mode is `safe`.
- Default output `*-repaired.epub`.
- Aggressive mode is explicit and may use Calibre roundtrip.
- Safe mode owns structural ZIP/container/OPF fixes in-domain.

### MetadataService

```text
inspect(source: Path) -> BookMetadata
update(source: Path, title: String?, author: String?) -> BookMetadata
```

Behavioral rules:

- Requires Calibre metadata tool.
- Update requires at least one provided field.

### DeliveryService

```text
send(source: Path, profileName: String?) -> SendResult
openHandoff() -> Void
isProfileSendReady(profileName: String?) -> Bool
```

Behavioral rules:

- SMTP send only through configured local profile + Keychain secret.
- Handoff never automates Amazon login/upload.
- Incomplete profile blocks send with actionable error.

### DependencyService

```text
calibreStatus() -> DependencyStatus
requireConvert() -> Path  # throws dependency error
requireMeta() -> Path
requirePolish() -> Path
```

Behavioral rules:

- Discovery order should preserve legacy semantics:
  1. explicit configured/env path
  2. PATH
  3. standard Calibre app locations
  4. Homebrew bin locations

### ConfigService

```text
load() -> AppConfig
save(AppConfig) -> Void
upsertProfile(DeliveryProfile, makeDefault: Bool) -> Void
defaultProfile() -> DeliveryProfile
```

### SecretService

```text
setPassword(profileName: String, secret: String) -> Void
getPassword(profileName: String) -> String  # throws if missing
hasPassword(profileName: String) -> Bool
deletePassword(profileName: String) -> Void
```

### LogService

```text
append(level, message, operationId?) -> Void
recent(limit: Int) -> [OperationLogEntry]
```

## Error contract

Domain errors SHOULD map to stable categories:

| Category        | Meaning                                                          |
| --------------- | ---------------------------------------------------------------- |
| `dependency`    | Calibre/tool missing or invalid                                  |
| `validation`    | bad input type/path/options                                      |
| `filesystem`    | unreadable source / unwritable output / exists without overwrite |
| `conversion`    | Calibre process failed                                           |
| `repair`        | structural repair failed                                         |
| `configuration` | profile/config invalid                                           |
| `delivery`      | SMTP send failed                                                 |
| `cancelled`     | user/system cancelled job                                        |

Each error exposed to UI MUST include a human-readable message.

## Parity mapping

| Legacy module                 | Service                                               |
| ----------------------------- | ----------------------------------------------------- |
| `readiness.py`                | `ReadinessService`                                    |
| `conversion.py`               | `ConversionService` (+ parts of repair orchestration) |
| `epub_repair.py`              | `RepairService` safe path                             |
| `metadata.py`                 | `MetadataService`                                     |
| `kindle.py`                   | `DeliveryService`                                     |
| `config.py`                   | `ConfigService` + `SecretService`                     |
| `calibre.py`                  | `DependencyService` + Calibre process runner          |
| `updater.py` / `installer.py` | Settings guidance helpers (not core domain path)      |
