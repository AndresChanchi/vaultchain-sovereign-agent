"use client";

import { useCallback } from "react";
import {
  createPublicClient,
  createWalletClient,
  custom,
  http,
  type Hex,
  type PublicClient,
} from "viem";
import { arbitrum, arbitrumSepolia } from "wagmi/chains";
import { useWallet } from "@context/WalletContext";
import { useSpaceRefresh } from "@context/SpaceRefreshContext";
import { VAULT_CONTRACT, CHAIN_CONFIG } from "@config/contracts";

/**
 * Contract bridge — reads (public RPC) + writes (wallet provider).
 *
 * Signer source — `WalletContext`, not wagmi
 *   The legacy hook used `useWriteContract` / `usePublicClient` /
 *   `useAccount`. The new login flow never touches wagmi, so this
 *   hook reads the session from `WalletContext` and builds:
 *
 *     - `createPublicClient({ http })` for all reads and gas
 *       estimation. No signer, no wallet extension — pure RPC.
 *     - `createWalletClient({ custom(provider) })` for the
 *       `registerUpload` write. `custom(provider)` bridges the raw
 *       EIP-1193 request method into viem's transport, so the
 *       wallet popup appears when viem calls `eth_sendTransaction`.
 *
 * Chain gate
 *   Both the read client and the write client are built for
 *   `CHAIN_CONFIG.id` only. A session on a different chain returns
 *   `WRONG_CHAIN` before any RPC call — the contract lives at one
 *   address on one chain, reading from another produces zero/garbage
 *   that looks like a valid result.
 *
 * Removed wagmi-derived flags
 *   `isProcessing`, `isSigning`, `isConfirming`, `isSuccess`,
 *   `writeError`, `txHash` — these were wagmi's `useWriteContract` /
 *   `useWaitForTransactionReceipt` state. In the new flow, stage and
 *   error tracking live in `useUploadFlow` (10.2), which owns the
 *   full pipeline. The legacy `UploadOrchestrator` that consumed
 *   these flags is not mounted anywhere; if someone re-mounts it,
 *   they must adapt it to read from the new flow. Documented
 *   explicitly so the next reader does not chase a phantom regression.
 *
 * `invalidateVaultCache`
 *   Kept as an alias to `useSpaceRefresh().bump` for one extra
 *   release. The 9.B reactive flow already consumes `version` via
 *   `useSpaceStats` / `useSpaceGallery` — calling `bump()` triggers
 *   a refetch of both. Remove the alias in 10.4 once the last
 *   consumer (`UploadOrchestrator`) stops being referenced.
 *
 * Gas-estimation retry (mobile + funding volatility)
 *   Unchanged from the legacy implementation. Arbitrum occasionally
 *   bumps the base fee between the estimation and the broadcast,
 *   producing an RPC `max fee per gas less than block base fee`
 *   (-32000). A 30% buffer plus 2-3 retries (mobile) smooths this.
 *   Non-gas errors are propagated immediately — a user rejection or
 *   a contract revert must not trigger a retry.
 */
export function useVault() {
  const { session, getEip1193Provider } = useWallet();
  const { bump } = useSpaceRefresh();

  const address = session?.address ?? null;
  const chainId = session?.chainId ?? null;

  const getPublicClient = useCallback((): PublicClient | null => {
    if (chainId === null || chainId !== CHAIN_CONFIG.id) return null;
    const chain =
      chainId === arbitrumSepolia.id
        ? arbitrumSepolia
        : chainId === arbitrum.id
          ? arbitrum
          : null;
    if (!chain) return null;
    return createPublicClient({
      chain,
      transport: http(CHAIN_CONFIG.rpc),
    });
  }, [chainId]);

  const getTotalPhotos = useCallback(async (): Promise<number> => {
    const client = getPublicClient();
    if (!address || !client) return 0;
    const data = await client.readContract({
      address: VAULT_CONTRACT.address,
      abi: VAULT_CONTRACT.abi.abi,
      functionName: "getMyTotalPhotos",
      account: address,
    });
    return Number(data);
  }, [address, getPublicClient]);

  const getGallery = useCallback(
    async (offset: number, limit: number): Promise<Hex[]> => {
      const client = getPublicClient();
      if (!address || !client) return [];
      const data = await client.readContract({
        address: VAULT_CONTRACT.address,
        abi: VAULT_CONTRACT.abi.abi,
        functionName: "getMyGalleryPaginated",
        args: [offset, limit],
        account: address,
      });
      return data as Hex[];
    },
    [address, getPublicClient],
  );

  const getPhotoId = useCallback(
    async (contentHash: Hex): Promise<string> => {
      const client = getPublicClient();
      if (!address || !client) return "";
      const data = await client.readContract({
        address: VAULT_CONTRACT.address,
        abi: VAULT_CONTRACT.abi.abi,
        functionName: "getMyPhoto",
        args: [contentHash],
        account: address,
      });
      return data as string;
    },
    [address, getPublicClient],
  );

  const estimateRegistrationCost = useCallback(
    async (contentHash: Hex, encryptedTxId: string): Promise<bigint> => {
      const client = getPublicClient();
      if (!address || !client) return 0n;
      try {
        return await client.estimateContractGas({
          address: VAULT_CONTRACT.address,
          abi: VAULT_CONTRACT.abi.abi,
          functionName: "registerUpload",
          args: [contentHash, encryptedTxId],
          account: address,
        });
      } catch {
        return 0n;
      }
    },
    [address, getPublicClient],
  );

  /**
   * Register an upload on Arbitrum. Broadcasts via the wallet
   * provider (popup), waits for the receipt, then signals the
   * reactive layer (`bump()`) so consumers refetch.
   *
   * Returns the transaction hash once mined. Throws on:
   *   - missing session / wrong chain / missing provider
   *   - user rejection (wallet returns 4001 → propagates as-is,
   *     callers can detect and treat as a no-op)
   *   - RPC revert on receipt
   *   - gas mis-estimate on broadcast after retries are exhausted
   */
  const registerUpload = useCallback(
    async (contentHash: Hex, encryptedTxId: string): Promise<Hex> => {
      if (!address || chainId === null) {
        throw new Error("WALLET_NOT_CONNECTED");
      }
      if (chainId !== CHAIN_CONFIG.id) {
        throw new Error("WRONG_CHAIN");
      }

      const provider = getEip1193Provider();
      if (!provider) {
        throw new Error("PROVIDER_UNAVAILABLE");
      }

      const chain =
        chainId === arbitrumSepolia.id
          ? arbitrumSepolia
          : chainId === arbitrum.id
            ? arbitrum
            : null;
      if (!chain) throw new Error("UNKNOWN_CHAIN");

      const publicClient = createPublicClient({
        chain,
        transport: http(CHAIN_CONFIG.rpc),
      });

      const walletClient = createWalletClient({
        account: address,
        chain,
        transport: custom(provider),
      });

      const isMobile =
        typeof navigator !== "undefined" &&
        /iPhone|iPad|iPod|Android/i.test(navigator.userAgent);
      const maxRetries = isMobile ? 3 : 1;

      for (let attempt = 0; attempt < maxRetries; attempt++) {
        try {
          const feeData = await publicClient.estimateFeesPerGas();
          const maxFeePerGas = feeData.maxFeePerGas
            ? (feeData.maxFeePerGas * 130n) / 100n
            : undefined;
          const maxPriorityFeePerGas = feeData.maxPriorityFeePerGas
            ? (feeData.maxPriorityFeePerGas * 130n) / 100n
            : undefined;

          const txHash = await walletClient.writeContract({
            address: VAULT_CONTRACT.address,
            abi: VAULT_CONTRACT.abi.abi,
            functionName: "registerUpload",
            args: [contentHash, encryptedTxId],
            chain,
            maxFeePerGas,
            maxPriorityFeePerGas,
          });

          // Broadcast OK. Wait for the receipt so callers know the
          // tx is mined, then signal. From this point forward we do
          // not retry — the tx is already on-chain; a receipt error
          // is a revert, not a gas mis-estimate.
          await publicClient.waitForTransactionReceipt({ hash: txHash });
          bump();
          return txHash;
        } catch (error: any) {
          const isGasError =
            error?.message?.includes("max fee per gas") ||
            error?.message?.includes("base fee");
          const isLastAttempt = attempt === maxRetries - 1;
          if (!isGasError || isLastAttempt) throw error;
          await new Promise((res) => setTimeout(res, 1800));
        }
      }

      // Unreachable — the loop either returns or throws.
      throw new Error("REGISTER_UPLOAD_UNREACHABLE");
    },
    [address, chainId, getEip1193Provider, bump],
  );

  return {
    getTotalPhotos,
    getGallery,
    getPhotoId,
    estimateRegistrationCost,
    registerUpload,
    /** @deprecated use `bump()` from `useSpaceRefresh` directly. */
    invalidateVaultCache: bump,
    /** Informational only. Ledger sessions throw in `signTypedData`. */
    isLedger: session?.kind === "wallet" && session.wallet === "ledger",
  };
}
