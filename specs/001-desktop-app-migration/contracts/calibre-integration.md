# Calibre Integration Contract

**Feature**: `001-desktop-app-migration`  
**Audience**: `Integrations/Calibre` and domain services that require external tools

## Tools

PageForge may invoke only these Calibre tools by default:

| Tool | Used for |
|------|----------|
| `ebook-convert` | format conversion and aggressive repair orchestration |
| `ebook-meta` | metadata inspect/update |
| `ebook-polish` | polish steps when required by existing workflows |

PageForge MUST NOT reimplement full conversion pipelines in-process.

## Discovery

For each tool, resolution order:

1. Explicit user/config override if present
2. Process environment override (`EBOOK_CONVERT_PATH`, `EBOOK_META_PATH`, `EBOOK_POLISH_PATH`) for developer/advanced use
3. `PATH` lookup
4. `/Applications/calibre.app/Contents/MacOS/<tool>`
5. `~/Applications/calibre.app/Contents/MacOS/<tool>`
6. `/opt/homebrew/bin/<tool>`
7. `/usr/local/bin/<tool>`

If an explicit override path is set but missing/non-executable, fail with a dependency error naming the override.

## Status model

`DependencyStatus` reports each tool path or absence.

- `isReady == true` only when all three tools are available
- `missingTools` lists human-facing tool names

UI guidance:
- If tools missing, block Calibre-backed actions
- Show recovery guidance (install Calibre / locate tools)
- Setup/update actions are optional helpers, not silent side effects

## Process execution

Invocation requirements:

- Run as external process with absolute tool path
- Pass source/output paths as arguments
- Capture stdout/stderr for logs and failure messages
- Non-zero exit => conversion/metadata/polish error
- Never execute shell string concatenation with unsanitized user input; use argument arrays

Progress:
- Stream or poll process lifetime into operation logs when useful
- Cancellation SHOULD terminate the child process tree when supported

## Operation matrix

| Domain operation | Requires convert | Requires meta | Requires polish | Notes |
|------------------|------------------|---------------|-----------------|-------|
| readiness audit (EPUB structure) | no | no | no | PageForge-owned ZIP/XML checks |
| readiness prepare (may convert MOBI, may polish/repair) | maybe | no | maybe | depends on path |
| convert MOBI/PDF/EPUB | yes | no | no | |
| safe structural repair | no | no | no | PageForge-owned |
| aggressive repair | yes | no | maybe | Calibre roundtrip |
| metadata inspect/update | no | yes | no | |
| SMTP send | no | no | no | |
| handoff open | no | no | no | |

## Failure messages

Messages MUST be actionable, for example:
- tool not found + install/locate guidance
- conversion failed + include compact stderr summary
- output path exists and overwrite disabled

## Security / safety

- Only invoke known tool binaries discovered by the rules above
- Do not accept arbitrary shell scripts as “Calibre tools”
- Do not use Calibre integration for DRM removal workflows
- Temporary files for intermediate conversion MUST be cleaned up on success and best-effort on failure
