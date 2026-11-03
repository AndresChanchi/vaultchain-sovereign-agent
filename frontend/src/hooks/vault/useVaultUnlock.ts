"use client";

/**
 * Vault unlock — the "open the space" trigger.
 *
 * Two behaviours, chosen by session kind:
 *
 *   - OAuth session → auto-unlock on mount. `WalletContext.signTypedData`
 *     signs locally with the ephemeral key, no popup, no prompt. The
 *     user never sees an unlock button; the space just appears.
 *
 *   - Wallet session → manual unlock. The user clicks a button
 *     ("Unlock space"); the click triggers `unlockVault()`, which
 *     routes to `eth_signTypedData_v4`. The wallet shows its own
 *     approval UI. This matches the user's mental model — wallets
 *     sign things, and the popup is the confirmation.
 *
 *   - Ledger session → `signTypedData` throws `unsupported`. The
 *     error surfaces to the UI, which offers a retry (same path, same
 *     error). Until the DMK signer is exposed (Fase 10), the honest
 *     outcome is "Ledger users cannot unlock the new space yet".
 *
 * Why not auto-unlock for wallets
 *   A signature popup appearing unprompted, right after landing on a
 *   page, is jarring and might be mistaken for phishing. Wallets get
 *   an explicit click → popup. OAuth signs silently (no popup), so
 *   the auto-attempt is invisible — the difference in behaviour maps
 *   directly to the difference in capability.
 *
 * One-shot auto-attempt
 *   `autoAttemptedRef` ensures the OAuth auto-unlock does not loop.
 *   If the auto-attempt fails (ephemeral key missing — edge case),
 *   the caller can call `unlock()` again via a retry button.
 *
 * Reset on session change
 *   `autoAttemptedRef` resets when `session.address` changes. A user
 *   who signs out and signs in with a different wallet (or OAuth
 *   identity) gets a fresh auto-attempt for their new session.
 *
 * Worker gate
 *   The auto-attempt waits for `workerReady` before running.
 *   `unlockVault` itself does not need the worker (key derivation
 *   happens on the main thread via `deriveKeyFromSignature`), but
 *   the tile's `decryptFile` does — the worker must be ready before
 *   `isLocked` flips to false, otherwise the tiles throw
 *   `VAULT_LOCKED` from the worker guard even though the key is
 *   present.
 */
import { useCallback, useEffect, useRef, useState } from "react";
import { useKipioCrypto } from "@hooks/useKipioCrypto";
import { useWallet } from "@context/WalletContext";

export type VaultUnlockState = {
  /** True until the master key is derived. */
  isLocked: boolean;
  /** True while a signature / derivation is in flight. */
  isUnlocking: boolean;
  /** Set when the last attempt failed. Retry via `unlock()`. */
  error: unknown | null;
  /**
   * Manual unlock — for wallet sessions (button click) and for retry
   * paths (any session kind after an error). For OAuth sessions this
   * is also callable as a "retry" when the auto-attempt fails.
   */
  unlock: () => void;
};

export function useVaultUnlock(): VaultUnlockState {
  const { session } = useWallet();
  const { isLocked, isUnlocking, workerReady, unlockVault } =
    useKipioCrypto();
  const [error, setError] = useState<unknown | null>(null);
  const autoAttemptedRef = useRef(false);

  // Reset the auto-attempt flag when the session identity changes.
  // A different wallet or OAuth identity is a different vault; the
  // new session deserves its own auto-attempt (if OAuth).
  useEffect(() => {
    autoAttemptedRef.current = false;
    setError(null);
  }, [session?.address]);

  // OAuth auto-unlock. Wallet sessions stay locked until the user
  // clicks (see "Why not auto-unlock for wallets" in the header).
  useEffect(() => {
    if (session?.kind !== "oauth") return;
    if (!isLocked) return;
    if (!workerReady) return;
    if (autoAttemptedRef.current) return;

    autoAttemptedRef.current = true;
    unlockVault().catch((e) => {
      // Silent — the UI shows an unlock button when `error` is set.
      setError(e);
    });
  }, [session, isLocked, workerReady, unlockVault]);

  const unlock = useCallback(() => {
    setError(null);
    unlockVault().catch((e) => setError(e));
  }, [unlockVault]);

  return { isLocked, isUnlocking, error, unlock };
}
