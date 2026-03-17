import { type Hex } from "viem";

/**
 * Configuration for the Key Derivation process.
 * Salt and Info are public but constant to ensure deterministic key generation.
 */
const KDF_CONFIG = {
  salt: new TextEncoder().encode("kipio-vault-v1-salt"),
  info: new TextEncoder().encode("kipio-vault-aes-256-encryption"),
  hash: "SHA-256",
} as const;

/**
 * Derives a non-extractable CryptoKey from an EIP-712 signature.
 * * @param signature - The Hex signature obtained from the wallet.
 * @returns A CryptoKey restricted to AES-GCM 256-bit operations.
 */
export async function deriveKeyFromSignature(signature: Hex): Promise<CryptoKey> {
  // 1. Convert Hex to a strict ArrayBuffer to satisfy Web Crypto API constraints
  const signatureBuffer = hexToArrayBuffer(signature);

  // 2. Import raw signature material
  const baseKey = await window.crypto.subtle.importKey(
    "raw",
    signatureBuffer,
    "HKDF",
    false,
    ["deriveKey"]
  );

  // 3. Derive the actual AES-GCM key using HKDF
  return await window.crypto.subtle.deriveKey(
    {
      name: "HKDF",
      salt: KDF_CONFIG.salt,
      info: KDF_CONFIG.info,
      hash: KDF_CONFIG.hash,
    },
    baseKey,
    {
      name: "AES-GCM",
      length: 256,
    },
    false, // Security: Key material cannot be read by JS after derivation
    ["encrypt", "decrypt"]
  );
}

/**
 * Utility: Converts a Hex string strictly to an ArrayBuffer.
 * This avoids the SharedArrayBuffer issue in strict TypeScript environments.
 */
function hexToArrayBuffer(hex: Hex): ArrayBuffer {
  const cleanHex = hex.startsWith("0x") ? hex.slice(2) : hex;
  if (cleanHex.length % 2 !== 0) {
    throw new Error("Invalid Hex string length for cryptographic operations");
  }

  const view = new Uint8Array(cleanHex.length / 2);
  for (let i = 0; i < cleanHex.length; i += 2) {
    view[i / 2] = parseInt(cleanHex.substring(i, i + 2), 16);
  }
  
  // We return the underlying ArrayBuffer specifically
  return view.buffer as ArrayBuffer;
}

/**
 * EIP-712 Domain and Message definitions for Wallet Signing.
 */
export const KIPIO_SIGN_DOMAIN = {
  name: "Kipio Vault",
  version: "1",
} as const;

export const KIPIO_SIGN_TYPES = {
  VaultAuth: [
    { name: "action", type: "string" },
    { name: "description", type: "string" },
  ],
} as const;

export const KIPIO_SIGN_MESSAGE = {
  action: "Unlock Sovereign Vault",
  description: "By signing this, you generate the unique key required to encrypt and decrypt your files. This remains local to your browser.",
} as const;
