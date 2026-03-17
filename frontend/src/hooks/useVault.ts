import { useCallback } from "react";
import { 
  useWriteContract, 
  useAccount,
  useWaitForTransactionReceipt,
  usePublicClient 
} from "wagmi";
import { useQueryClient } from "@tanstack/react-query";
import { VAULT_CONTRACT, CHAIN_CONFIG } from "@config/contracts";
import { readContract } from "viem/actions";
import type { Hex, Client } from "viem";

/**
 * Hook to interact with the Arbitrum Stylus Vault contract.
 * Manages both high-level write operations and imperative read access for the gallery.
 * * DESIGN PATTERN: We use the PublicClient for read operations to allow 
 * async orchestration within the gallery without triggering complex hook dependencies.
 */
export function useVault() {
  const { address } = useAccount();
  const queryClient = useQueryClient();
  
  // Explicitly scope the client to the configured chain ID to prevent Mainnet/Sepolia type mismatches
  const publicClient = usePublicClient({ chainId: CHAIN_CONFIG.id });
  
  const { 
    writeContractAsync, 
    data: txHash, 
    isPending: isWriting,
    error: writeError 
  } = useWriteContract();

  /**
   * Watches the transaction status on Arbitrum Sepolia/Mainnet.
   * isConfirming: block is being mined.
   * isSuccess: transaction is finalized.
   */
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ 
    hash: txHash,
    chainId: CHAIN_CONFIG.id 
  });

  // --- READ OPERATIONS (Imperative for Gallery Orchestration) ---

  /**
   * Returns the total number of entries in the user's private vault.
   */
  const getTotalPhotos = useCallback(async (): Promise<number> => {
    if (!address || !publicClient) return 0;
    
    // Using 'as Client' to bypass strict blockExplorer URL validation in production builds
    const data = await readContract(publicClient as Client, {
      address: VAULT_CONTRACT.address,
      abi: VAULT_CONTRACT.abi.abi,
      functionName: "getMyTotalPhotos",
      account: address,
    });
    return Number(data);
  }, [address, publicClient]);

  /**
   * Fetches a paginated list of B256 content hashes from Stylus.
   */
  const getGallery = useCallback(async (offset: number, limit: number): Promise<Hex[]> => {
    if (!address || !publicClient) return [];
    
    const data = await readContract(publicClient as Client, {
      address: VAULT_CONTRACT.address,
      abi: VAULT_CONTRACT.abi.abi,
      functionName: "getMyGalleryPaginated",
      args: [offset, limit],
      account: address,
    });
    return data as Hex[];
  }, [address, publicClient]);

  /**
   * Retrieves the encrypted transaction ID (Irys ID) for a specific content hash.
   */
  const getPhotoId = useCallback(async (contentHash: Hex): Promise<string> => {
    if (!address || !publicClient) return "";
    
    const data = await readContract(publicClient as Client, {
      address: VAULT_CONTRACT.address,
      abi: VAULT_CONTRACT.abi.abi,
      functionName: "getMyPhoto",
      args: [contentHash],
      account: address,
    });
    return data as string;
  }, [address, publicClient]);

  // --- WRITE OPERATIONS ---

  /**
   * Links a content hash to its Irys transaction ID on-chain.
   */
  const registerUpload = useCallback(async (contentHash: Hex, encryptedTxId: string) => {
    if (!address) throw new Error("WALLET_NOT_CONNECTED");

    return await writeContractAsync({
      address: VAULT_CONTRACT.address,
      abi: VAULT_CONTRACT.abi.abi,
      functionName: "registerUpload",
      args: [contentHash, encryptedTxId],
      chainId: CHAIN_CONFIG.id,
    });
  }, [address, writeContractAsync]);

  /**
   * Optimized batch registration to save gas on multiple uploads.
   */
  const registerBatch = useCallback(async (hashes: Hex[], encryptedIds: string[]) => {
    if (!address) throw new Error("WALLET_NOT_CONNECTED");

    return await writeContractAsync({
      address: VAULT_CONTRACT.address,
      abi: VAULT_CONTRACT.abi.abi,
      functionName: "registerBatch",
      args: [hashes, encryptedIds],
      chainId: CHAIN_CONFIG.id,
    });
  }, [address, writeContractAsync]);

  /**
   * Refreshes the gallery data across the app.
   */
  const invalidateVaultCache = useCallback(() => {
    queryClient.invalidateQueries({ queryKey: ['readContract'] });
  }, [queryClient]);

  return {
    // Read methods
    getTotalPhotos,
    getGallery,
    getPhotoId,
    // Write methods
    registerUpload,
    registerBatch,
    invalidateVaultCache,
    isProcessing: isWriting || isConfirming,
    isSuccess,
    writeError,
    txHash
  };
}
