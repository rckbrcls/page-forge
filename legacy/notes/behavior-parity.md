# Behavior Parity Map

| Legacy module | Swift destination | Status |
|---------------|-------------------|--------|
| `readiness.py` | `PageForge/Domain/Services/ReadinessService.swift` | Ported |
| `epub_repair.py` | `PageForge/Domain/Services/EPUBRepair.swift` + `EPUBInspection.swift` | Ported |
| `conversion.py` | `PageForge/Domain/Services/ConversionService.swift` + `RepairService.swift` | Ported |
| `metadata.py` | `PageForge/Domain/Services/MetadataService.swift` | Ported |
| `kindle.py` | `PageForge/Domain/Services/DeliveryService.swift` + `Integrations/Mail` | Ported |
| `config.py` | `ConfigService` + `SecretService` + Keychain store | Ported |
| `calibre.py` | `CalibreToolLocator` + `CalibreProcessRunner` + `DependencyService` | Ported |
| `tui_app.py` / `cli.py` | Desktop feature views | Replaced (UI inspiration only) |
| `updater.py` / `installer.py` | `SetupGuidanceService` | Guidance ported |

## Contracts preserved

- Readiness statuses: `ready`, `needs_fixes`, `blocked`
- Issue severities: `info`, `warning`, `error`, `fixable`
- Outputs: `*-kindle-ready.epub`, `*-repaired.epub`
- No DRM removal
- No Amazon login/upload automation
- PDF conversion without OCR promises
