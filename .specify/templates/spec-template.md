# Feature Specification: [FEATURE NAME]

**Feature Branch**: `[###-feature-name]`

**Created**: [DATE]

**Status**: Draft

**Input**: User description: "$ARGUMENTS"

## User Scenarios & Testing _(mandatory)_

<!--
  Prioritize independently testable user journeys. Advanced EPUB preparation is
  a background capability; do not turn its internal stages into navigation.
-->

### User Story 1 - [Brief Title] (Priority: P1)

[Describe the user journey in plain language]

**Why this priority**: [Explain the value and priority]

**Independent Test**: [Describe an independent acceptance test]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]
2. **Given** [initial state], **When** [action], **Then** [expected outcome]

---

### User Story 2 - [Brief Title] (Priority: P2)

[Describe the user journey in plain language]

**Why this priority**: [Explain the value and priority]

**Independent Test**: [Describe an independent acceptance test]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]

---

### User Story 3 - [Brief Title] (Priority: P3)

[Describe the user journey in plain language]

**Why this priority**: [Explain the value and priority]

**Independent Test**: [Describe an independent acceptance test]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]

### Edge Cases

- What happens when a mixed batch contains eligible, repairable, unsafe, unsupported, and duplicate books?
- How does cancellation affect pending, active, completed, and delivery-unknown items?
- What happens when background preparation cannot safely restore a book?

## Requirements _(mandatory)_

### Functional Requirements

- **FR-001**: System MUST [specific two-screen or delivery-setup capability]
- **FR-002**: System MUST [specific batch intake or concise-feedback capability]
- **FR-003**: System MUST [specific background preparation capability]
- **FR-004**: System MUST [specific original-preservation or safety behavior]
- **FR-005**: System MUST [specific explicit-delivery behavior]

_Use `[NEEDS CLARIFICATION: specific question]` only when no safe default exists._

### Constitution Constraints _(mandatory)_

- **CC-001**: Feature MUST remain within `Delivery Setup` and `Send Book`; dialogs,
  progress, and inline disclosure MUST NOT become additional primary screens
- **CC-002**: Feature MUST keep advanced EPUB safety, audit, deterministic
  cleanup/restoration, separate-copy writing, and revalidation in the background
- **CC-003**: Feature MUST expose concise derived states and only reveal technical
  evidence inline when it supports an action, failure, or decision
- **CC-004**: Feature MUST process a stable batch sequentially, isolate outcomes
  per book, preserve completed work, and define cooperative cancellation
- **CC-005**: Feature MUST keep processing local, preserve originals and existing
  files, and require explicit confirmation before SMTP transmission
- **CC-006**: Feature MUST use typed pipeline evidence and failures, keep domain
  rules outside SwiftUI views, and test every automatic rule with fixtures
- **CC-007**: Feature MUST NOT introduce Raycast, external ebook engines, helper
  processes, conversion, DRM removal, library, history, cloud, account, AI, or a
  parallel product surface

### Key Entities _(include if feature involves data)_

- **Current Batch**: Ordered temporary selected snapshot and aggregate progress
- **Batch Item**: One EPUB or PDF with eligibility, pipeline state, and outcome
- **Health Finding**: Stable evidence with severity, repairability, action, and revalidation result
- **Prepared Book**: Eligible original PDF or validated EPUB working copy
- **Delivery Attempt**: One explicit independent SMTP transmission and terminal outcome

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: [First-use or repeated-send completion metric]
- **SC-002**: [Launch, shortcut, or concise-feedback responsiveness metric]
- **SC-003**: [Original-preservation and pipeline-correctness metric]
- **SC-004**: [Batch isolation and capacity metric]
- **SC-005**: [Two-screen, accessibility, privacy, or explicit-delivery metric]

## Assumptions

- Target users have a supported Mac, local EPUB or PDF books, valid SMTP
  credentials, and a Kindle personal-document address
- The product exposes only delivery setup and sending; EPUB preparation remains
  an automatic background pipeline
- A temporary batch is not a persistent queue or delivery history
- Processing is local and SMTP transmission requires explicit confirmation
- Cloud sync, accounts, conversion, DRM removal, external engines, and non-book
  inputs are out of scope
