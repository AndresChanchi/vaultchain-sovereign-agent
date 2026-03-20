"use client";

import { useKipioContext } from "@context/KipioContext";

/**
 * @title useKipioCrypto Bridge Hook
 * @notice Provides a high-level API for cryptographic operations by consuming the KipioContext.
 * @dev This bridge maintains API compatibility while delegating all state and worker 
 * management to the global KipioProvider.
 */
export function useKipioCrypto() {
  const {
    unlockVault,
    encryptFile,
    decryptFile,
    encryptMetadata,
    decryptMetadata,
    isLocked,
    isUnlocking,
    workerReady
  } = useKipioContext();

  // Return the standard interface expected by UI components
  return {
    unlockVault,
    encryptFile,
    decryptFile,
    encryptMetadata,
    decryptMetadata,
    isLocked,
    isUnlocking,
    workerReady
  };
}
