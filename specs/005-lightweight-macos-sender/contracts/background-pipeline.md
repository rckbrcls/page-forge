# Contract: Background Pipeline and Batch

## Intake

Both intake surfaces produce an ordered list of candidate URLs for one
`BookIntakeService`. Intake validates supported type, readability, regular-file
status, duplicate identity, size limit, and stable streaming copy. Security scope
is acquired and balanced around the copy only.

## Preparation

EPUB:

```text
Safety Check -> Structural Audit -> Plan -> Repair if deterministic
-> Write Separate Copy -> Reopen -> Revalidate -> Compare -> Ready or Blocked
```

PDF:

```text
Eligibility Check -> Immutable Staged Snapshot -> Ready or Blocked
```

The UI receives only typed minimal events. Audit reports and applied-action
evidence remain available to tests and inline failure disclosure.

## Stable confirmation

Confirmation creates an immutable ordered snapshot containing the setup revision,
destination, eligible IDs, and excluded IDs. Later editing does not mutate the
active snapshot. The actor processes eligible IDs sequentially and opens one
independent delivery attempt per item.

## Cancellation

Cancellation:

- prevents scheduling pending items;
- calls `Task.checkCancellation()` between stages;
- lets streaming archive/filesystem/SMTP callbacks stop cooperatively;
- closes the active SMTP channel;
- preserves completed results;
- removes safe partial output;
- reports `cancelled` before DATA and `deliveryUnknown` after DATA starts without
  a final response.

## Failure isolation

An intake, preparation, or delivery failure terminates only its item. Later
eligible items proceed unless the batch is cancelled. There is no automatic
retry. Every selected item reaches one visible terminal or excluded state.

## Resource bounds

At most one book preparation, archive entry operation, and SMTP attempt is
active. A 20-item accepted batch must not fail solely due to batch count. Each
adapter enforces its own size, time, and memory limits and returns typed failure.
