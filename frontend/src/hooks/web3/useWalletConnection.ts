"use client";

/**
 * Wallet connection — the single entry point for "connect a wallet".
 *
 * Wraps `WalletContext.connect` with:
 *   - EIP-6963 lookup for branded wallets (`getWalletById`),
 *   - the Ledger DMK adapter (`lib/wallet/ledger.ts`) for hardware,
 *   - error normalization (`normalizeWalletError`) so every throw site
 *     produces a `WalletError`, never a raw provider error,
 *   - a `busy` flag keyed on the exact UI row being connected (so two
 *     Ledger rows — physical and Speculos — do not both spin),
 *   - an `error` state the caller can render without its own try/catch.
 *
 * Why a hook and not just `useWallet().connect`
 *   `useWallet().connect` takes an `EIP1193Provider` and a
 *   `WalletKind`. Multiple call sites were duplicating the same
 *   preamble:
 *
 *     const discovered = getWalletById(id);
 *     if (!discovered) throw noProviderError(id);
 *     try { await connect(discovered.provider, id); }
 *     catch (e) { onError(normalizeWalletError(e)); }
 *
 *   `wallet-list.tsx` did it inline. The hero (Fase 10) and any future
 *   "switch wallet" surface would repeat it. Moving the preamble into
 *   one hook keeps the error shape and the busy semantics consistent
 *   across surfaces.
 *
 * Error semantics
 *   Every `connect*` function rejects with a `WalletError` (never a
 *   raw provider error) **and** sets it on `error`. The caller can
 *   choose:
 *     - `await connectInjected(id)` and handle the reject, or
 *     - read `error` from the hook and render it.
 *   Both work. The reject is there so a future `await` chain
 *   (hero → upload flow) can branch on the error code without a
 *   second state read. The `error` state is there so presentational
 *   components (`wallet-list.tsx`) do not need try/catch.
 *
 *   `error.cancelled === true` is not filtered out by the hook — the
 *   consumer decides. `LoginPanel` already filters cancelled errors
 *   out of the visible banner. Filtering in the hook would hide the
 *   information from a caller that wants to log "user cancelled"
 *   separately.
 *
 * `busy` key
 *   `busy` holds the **row identifier**, not the wallet kind. Possible
 *   values, mapped to where they come from:
 *
 *     - `"metamask" | "brave" | "rabby"` — from `connectInjected`.
 *       The row id equals the branded kind.
 *     - `"physical" | "speculos"` — from `connectLedgerDevice`.
 *       The key equals the transport so the two Ledger rows (if the
 *       Speculos row were enabled) spin independently.
 *     - `"injected"` — from `connectProvider` called with
 *       `kind: "injected"` (the "More wallets" dialog). The dialog
 *       does not render per-row spinners, so any stable string
 *       would do; `"injected"` is the honest one.
 *     - `"ledger"` — possible from `connectProvider` if a caller ever
 *       passes `kind: "ledger"` directly. No caller does today (the
 *       hardware path goes through `connectLedgerDevice`, which
 *       uses the transport as key). Still a valid type.
 *
 * Ledger adapter
 *   `connectLedgerDevice` calls `connectLedger` (the adapter in
 *   `lib/wallet/ledger.ts`) before `connect`. The adapter itself is
 *   slow (DMK discovery + device approval), so `busy` is set *before*
 *   the adapter call, not after — otherwise the button would stay
 *   visually idle during the device prompt. This is why the Ledger
 *   path does not funnel through `connectProvider`.
 *
 * Injected wallets not in `KNOWN_WALLETS`
 *   The "More wallets" dialog passes `kind: "injected"`. The session
 *   records `wallet: "injected"` — it *is* an injected provider, we
 *   just do not have a brand slot for it (Phantom, Trust, Coinbase
 *   Wallet, …). `WalletContext.validateSession` accepts `"injected"`
 *   (see the `WalletKind` union). When the brand becomes relevant for
 *   display, add `walletName?: string` to `WalletSession` and
 *   populate it from `DiscoveredWallet.name` here.
 *
 * What this hook does NOT do
 *   - Open the login modal. Callers call `openLogin()` from
 *     `LoginModalContext` themselves.
 *   - Redirect. Callers decide where to go after `connect` resolves.
 *   - Persist anything. `WalletContext.connect` owns persistence.
 *   - Listen for account/chain changes. `WalletContext` owns the
 *     listeners. The hook is the "connect now" path, not the "watch"
 *     path.
 */

import { useCallback, useState } from "react";
import {
  useWallet,
  type WalletKind,
  type WalletSession,
} from "@context/WalletContext";
import { getWalletById } from "@lib/wallet/discovery";
import {
  connectLedger as connectLedgerAdapter,
  type LedgerTransport,
} from "@lib/wallet/ledger";
import {
  noProviderError,
  normalizeWalletError,
  type WalletError,
} from "@lib/wallet/errors";
import type { EIP1193Provider } from "viem";

/**
 * Branded kinds that can be connected by id. `"ledger"` is hardware
 * (see `connectLedgerDevice`) and `"injected"` names the generic
 * category (multiple wallets share it — look the specific one up via
 * `getDiscoveredWallets` and pass its provider to `connectProvider`).
 */
export type BrandedWalletKind = Exclude<WalletKind, "ledger" | "injected">;

/** Any key that can appear in `busy` while a connect is in progress. */
export type ConnectBusyKey = WalletKind | LedgerTransport;

export type UseWalletConnectionResult = {
  /**
   * Connect a branded EIP-6963 wallet by its stable id. Accepts
   * `"metamask" | "brave" | "rabby"` — not `"ledger"` (hardware,
   * use `connectLedgerDevice`) and not `"injected"` (multiple
   * wallets share that id; use `connectProvider` with the
   * discovered wallet's provider).
   */
  connectInjected: (id: BrandedWalletKind) => Promise<WalletSession>;
  /** Connect a Ledger device over the given transport. */
  connectLedgerDevice: (transport: LedgerTransport) => Promise<WalletSession>;
  /**
   * Connect a provider directly. Used by the "More wallets" dialog
   * for wallets not in `KNOWN_WALLETS` (pass `kind: "injected"`), and
   * by any future surface that already holds a provider.
   */
  connectProvider: (
    provider: EIP1193Provider,
    kind: WalletKind,
    busyKey?: ConnectBusyKey,
  ) => Promise<WalletSession>;
  /** The row identifier currently being connected, or `null`. */
  busy: ConnectBusyKey | null;
  /** The last connection error, or `null`. */
  error: WalletError | null;
  /** Clear the error without connecting. */
  clearError: () => void;
};

export function useWalletConnection(): UseWalletConnectionResult {
  const { connect } = useWallet();
  const [busy, setBusy] = useState<ConnectBusyKey | null>(null);
  const [error, setError] = useState<WalletError | null>(null);

  const clearError = useCallback(() => setError(null), []);

  const connectProvider = useCallback(
    async (
      provider: EIP1193Provider,
      kind: WalletKind,
      busyKey: ConnectBusyKey = kind,
    ): Promise<WalletSession> => {
      setBusy(busyKey);
      setError(null);
      try {
        return await connect(provider, kind);
      } catch (raw) {
        const normalized = normalizeWalletError(raw);
        setError(normalized);
        throw normalized;
      } finally {
        setBusy(null);
      }
    },
    [connect],
  );

  const connectInjected = useCallback(
    async (id: BrandedWalletKind): Promise<WalletSession> => {
      const discovered = getWalletById(id);
      if (!discovered) {
        const notDetected = noProviderError(id);
        setError(notDetected);
        throw notDetected;
      }
      return connectProvider(discovered.provider, id, id);
    },
    [connectProvider],
  );

  const connectLedgerDevice = useCallback(
    async (transport: LedgerTransport): Promise<WalletSession> => {
      setBusy(transport);
      setError(null);
      try {
        const { provider } = await connectLedgerAdapter(transport);
        return await connect(provider, "ledger");
      } catch (raw) {
        const normalized = normalizeWalletError(raw);
        setError(normalized);
        throw normalized;
      } finally {
        setBusy(null);
      }
    },
    [connect],
  );

  return {
    connectInjected,
    connectLedgerDevice,
    connectProvider,
    busy,
    error,
    clearError,
  };
}
