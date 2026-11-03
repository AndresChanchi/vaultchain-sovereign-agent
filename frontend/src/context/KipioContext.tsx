"use client";

import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useRef,
  useState,
} from "react";
import * as Comlink from "comlink";
import type { Hex } from "viem";
import { useWallet } from "@context/WalletContext";
import {
  deriveKeyFromSignature,
  KIPIO_SIGN_DOMAIN,
  KIPIO_SIGN_TYPES,
  KIPIO_SIGN_MESSAGE,
} from "@lib/crypto/kdf";
import type { CryptoWorkerAPI } from "@lib/workers/crypto.worker";
import type { FileMetadata } from "@interfaces/vault";

/**
 * @title Kipio Security Context
 * @notice Centralized orchestrator for cryptographic operations and vault state.
 * @dev Singleton Worker pattern, AES-GCM master key stays strictly in
 * volatile memory (RAM).
 *
 * Signer source — `WalletContext`
 *   The session-aware signer lives in `WalletContext.signTypedData`.
 *   `KipioContext` calls it with the fixed KIPIO_SIGN_* payload and
 *   receives a signature without knowing whether the user
 *   authenticated with a wallet or OAuth. The derivation is
 *   identical for both.
 *
 * Key storage — ref + state
 *   `encryptionKeyRef.current` holds the derived CryptoKey for the
 *   imperative crypto operations (`encryptFile`, `decryptFile`, …).
 *   `encryptionKey` state mirrors the same value for UI reactivity
 *   (`isLocked`). Two reasons for the duplication:
 *
 *   1. `useCallback` captures state at definition time. After
 *      `unlockVault()` returns, `setEncryptionKey(key)` triggers a
 *      re-render but does not update any in-flight closure. A caller
 *      that does `await unlockVault(); await encryptFile(...)` in the
 *      same tick uses the *old* closure where `encryptionKey` is
 *      still `null`, and `encryptFile` throws `VAULT_LOCKED`. This is
 *      the exact failure mode of the upload flow before this fix.
 *      Reading the ref inside `encryptFile` avoids the stale capture.
 *
 *   2. State is still required so `isLocked` derives correctly and
 *      `DecryptedImage` / `useVaultUnlock` re-render when the key
 *      becomes available. The ref alone would leave the UI blind.
 *
 *   Both are updated in lockstep inside `unlockVault()` and cleared
 *   in lockstep on session change.
 *
 * Master key lifecycle
 *   Derived from the EIP-712 signature via HKDF, held in memory, never
 *   persisted. A tab reload forces re-derivation.
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
  const { session, signTypedData } = useWallet();

  /**
   * Ref mirror of the master key. Read inside every crypto callback
   * so an `await unlockVault(); await encryptFile();` sequence sees
   * the freshly derived key, not the closure's stale `null`.
   */
  const encryptionKeyRef = useRef<CryptoKey | null>(null);

  /**
   * State mirror for UI reactivity. `isLocked` below reads this.
   */
  const [encryptionKey, setEncryptionKey] = useState<CryptoKey | null>(null);

  const [isUnlocking, setIsUnlocking] = useState(false);
  const [workerReady, setWorkerReady] = useState(false);

  const workerApi = useRef<Comlink.Remote<CryptoWorkerAPI> | null>(null);
  const workerRef = useRef<Worker | null>(null);

  useEffect(() => {
    if (typeof window === "undefined") return;

    const worker = new Worker(
      new URL("../lib/workers/crypto.worker.ts", import.meta.url),
      { type: "module" },
    );

    workerRef.current = worker;
    workerApi.current = Comlink.wrap<CryptoWorkerAPI>(worker);
    setWorkerReady(true);

    return () => {
      worker.terminate();
      setWorkerReady(false);
    };
  }, []);

  /**
   * Clear the key whenever the session changes or ends — ref and
   * state together. Prevents a stale key from a previous wallet from
   * decrypting (or failing to decrypt) the current session's photos.
   */
  useEffect(() => {
    encryptionKeyRef.current = null;
    setEncryptionKey(null);
  }, [session?.address]);

  const unlockVault = useCallback(async () => {
    if (!session) throw new Error("WALLET_NOT_CONNECTED");

    try {
      setIsUnlocking(true);
      const signature = await signTypedData({
        domain: KIPIO_SIGN_DOMAIN,
        types: KIPIO_SIGN_TYPES,
        primaryType: "VaultAuth",
        message: KIPIO_SIGN_MESSAGE,
      });
      const key = await deriveKeyFromSignature(signature);
      // Ref first so any in-flight caller sees the key immediately;
      // state second for the next render's UI.
      encryptionKeyRef.current = key;
      setEncryptionKey(key);
      return key;
    } catch (error) {
      console.error("[KIPIO_CONTEXT] Critical unlock failure:", error);
      throw error;
    } finally {
      setIsUnlocking(false);
    }
  }, [session, signTypedData]);

  /**
   * Crypto callbacks below have empty deps and read the key from the
   * ref. That makes them stable references and immune to the stale
   * closure problem described in the file header. The runtime guards
   * (`workerApi.current`, `encryptionKeyRef.current`) throw the same
   * `VAULT_LOCKED` error the previous version did, so existing error
   * handling remains valid.
   */

  const encryptFile = useCallback(async (data: ArrayBuffer, hash: Hex) => {
    const key = encryptionKeyRef.current;
    if (!workerApi.current || !key) throw new Error("VAULT_LOCKED");
    return await workerApi.current.encryptFileWorker(
      Comlink.transfer(data, [data]),
      hash,
      key,
    );
  }, []);

  const decryptFile = useCallback(
    async (encryptedData: ArrayBuffer, hash: Hex) => {
      const key = encryptionKeyRef.current;
      if (!workerApi.current || !key) throw new Error("VAULT_LOCKED");
      return await workerApi.current.decryptFileWorker(
        Comlink.transfer(encryptedData, [encryptedData]),
        hash,
        key,
      );
    },
    [],
  );

  const encryptMetadata = useCallback(async (metadata: FileMetadata) => {
    const key = encryptionKeyRef.current;
    if (!workerApi.current || !key) throw new Error("VAULT_LOCKED");
    return await workerApi.current.encryptMetadataWorker(metadata, key);
  }, []);

  const decryptMetadata = useCallback(async (encryptedData: ArrayBuffer) => {
    const key = encryptionKeyRef.current;
    if (!workerApi.current || !key) throw new Error("VAULT_LOCKED");
    return await workerApi.current.decryptMetadataWorker(
      Comlink.transfer(encryptedData, [encryptedData]),
      key,
    );
  }, []);

  const value: KipioContextType = {
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

  return (
    <KipioContext.Provider value={value}>{children}</KipioContext.Provider>
  );
}

export function useKipioContext() {
  const context = useContext(KipioContext);
  if (!context)
    throw new Error("useKipioContext must be used within KipioProvider");
  return context;
}
