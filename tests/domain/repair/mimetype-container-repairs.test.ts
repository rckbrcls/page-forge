import { describe, expect, it } from "vitest";

import { rebuildContainerForSingleOpf, writeCanonicalMimetype } from "../../../src/domain/repair/xml-transformations";
import {
  canonicalContainer,
  canonicalMimetype,
  containerRepairFixtures,
  mimetypeRepairFixtures,
} from "../../fixtures/repair/mimetype-container-fixtures";

describe("mimetype and container repairs", () => {
  it.each(mimetypeRepairFixtures)("writes canonical bytes for $name", (fixture) => {
    expect(fixture.epub.subarray(0, 4)).toEqual(Buffer.from([0x50, 0x4b, 0x03, 0x04]));

    const first = writeCanonicalMimetype();
    const second = writeCanonicalMimetype();

    expect(first).toEqual(fixture.expected);
    expect(second).toEqual(first);
    expect(first).toEqual(canonicalMimetype);
    expect(Buffer.from(first).toString("ascii")).toBe("application/epub+zip");
  });

  it.each(containerRepairFixtures)("rebuilds a canonical container for the sole OPF in $name", (fixture) => {
    expect(fixture.epub.subarray(0, 4)).toEqual(Buffer.from([0x50, 0x4b, 0x03, 0x04]));
    const originalSource = fixture.source && Buffer.from(fixture.source);

    const first = rebuildContainerForSingleOpf(fixture.packagePath);
    const second = rebuildContainerForSingleOpf(fixture.packagePath);

    expect(first).toEqual(fixture.expected);
    expect(second).toEqual(first);
    expect(first).toEqual(canonicalContainer);
    expect(Buffer.from(first).toString("utf8")).toContain('full-path="EPUB/O&apos;Brien &amp; Notes.opf"');
    expect(fixture.source).toEqual(originalSource);
  });

  it("does not copy malformed container markup or editorial package data", () => {
    const malformed = containerRepairFixtures.find(({ source }) =>
      source ? Buffer.from(source).toString("utf8").includes("<rootfiles>") : false,
    );
    expect(malformed).toBeDefined();

    const output = Buffer.from(rebuildContainerForSingleOpf(malformed!.packagePath)).toString("utf8");

    expect(output).toBe(Buffer.from(canonicalContainer).toString("utf8"));
    expect(output).not.toContain("Fixture Book");
    expect(output).not.toContain("<metadata");
  });
});
