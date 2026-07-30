# Contract: Send History UI

## Purpose

Expose a calm local record of definitive submissions inside `Send Book` without
creating a third primary screen or adding book-management behavior.

## Navigation

- `Send Book` contains exactly two local tabs: `Send` and `History`.
- `Send` is the default.
- The application route remains `Send Book`; selecting `History` is not a route
  change, Settings tab, sheet, window, or primary screen.
- Both tabs are keyboard reachable and expose clear accessibility names and
  selected state.

## Batch independence

Switching between tabs:

- does not add, remove, clear, confirm, retry, schedule, cancel, or restart a
  book;
- does not change the current batch identity, snapshot, progress, outcome,
  selection, or detail disclosure;
- does not interrupt an active sequential delivery;
- does not duplicate pipeline or accessibility events;
- returns to the same current batch state when `Send` is selected again.

## History list

- Render one row per `SubmissionRecord`.
- Order rows newest first as supplied by the application snapshot.
- Every row shows the original sanitized display name.
- Every row shows submission date and time derived from `acceptedAt`.
- Format date and time with the user's current locale, calendar, and time zone.
- Do not persist formatted date/time strings.
- Use wording equivalent to SMTP submission only.
- Do not claim Kindle receipt, processing, conversion, availability, or library
  presence.

The list contains no thumbnail, cover, grouping, analytics, chart, search,
filter, export, resend, retry, preview, open, reveal, locate, rename, delete-one,
or file-management action.

## Empty state

When a successful empty snapshot is loaded:

```text
No books submitted yet.
```

The empty state:

- does not imply history was loaded successfully when storage is unavailable;
- remains keyboard and accessibility readable;
- does not add a decorative card or oversized placeholder;
- does not affect an active or completed batch.

## Loading and failure

- Loading uses a concise non-blocking state.
- A load failure presents safe actionable history feedback and must not display
  a false successful-empty claim.
- A record failure may appear while the accepted item remains `Submitted`.
- History feedback remains visually and semantically separate from SMTP
  delivery feedback.
- No raw path, filesystem error, encoded record, or technical payload is shown.

## Clear History

- `Clear History` is a visibly secondary action.
- It is disabled when there are no loaded records or a clear is already active.
- Invoking it presents a native confirmation.
- Confirmation explains that local history records will be removed and the
  current batch will remain.
- Cancelling changes nothing.
- Successful clearing publishes an empty snapshot and a transient success
  acknowledgement.
- Failed clearing preserves the current visible list and shows persistent
  actionable feedback.

Clear History does not:

- clear, cancel, or reset the current batch;
- alter setup, credentials, shortcut, or application preferences;
- remove book files or prepared workspace;
- retry, retract, or reinterpret a delivery;
- clear unrelated diagnostics.

## Accessibility

- Tab controls expose names `Send` and `History` plus selected state.
- History rows expose one coherent label containing display name, submission
  date, and submission time.
- Date/time remains understandable without color or icon interpretation.
- Empty, loading, failure, and clear-confirmation states have explicit text.
- Focus returns predictably after confirmation or cancellation.
- A successful clear acknowledgement is announced once and expires according to
  the transient feedback contract.
- Dynamic history insertion does not flood announcements during a multi-book
  active batch.

## Acceptance checks

- Empty history presents the exact required string.
- One and multiple records render in newest-first order.
- Same-name accepted records remain separate.
- Locale/time-zone changes alter presentation without changing stored instants.
- Active batch state is identical before and after tab switching.
- Clear cancellation preserves records.
- Clear success empties history only.
- Clear failure preserves visible records.
- Storage unavailable is distinguishable from successful empty.
- Keyboard and supported assistive technology can select tabs, read rows, and
  operate clear confirmation.
