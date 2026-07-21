import { createFinding } from "../../../src/domain/audit/finding-catalog";
import { parseInternalPath } from "../../../src/domain/audit/internal-path";
import type { RepairCandidateFacts } from "../../../src/domain/repair/create-repair-plan";
import type { InternalPath } from "../../../src/domain/models/archive";
import type { Finding } from "../../../src/domain/models/finding";

export interface AmbiguousRepairRefusalFixture {
  readonly name: string;
  readonly policyArea:
    | "opf"
    | "cover"
    | "navigation"
    | "reference"
    | "metadata"
    | "manifest"
    | "chapter"
    | "xhtml"
    | "script"
    | "font"
    | "css";
  readonly finding: Finding;
  readonly candidates: RepairCandidateFacts;
  readonly proposedAction: string;
  readonly protectedPaths: readonly InternalPath[];
  readonly expectedReason: RegExp;
}

const packagePath = internalPath("EPUB/package.opf");
const chapterPath = internalPath("EPUB/text/chapter.xhtml");
const alternateChapterPath = internalPath("EPUB/text/alternate/chapter.xhtml");
const coverPath = internalPath("EPUB/images/cover.png");
const alternateCoverPath = internalPath("EPUB/images/cover.jpg");
const navPath = internalPath("EPUB/nav.xhtml");
const scriptPath = internalPath("EPUB/scripts/book.js");
const fontPath = internalPath("EPUB/fonts/book.woff");
const stylesheetPath = internalPath("EPUB/styles/book.css");

function internalPath(value: string): InternalPath {
  const parsed = parseInternalPath(value);
  if (!parsed.ok) throw new Error(`Invalid fixture internal path: ${value}`);
  return parsed.value.path;
}

function forbiddenProposal(
  finding: Finding,
  proposedAction: string,
): Finding {
  return {
    ...finding,
    repairability: "automatic",
    recommendedRepair: proposedAction,
  } as unknown as Finding;
}

function refusal(
  fixture: Omit<AmbiguousRepairRefusalFixture, "candidates" | "expectedReason"> & {
    readonly candidates?: RepairCandidateFacts;
    readonly expectedReason?: RegExp;
  },
): AmbiguousRepairRefusalFixture {
  return {
    ...fixture,
    candidates: fixture.candidates ?? {},
    expectedReason: fixture.expectedReason ?? /allow|permitted|support/i,
  };
}

const ambiguousReference = createFinding("CONTENT_LINK_BROKEN", {
  location: { kind: "xml", path: chapterPath, line: 9, column: 16 },
  targetIdentifier: "EPUB/text/chapter.xhtml#target",
  evidence: { reference: "chapter.xhtml#target" },
  repairability: "automatic",
  stateImpact: "repairable",
  recommendedRepair: "correct_unique_reference",
});

export const ambiguousRepairRefusalFixtures = [
  refusal({
    name: "multiple plausible OPF package documents",
    policyArea: "opf",
    finding: forbiddenProposal(
      createFinding("PACKAGE_AMBIGUOUS", {
        location: { kind: "internal_path", path: packagePath },
      }),
      "choose_package_document",
    ),
    proposedAction: "choose_package_document",
    protectedPaths: [packagePath],
  }),
  refusal({
    name: "multiple plausible cover resources",
    policyArea: "cover",
    finding: forbiddenProposal(
      createFinding("COVER_AMBIGUOUS", {
        location: { kind: "internal_path", path: packagePath },
        evidence: { first: coverPath, second: alternateCoverPath },
      }),
      "choose_cover",
    ),
    proposedAction: "choose_cover",
    protectedPaths: [packagePath, coverPath, alternateCoverPath],
  }),
  refusal({
    name: "missing navigation requiring inferred reading semantics",
    policyArea: "navigation",
    finding: forbiddenProposal(
      createFinding("NAVIGATION_MISSING", {
        location: { kind: "internal_path", path: packagePath },
      }),
      "infer_navigation",
    ),
    proposedAction: "infer_navigation",
    protectedPaths: [packagePath, navPath],
  }),
  refusal({
    name: "broken reference with multiple plausible targets",
    policyArea: "reference",
    finding: ambiguousReference,
    candidates: {
      referenceCorrections: [
        {
          findingId: ambiguousReference.identity,
          ownerPath: chapterPath,
          originalReference: "chapter.xhtml#target",
          replacementReference: "../chapter.xhtml#target",
          targetPath: chapterPath,
        },
        {
          findingId: ambiguousReference.identity,
          ownerPath: chapterPath,
          originalReference: "chapter.xhtml#target",
          replacementReference: "alternate/chapter.xhtml#target",
          targetPath: alternateChapterPath,
        },
      ],
    },
    proposedAction: "correct_unique_reference",
    protectedPaths: [chapterPath, alternateChapterPath],
    expectedReason: /unique|ambiguous|deterministic/i,
  }),
  refusal({
    name: "missing title requiring editorial metadata",
    policyArea: "metadata",
    finding: forbiddenProposal(
      createFinding("METADATA_TITLE_MISSING", {
        location: { kind: "internal_path", path: packagePath },
      }),
      "rewrite_editorial_metadata",
    ),
    proposedAction: "rewrite_editorial_metadata",
    protectedPaths: [packagePath],
  }),
  refusal({
    name: "missing manifest requiring deep reconstruction",
    policyArea: "manifest",
    finding: forbiddenProposal(
      createFinding("MANIFEST_MISSING", {
        location: { kind: "internal_path", path: packagePath },
      }),
      "reconstruct_manifest",
    ),
    proposedAction: "reconstruct_manifest",
    protectedPaths: [packagePath],
  }),
  refusal({
    name: "empty chapter proposed for deletion",
    policyArea: "chapter",
    finding: forbiddenProposal(
      createFinding("CONTENT_CHAPTER_EMPTY", {
        location: { kind: "internal_path", path: chapterPath },
      }),
      "delete_chapter",
    ),
    proposedAction: "delete_chapter",
    protectedPaths: [packagePath, chapterPath, navPath],
  }),
  refusal({
    name: "malformed XHTML proposed for destructive rewrite",
    policyArea: "xhtml",
    finding: forbiddenProposal(
      createFinding("XHTML_MALFORMED", {
        location: { kind: "internal_path", path: chapterPath },
      }),
      "rewrite_xhtml",
    ),
    proposedAction: "rewrite_xhtml",
    protectedPaths: [chapterPath],
  }),
  refusal({
    name: "scripted content proposed for removal",
    policyArea: "script",
    finding: forbiddenProposal(
      createFinding("CONTENT_SCRIPTED", {
        location: { kind: "internal_path", path: chapterPath },
      }),
      "remove_script",
    ),
    proposedAction: "remove_script",
    protectedPaths: [chapterPath, scriptPath],
  }),
  refusal({
    name: "missing font proposed for removal",
    policyArea: "font",
    finding: forbiddenProposal(
      createFinding("CONTENT_FONT_MISSING", {
        location: { kind: "internal_path", path: stylesheetPath },
        targetIdentifier: fontPath,
      }),
      "remove_font",
    ),
    proposedAction: "remove_font",
    protectedPaths: [packagePath, stylesheetPath, fontPath],
  }),
  refusal({
    name: "stylesheet proposed for aesthetic editorial rewrite",
    policyArea: "css",
    finding: forbiddenProposal(
      createFinding("CONTENT_STYLESHEET_MISSING", {
        location: { kind: "internal_path", path: chapterPath },
        targetIdentifier: stylesheetPath,
      }),
      "rewrite_css_aesthetics",
    ),
    proposedAction: "rewrite_css_aesthetics",
    protectedPaths: [chapterPath, stylesheetPath],
  }),
] as const satisfies readonly AmbiguousRepairRefusalFixture[];
