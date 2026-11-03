"use client";

/**
 * `/space` — Home for the authenticated surface.
 *
 * Gate on `useSpaceStats`:
 *   - `status === "ready" && photoCount > 0` → `SpaceOverview`
 *   - `status === "loading"` → `SpaceWelcome` (safe default: the
 *     Welcome CTAs are disabled, so a user with photos who sees
 *     Welcome for one render cannot do anything wrong — the layout
 *     settles to the correct state on the next tick)
 *   - `status === "error"` → `SpaceWelcome` (same rationale; the
 *     error cases are chain mismatch and RPC failure, both
 *     transient and both resolved by refresh once the underlying
 *     cause is fixed)
 *   - `status === "ready" && photoCount === 0` → `SpaceWelcome`
 *
 * Why "loading → Welcome" instead of "loading → null"
 *   A blank main column for the 200-400ms the RPC takes would flash
 *   the page. Welcome is a complete, valid state (its CTAs are
 *   disabled anyway); showing it during loading is visually
 *   stable and semantically honest ("this is what you see when
 *   there is nothing to show yet"). When the count resolves to ≥1,
 *   Overview replaces Welcome.
 *
 *   The alternative — a skeleton — is more complex and no more
 *   honest, because the skeleton would look nothing like the
 *   Overview (which is a completely different layout). A brief
 *   Welcome is closer to "no content yet" than a false skeleton of
 *   content that is not coming.
 *
 * Why no wagmi
 *   The gate reads through `useSpaceStats` (viem + RPC). `WalletContext`
 *   is the only session source. wagmi is not imported by this file,
 *   not by the shell, not by any child in `/space`. Fase 10 removes
 *   wagmi from the tree entirely once the upload flow is rewired.
 */

import { useWallet } from "@context/WalletContext";
import { useSpaceStats } from "@hooks/protocol/useSpaceStats";
import { SpaceWelcome } from "@components/space/space-welcome";
import { SpaceOverview } from "@components/space/space-overview";

export default function SpacePage() {
  const { session } = useWallet();
  const stats = useSpaceStats(
    session?.address ?? null,
    session?.chainId ?? null,
  );

  if (stats.status === "ready" && stats.photoCount > 0) {
    return <SpaceOverview photoCount={stats.photoCount} />;
  }

  return <SpaceWelcome />;
}
