import { createHash } from "node:crypto";
import { createReadStream } from "node:fs";

export interface FileHash {
  algorithm: "sha256";
  digest: string;
  sizeBytes: number;
}

export function hashBytes(value: string | Uint8Array): FileHash {
  const bytes = typeof value === "string" ? Buffer.from(value) : Buffer.from(value);
  return {
    algorithm: "sha256",
    digest: createHash("sha256").update(bytes).digest("hex"),
    sizeBytes: bytes.length,
  };
}

export async function hashFile(path: string): Promise<FileHash> {
  const hash = createHash("sha256");
  let sizeBytes = 0;
  for await (const chunk of createReadStream(path)) {
    const bytes = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
    sizeBytes += bytes.length;
    hash.update(bytes);
  }
  return { algorithm: "sha256", digest: hash.digest("hex"), sizeBytes };
}

export async function hashSourceAndOutput(
  sourcePath: string,
  outputPath: string,
): Promise<{ source: FileHash; output: FileHash; identical: boolean }> {
  const [source, output] = await Promise.all([hashFile(sourcePath), hashFile(outputPath)]);
  return {
    source,
    output,
    identical: source.sizeBytes === output.sizeBytes && source.digest === output.digest,
  };
}
