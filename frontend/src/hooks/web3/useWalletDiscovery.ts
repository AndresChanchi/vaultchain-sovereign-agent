"use client";

/**
 * React binding for EIP-6963 discovery.
 *
 * `subscribeDiscovery` (in `lib/wallet/discovery.ts`) is the
 * singleton store. This hook wraps it in `useSyncExternalStore` so
 * every consumer sees the same snapshot and re-renders exactly once
 * per change.
 *
 * Why `useSyncExternalStore` and not `useState` + `useEffect`
 *   The store can emit between the effect's subscribe and the next
 *   paint. `useSyncExternalStore` guarantees the snapshot and the
 *   render are consistent — no lost events, no tearing. It also
 *   handles SSR: `getServerSnapshot` returns `EMPTY_DISCOVERY`, a
 *   frozen reference, so React does not warn about a new snapshot
 *   on every server render.
 *
 * Stability of `getSnapshot` and `getServerSnapshot`
 *   Both must be stable across renders. Passing an inline arrow
 *   would create a new function on every render and cause React to
 *   re-subscribe. `getDiscoveredWallets` is a module-level
 *   function — stable by construction. `getServerSnapshot` is
 *   defined once outside the component.
 *
 * Usage
 *   const wallets = useWalletDiscovery();
 *   const metamask = wallets.find((w) => w.id === "metamask");
 *
 * The hook returns a `readonly` array. Consumers must not mutate it;
 * the store freezes each emission. Sorting/filtering should create a
 * new array (`[...wallets].sort(...)`), never mutate in place.
 *
 * Ledger is not here
 *   Hardware wallets are not injected providers. They are connected
 *   through DMK (`lib/ledger/connector.ts`), not EIP-6963. The
 *   wallet list component renders the Ledger row separately.
 */

import { useSyncExternalStore } from "react";
import {
  EMPTY_DISCOVERY,
  getDiscoveredWallets,
  subscribeDiscovery,
  type DiscoveredWallet,
} from "@lib/wallet/discovery";

/**
 * Stable server snapshot. Defined at module scope so its identity
 * never changes across renders — otherwise React loops.
 */
const getServerSnapshot = (): readonly DiscoveredWallet[] => EMPTY_DISCOVERY;

export function useWalletDiscovery(): readonly DiscoveredWallet[] {
  return useSyncExternalStore(
    subscribeDiscovery,
    getDiscoveredWallets,
    getServerSnapshot,
  );
}
