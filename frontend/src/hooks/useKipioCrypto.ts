import { useState, useEffect, useCallback, useRef } from "react";
import * as Comlink from "comlink";
import { useSignTypedData, useAccount } from "wagmi";
import { deriveKeyFromSignature, KIPIO_SIGN_DOMAIN, KIPIO_SIGN_TYPES, KIPIO_SIGN_MESSAGE } from "@lib/crypto/kdf";
import type { CryptoWorkerAPI } from "@lib/workers/crypto.worker";
import type { Hex } from "viem";
import type { FileMetadata } from "@interfaces/vault";

export function useKipioCrypto() {
  const { address } = useAccount();
  const { signTypedDataAsync } = useSignTypedData();
  
  const [encryptionKey, setEncryptionKey] = useState<CryptoKey | null>(null);
  const [isUnlocking, setIsUnlocking] = useState(false);
  const [workerReady, setWorkerReady] = useState(false);
  
  // Maybe use useRef to avoid the mistake DataCloneError React 19, i have to update my knowledge...
  const workerApi = useRef<Comlink.Remote<CryptoWorkerAPI> | null>(null);

  useEffect(() => {
    if (typeof window === "undefined") return;
    
    const worker = new Worker(new URL("../lib/workers/crypto.worker.ts", import.meta.url), {
      type: "module",
    });
    
    workerApi.current = Comlink.wrap<CryptoWorkerAPI>(worker);
    setWorkerReady(true);

    return () => {
      worker.terminate();
      setWorkerReady(false);
    };
  }, []);

  const unlockVault = useCallback(async () => {
    if (!address) throw new Error("Wallet not connected");
    
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
      console.error("Failed to unlock vault:", error);
      throw error;
    } finally {
      setIsUnlocking(false);
    }
  }, [address, signTypedDataAsync]);

  const encryptFile = useCallback(async (data: ArrayBuffer, hash: Hex) => {
    if (!workerApi.current || !encryptionKey) throw new Error("Vault is locked or worker not ready");
    
    return await workerApi.current.encryptFileWorker(
      Comlink.transfer(data, [data]), 
      hash, 
      encryptionKey
    );
  }, [encryptionKey]);

  const decryptFile = useCallback(async (encryptedData: ArrayBuffer, hash: Hex) => {
    if (!workerApi.current || !encryptionKey) throw new Error("Vault is locked");

    return await workerApi.current.decryptFileWorker(
      Comlink.transfer(encryptedData, [encryptedData]), 
      hash, 
      encryptionKey
    );
  }, [encryptionKey]);

  const encryptMetadata = useCallback(async (metadata: FileMetadata) => {
    if (!workerApi.current || !encryptionKey) throw new Error("Vault is locked");
    return await workerApi.current.encryptMetadataWorker(metadata, encryptionKey);
  }, [encryptionKey]);

  const decryptMetadata = useCallback(async (encryptedData: ArrayBuffer) => {
    if (!workerApi.current || !encryptionKey) throw new Error("Vault is locked");
    
    return await workerApi.current.decryptMetadataWorker(
      Comlink.transfer(encryptedData, [encryptedData]), 
      encryptionKey
    );
  }, [encryptionKey]);

  return {
    unlockVault,
    encryptFile,
    decryptFile,
    encryptMetadata,
    decryptMetadata,
    isLocked: !encryptionKey,
    isUnlocking,
    workerReady
  };
}
