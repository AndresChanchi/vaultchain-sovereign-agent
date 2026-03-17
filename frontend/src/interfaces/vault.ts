import type { Address, Hex } from "viem";
import type { WebIrys } from "@irys/sdk";

/**
 * Represents the lifecycle stages of a photo within the client.
 */
export type PhotoStatus = 
  | 'idle' 
  | 'compressing' 
  | 'encrypting' 
  | 'uploading' 
  | 'registering' 
  | 'success' 
  | 'error';

/**
 * Strict structure for local file management and UI state.
 */
export interface LocalPhoto {
  readonly id: string;             // UUID v4
  readonly file: File;             // Original File/Blob
  readonly previewUrl: string;     // URL.createObjectURL() reference
  readonly status: PhotoStatus;
  readonly progress: number;       // Percentage (0 to 100)
  readonly errorMessage?: string;
}

/**
 * Technical metadata to be encrypted alongside the file.
 * The contentHash acts as the unique link to the Arbitrum Stylus contract.
 */
export interface FileMetadata {
  readonly name: string;
  readonly type: string;
  readonly size: number;
  readonly lastModified: number;
  readonly contentHash: Hex;       // B256 in Stylus matches 0x${string}
}

/**
 * Parameters for Stylus register_batch or register_upload functions.
 */
export interface StylusRegistryParams {
  readonly contentHash: Hex; 
  readonly encryptedTxId: string; // Irys Transaction ID (Irys Hash)
}

/**
 * Irys session state with SDK-specific typing.
 */
export interface IrysSession {
  readonly instance: WebIrys | null;
  readonly balance: string;        // Human-readable formatted string
  readonly address: Address | null;
  readonly isLoading: boolean;
}

/**
 * Standardized error interface for strict catch-block handling.
 */
export interface KipioError {
  readonly code: string;
  readonly message: string;
  readonly step: PhotoStatus;
}

/**
 * Response structure for paginated gallery queries
 */
export interface GalleryResponse {
  hashes: Hex[];
  total: number;
  offset: number;
  limit: number;
}
