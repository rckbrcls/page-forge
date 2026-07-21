import { createHash } from "node:crypto";
import { createReadStream } from "node:fs";
import { lstat, open, unlink } from "node:fs/promises";
import { dirname, join } from "node:path";
import type { FileHandle } from "node:fs/promises";

import type { BoundedReadable } from "../../application/ports";
import type { ProcessingFailure } from "../../domain/models/processing-failure";
import type {
  SelectedEpub,
  SourceFingerprint,
  SourceSnapshot,
  VerifiedReadDescriptor,
  Sha256Digest,
} from "../../domain/models/epub-document";
import { err, ok, type Result } from "../../domain/models/result";
import { resolveVerifiedFileHandle } from "./local-epub-files";

interface DeliverySnapshotIdentity {
  readonly path: string;
  readonly device: bigint;
  readonly file: bigint;
}

export interface DeliverySnapshot {
  readonly id: string;
  readonly path: string;
  readonly sourcePath: string;
  readonly reviewedFingerprint: SourceFingerprint;
  readonly snapshotFingerprint: SourceFingerprint;
}

const ownedDeliverySnapshots = new WeakMap<DeliverySnapshot, DeliverySnapshotIdentity>();

function internalFailure(message: string): ProcessingFailure {
  return {
    category: "internal",
    code: "INTERNAL_FAILURE",
    safeMessage: message,
    retryable: true,
    phase: "connecting",
  };
}

function inputFailure(message: string): ProcessingFailure {
  return {
    category: "input",
    code: "INPUT_CHANGED",
    safeMessage: message,
    retryable: true,
    phase: "connecting",
  };
}

function transportFailure(message: string): ProcessingFailure {
  return {
    category: "delivery_transport",
    code: "DELIVERY_STREAM_FAILED",
    safeMessage: message,
    retryable: true,
    phase: "transmitting",
  };
}

function sameSnapshot(left: SourceSnapshot, right: SourceSnapshot): boolean {
  return (
    left.identity.device === right.identity.device &&
    left.identity.file === right.identity.file &&
    left.sizeBytes === right.sizeBytes &&
    left.modifiedAtMs === right.modifiedAtMs
  );
}

function toSnapshot(stats: {
  dev: string | number | bigint;
  ino: string | number | bigint;
  size: number;
  mtimeMs: number;
}): SourceSnapshot {
  return {
    identity: {
      device: String(stats.dev),
      file: String(stats.ino),
    },
    sizeBytes: stats.size,
    modifiedAtMs: stats.mtimeMs,
  };
}

function toDigestFailure(message: string): ProcessingFailure {
  return {
    category: "delivery_transport",
    code: "DELIVERY_STREAM_FAILED",
    safeMessage: message,
    retryable: false,
    phase: "transmitting",
  };
}

async function calculateFileDigest(path: string): Promise<string> {
  const hash = createHash("sha256");
  for await (const chunk of createReadStream(path)) {
    hash.update(chunk);
  }
  return hash.digest("hex");
}

async function copyAndHashFromHandle(handle: FileHandle, path: string): Promise<string> {
  const output = await open(path, "wx", 0o600);
  const hash = createHash("sha256");
  const buffer = Buffer.allocUnsafe(64 * 1024);
  let position = 0;

  try {
    while (true) {
      const { bytesRead } = await handle.read(buffer, 0, buffer.byteLength, position);
      if (bytesRead === 0) break;
      const chunk = buffer.subarray(0, bytesRead);
      hash.update(chunk);
      await output.write(chunk);
      position += bytesRead;
    }
    await output.sync();
    return hash.digest("hex");
  } finally {
    await output.close();
  }
}

export async function createDeliverySnapshot(
  source: SelectedEpub,
  descriptor: VerifiedReadDescriptor,
  reviewedFingerprint: SourceFingerprint,
): Promise<Result<DeliverySnapshot, ProcessingFailure>> {
  if (descriptor.sourceId !== source.id) {
    return err(inputFailure("The selected EPUB does not match the verified descriptor."));
  }

  if (!sameSnapshot(source, descriptor.snapshot)) {
    return err(inputFailure("The selected EPUB no longer matches its descriptor."));
  }

  const handle = resolveVerifiedFileHandle(descriptor);
  if (!handle) {
    return err(inputFailure("The verified file descriptor is no longer available."));
  }

  const id = `${Date.now()}-${Math.random()}`;
  const path = join(dirname(source.sourcePath), `.book-sender-delivery-${id}.tmp`);

  try {
    const digest = await copyAndHashFromHandle(handle, path);

    const currentSource = await handle.stat();
    if (!sameSnapshot(source, toSnapshot(currentSource))) {
      await cleanupDirect(path);
      return err(inputFailure("The selected EPUB changed while creating the delivery snapshot."));
    }

    const snapshotStats = await lstat(path, { bigint: true });
    const snapshotFingerprint: SourceFingerprint = {
      identity: {
        device: String(snapshotStats.dev),
        file: String(snapshotStats.ino),
      },
      sizeBytes: Number(snapshotStats.size),
      modifiedAtMs: Number(snapshotStats.mtimeMs),
      sha256: digest as Sha256Digest,
    };

    if (snapshotFingerprint.sha256 !== reviewedFingerprint.sha256) {
      await cleanupDirect(path);
      return err(toDigestFailure("The reviewed digest does not match the copied snapshot digest."));
    }

    const snapshot: DeliverySnapshot = {
      id,
      path,
      sourcePath: source.sourcePath,
      reviewedFingerprint,
      snapshotFingerprint,
    };
    ownedDeliverySnapshots.set(snapshot, {
      path,
      device: snapshotStats.dev,
      file: snapshotStats.ino,
    });

    return ok(snapshot);
  } catch {
    await cleanupDirect(path);
    return err(transportFailure("The delivery snapshot could not be created."));
  }
}

export async function openDeliverySnapshot(
  snapshot: DeliverySnapshot,
): Promise<Result<BoundedReadable, ProcessingFailure>> {
  const owned = ownedDeliverySnapshots.get(snapshot);
  if (!owned || owned.path !== snapshot.path) {
    return err(internalFailure("The delivery snapshot is not owned by the adapter."));
  }

  try {
    const stream = createReadStream(snapshot.path);
    const iterator = stream[Symbol.asyncIterator]();
    const bounded: BoundedReadable = {
      [Symbol.asyncIterator]: () => iterator,
      close: async () => {
        if (stream.destroyed || stream.readableEnded || stream.closed) {
          return ok(undefined);
        }
        await new Promise<void>((resolve) => {
          stream.once("close", resolve);
          stream.destroy();
        });
        return ok(undefined);
      },
    };
    return ok(bounded);
  } catch {
    return err(transportFailure("The delivery snapshot stream could not be opened."));
  }
}

export async function reopenDeliverySnapshot(
  snapshot: DeliverySnapshot,
): Promise<Result<BoundedReadable, ProcessingFailure>> {
  return openDeliverySnapshot(snapshot);
}

export function bindDeliverySnapshotDigest(snapshot: DeliverySnapshot): SourceFingerprint {
  return snapshot.snapshotFingerprint;
}

export const bindDeliverySnapshotFingerprint = bindDeliverySnapshotDigest;

export async function verifyDeliverySnapshot(snapshot: DeliverySnapshot): Promise<Result<boolean, ProcessingFailure>> {
  try {
    const digest = (await calculateFileDigest(snapshot.path)) as Sha256Digest;
    return ok(digest === snapshot.snapshotFingerprint.sha256);
  } catch {
    return err(toDigestFailure("The delivery snapshot stream could not be verified."));
  }
}

export async function cleanupDeliverySnapshot(snapshot: DeliverySnapshot): Promise<Result<void, ProcessingFailure>> {
  const owned = ownedDeliverySnapshots.get(snapshot);
  if (!owned) {
    return ok(undefined);
  }

  try {
    const current = await lstat(snapshot.path, { bigint: true });
    if (owned.path !== snapshot.path || current.dev !== owned.device || current.ino !== owned.file) {
      return err(internalFailure("The delivery snapshot ownership could not be verified."));
    }
    await unlink(snapshot.path);
    ownedDeliverySnapshots.delete(snapshot);
    return ok(undefined);
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") {
      ownedDeliverySnapshots.delete(snapshot);
      return ok(undefined);
    }
    return err(internalFailure("The delivery snapshot could not be removed safely."));
  }
}

export const deliverySnapshot = {
  createDeliverySnapshot,
  openDeliverySnapshot,
  reopenDeliverySnapshot,
  bindDeliverySnapshotDigest,
  bindDeliverySnapshotFingerprint,
  verifyDeliverySnapshot,
  cleanupDeliverySnapshot,
} as const;

async function cleanupDirect(path: string): Promise<void> {
  try {
    await unlink(path);
  } catch {
    // best-effort cleanup
  }
}
