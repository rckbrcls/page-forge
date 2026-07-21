import { createFinding } from "../finding-catalog";
import type { InternalPath } from "../../models/archive";
import type { MimetypeProjection } from "../../models/epub-document";
import type { Finding } from "../../models/finding";

const MIMETYPE_PATH = "mimetype" as InternalPath;
const MIMETYPE_VALUE = "application/epub+zip";

export function auditMimetype(mimetype: MimetypeProjection | undefined): Finding[] {
  const location = { kind: "internal_path" as const, path: MIMETYPE_PATH };
  if (mimetype === undefined) return [createFinding("MIMETYPE_MISSING", { location })];

  const findings: Finding[] = [];
  if (mimetype.entryIndex !== 0) {
    findings.push(
      createFinding("MIMETYPE_NOT_FIRST", {
        location,
        evidence: { entryIndex: mimetype.entryIndex },
      }),
    );
  }
  if (mimetype.compressionMethod !== 0) {
    findings.push(
      createFinding("MIMETYPE_COMPRESSED", {
        location,
        evidence: { compressionMethod: mimetype.compressionMethod },
      }),
    );
  }
  if (mimetype.value !== MIMETYPE_VALUE) {
    findings.push(createFinding("MIMETYPE_VALUE_INVALID", { location }));
  }
  if (mimetype.localHeaderExtraLength !== 0) {
    findings.push(
      createFinding("MIMETYPE_EXTRA_FIELD", {
        location,
        evidence: { extraLength: mimetype.localHeaderExtraLength },
      }),
    );
  }
  return findings;
}

export const auditMimetypeRules = auditMimetype;
