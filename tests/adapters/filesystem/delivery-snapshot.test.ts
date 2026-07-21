import * as fsPromises from "node:fs/promises";

import { describe, expect, it } from "vitest";

import {
  closeVerifiedSource,
  openVerifiedSource,
  fingerprint,
  snapshotSource,
} from "../../../src/adapters/filesystem/local-epub-files";
import {
  bindDeliverySnapshotDigest,
  cleanupDeliverySnapshot,
  createDeliverySnapshot,
  openDeliverySnapshot,
  reopenDeliverySnapshot,
  type DeliverySnapshot,
  verifyDeliverySnapshot,
} from "../../../src/adapters/filesystem/delivery-snapshot";
import type { BoundedReadable } from "../../../src/application/ports";
import type { SelectedEpub, SourceFingerprint, VerifiedReadDescriptor } from "../../../src/domain/models/epub-document";
import type { Result } from "../../../src/domain/models/result";
import { withTestFilesystem } from "../../support/test-filesystem";
import type { TestFilesystem } from "../../support/test-filesystem";

async function prepareReviewedSource(
  content: string,
  filesystem: TestFilesystem,
): Promise<{
  readonly source: SelectedEpub;
  readonly descriptor: VerifiedReadDescriptor;
  readonly reviewedFingerprint: SourceFingerprint;
  readonly close: () => Promise<void>;
}> {
  const sourcePath = await filesystem.write("books/source.epub", content);
  const snapshot = await snapshotSource(sourcePath);
  if (!snapshot.ok) {
    throw new Error(snapshot.failure.safeMessage);
  }

  const descriptorResult = await openVerifiedSource(snapshot.value);
  if (!descriptorResult.ok) {
    throw new Error(descriptorResult.failure.safeMessage);
  }

  const controller = new AbortController();
  const fingerprintResult = await fingerprint(descriptorResult.value, controller.signal);
  if (!fingerprintResult.ok) {
    throw new Error(fingerprintResult.failure.safeMessage);
  }

  return {
    source: snapshot.value,
    descriptor: descriptorResult.value,
    reviewedFingerprint: fingerprintResult.value,
    close: async () => {
      const closeResult = await closeVerifiedSource(descriptorResult.value);
      if (!closeResult.ok) {
        throw new Error(closeResult.failure.safeMessage);
      }
    },
  };
}

function assertResultOk<T, F>(result: Result<T, F>): T {
  if (!result.ok) {
    throw new Error(`Expected an ok result, got ${result.failure}.`);
  }
  return result.value;
}

async function readBoundedStream(readable: BoundedReadable): Promise<Buffer> {
  const chunks: Buffer[] = [];
  for await (const chunk of readable) {
    chunks.push(Buffer.from(chunk));
  }
  const closeResult = await readable.close();
  expect(closeResult).toMatchObject({ ok: true });
  return Buffer.concat(chunks);
}

describe("delivery snapshots", () => {
  it("creates a private mode-0600 snapshot with matching reviewed digest", async () => {
    const content = "ready-for-delivery";

    await withTestFilesystem(async (filesystem) => {
      const fixture = await prepareReviewedSource(content, filesystem);
      try {
        const snapshotResult = await createDeliverySnapshot(
          fixture.source,
          fixture.descriptor,
          fixture.reviewedFingerprint,
        );
        const snapshot = assertResultOk(snapshotResult);

        expect(snapshot).toMatchObject({
          sourcePath: fixture.source.sourcePath,
          reviewedFingerprint: fixture.reviewedFingerprint,
        });

        expect(snapshot.path).not.toBe(fixture.source.sourcePath);
        expect(snapshot.path).toContain(".book-sender-delivery-");
        const snapshotStats = await fsPromises.lstat(snapshot.path);
        if (process.platform !== "win32") {
          expect(snapshotStats.mode & 0o777).toBe(0o600);
        }
        expect(snapshotStats.isFile()).toBe(true);

        const firstOpen = await openDeliverySnapshot(snapshot);
        const firstReader = assertResultOk(firstOpen);
        const loaded = await readBoundedStream(firstReader);
        expect(loaded.toString("utf8")).toBe(content);

        const reopened = await reopenDeliverySnapshot(snapshot);
        const reopenedValue = assertResultOk(reopened);
        const reopenData = await readBoundedStream(reopenedValue);
        expect(reopenData.toString("utf8")).toBe(content);

        const verification = await verifyDeliverySnapshot(snapshot);
        const verified = assertResultOk(verification);
        expect(verified).toBe(true);

        const boundFingerprint = bindDeliverySnapshotDigest(snapshot);
        expect(boundFingerprint.sha256).toBe(fixture.reviewedFingerprint.sha256);

        const cleanup = await cleanupDeliverySnapshot(snapshot);
        expect(cleanup).toMatchObject({ ok: true });
        await expect(fsPromises.lstat(snapshot.path)).rejects.toMatchObject({ code: "ENOENT" });
      } finally {
        await fixture.close();
      }
    });
  });

  it("blocks digest mismatches and removes temporary snapshot data", async () => {
    const content = "digest-mismatch-blocked";

    await withTestFilesystem(async (filesystem) => {
      const fixture = await prepareReviewedSource(content, filesystem);
      try {
        const wrongFingerprint: SourceFingerprint = {
          ...fixture.reviewedFingerprint,
          sha256: "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff" as SourceFingerprint["sha256"],
        };

        const snapshotResult = await createDeliverySnapshot(fixture.source, fixture.descriptor, wrongFingerprint);
        expect(snapshotResult).toMatchObject({ ok: false, failure: { category: "delivery_transport" } });

        const entries = await fsPromises.readdir(filesystem.root);
        const leftovers = entries.filter((entry) => entry.startsWith(".page-forge-delivery-"));
        expect(leftovers).toHaveLength(0);
      } finally {
        await fixture.close();
      }
    });
  });

  it("does not remove files for unknown snapshot ownership", async () => {
    const content = "unowned-cleanup";

    await withTestFilesystem(async (filesystem) => {
      const sourcePath = await filesystem.write("books/book.epub", content);
      const sourceSnapshot = await snapshotSource(sourcePath);
      if (!sourceSnapshot.ok) {
        throw new Error(sourceSnapshot.failure.safeMessage);
      }

      await fsPromises.writeFile(filesystem.path(".page-forge-delivery-unowned.tmp"), "retain");
      const unownedPath = filesystem.path(".page-forge-delivery-unowned.tmp");
      const unowned: DeliverySnapshot = {
        id: "unowned-id",
        path: unownedPath,
        sourcePath,
        reviewedFingerprint: {
          ...sourceSnapshot.value,
          sha256: "beef" as SourceFingerprint["sha256"],
        },
        snapshotFingerprint: {
          ...sourceSnapshot.value,
          sha256: "beef" as SourceFingerprint["sha256"],
        },
      };

      const cleanup = await cleanupDeliverySnapshot(unowned);
      expect(cleanup).toMatchObject({ ok: true });

      await expect(fsPromises.lstat(unownedPath)).resolves.toBeDefined();
      expect((await fsPromises.readFile(unownedPath)).toString("utf8")).toBe("retain");

      const reopenUnknown = await openDeliverySnapshot(unowned);
      expect(reopenUnknown).toMatchObject({ ok: false, failure: { category: "internal" } });
    });
  });

  it("supports reopen after explicit close", async () => {
    const content = "close-and-reopen";

    await withTestFilesystem(async (filesystem) => {
      const fixture = await prepareReviewedSource(content, filesystem);
      try {
        const snapshot = assertResultOk(
          await createDeliverySnapshot(fixture.source, fixture.descriptor, fixture.reviewedFingerprint),
        );

        const openOnce = await openDeliverySnapshot(snapshot);
        const opened = assertResultOk(openOnce);
        const firstPayload = await readBoundedStream(opened);
        expect(firstPayload.toString()).toBe(content);

        const openAgain = await reopenDeliverySnapshot(snapshot);
        const reopened = assertResultOk(openAgain);
        const secondPayload = await readBoundedStream(reopened);
        expect(secondPayload.toString()).toBe(content);

        const finalCleanup = await cleanupDeliverySnapshot(snapshot);
        expect(finalCleanup).toMatchObject({ ok: true });
      } finally {
        await fixture.close();
      }
    });
  });
});
