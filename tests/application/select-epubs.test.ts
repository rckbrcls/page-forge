import { describe, expect, it, vi } from "vitest";

import type { SelectionPort } from "../../src/application/ports";
import { selectEpubs } from "../../src/application/select-epubs";
import { ok } from "../../src/domain/models/result";
import {
  changedPickerSelection,
  duplicateIdentitySelection,
  mixedFinderSelection,
  pickerFallbackSelection,
  type InputFixtureDefinition,
} from "../fixtures/input/fixture-definitions";

class FakeSelectionPort implements SelectionPort {
  readonly selectedFinderPaths = vi.fn(async () => ok(this.fixture.finderPaths));
  readonly pickEpubPaths = vi.fn(async () => ok(this.fixture.pickerPaths));
  readonly snapshotSelection = vi.fn(async (paths: readonly string[], _signal: AbortSignal) => {
    if (paths === this.fixture.finderPaths) return ok(this.fixture.finderSnapshot);
    if (paths === this.fixture.pickerPaths) return ok(this.fixture.pickerSnapshot);
    throw new Error("Unexpected selection source");
  });

  constructor(private readonly fixture: InputFixtureDefinition) {}
}

async function runSelection(fixture: InputFixtureDefinition) {
  const port = new FakeSelectionPort(fixture);
  const result = await selectEpubs(port, new AbortController().signal);
  expect(result.ok).toBe(true);
  if (!result.ok) throw new Error(result.failure.safeMessage);
  return { port, snapshot: result.value };
}

describe("selectEpubs", () => {
  it("keeps supported Finder EPUBs in first-selection order and reports every rejected item", async () => {
    const { port, snapshot } = await runSelection(mixedFinderSelection);

    expect(snapshot.items.map(({ displayName }) => displayName)).toEqual([
      "Cem anos de solidão.epub",
      "REFERENCE.EPUB",
    ]);
    expect(
      snapshot.rejections.map(({ selectionIndex, displayName, finding }) => ({
        selectionIndex,
        displayName,
        code: finding.code,
      })),
    ).toEqual([
      { selectionIndex: 1, displayName: "notes.txt", code: "INPUT_NOT_EPUB" },
      { selectionIndex: 4, displayName: "library.epub", code: "INPUT_NOT_REGULAR_FILE" },
      { selectionIndex: 5, displayName: "missing.epub", code: "INPUT_NOT_REGULAR_FILE" },
      { selectionIndex: 6, displayName: "unreadable.epub", code: "INPUT_UNREADABLE" },
    ]);
    expect(port.pickEpubPaths).not.toHaveBeenCalled();
  });

  it("opens the multi-file picker only when Finder leaves no valid EPUB", async () => {
    const { port, snapshot } = await runSelection(pickerFallbackSelection);

    expect(port.snapshotSelection).toHaveBeenNthCalledWith(
      1,
      pickerFallbackSelection.finderPaths,
      expect.any(AbortSignal),
    );
    expect(port.pickEpubPaths).toHaveBeenCalledOnce();
    expect(port.snapshotSelection).toHaveBeenNthCalledWith(
      2,
      pickerFallbackSelection.pickerPaths,
      expect.any(AbortSignal),
    );
    expect(snapshot).toEqual(pickerFallbackSelection.pickerSnapshot);
  });

  it("does not invoke the picker for a mixed Finder selection containing a valid EPUB", async () => {
    const { port } = await runSelection(mixedFinderSelection);

    expect(port.snapshotSelection).toHaveBeenCalledOnce();
    expect(port.pickEpubPaths).not.toHaveBeenCalled();
  });

  it("collapses aliases by filesystem identity and preserves the first selected path", async () => {
    const { snapshot } = await runSelection(duplicateIdentitySelection);

    expect(snapshot.items).toHaveLength(1);
    expect(snapshot.items[0]).toMatchObject({
      sourcePath: "/fixtures/alias.epub",
      displayName: "alias.epub",
      identity: { device: "fixture-device", file: "shared-inode" },
    });
  });

  it("returns an item-level INPUT_CHANGED rejection when picker submission no longer matches", async () => {
    const { snapshot } = await runSelection(changedPickerSelection);

    expect(snapshot.items).toEqual([]);
    expect(snapshot.rejections).toHaveLength(1);
    expect(snapshot.rejections[0]).toMatchObject({
      selectionIndex: 0,
      displayName: "replaced.epub",
      finding: {
        code: "INPUT_CHANGED",
        stateImpact: "needs_review",
        repairability: "none",
      },
    });
  });
});
