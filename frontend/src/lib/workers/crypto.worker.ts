import * as Comlink from "comlink";
import { encryptFile, decryptFile, encryptJSON, decryptJSON } from "../crypto/aes-gcm";
import type { Hex } from "viem";
import type { FileMetadata } from "@interfaces/vault";

/**
 * Worker API exposed to the main thread via Comlink.
 * All functions use Comlink.transfer to guarantee Zero-Copy memory management.
 */
const cryptoWorkerApi = {
  
  async encryptFileWorker(fileData: ArrayBuffer, contentHash: Hex, key: CryptoKey) {
    const encryptedBuffer = await encryptFile(fileData, contentHash, key);
    // TRANSFER: Moves ownership of the bytes to the main thread. No memory duplication.
    return Comlink.transfer(encryptedBuffer, [encryptedBuffer]);
  },

  async decryptFileWorker(encryptedBuffer: ArrayBuffer, contentHash: Hex, key: CryptoKey) {
    const decryptedBuffer = await decryptFile(encryptedBuffer, contentHash, key);
    return Comlink.transfer(decryptedBuffer, [decryptedBuffer]);
  },

  async encryptMetadataWorker(metadata: FileMetadata, key: CryptoKey) {
    const encryptedBuffer = await encryptJSON(metadata, key);
    return Comlink.transfer(encryptedBuffer, [encryptedBuffer]);
  },

  async decryptMetadataWorker(encryptedBuffer: ArrayBuffer, key: CryptoKey) {
    // We don't transfer the result here because it's a parsed JSON object, not an ArrayBuffer
    return await decryptJSON<FileMetadata>(encryptedBuffer, key);
  }
};

Comlink.expose(cryptoWorkerApi);

// Export the type so the main thread (React hooks) knows exactly what methods exist
export type CryptoWorkerAPI = typeof cryptoWorkerApi;
