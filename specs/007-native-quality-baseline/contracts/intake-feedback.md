# Contract: Intake Feedback

## Purpose

Ensure every Finder and drag-and-drop intake attempt produces a deterministic
accepted, rejected, cancelled, or failed outcome without leaking sensitive
details.

## Shared path

Finder and drag-and-drop must forward accepted URLs into the same application
intake service. SwiftUI views may collect platform results and forward intent,
but they do not own file validation, deduplication, batch limits,
security-scoped access, or preparation.

## Finder contract

1. User cancellation is an expected no-op and does not show an error.
2. Successful URLs preserve picker order and enter the shared intake path once.
3. Non-cancellation failures produce concise sanitized visible feedback.
4. A raw provider exception or full path is never shown or logged.

## Drag-and-drop contract

1. Each supplied item provider receives one explicit transfer outcome.
2. URL transfer uses the modern transferable API.
3. Successful URLs preserve provider order before shared validation.
4. Failed transfers do not discard valid peers.
5. The user sees the number of items that could not be read and a safe next
   action.
6. Completion is delivered to the presentation model on `MainActor`.

## Shared validation outcomes

Every accepted URL subsequently reaches one of the existing typed outcomes:
accepted, duplicate, unsupported, over batch limit, unsafe, or unreadable.
Concise feedback may aggregate repeated reasons, but no attempted URL silently
disappears.

## Required evidence

- Finder success.
- Finder user cancellation.
- Finder non-cancellation failure.
- Drop with all providers valid.
- Drop with mixed valid and failed providers.
- Drop with all providers failed.
- Stable accepted-item ordering despite asynchronous provider completion.
- Sanitization checks excluding raw errors and full paths.
