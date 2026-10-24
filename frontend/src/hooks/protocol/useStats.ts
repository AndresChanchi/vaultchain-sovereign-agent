/**
 * Protocol stats — read-only summary derived from public contract events.
 *
 * Today this hook returns `null` for every field. That is the honest
 * answer, not a placeholder. The current VaultChainMVP contract
 * (0xfe76…7452) emits:
 *
 *   event PhotoRegistered(
 *     address indexed user,
 *     bytes32 indexed contentHash,
 *     string encryptedTxId
 *   )
 *
 * From which:
 *
 *   - "Photos kept"   → derivable by counting PhotoRegistered events.
 *                       Requires eth_getLogs over the full history
 *                       (from the deployment block) — costly on the
 *                       client, unreliable without an indexer.
 *
 *   - "Spaces opened" → derivable by counting unique `user` values
 *                       across those events. Same constraint.
 *
 *   - "Data stored"   → NOT derivable. The event carries no size.
 *                       No view function exposes per-file size.
 *
 *   - "Photos shared" → NOT derivable. The contract has no concept
 *                       of shares. The event emits ownership, not
 *                       sharing.
 *
 * The new modular contracts (kipio_economics, kipio_identity_content,
 * kipio_runtime, …) are deployed on Sepolia but inactive pending the
 * Arbitrum Stylus activation pause. When they go live and emit size +
 * share events, this hook will read them through a dedicated indexer
 * or view function. Until then:
 *
 *   - the hook returns nulls;
 *   - consumers render "—" (design system rule: never show a fake
 *     number);
 *   - no numeric values are ever hardcoded here.
 *
 * Server vs. client
 *   No `"use client"` today. The hook is a plain function that returns
 *   a constant object; it is safe to call from a Server Component
 *   (LiveStats stays server-rendered).
 *
 *   Migration path when the indexer lands:
 *     1. this file becomes a `useQuery` (from @tanstack/react-query);
 *     2. `"use client"` is added to this file;
 *     3. LiveStats becomes a small client island (consumers do not
 *        change — the return shape is preserved);
 *     4. `QueryClientProvider` is already mounted in Web3Provider
 *        (verified), so no provider plumbing is required.
 *
 * Consumers
 *   - `components/landing/live-stats.tsx` (Fase 5).
 *   - Future: dashboard `(app)/home`, explorer view, protocol analytics
 *     page. Same return shape across all.
 */

export type ProtocolStats = {
  /** Total photos registered across all vaults (contract events). */
  photosKept: number | null;
  /** Distinct `user` addresses that have ever registered a photo. */
  spacesOpened: number | null;
  /** Total bytes stored, expressed in gigabytes. */
  dataStoredGb: number | null;
  /** Total number of photos currently shared with at least one link. */
  photosShared: number | null;
};

export function useStats(): ProtocolStats {
  // TODO (Fase 11+): replace with a useQuery against the protocol
  // indexer once the new modular contracts are active and emitting
  // size + share events. The shape of this function is intentionally
  // stable — consumers will not need to change.
  return {
    photosKept: null,
    spacesOpened: null,
    dataStoredGb: null,
    photosShared: null,
  };
}
