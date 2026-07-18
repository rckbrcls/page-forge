# Task for scout

Map the Kindle Readiness Doctor / readiness flow in the PageForge repo at /Users/erickpatrickbarcelos/codes/side-projects/page-forge.

Goal: produce a concise handoff-ready map of the readiness flow only (not the whole app).

Investigate and report:
1. Entry points (CLI, TUI, public APIs)
2. Core modules/files and their roles
3. Call graph / orchestration order: audit → fix → status → send/handoff
4. Key types, status vocabulary (ready/needs_fixes/blocked), severity vocabulary
5. Output contracts (e.g. *-kindle-ready.epub vs *-repaired.epub)
6. Boundaries: what readiness does vs what repair/convert/send own
7. Shared services used by CLI and TUI
8. Important functions/classes/symbols with file paths

Constraints:
- Read-only recon only
- Prefer rg/file reads; do not run app/build/tests
- Focus strictly on readiness/doctor/kindle-ready path
- Return ONLY a structured handoff for the parent agent (no fluff)

Return format:
## Handoff: Readiness Flow
### Entry points
### Core files
### Flow (ordered)
### Contracts & vocabulary
### Boundaries
### Key symbols
### Open risks / unknowns (if any)

## Acceptance Contract
Acceptance level: attested
Completion is not accepted from prose alone. End with a structured acceptance report.

Criteria:
- criterion-1: Return concrete findings with file paths and severity when applicable

Required evidence: review-findings, residual-risks

Finish with a fenced JSON block tagged `acceptance-report` in this shape:
Use empty arrays when no items apply; array fields contain strings unless object entries are shown.
```acceptance-report
{
  "criteriaSatisfied": [
    {
      "id": "criterion-1",
      "status": "satisfied",
      "evidence": "specific proof"
    }
  ],
  "changedFiles": [
    "src/file.ts"
  ],
  "testsAddedOrUpdated": [
    "test/file.test.ts"
  ],
  "commandsRun": [
    {
      "command": "command",
      "result": "passed",
      "summary": "short result"
    }
  ],
  "validationOutput": [
    "validation output or concise summary"
  ],
  "residualRisks": [
    "none"
  ],
  "noStagedFiles": true,
  "diffSummary": "short description of the diff",
  "reviewFindings": [
    "blocker: file.ts:12 - issue found, or no blockers"
  ],
  "manualNotes": "anything else the parent should know"
}
```