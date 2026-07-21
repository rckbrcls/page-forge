import * as filesystem from "node:fs/promises";

import { afterEach, describe, expect, it, vi } from "vitest";

import { parseSafeXml } from "../../../src/adapters/xml/safe-xml-parser";
import type { SafeXmlError } from "../../../src/adapters/xml/safe-xml-parser";
import { XML_LIMITS } from "../../../src/domain/audit/limits";
import {
  cancellableXml,
  externalResolutionXml,
  nestedXml,
  recursiveEntityXml,
  rejectedXmlFixtures,
  sizedXml,
  xmlDepthBoundaries,
  xmlSizeBoundaries,
} from "../../fixtures/malicious/xml-fixtures";

vi.mock("node:fs/promises", () => ({ readFile: vi.fn() }));

const activeSignal = () => new AbortController().signal;

async function expectXmlError(
  operation: Promise<unknown>,
  code: SafeXmlError["code"],
): Promise<void> {
  await expect(operation).rejects.toMatchObject({ name: "SafeXmlError", code });
}

describe("safe XML parsing", () => {
  it.each(rejectedXmlFixtures)("rejects $name", async ({ bytes, code }) => {
    await expectXmlError(parseSafeXml(bytes, XML_LIMITS, activeSignal()), code);
  });

  it.each(xmlSizeBoundaries)(
    "handles XML size $name the 10 MB limit",
    async ({ byteLength, accepted }) => {
      const operation = parseSafeXml(sizedXml(byteLength), XML_LIMITS, activeSignal());

      if (accepted) {
        await expect(operation).resolves.toMatchObject({ byteLength });
      } else {
        await expectXmlError(operation, "too_large");
      }
    },
  );

  it.each(xmlDepthBoundaries)(
    "handles XML depth $name depth 64",
    async ({ depth, accepted }) => {
      const operation = parseSafeXml(nestedXml(depth), XML_LIMITS, activeSignal());

      if (accepted) {
        await expect(operation).resolves.toMatchObject({ encoding: "utf-8" });
      } else {
        await expectXmlError(operation, "too_deep");
      }
    },
  );

  it("bounds recursive entity input without expanding it", async () => {
    const onText = vi.fn();

    await expectXmlError(
      parseSafeXml(recursiveEntityXml, XML_LIMITS, activeSignal(), { onText }),
      "doctype_forbidden",
    );
    expect(onText).not.toHaveBeenCalled();
  });

  it("cancels between input chunks", async () => {
    const controller = new AbortController();

    await expectXmlError(
      parseSafeXml(cancellableXml(controller), XML_LIMITS, controller.signal),
      "cancelled",
    );
  });

  it.each(externalResolutionXml)(
    "never resolves local or remote resources",
    async (bytes) => {
      const fetch = vi.fn();
      vi.stubGlobal("fetch", fetch);
      const readFile = vi.mocked(filesystem.readFile);

      await expectXmlError(parseSafeXml(bytes, XML_LIMITS, activeSignal()), "doctype_forbidden");

      expect(fetch).not.toHaveBeenCalled();
      expect(readFile).not.toHaveBeenCalled();
    },
  );
});

afterEach(() => {
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});
