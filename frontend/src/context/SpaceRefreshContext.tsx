"use client";

/**
 * Space refresh — a version counter that any data-consuming hook can
 * watch to re-fetch on demand.
 *
 * The problem
 *   `/space` reads contract state (photo count, gallery hashes) via
 *   viem. After an upload completes in the future (Fase 10), the
 *   contract state changes — but nothing tells the reading hooks to
 *   re-run. The current MVP's dashboard has a manual "Refresh" button
 *   for exactly this reason, and the user explicitly wants to avoid
 *   that pattern.
 *
 * The solution
 *   A single `version` counter in context. Any hook that reads
 *   contract state includes `version` in its `useEffect` deps. When
 *   the upload flow completes, it calls `bump()`. Every dependent
 *   hook re-runs its read; the UI updates without a manual reload.
 *
 *   Today only two consumers exist — `useSpaceStats` and
 *   `useSpaceGallery` — but the pattern is designed for Fase 10+
 *   (activity feed, moments, offers). Each new reactive surface adds
 *   `version` to its read deps; no coordination between them.
 *
 * Why not CustomEvent
 *   `window.dispatchEvent(new CustomEvent("kipio:space:refresh"))`
 *   works, but loses TypeScript — the event name and payload are
 *   strings, and every listener would need to re-import the
 *   constant. A context value is typed, tree-shakeable and does not
 *   collide with any native event.
 *
 * Why not TanStack Query invalidation
 *   `@tanstack/react-query` is already in the stack (used by
 *   `useUploadQuote`), but the query-cache pattern is overkill for
 *   two one-shot reads. Query adds cache, retries, prefetch,
 *   deduplication — none of which this flow needs. When the surface
 *   grows to 5+ reactive reads with cross-component sharing, migrate
 *   to Query then. The `version` contract survives the migration
 *   (it becomes a `queryKey` segment).
 *
 * Consumer contract
 *   ```ts
 *   const { version } = useSpaceRefresh();
 *   useEffect(() => {
 *     // ... fetch
 *   }, [version, address, chainId]);
 *   ```
 *
 * Emitter contract
 *   ```ts
 *   const { bump } = useSpaceRefresh();
 *   await uploadComplete();
 *   bump();  // triggers every listener's re-fetch
 *   ```
 *
 * Placement
 *   Mounted inside `(app)/layout.tsx` — the counter resets when
 *   leaving the authenticated shell. A `bump()` fired on `/space`
 *   does not reach any data hooks on `/library` (they unmount first
 *   anyway), and vice versa. Session-scoped, matching the data's
 *   lifetime.
 */

import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useState,
  type ReactNode,
} from "react";

type SpaceRefreshContextValue = {
  /**
   * Increments on every `bump()`. Hooks include this in their
   * `useEffect` deps to re-fetch.
   */
  version: number;
  /** Signal that the underlying contract state has changed. */
  bump: () => void;
};

const SpaceRefreshContext = createContext<SpaceRefreshContextValue | null>(
  null,
);

export function SpaceRefreshProvider({ children }: { children: ReactNode }) {
  const [version, setVersion] = useState(0);
  const bump = useCallback(() => setVersion((v) => v + 1), []);
  const value = useMemo<SpaceRefreshContextValue>(
    () => ({ version, bump }),
    [version, bump],
  );
  return (
    <SpaceRefreshContext.Provider value={value}>
      {children}
    </SpaceRefreshContext.Provider>
  );
}

export function useSpaceRefresh(): SpaceRefreshContextValue {
  const ctx = useContext(SpaceRefreshContext);
  if (ctx === null) {
    throw new Error(
      "useSpaceRefresh must be used inside <SpaceRefreshProvider>.",
    );
  }
  return ctx;
}
