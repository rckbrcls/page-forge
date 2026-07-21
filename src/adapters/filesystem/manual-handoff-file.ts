import { randomUUID } from "node:crypto";
import { copyFile, mkdir } from "node:fs/promises";
import { basename, join } from "node:path";
import { tmpdir } from "node:os";

import type { ProcessingFailure } from "../../domain/models/processing-failure";
import { err, ok, type Result } from "../../domain/models/result";

export async function createManualHandoffFile(
  sourcePath: string,
  originalDisplayName: string,
): Promise<Result<string, ProcessingFailure>> {
  const directory = join(tmpdir(), `book-sender-${randomUUID()}`);
  const outputPath = join(directory, basename(originalDisplayName));
  try {
    await mkdir(directory, { mode: 0o700 });
    await copyFile(sourcePath, outputPath);
    return ok(outputPath);
  } catch {
    return err({
      category: "internal",
      code: "INTERNAL_FAILURE",
      safeMessage: "The repaired book could not be prepared for manual upload.",
      retryable: true,
      phase: "completed",
    });
  }
}
