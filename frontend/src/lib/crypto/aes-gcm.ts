import { type FileMetadata } from "@interfaces/vault";
import { type Hex } from "viem";

/**
 * NIST recommendation: 96-bit (12 bytes) IV for AES-GCM provides 
 * the best performance and security balance.
 */
const AES_CONFIG = {
  name: "AES-GCM",
  ivLength: 12, 
  tagLength: 128, // bits (Authentication tag)
} as const;

/**
 * Encrypts a binary buffer using AES-GCM 256.
 * Binds the ciphertext to the contentHash using AAD (Additional Authenticated Data).
 * Layout: [IV (12 bytes)][Ciphertext + Auth Tag]
 */
export async function encryptFile(
  fileData: ArrayBuffer,
  contentHash: Hex,
  key: CryptoKey
): Promise<ArrayBuffer> {
  const iv = crypto.getRandomValues(new Uint8Array(AES_CONFIG.ivLength));
  const aad = new TextEncoder().encode(contentHash);

  const encryptedContent = await crypto.subtle.encrypt(
    {
      name: AES_CONFIG.name,
      iv,
      additionalData: aad,
      tagLength: AES_CONFIG.tagLength,
    },
    key,
    fileData
  );

  const result = new Uint8Array(iv.byteLength + encryptedContent.byteLength);
  result.set(iv, 0);
  result.set(new Uint8Array(encryptedContent), iv.byteLength);

  return result.buffer;
}

/**
 * Decrypts a buffer from Irys and verifies integrity via AAD.
 * Throws an error if the data was tampered with or the key is incorrect.
 */
export async function decryptFile(
  encryptedBuffer: ArrayBuffer,
  contentHash: Hex,
  key: CryptoKey
): Promise<ArrayBuffer> {
  const view = new Uint8Array(encryptedBuffer);
  const iv = view.subarray(0, AES_CONFIG.ivLength);
  const ciphertext = view.subarray(AES_CONFIG.ivLength);
  const aad = new TextEncoder().encode(contentHash);

  try {
    return await crypto.subtle.decrypt(
      {
        name: AES_CONFIG.name,
        iv,
        additionalData: aad,
        tagLength: AES_CONFIG.tagLength,
      },
      key,
      ciphertext
    );
  } catch (err) {
    throw new Error("DECRYPTION_FAILED: Integrity violation or invalid key.");
  }
}

/**
 * Protects file attributes (name, size, etc) before uploading to Irys.
 */
export async function encryptJSON(
  metadata: FileMetadata,
  key: CryptoKey
): Promise<ArrayBuffer> {
  const data = new TextEncoder().encode(JSON.stringify(metadata));
  const iv = crypto.getRandomValues(new Uint8Array(AES_CONFIG.ivLength));

  const encrypted = await crypto.subtle.encrypt(
    { name: AES_CONFIG.name, iv },
    key,
    data
  );

  const result = new Uint8Array(iv.byteLength + encrypted.byteLength);
  result.set(iv, 0);
  result.set(new Uint8Array(encrypted), iv.byteLength);

  return result.buffer;
}

/**
 * Restores metadata from its encrypted state with robust error handling.
 */
export async function decryptJSON<T>(
  encryptedBuffer: ArrayBuffer,
  key: CryptoKey
): Promise<T> {
  const view = new Uint8Array(encryptedBuffer);
  const iv = view.subarray(0, AES_CONFIG.ivLength);
  const ciphertext = view.subarray(AES_CONFIG.ivLength);

  try {
    const decrypted = await crypto.subtle.decrypt(
      { name: AES_CONFIG.name, iv },
      key,
      ciphertext
    );
    return JSON.parse(new TextDecoder().decode(decrypted)) as T;
  } catch (err) {
    throw new Error("METADATA_DECRYPTION_FAILED: Invalid key or corrupted JSON metadata.");
  }
}
