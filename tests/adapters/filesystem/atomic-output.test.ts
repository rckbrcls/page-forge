import * as fsPromises from "node:fs/promises";
import { basename, dirname } from "node:path";

import { afterEach, describe, expect, it, vi } from "vitest";

import type { TemporaryOutput } from "../../../src/application/ports";
import {
  cleanupTemporary,
  createSameDirectoryTemporary,
  predictOutput,
  promoteNoClobber,
} from "../../../src/adapters/filesystem/atomic-output-writer";
import { withTestFilesystem } from "../../support/test-filesystem";

const linkMock = vi.hoisted(() => vi.fn());

vi.mock("node:fs/promises", async (importOriginal) => {
  const actual = await importOriginal<typeof import("node:fs/promises")>();
  linkMock.mockImplementation((existingPath: string, newPath: string) =>
    actual.link(existingPath, newPath),
  );
  return { ...actual, link: linkMock };
});

afterEach(() => {
  linkMock.mockClear();
});

describe("atomic output writer", () => {
  it("predicts the first unused readable suffix without creating or reserving it", async () => {
    await withTestFilesystem(async (filesystem) => {
      const sourcePath = await filesystem.write("My Book.epub", "source");

      const first = await predictOutput(sourcePath, 1);

      expect(first).toMatchObject({
        ok: true,
        value: {
          sourcePath,
          candidatePath: filesystem.path("My Book-kindle-ready.epub"),
          suffix: 1,
        },
      });
      expect(await filesystem.exists("My Book-kindle-ready.epub")).toBe(false);

      await filesystem.write("My Book-kindle-ready.epub", "existing-1");
      await filesystem.write("My Book-kindle-ready-2.epub", "existing-2");
      const third = await predictOutput(sourcePath, 1);

      expect(third).toMatchObject({
        ok: true,
        value: {
          candidatePath: filesystem.path("My Book-kindle-ready-3.epub"),
          suffix: 3,
        },
      });
      expect(await filesystem.exists("My Book-kindle-ready-3.epub")).toBe(false);
    });
  });

  it("creates a private recognizable temporary in the source directory", async () => {
    await withTestFilesystem(async (filesystem) => {
      const sourcePath = await filesystem.write("nested/book.epub", "source");
      const prediction = await predictOutput(sourcePath, 1);
      if (!prediction.ok) throw new Error(prediction.failure.safeMessage);

      const result = await createSameDirectoryTemporary(prediction.value);

      expect(result.ok).toBe(true);
      if (!result.ok) return;
      expect(dirname(result.value.path)).toBe(dirname(sourcePath));
      expect(result.value.path).not.toBe(prediction.value.candidatePath);
      expect(basename(result.value.path)).toMatch(/^\.page-forge-.+/u);
      const stats = await fsPromises.lstat(result.value.path);
      expect(stats.isFile()).toBe(true);
      expect(stats.mode & 0o777).toBe(0o600);
    });
  });

  it("promotes with a no-clobber hard link and reports the final fingerprint", async () => {
    await withTestFilesystem(async (filesystem) => {
      const sourcePath = await filesystem.write("book.epub", "source");
      const prediction = await predictOutput(sourcePath, 1);
      if (!prediction.ok) throw new Error(prediction.failure.safeMessage);
      const temporary = await createSameDirectoryTemporary(prediction.value);
      if (!temporary.ok) throw new Error(temporary.failure.safeMessage);
      await fsPromises.writeFile(temporary.value.path, "revalidated output");
      const temporaryStats = await fsPromises.lstat(temporary.value.path);

      const result = await promoteNoClobber(temporary.value, prediction.value);

      expect(result).toMatchObject({
        ok: true,
        value: {
          path: filesystem.path("book-kindle-ready.epub"),
          displayName: "book-kindle-ready.epub",
          fingerprint: { sizeBytes: Buffer.byteLength("revalidated output") },
        },
      });
      const finalStats = await fsPromises.lstat(filesystem.path("book-kindle-ready.epub"));
      expect(finalStats.ino).toBe(temporaryStats.ino);
      expect(await filesystem.read("book-kindle-ready.epub")).toEqual(Buffer.from("revalidated output"));
    });
  });

  it("retries suffixes after race-time EEXIST without replacing prior outputs", async () => {
    await withTestFilesystem(async (filesystem) => {
      const sourcePath = await filesystem.write("book.epub", "source");
      const prediction = await predictOutput(sourcePath, 1);
      if (!prediction.ok) throw new Error(prediction.failure.safeMessage);
      const temporary = await createSameDirectoryTemporary(prediction.value);
      if (!temporary.ok) throw new Error(temporary.failure.safeMessage);
      await fsPromises.writeFile(temporary.value.path, "new output");

      await filesystem.write("book-kindle-ready.epub", "won race");
      await filesystem.write("book-kindle-ready-2.epub", "prior output");
      const result = await promoteNoClobber(temporary.value, prediction.value);

      expect(result).toMatchObject({
        ok: true,
        value: {
          path: filesystem.path("book-kindle-ready-3.epub"),
          displayName: "book-kindle-ready-3.epub",
        },
      });
      expect(await filesystem.read("book-kindle-ready.epub")).toEqual(Buffer.from("won race"));
      expect(await filesystem.read("book-kindle-ready-2.epub")).toEqual(Buffer.from("prior output"));
      expect(await filesystem.read("book-kindle-ready-3.epub")).toEqual(Buffer.from("new output"));
    });
  });

  it("fails safely when the volume cannot provide no-clobber hard-link promotion", async () => {
    await withTestFilesystem(async (filesystem) => {
      const sourcePath = await filesystem.write("book.epub", "source");
      const prediction = await predictOutput(sourcePath, 1);
      if (!prediction.ok) throw new Error(prediction.failure.safeMessage);
      const temporary = await createSameDirectoryTemporary(prediction.value);
      if (!temporary.ok) throw new Error(temporary.failure.safeMessage);
      await fsPromises.writeFile(temporary.value.path, "complete temporary");
      const unsupported = Object.assign(new Error("Hard links are unsupported"), { code: "ENOTSUP" });
      linkMock.mockRejectedValueOnce(unsupported);

      const result = await promoteNoClobber(temporary.value, prediction.value);

      expect(result).toMatchObject({
        ok: false,
        failure: { category: "repair", code: "REPAIR_OUTPUT_UNWRITABLE", phase: "promoting" },
      });
      expect(await filesystem.exists("book-kindle-ready.epub")).toBe(false);
      expect(await fsPromises.readFile(temporary.value.path)).toEqual(Buffer.from("complete temporary"));
    });
  });

  it("cleans owned temporaries but never deletes unrecognized files", async () => {
    await withTestFilesystem(async (filesystem) => {
      const sourcePath = await filesystem.write("book.epub", "source");
      const prediction = await predictOutput(sourcePath, 1);
      if (!prediction.ok) throw new Error(prediction.failure.safeMessage);
      const temporary = await createSameDirectoryTemporary(prediction.value);
      if (!temporary.ok) throw new Error(temporary.failure.safeMessage);
      const unrelatedPath = await filesystem.write(".not-page-forge.tmp", "keep");
      const unrecognized: TemporaryOutput = {
        ...temporary.value,
        id: "fabricated-owner",
        path: unrelatedPath,
      };

      const cleanup = await cleanupTemporary(temporary.value);
      await cleanupTemporary(unrecognized);

      expect(cleanup).toMatchObject({ ok: true });
      await expect(fsPromises.lstat(temporary.value.path)).rejects.toMatchObject({ code: "ENOENT" });
      expect(await filesystem.read(".not-page-forge.tmp")).toEqual(Buffer.from("keep"));
      expect(await filesystem.read("book.epub")).toEqual(Buffer.from("source"));
    });
  });
});
