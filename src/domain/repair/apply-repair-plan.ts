import type { InternalPath } from "../models/archive";
import type { ProcessingFailure } from "../models/processing-failure";
import type {
  AppliedRepair,
  RepairOperation,
  RepairOperationId,
  RepairPlan,
} from "../models/repair";
import {
  correctManifestMediaType,
  correctUniqueReference,
  normalizeEquivalentInternalPath,
  normalizeXmlEncoding,
  rebuildContainerForSingleOpf,
  writeCanonicalMimetype,
} from "./xml-transformations";

export interface RepairOperationInput {
  readonly path?: InternalPath;
  readonly content?: Uint8Array;
  readonly preservedEntryCount?: number;
}

export interface RepairOperationApplication {
  readonly path?: InternalPath;
  readonly content?: Uint8Array;
  readonly repair: AppliedRepair;
}

export function applyRepairPlan(
  plan: RepairPlan,
  operationId: RepairOperationId,
  input: RepairOperationInput = {},
): RepairOperationApplication {
  const operation = plan.operations.find(({ id }) => id === operationId);
  if (operation === undefined) {
    return failedApplication(operationId, [], input.preservedEntryCount, "The operation is not present in the confirmed repair plan.");
  }

  try {
    return dispatch(operation, input);
  } catch {
    return failedApplication(
      operation.id,
      operation.findingIds,
      input.preservedEntryCount,
      "The planned repair could not be applied to the reviewed archive entry.",
    );
  }
}

export const applyRepairOperation = applyRepairPlan;

function dispatch(
  operation: RepairOperation,
  input: RepairOperationInput,
): RepairOperationApplication {
  const preservedEntryCount = validCount(input.preservedEntryCount);
  switch (operation.kind) {
    case "write_canonical_mimetype":
      requireOptionalEntryPath(input, "mimetype" as InternalPath);
      return bytesApplication(operation, "mimetype" as InternalPath, input.content, writeCanonicalMimetype(), preservedEntryCount);
    case "rebuild_container_for_single_opf":
      requireOptionalEntryPath(input, "META-INF/container.xml" as InternalPath);
      return bytesApplication(
        operation,
        "META-INF/container.xml" as InternalPath,
        input.content,
        rebuildContainerForSingleOpf(operation.packagePath),
        preservedEntryCount,
      );
    case "correct_manifest_media_type": {
      requireEntry(input, operation.packagePath);
      return bytesApplication(
        operation,
        operation.packagePath,
        input.content,
        correctManifestMediaType(input.content!, operation.manifestId, operation.mediaType),
        preservedEntryCount,
      );
    }
    case "correct_unique_reference": {
      requireEntry(input, operation.ownerPath);
      return bytesApplication(
        operation,
        operation.ownerPath,
        input.content,
        correctUniqueReference(
          input.content!,
          operation.originalReference,
          operation.replacementReference,
        ),
        preservedEntryCount,
      );
    }
    case "normalize_equivalent_internal_path": {
      requireEntry(input, operation.sourcePath);
      const normalized = normalizeEquivalentInternalPath(
        operation.sourcePath,
        operation.targetPath,
        input.content!,
      );
      return {
        ...normalized,
        repair: appliedEvidence(operation, operation.changedPaths, preservedEntryCount),
      };
    }
    case "normalize_xml_encoding": {
      requireEntry(input, operation.path);
      return bytesApplication(
        operation,
        operation.path,
        input.content,
        normalizeXmlEncoding(input.content!),
        preservedEntryCount,
      );
    }
    case "rebuild_epub_archive":
      return {
        repair: appliedEvidence(operation, operation.changedPaths, preservedEntryCount),
      };
  }
}

function bytesApplication(
  operation: RepairOperation,
  path: InternalPath,
  before: Uint8Array | undefined,
  after: Uint8Array,
  preservedEntryCount: number,
): RepairOperationApplication {
  const unchanged = before !== undefined && bytesEqual(before, after);
  return {
    path,
    content: unchanged ? before : after,
    repair: unchanged
      ? alreadySatisfiedEvidence(operation, preservedEntryCount)
      : appliedEvidence(operation, operation.changedPaths, preservedEntryCount),
  };
}

function requireEntry(
  input: RepairOperationInput,
  expectedPath: InternalPath,
): asserts input is RepairOperationInput & { readonly path: InternalPath; readonly content: Uint8Array } {
  if (input.path !== expectedPath || input.content === undefined) {
    throw new Error("The supplied entry does not match the planned target.");
  }
}

function requireOptionalEntryPath(input: RepairOperationInput, expectedPath: InternalPath): void {
  if (input.content !== undefined && input.path !== expectedPath) {
    throw new Error("The supplied entry does not match the planned target.");
  }
  if (input.content === undefined && input.path !== undefined) {
    throw new Error("An entry path was supplied without its content.");
  }
}

function appliedEvidence(
  operation: RepairOperation,
  changedEntries: readonly InternalPath[],
  preservedEntryCount: number,
): AppliedRepair {
  return {
    operationId: operation.id,
    outcome: "applied",
    resolvedFindingIds: operation.findingIds,
    changedEntries,
    preservedEntryCount,
  };
}

function alreadySatisfiedEvidence(
  operation: RepairOperation,
  preservedEntryCount: number,
): AppliedRepair {
  return {
    operationId: operation.id,
    outcome: "already_satisfied",
    resolvedFindingIds: operation.findingIds,
    changedEntries: [],
    preservedEntryCount,
  };
}

function failedApplication(
  operationId: RepairOperationId,
  findingIds: RepairOperation["findingIds"],
  preservedEntryCount: number | undefined,
  safeMessage: string,
): RepairOperationApplication {
  const failure: ProcessingFailure = {
    category: "repair",
    code: "REPAIR_WRITE_FAILED",
    safeMessage,
    retryable: false,
    phase: "reconstructing",
  };
  return {
    repair: {
      operationId,
      outcome: "failed",
      resolvedFindingIds: findingIds,
      changedEntries: [],
      preservedEntryCount: validCount(preservedEntryCount),
      failure,
    },
  };
}

function validCount(value: number | undefined): number {
  return Number.isSafeInteger(value) && value! >= 0 ? value! : 0;
}

function bytesEqual(left: Uint8Array, right: Uint8Array): boolean {
  if (left.byteLength !== right.byteLength) return false;
  return left.every((value, index) => value === right[index]);
}
