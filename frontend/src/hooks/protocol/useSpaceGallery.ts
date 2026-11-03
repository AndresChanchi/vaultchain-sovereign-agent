"use client";

/**
 * Space gallery — read the user's recent photos (hashes + Irys IDs).
 *
 * Flow
 *   1. `getMyGalleryPaginated(0, limit)` → array of content hashes
 *      (one read).
 *   2. For each hash, `getMyPhoto(hash)` → Irys ID (N parallel
 *      reads).
 *   3. Filter out entries with empty or zero IDs (the contract can
 *      return a zero-hash placeholder for a not-yet-resolved row;
 *      the MVP gallery did the same filter).
 *
 *   1 + N reads. For `limit = 8`, 9 reads. Parallelised via
 *   `Promise.all`. If the contract ever exposes a combined
 *   `getMyGalleryWithIds(offset, limit)` view, swap the two-step
 *   read for one — the returned shape (`{ items }`) does not change.
 *
 * Why viem and not wagmi
 *   Same rationale as `useSpaceStats`: `WalletContext` is the only
 *   session source. Contract views are public reads — the caller's
 *   address is passed as `account`, the RPC answers. No wagmi
 *   provider needed.
 *
 * Reactive
 *   `version` from `useSpaceRefresh()` is in the effect deps. After
 *   an upload (Fase 10), the flow calls `bump()` and this hook
 *   re-fetches — the new photo appears without a manual reload.
 *
 * Decryption
 *   This hook returns *identifiers* only — hash + Irys ID. Turning
 *   them into a displayed photo (fetch ciphertext from Irys,
 *   decrypt with the user's AES key) is the consumer's job. In 9.B
 *   that consumer is `SpaceGallery`, which uses `DecryptedImage`.
 *   The key derivation path is being rewired to `WalletContext` in
 *   a follow-up — see `SpaceGallery` for the temporary state.
 *
 * Errors
 *   - Chain mismatch → error state (page gate falls back to Welcome).
 *   - RPC failure → error state (same).
 *   - Any single `getMyPhoto` failure → that entry is skipped, the
 *     rest are returned. One broken row does not blank the gallery.
 */

import { useEffect, useState } from "react";
import { createPublicClient, http } from "viem";
import { arbitrum, arbitrumSepolia } from "wagmi/chains";
import { useSpaceRefresh } from "@context/SpaceRefreshContext";
import { CHAIN_CONFIG, VAULT_CONTRACT } from "@config/contracts";

export type SpaceGalleryItem = {
  /** Content hash, used as the React key and (later) as the lookup
   *  for the decryption cache. */
  hash: `0x${string}`;
  /** Irys content ID. The ciphertext lives at
   *  `${IRYS_CONFIG.gateway}${irysId}`. */
  irysId: string;
};

export type SpaceGalleryState =
  | { status: "loading" }
  | { status: "ready"; items: SpaceGalleryItem[] }
  | { status: "error"; error: unknown };

const CHAIN_BY_ID = {
  [arbitrumSepolia.id]: arbitrumSepolia,
  [arbitrum.id]: arbitrum,
} as const;

export function useSpaceGallery(
  address: `0x${string}` | null,
  chainId: number | null,
  limit: number = 8,
): SpaceGalleryState {
  const { version } = useSpaceRefresh();
  const [state, setState] = useState<SpaceGalleryState>({ status: "loading" });

  useEffect(() => {
    if (!address || chainId === null) {
      setState({ status: "loading" });
      return;
    }

    if (chainId !== CHAIN_CONFIG.id) {
      setState({
        status: "error",
        error: new Error(
          `Chain mismatch: session is on ${chainId}, contracts on ${CHAIN_CONFIG.id}.`,
        ),
      });
      return;
    }

    const chain = CHAIN_BY_ID[chainId];
    if (!chain) {
      setState({
        status: "error",
        error: new Error(`No viem chain definition for id ${chainId}.`),
      });
      return;
    }

    const controller = new AbortController();

    const client = createPublicClient({
      chain,
      transport: http(CHAIN_CONFIG.rpc),
    });

    (async () => {
      try {
        const hashes = (await client.readContract({
          address: VAULT_CONTRACT.address,
          abi: VAULT_CONTRACT.abi.abi,
          functionName: "getMyGalleryPaginated",
          args: [0, limit],
          account: address,
        })) as readonly `0x${string}`[];

        if (controller.signal.aborted) return;

        const resolved = await Promise.all(
          hashes.map(async (hash) => {
            try {
              const irysId = (await client.readContract({
                address: VAULT_CONTRACT.address,
                abi: VAULT_CONTRACT.abi.abi,
                functionName: "getMyPhoto",
                args: [hash],
                account: address,
              })) as string;
              return { hash, irysId };
            } catch {
              return { hash, irysId: "" };
            }
          }),
        );

        if (controller.signal.aborted) return;

        // Filter out unresolved rows. The contract returns the
        // zero-hash / empty-ID pair for rows that exist in the index
        // but do not yet have an Irys ID bound (a rare transitional
        // state).
        const items = resolved.filter(
          (item) => item.irysId !== "" && !item.irysId.startsWith("0x00000000"),
        );

        setState({ status: "ready", items });
      } catch (error) {
        if (controller.signal.aborted) return;
        setState({ status: "error", error });
      }
    })();

    return () => {
      controller.abort();
    };
  }, [address, chainId, limit, version]);

  return state;
}
