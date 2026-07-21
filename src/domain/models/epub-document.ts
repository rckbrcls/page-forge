import type { ArchiveEntryDescriptor, InternalPath } from "./archive";
import type { Finding } from "./finding";

declare const selectedEpubIdBrand: unique symbol;
declare const descriptorIdBrand: unique symbol;
declare const digestBrand: unique symbol;

export type SelectedEpubId = string & { readonly [selectedEpubIdBrand]: "SelectedEpubId" };
export type VerifiedDescriptorId = string & {
  readonly [descriptorIdBrand]: "VerifiedDescriptorId";
};
export type Sha256Digest = string & { readonly [digestBrand]: "Sha256Digest" };

export interface FilesystemIdentity {
  readonly device: string;
  readonly file: string;
}

export interface SourceSnapshot {
  readonly identity: FilesystemIdentity;
  readonly sizeBytes: number;
  readonly modifiedAtMs: number;
}

export interface SourceFingerprint extends SourceSnapshot {
  readonly sha256: Sha256Digest;
}

export interface SelectedEpub extends SourceSnapshot {
  readonly id: SelectedEpubId;
  readonly sourcePath: string;
  readonly displayName: string;
  readonly readable: boolean;
}

export interface VerifiedReadDescriptor {
  readonly id: VerifiedDescriptorId;
  readonly sourceId: SelectedEpubId;
  readonly snapshot: SourceSnapshot;
}

export interface SelectionRejection {
  readonly selectionIndex: number;
  readonly displayName: string;
  readonly finding: Finding;
}

export interface SelectionSnapshot {
  readonly items: readonly SelectedEpub[];
  readonly rejections: readonly SelectionRejection[];
  readonly selectedAtMs: number;
}

export interface MimetypeProjection {
  readonly entryIndex: number;
  readonly compressionMethod: number;
  readonly localHeaderExtraLength: number;
  readonly value: string;
}

export interface ContainerRootfileProjection {
  readonly fullPath: string;
  readonly mediaType?: string;
  readonly resolvedPath?: InternalPath;
}

export interface ContainerProjection {
  readonly path: InternalPath;
  readonly rootfiles: readonly ContainerRootfileProjection[];
}

export interface MetadataProjection {
  readonly titles: readonly string[];
  readonly identifiers: readonly { readonly id?: string; readonly value: string }[];
  readonly languages: readonly string[];
  readonly uniqueIdentifier?: string;
  readonly renditionLayout?: string;
}

export interface ManifestItemProjection {
  readonly id: string;
  readonly href: string;
  readonly resolvedPath?: InternalPath;
  readonly mediaType?: string;
  readonly properties: readonly string[];
}

export interface SpineItemProjection {
  readonly idref?: string;
  readonly linear?: boolean;
}

export interface PackageProjection {
  readonly path: InternalPath;
  readonly version: "2" | "3" | "unknown";
  readonly metadata: MetadataProjection;
  readonly manifest: readonly ManifestItemProjection[];
  readonly spine: readonly SpineItemProjection[];
  readonly spineToc?: string;
}

export interface ContentReferenceProjection {
  readonly rawReference: string;
  readonly targetPath?: InternalPath;
  readonly fragment?: string;
  readonly kind: "link" | "image" | "stylesheet" | "font" | "other";
}

export interface ContentProjection {
  readonly path: InternalPath;
  readonly mediaType: string;
  readonly references: readonly ContentReferenceProjection[];
  readonly scripted: boolean;
  readonly interactive: boolean;
  readonly hasUsefulContent: boolean;
}

export interface EncryptionProjection {
  readonly path: InternalPath;
  readonly affectedPaths: readonly InternalPath[];
}

export interface LoadedEpub {
  readonly source: SelectedEpub;
  readonly entries: readonly ArchiveEntryDescriptor[];
  readonly entryIndex: ReadonlyMap<InternalPath, ArchiveEntryDescriptor>;
  readonly mimetype?: MimetypeProjection;
  readonly container?: ContainerProjection;
  readonly packages: readonly PackageProjection[];
  readonly contentDocuments: readonly ContentProjection[];
  readonly encryption?: EncryptionProjection;
}

export interface ParseOutcome<TProjection> {
  readonly projection?: TProjection;
  readonly findings: readonly Finding[];
}
