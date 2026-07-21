import { getSelectedFinderItems } from "@raycast/api";

import type { ProcessingFailure } from "../../domain/models/processing-failure";
import { ok, type Result } from "../../domain/models/result";

/** Finder not being the active application is an expected reason to use the picker. */
export async function selectedFinderPaths(): Promise<Result<readonly string[], ProcessingFailure>> {
  try {
    const items = await getSelectedFinderItems();
    return ok(items.map(({ path }) => path));
  } catch {
    return ok([]);
  }
}

export const selectedFinderItems = { selectedFinderPaths } as const;
