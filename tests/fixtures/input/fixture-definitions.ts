import type { FindingCode } from "../../../src/domain/audit/finding-codes";
import type {
  FilesystemIdentity,
  SelectedEpub,
  SelectedEpubId,
  SelectionRejection,
  SelectionSnapshot,
} from "../../../src/domain/models/epub-document";
import { createFindingIdentity, type Finding } from "../../../src/domain/models/finding";

const SELECTED_AT_MS = Date.UTC(2026, 6, 20, 12);

function identity(device: string, file: string): FilesystemIdentity {
  return { device, file };
}

export function selectedEpub(
  sourcePath: string,
  displayName: string,
  file: string,
  overrides: Partial<SelectedEpub> = {},
): SelectedEpub {
  return {
    id: `selected-${file}` as SelectedEpubId,
    sourcePath,
    displayName,
    identity: identity("fixture-device", file),
    sizeBytes: 4_096,
    modifiedAtMs: SELECTED_AT_MS - 1_000,
    readable: true,
    ...overrides,
  };
}

function inputFinding(code: FindingCode, title: string, description: string): Finding {
  const stateImpact = code === "INPUT_CHANGED" ? "needs_review" : "unsupported";
  return {
    identity: createFindingIdentity(code),
    code,
    severity: "error",
    category: "input",
    title,
    description,
    repairability: "none",
    revalidation: "not_compared",
    evidence: {},
    stateImpact,
  };
}

function rejection(
  selectionIndex: number,
  displayName: string,
  code: FindingCode,
  title: string,
): SelectionRejection {
  return {
    selectionIndex,
    displayName,
    finding: inputFinding(code, title, `Fixture rejection for ${displayName}.`),
  };
}

export interface InputFixtureDefinition {
  readonly name: string;
  readonly finderPaths: readonly string[];
  readonly pickerPaths: readonly string[];
  readonly finderSnapshot: SelectionSnapshot;
  readonly pickerSnapshot: SelectionSnapshot;
}

const unicodeBook = selectedEpub(
  "/fixtures/Cem anos de solidão.epub",
  "Cem anos de solidão.epub",
  "unicode-book",
);
const upperCaseBook = selectedEpub("/fixtures/REFERENCE.EPUB", "REFERENCE.EPUB", "uppercase-book");

export const mixedFinderSelection: InputFixtureDefinition = {
  name: "mixed Finder selection",
  finderPaths: [
    unicodeBook.sourcePath,
    "/fixtures/notes.txt",
    upperCaseBook.sourcePath,
    unicodeBook.sourcePath,
    "/fixtures/library.epub",
    "/fixtures/missing.epub",
    "/fixtures/unreadable.epub",
  ],
  pickerPaths: [],
  finderSnapshot: {
    items: [unicodeBook, upperCaseBook],
    rejections: [
      rejection(1, "notes.txt", "INPUT_NOT_EPUB", "Unsupported file type"),
      rejection(4, "library.epub", "INPUT_NOT_REGULAR_FILE", "Not a regular file"),
      rejection(5, "missing.epub", "INPUT_NOT_REGULAR_FILE", "File not found"),
      rejection(6, "unreadable.epub", "INPUT_UNREADABLE", "File is not readable"),
    ],
    selectedAtMs: SELECTED_AT_MS,
  },
  pickerSnapshot: { items: [], rejections: [], selectedAtMs: SELECTED_AT_MS },
};

const pickerBook = selectedEpub("/fixtures/picker-book.epub", "picker-book.epub", "picker-book");

export const pickerFallbackSelection: InputFixtureDefinition = {
  name: "picker fallback",
  finderPaths: ["/fixtures/readme.md", "/fixtures/books"],
  pickerPaths: [pickerBook.sourcePath, "/fixtures/picker-notes.txt"],
  finderSnapshot: {
    items: [],
    rejections: [
      rejection(0, "readme.md", "INPUT_NOT_EPUB", "Unsupported file type"),
      rejection(1, "books", "INPUT_NOT_REGULAR_FILE", "Not a regular file"),
    ],
    selectedAtMs: SELECTED_AT_MS,
  },
  pickerSnapshot: {
    items: [pickerBook],
    rejections: [
      rejection(1, "picker-notes.txt", "INPUT_NOT_EPUB", "Unsupported file type"),
    ],
    selectedAtMs: SELECTED_AT_MS + 1,
  },
};

const firstAlias = selectedEpub("/fixtures/alias.epub", "alias.epub", "shared-inode");

export const duplicateIdentitySelection: InputFixtureDefinition = {
  name: "duplicate filesystem identity",
  finderPaths: ["/fixtures/alias.epub", "/fixtures/original.epub"],
  pickerPaths: [],
  finderSnapshot: {
    items: [firstAlias],
    rejections: [],
    selectedAtMs: SELECTED_AT_MS,
  },
  pickerSnapshot: { items: [], rejections: [], selectedAtMs: SELECTED_AT_MS },
};

export const changedPickerSelection: InputFixtureDefinition = {
  name: "changed picker snapshot",
  finderPaths: [],
  pickerPaths: ["/fixtures/replaced.epub"],
  finderSnapshot: { items: [], rejections: [], selectedAtMs: SELECTED_AT_MS },
  pickerSnapshot: {
    items: [],
    rejections: [rejection(0, "replaced.epub", "INPUT_CHANGED", "File changed after selection")],
    selectedAtMs: SELECTED_AT_MS + 1,
  },
};

export const inputFixtureDefinitions = [
  mixedFinderSelection,
  pickerFallbackSelection,
  duplicateIdentitySelection,
  changedPickerSelection,
] as const;
