"use client";

/**
 * Space stats — read the user's total photo count from the MVP
 * contract on Arbitrum Sepolia.
 *
 * Why viem and not wagmi
 *   `WalletContext` is the single source of truth for the session.
 *   `/space` gates on it. A wagmi read would require the wagmi
 *   provider to be connected *and* on the same chain — and the login
 *   flow never touches wagmi. This hook reads directly from the RPC
 *   with `createPublicClient` + the client's `readContract` action,
 *   using only `session.address` and `session.chainId` from
 *   `WalletContext`.
 *
 *   No signing, no auth, no wallet extension interaction. The RPC
 *   answers a public view function; the caller's address is passed
 *   as `account` so the contract returns *that address's* count
 *   (`getMyTotalPhotos` reads `msg.sender` internally).
 *
 * viem v2 API note
 *   `readContract` is NOT a top-level export from `viem` in 2.x.
 *   Actions are methods on a client instance:
 *
 *     const client = createPublicClient({ … });
 *     const data = await client.readContract({ … });
 *
 *   We use the client-method form — no extra import, same call
 *   signature, idiomatic for a hook that already holds a client.
 *
 * Reactive to `SpaceRefreshContext`
 *   `version` from `useSpaceRefresh()` is in the effect deps. When
 *   the upload flow completes (Fase 10), it calls `bump()` — this
 *   hook re-fetches and updates the count without a manual reload.
 *
 * Chain gate
 *   The MVP contract is deployed on Arbitrum Sepolia. If the session
 *   is on a different chain, reading a Sepolia address from a
 *   mainnet RPC would return 0 or fail — both look the same to the
 *   caller. The hook gates on `chainId === CHAIN_CONFIG.id` and
 *   returns an error state. The gate in `(app)/space/page.tsx` falls
 *   back to Welcome on error.
 *
 * Abort semantics
 *   `readContract` does not accept a `signal`, so the request will
 *   run to completion even after unmount. The `AbortController`
 *   gates the `setState` — the promise resolves, but the state
 *   update is skipped if the effect already cleaned up.
 */

import { useEffect, useState } from "react";
import { createPublicClient, http } from "viem";
import { arbitrum, arbitrumSepolia } from "wagmi/chains";
import { useSpaceRefresh } from "@context/SpaceRefreshContext";
import { CHAIN_CONFIG, VAULT_CONTRACT } from "@config/contracts";

export type SpaceStatsState =
  | { status: "loading" }
  | { status: "ready"; photoCount: number }
  | { status: "error"; error: unknown };

const CHAIN_BY_ID = {
  [arbitrumSepolia.id]: arbitrumSepolia,
  [arbitrum.id]: arbitrum,
} as const;

export function useSpaceStats(
  address: `0x${string}` | null,
  chainId: number | null,
): SpaceStatsState {
  const { version } = useSpaceRefresh();
  const [state, setState] = useState<SpaceStatsState>({ status: "loading" });

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
        const raw = await client.readContract({
          address: VAULT_CONTRACT.address,
          abi: VAULT_CONTRACT.abi.abi,
          functionName: "getMyTotalPhotos",
          account: address,
        });
        if (controller.signal.aborted) return;
        setState({ status: "ready", photoCount: Number(raw) });
      } catch (error) {
        if (controller.signal.aborted) return;
        setState({ status: "error", error });
      }
    })();

    return () => {
      controller.abort();
    };
  }, [address, chainId, version]);

  return state;
}
