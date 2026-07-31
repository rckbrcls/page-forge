# Contract: Batch Row Divider

## Purpose

Make each boundary between complete adjacent book rows span almost the full
usable batch-card width while preserving native list scrolling, accessibility,
expanded details, and calm hierarchy.

## Rendering contract

The batch continues using its existing `GroupBox` and `List`.

For a stable ordered snapshot of `n` items:

- hide the list's default row separators;
- render one complete item container per book;
- keep `BatchItemRow` and optional `ItemDetailDisclosure` inside that container;
- append one explicit `Divider` only when `index < n - 1`;
- place the divider after expanded/collapsed detail content;
- use balanced leading/trailing row insets;
- keep divider inside the GroupBox boundary.

## Count invariants

| Item count | Divider count |
|---:|---:|
| 0 | 0 |
| 1 | 0 |
| 2 | 1 |
| `n` | `n - 1` |

Removing, adding, or clearing items recomputes count from the current ordered
snapshot.

## Geometry contract

For every visible divider:

```text
divider width / usable card row width >= 0.90
```

Additionally:

- leading and trailing insets are equal within normal rendering precision;
- divider does not touch or cross the GroupBox border;
- long filenames and trailing status/remove controls do not shorten it;
- expanded details do not split the row from its divider;
- scrolling/reuse does not change its alignment;
- window resizing preserves the ratio at every supported size.

## Accessibility contract

- Divider is decorative and hidden from the semantic reading order.
- It may expose a deterministic test-only identifier:
  `sendBook.item.divider.<itemID>`.
- Book row label, state, details, and remove action remain unchanged.
- Divider cannot become a keyboard or pointer target.

## Appearance contract

- Use the native semantic separator style.
- Normal contrast remains subtle and subordinate to text/status.
- Increase Contrast keeps it perceivable.
- Divider does not use accent, success, warning, or error color.
- No shadow, glass, animation, or rounded container is added to each row.

## UI geometry test

For batches containing 2, 3, and 20 items:

1. capture batch-card frame;
2. capture every visible divider frame;
3. derive usable row width from card/list content bounds;
4. assert each ratio is at least 0.90;
5. assert no divider exists for the final item;
6. expand a failure detail and repeat;
7. resize to supported minimum and a larger size and repeat;
8. scroll and repeat for reused rows.

## Non-goals

- replacing `List`;
- adding selection behavior;
- adding a card around every row;
- changing filename/status/remove layout;
- changing batch ordering or item identity;
- changing per-item preparation, delivery, failure, or retry behavior.
