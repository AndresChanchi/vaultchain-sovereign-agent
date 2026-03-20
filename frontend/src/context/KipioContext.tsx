"use client";

import React, { createContext, useContext, useState, useEffect, useCallback, useRef } from 'react';
import * as Comlink from "comlink";
import { useSignTypedData, useAccount } from "wagmi";
import { 
  deriveKeyFromSignature, 
  KIPIO_SIGN_DOMAIN, 
  KIPIO_SIGN_TYPES, 
  KIPIO_SIGN_MESSAGE 
} from "@lib/crypto/kdf";
import type { CryptoWorkerAPI } from "@lib/workers/crypto.worker";
import type { Hex } from "viem";
import type { FileMetadata } from "@interfaces/vault";

/**
 * @title Kipio Security Context
 * @notice Centralized orchestrator for cryptographic operations and vault state.
 * @dev Implements a Singleton Worker pattern and ensures the AES-GCM master key 
 * remains strictly in volatile memory (RAM).
 */
interface KipioContextType {
  encryptionKey: CryptoKey | null;
  isLocked: boolean;
  isUnlocking: boolean;
  workerReady: boolean;
  unlockVault: () => Promise<CryptoKey>;
  encryptFile: (data: ArrayBuffer, hash: Hex) => Promise<ArrayBuffer>;
  decryptFile: (data: ArrayBuffer, hash: Hex) => Promise<ArrayBuffer>;
  encryptMetadata: (metadata: FileMetadata) => Promise<ArrayBuffer>;
  decryptMetadata: (data: ArrayBuffer) => Promise<FileMetadata>;
}

const KipioContext = createContext<KipioContextType | null>(null);

export function KipioProvider({ children }: { children: React.ReactNode }) {
  const { address } = useAccount();
  const { signTypedDataAsync } = useSignTypedData();

  /**
   * @dev Master Encryption Key (AES-GCM-256). 
   * NEVER persists to LocalStorage or IndexedDB.
   */
  const [encryptionKey, setEncryptionKey] = useState<CryptoKey | null>(null);
  const [isUnlocking, setIsUnlocking] = useState(false);
  const [workerReady, setWorkerReady] = useState(false);

  /**
   * @dev Singleton Worker Management.
   * Prevents memory leaks and redundant thread allocation.
   */
  const workerApi = useRef<Comlink.Remote<CryptoWorkerAPI> | null>(null);
  const workerRef = useRef<Worker | null>(null);

  useEffect(() => {
    if (typeof window === "undefined") return;

    // Initialize the Web Worker for off-main-thread cryptography
    const worker = new Worker(
      new URL("../lib/workers/crypto.worker.ts", import.meta.url),
      { type: "module" }
    );

    workerRef.current = worker;
    workerApi.current = Comlink.wrap<CryptoWorkerAPI>(worker);
    setWorkerReady(true);

    // Clean up worker on application unmount
    return () => {
      worker.terminate();
      setWorkerReady(false);
    };
  }, []);

  /**
   * @notice Triggers the EIP-712 signature flow to derive the vault's master key.
   * @dev Deterministic derivation ensures the same key is generated across devices.
   */
  const unlockVault = useCallback(async () => {
    if (!address) throw new Error("WALLET_NOT_CONNECTED");
    
    try {
      setIsUnlocking(true);
      const signature = await signTypedDataAsync({
        domain: KIPIO_SIGN_DOMAIN,
        types: KIPIO_SIGN_TYPES,
        primaryType: "VaultAuth",
        message: KIPIO_SIGN_MESSAGE,
      });

      const key = await deriveKeyFromSignature(signature as Hex);
      setEncryptionKey(key);
      return key;
    } catch (error) {
      console.error("[KIPIO_CONTEXT] Critical unlock failure:", error);
      throw error;
    } finally {
      setIsUnlocking(false);
    }
  }, [address, signTypedDataAsync]);

  /**
   * @notice Encrypts a file buffer using the pre-injected Master Key.
   * @dev Uses Comlink.transfer to avoid memory cloning (Zero-Copy).
   */
  const encryptFile = useCallback(async (data: ArrayBuffer, hash: Hex) => {
    if (!workerApi.current || !encryptionKey) throw new Error("VAULT_LOCKED");
    return await workerApi.current.encryptFileWorker(
      Comlink.transfer(data, [data]), 
      hash, 
      encryptionKey
    );
  }, [encryptionKey]);

  /**
   * @notice Decrypts an encrypted file buffer.
   */
  const decryptFile = useCallback(async (encryptedData: ArrayBuffer, hash: Hex) => {
    if (!workerApi.current || !encryptionKey) throw new Error("VAULT_LOCKED");
    return await workerApi.current.decryptFileWorker(
      Comlink.transfer(encryptedData, [encryptedData]), 
      hash, 
      encryptionKey
    );
  }, [encryptionKey]);

  /**
   * @notice Secures asset metadata before IPFS/Irys propagation.
   */
  const encryptMetadata = useCallback(async (metadata: FileMetadata) => {
    if (!workerApi.current || !encryptionKey) throw new Error("VAULT_LOCKED");
    return await workerApi.current.encryptMetadataWorker(metadata, encryptionKey);
  }, [encryptionKey]);

  /**
   * @notice Decodes encrypted metadata back into a readable JSON object.
   */
  const decryptMetadata = useCallback(async (encryptedData: ArrayBuffer) => {
    if (!workerApi.current || !encryptionKey) throw new Error("VAULT_LOCKED");
    return await workerApi.current.decryptMetadataWorker(
      Comlink.transfer(encryptedData, [encryptedData]), 
      encryptionKey
    );
  }, [encryptionKey]);

  const value = {
    encryptionKey,
    isLocked: !encryptionKey,
    isUnlocking,
    workerReady,
    unlockVault,
    encryptFile,
    decryptFile,
    encryptMetadata,
    decryptMetadata,
  };

  return <KipioContext.Provider value={value}>{children}</KipioContext.Provider>;
}

export function useKipioContext() {
  const context = useContext(KipioContext);
  if (!context) throw new Error("useKipioContext must be used within KipioProvider");
  return context;
}
