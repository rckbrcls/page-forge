import { mkdtemp, mkdir, readFile, rm, stat, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, isAbsolute, join, relative, resolve } from "node:path";

import { hashFile, type FileHash } from "./hashes";

export interface TestFilesystem {
  readonly root: string;
  path(relativePath: string): string;
  write(relativePath: string, contents: string | Uint8Array): Promise<string>;
  read(relativePath: string): Promise<Buffer>;
  exists(relativePath: string): Promise<boolean>;
  hash(relativePath: string): Promise<FileHash>;
  cleanup(): Promise<void>;
}

function safePath(root: string, relativePath: string): string {
  if (relativePath.length === 0 || isAbsolute(relativePath)) {
    throw new Error("Test paths must be non-empty and relative");
  }
  const target = resolve(root, relativePath);
  const fromRoot = relative(root, target);
  if (fromRoot === ".." || fromRoot.startsWith(`..${process.platform === "win32" ? "\\" : "/"}`)) {
    throw new Error("Test paths must remain inside the temporary directory");
  }
  return target;
}

export async function createTestFilesystem(prefix = "page-forge-test-"): Promise<TestFilesystem> {
  const root = await mkdtemp(join(tmpdir(), prefix));
  let cleaned = false;

  return {
    root,
    path(relativePath: string): string {
      return safePath(root, relativePath);
    },
    async write(relativePath: string, contents: string | Uint8Array): Promise<string> {
      const target = safePath(root, relativePath);
      await mkdir(dirname(target), { recursive: true });
      await writeFile(target, contents);
      return target;
    },
    read(relativePath: string): Promise<Buffer> {
      return readFile(safePath(root, relativePath));
    },
    async exists(relativePath: string): Promise<boolean> {
      try {
        await stat(safePath(root, relativePath));
        return true;
      } catch (error) {
        if ((error as NodeJS.ErrnoException).code === "ENOENT") return false;
        throw error;
      }
    },
    hash(relativePath: string): Promise<FileHash> {
      return hashFile(safePath(root, relativePath));
    },
    async cleanup(): Promise<void> {
      if (cleaned) return;
      cleaned = true;
      await rm(root, { recursive: true, force: true });
    },
  };
}

export async function withTestFilesystem<T>(run: (filesystem: TestFilesystem) => Promise<T>): Promise<T> {
  const filesystem = await createTestFilesystem();
  try {
    return await run(filesystem);
  } finally {
    await filesystem.cleanup();
  }
}
