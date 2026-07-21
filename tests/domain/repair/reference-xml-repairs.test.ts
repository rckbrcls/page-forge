import { describe, expect, it } from "vitest";

import {
  correctManifestMediaType,
  correctUniqueReference,
  normalizeEquivalentInternalPath,
  normalizeXmlEncoding,
} from "../../../src/domain/repair/xml-transformations";
import {
  equivalentPathRepairFixtures,
  mediaTypeRepairFixture,
  referenceRepairFixture,
  xmlEncodingRepairFixtures,
} from "../../fixtures/repair/reference-xml-fixtures";

function expectEpubFixture(epub: Uint8Array): void {
  expect(epub.subarray(0, 4)).toEqual(Buffer.from([0x50, 0x4b, 0x03, 0x04]));
}

describe("reference and XML repairs", () => {
  it("corrects only the selected manifest item's media type", () => {
    const fixture = mediaTypeRepairFixture;
    expectEpubFixture(fixture.epub);
    const original = Buffer.from(fixture.input);

    const first = correctManifestMediaType(fixture.input, fixture.manifestId, fixture.mediaType);
    const second = correctManifestMediaType(fixture.input, fixture.manifestId, fixture.mediaType);

    expect(first).toEqual(fixture.expected);
    expect(second).toEqual(first);
    expect(fixture.input).toEqual(original);
    expect(Buffer.from(first).toString("utf8")).toContain(
      "Keep text/plain &amp; punctuation exactly.",
    );
    expect(Buffer.from(first).toString("utf8")).toContain('data-note="text/plain"');
  });

  it("corrects exactly one planned reference without rewriting authored text", () => {
    const fixture = referenceRepairFixture;
    expectEpubFixture(fixture.epub);
    const original = Buffer.from(fixture.input);

    const first = correctUniqueReference(
      fixture.input,
      fixture.originalReference,
      fixture.replacementReference,
    );
    const second = correctUniqueReference(
      fixture.input,
      fixture.originalReference,
      fixture.replacementReference,
    );

    expect(first).toEqual(fixture.expected);
    expect(second).toEqual(first);
    expect(fixture.input).toEqual(original);
    expect(Buffer.from(first).toString("utf8")).toContain(
      `Keep ${fixture.originalReference} as authored text.`,
    );
    expect(Buffer.from(first).toString("utf8")).toContain(
      `data-note="${fixture.originalReference}"`,
    );
  });

  it.each(equivalentPathRepairFixtures)(
    "normalizes $name without changing resource bytes",
    (fixture) => {
      expectEpubFixture(fixture.epub);
      const original = Buffer.from(fixture.content);

      const first = normalizeEquivalentInternalPath(
        fixture.sourcePath,
        fixture.targetPath,
        fixture.content,
      );
      const second = normalizeEquivalentInternalPath(
        fixture.sourcePath,
        fixture.targetPath,
        fixture.content,
      );

      expect(first).toEqual({ path: fixture.targetPath, content: fixture.content });
      expect(second).toEqual(first);
      expect(first.content).toEqual(original);
      expect(fixture.content).toEqual(original);
    },
  );

  it.each(xmlEncodingRepairFixtures)(
    "normalizes $name to UTF-8 without changing XML meaning or editorial data",
    (fixture) => {
      expectEpubFixture(fixture.epub);
      const original = Buffer.from(fixture.input);

      const first = normalizeXmlEncoding(fixture.input);
      const second = normalizeXmlEncoding(fixture.input);

      expect(first).toEqual(fixture.expected);
      expect(second).toEqual(first);
      expect(fixture.input).toEqual(original);
      expect(Buffer.from(first).toString("utf8")).toContain("Café &amp; Tea");
      expect(Buffer.from(first).toString("utf8")).toContain("  Keep  spaces  ");
      expect(Buffer.from(first).toString("utf8")).toContain("Preserve spacing, comments, entities");
    },
  );
});
