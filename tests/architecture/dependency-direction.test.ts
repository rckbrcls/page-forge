import { readFile, readdir } from "node:fs/promises";
import { builtinModules } from "node:module";
import { extname, relative, resolve } from "node:path";

import { describe, expect, it } from "vitest";

const repositoryRoot = resolve(import.meta.dirname, "../..");
const domainRoot = resolve(repositoryRoot, "src/domain");
const sourceExtensions = new Set([".ts", ".tsx"]);
const nodeBuiltins = new Set(builtinModules.map((name) => name.replace(/^node:/, "")));
const forbiddenPackages = new Set([
  "@raycast/api",
  "@raycast/utils",
  "react",
  "react-dom",
  "yauzl",
  "yazl",
  "saxes",
  "nodemailer",
]);
const importPattern = /(?:import|export)\s+(?:type\s+)?(?:[^"']*?\s+from\s+)?["']([^"']+)["']|require\(\s*["']([^"']+)["']\s*\)|import\(\s*["']([^"']+)["']\s*\)/g;

async function sourceFiles(directory: string): Promise<string[]> {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = await Promise.all(
    entries.map(async (entry) => {
      const path = resolve(directory, entry.name);
      if (entry.isDirectory()) return sourceFiles(path);
      return sourceExtensions.has(extname(entry.name)) ? [path] : [];
    }),
  );
  return files.flat().sort();
}

function importedSpecifiers(source: string): string[] {
  return [...source.matchAll(importPattern)].map((match) => match[1] ?? match[2] ?? match[3]);
}

function forbiddenReason(specifier: string): string | undefined {
  const bareSpecifier = specifier.replace(/^node:/, "").split("/")[0];
  const importsForbiddenPackage = [...forbiddenPackages].some(
    (packageName) => specifier === packageName || specifier.startsWith(`${packageName}/`),
  );
  if (nodeBuiltins.has(bareSpecifier) || importsForbiddenPackage) {
    return "runtime/framework package";
  }
  if (/^(?:\.\.\/)+(?:application|adapters|commands)(?:\/|$)/.test(specifier)) {
    return "higher or adapter layer";
  }
  if (/\/(?:application|adapters|commands)\//.test(specifier)) {
    return "higher or adapter layer";
  }
  return undefined;
}

describe("domain dependency direction", () => {
  it("keeps domain modules independent of UI, adapters, I/O, and vendor libraries", async () => {
    const violations: string[] = [];
    for (const file of await sourceFiles(domainRoot)) {
      const source = await readFile(file, "utf8");
      for (const specifier of importedSpecifiers(source)) {
        const reason = forbiddenReason(specifier);
        if (reason) {
          violations.push(`${relative(repositoryRoot, file)} imports ${specifier} (${reason})`);
        }
      }
    }
    expect(violations).toEqual([]);
  });
});
