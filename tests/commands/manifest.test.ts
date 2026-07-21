import { readFileSync } from "node:fs";
import { resolve } from "node:path";

import { describe, expect, it } from "vitest";

describe("Book Sender manifest", () => {
  it("exposes exactly one Kindle delivery command", () => {
    const manifest = JSON.parse(readFileSync(resolve(__dirname, "../../package.json"), "utf8")) as {
      title: string;
      commands: Array<{ name: string; title: string }>;
    };

    expect(manifest.title).toBe("Book Sender");
    expect(manifest.commands.map(({ name, title }) => ({ name, title }))).toEqual([
      { name: "send-book-to-kindle", title: "Send Book to Kindle" },
    ]);
  });
});
