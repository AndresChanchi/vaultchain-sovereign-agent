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
 * Includes gas estimation for transparent cost reporting on mobile.
 */
export function useVault() {
  const { address } = useAccount();
  const queryClient = useQueryClient();
  const publicClient = usePublicClient({ chainId: CHAIN_CONFIG.id });
  
  const { 
    writeContractAsync, 
    data: txHash, 
    isPending: isWriting,
    error: writeError 
  } = useWriteContract();

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ 
    hash: txHash,
    chainId: CHAIN_CONFIG.id 
  });

  const estimateRegistrationCost = useCallback(async (contentHash: Hex, encryptedTxId: string): Promise<bigint> => {
    if (!address || !publicClient) return 0n;
    try {
      return await publicClient.estimateContractGas({
        address: VAULT_CONTRACT.address,
        abi: VAULT_CONTRACT.abi.abi,
        functionName: "registerUpload",
        args: [contentHash, encryptedTxId],
        account: address,
      });
    } catch (error) {
      return 0n;
    }
  }, [address, publicClient]);

  const getTotalPhotos = useCallback(async (): Promise<number> => {
    if (!address || !publicClient) return 0;
    const data = await readContract(publicClient as Client, {
      address: VAULT_CONTRACT.address,
      abi: VAULT_CONTRACT.abi.abi,
      functionName: "getMyTotalPhotos",
      account: address,
    });
    return Number(data);
  }, [address, publicClient]);

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

  /**
   * Registers upload on Arbitrum Stylus.
   * BUGFIX: Uses viem's native fee estimators instead of hardcoded priority fees
   * to strictly prevent RLP non-canonical integer (-32000) errors on Arbitrum.
   */
  const registerUpload = useCallback(async (contentHash: Hex, encryptedTxId: string) => {
    if (!address || !publicClient) throw new Error("WALLET_NOT_CONNECTED");

    const isMobile = typeof navigator !== 'undefined' && /iPhone|iPad|iPod|Android/i.test(navigator.userAgent);
    const maxRetries = isMobile ? 3 : 1;
    let attempt = 0;

    while (attempt < maxRetries) {
      try {
        /**
         * RLP Canonical Safety & Mobile Latency:
         * Arbitrum L2 rejects manual arbitrary priority fees if they create leading zero bytes.
         * We use viem's native fee estimator and scale it by 30% to buffer 
         * against mobile wallet latency, ensuring valid EIP-1559 RLP encoding.
         */
        const feeData = await publicClient.estimateFeesPerGas();
        const maxFeePerGas = feeData.maxFeePerGas ? (feeData.maxFeePerGas * 130n) / 100n : undefined;
        const maxPriorityFeePerGas = feeData.maxPriorityFeePerGas ? (feeData.maxPriorityFeePerGas * 130n) / 100n : undefined;

        return await writeContractAsync({
          address: VAULT_CONTRACT.address,
          abi: VAULT_CONTRACT.abi.abi,
          functionName: "registerUpload",
          args: [contentHash, encryptedTxId],
          chainId: CHAIN_CONFIG.id,
          maxFeePerGas,
          maxPriorityFeePerGas,
        });
      } catch (error: any) {
        attempt++;
        const isGasError = error?.message?.includes("max fee per gas") || error?.message?.includes("base fee");
        if (attempt >= maxRetries || !isGasError) throw error;
        await new Promise(res => setTimeout(res, 1800));
      }
    }
  }, [address, writeContractAsync, publicClient]);

  const invalidateVaultCache = useCallback(() => {
    queryClient.invalidateQueries({ queryKey: ['readContract'] });
  }, [queryClient]);

  return {
    getTotalPhotos,
    getGallery,
    getPhotoId,
    estimateRegistrationCost,
    registerUpload,
    invalidateVaultCache,
    isProcessing: isWriting || isConfirming,
    isSuccess,
    writeError,
    txHash
  };
}
