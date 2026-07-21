import type { Finding } from "../models/finding";
import type { RepairKind } from "../models/repair";

const CLOSED_REPAIR_ALLOWLIST = new Set<RepairKind>([
  "write_canonical_mimetype",
  "rebuild_container_for_single_opf",
  "correct_manifest_media_type",
  "correct_unique_reference",
  "normalize_equivalent_internal_path",
  "normalize_xml_encoding",
]);

const PROHIBITED_EDITORIAL_REPAIRS = new Set<string>([
  "choose_package_document",
  "choose_cover",
  "infer_navigation",
  "rewrite_editorial_metadata",
  "reconstruct_manifest",
  "delete_chapter",
  "rewrite_xhtml",
  "remove_script",
  "remove_font",
  "rewrite_css_aesthetics",
]);

export { CLOSED_REPAIR_ALLOWLIST, PROHIBITED_EDITORIAL_REPAIRS };

export function evaluateRepairPermission(finding: Finding): string | undefined {
  const proposedRepair = finding.recommendedRepair;

  if (proposedRepair === undefined) {
    return "This finding was not proposed with a supported automatic repair action.";
  }

  if (PROHIBITED_EDITORIAL_REPAIRS.has(proposedRepair)) {
    return `The proposed repair (${proposedRepair}) is editorially ambiguous and is not a permitted automatic repair.`;
  }

  if (proposedRepair === "rebuild_epub_archive" || !CLOSED_REPAIR_ALLOWLIST.has(proposedRepair)) {
    return "This finding has no supported repair in the closed allowlist.";
  }

  return undefined;
}
