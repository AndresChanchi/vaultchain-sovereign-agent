/**
 * EIP-6963 wallet discovery.
 *
 * Wallets that implement EIP-6963 announce themselves via a DOM
 * CustomEvent (`eip6963:announceProvider`). A listener that wants the
 * current set dispatches `eip6963:requestProvider` and each wallet
 * re-announces. This is the standard way to discover injected wallets
 * without fighting over `window.ethereum` — the "last one wins"
 * problem that plagued EIP-1193-only discovery.
 *
 * `mipd` is a ~5 KB library that wraps this protocol. We use it
 * because it is framework-agnostic and it exposes a stable,
 * subscribe-able store. Reference:
 * https://eips.ethereum.org/EIPS/eip-6963
 *
 * Why not wagmi's `multiInjectedProviderDiscovery`?
 *   - Wagmi couples discovery to its own config and hooks. The login
 *     surface must work with zero wagmi dependency: the legacy
 *     dashboard keeps wagmi, the login is the entry point for
 *     non-crypto users and should not pay for the entire stack.
 *   - `mipd` is 5 KB. Wagmi's discovery pulls in the viem chain
 *     config through wagmi core.
 *
 * `mipd` API notes (v0.0.7)
 *   `createStore()` takes **no arguments**. The store listens on
 *   `window` by default and dispatches `eip6963:requestProvider`
 *   synchronously on creation, so wallets that were installed before
 *   this module loaded re-announce immediately. The first `subscribe`
 *   call with `{ emitImmediately: true }` receives the full set as
 *   its first emission — that is what initialises `current`.
 *   Reference: https://github.com/wevm/mipd
 *
 * Singleton pattern
 *   `mipd`'s `createStore()` is designed to be created once per page.
 *   Creating a new store on every render (or every component mount)
 *   would re-scan all wallets each time. We memoize the store in
 *   module scope and expose a single subscription API. Consumers use
 *   `subscribeDiscovery()` inside `useEffect` (or via
 *   `useSyncExternalStore`) — the store handles the rest.
 *
 * SSR safety
 *   `ensureStore()` returns early if `window` is undefined. This file
 *   can be imported from anywhere; only calls made after mount do
 *   anything. The empty result is a valid "no wallets yet" state,
 *   not an error. `EMPTY_DISCOVERY` is a stable frozen reference so
 *   `useSyncExternalStore`'s `getServerSnapshot` can return it
 *   without triggering React's "getSnapshot should be cached"
 *   warning.
 *
 * Why Ledger is NOT part of discovery
 *   Ledger is a hardware device, not an injected provider. It is
 *   connected via DMK (`lib/ledger/connector.ts`), not via 6963. The
 *   Ledger row in the wallet list is rendered separately by the UI —
 *   this module returns only injected wallets. If Ledger Live
 *   extension announces via 6963 (rdns `com.ledger`), we still route
 *   clicks through DMK, so we do not recognise that rdns in
 *   `KNOWN_WALLETS`.
 *
 * What `"injected"` means
 *   A discovered wallet whose RDNS is not in `KNOWN_WALLETS` gets
 *   `id: "injected"`. It *is* an injected provider — we simply do not
 *   have a brand slot for it (Phantom, Trust, Coinbase Wallet, …).
 *   The word is honest: it names the category, not a brand. It is
 *   not an error, and it is not the same concept as
 *   `WalletError.code === "unknown"` (which really does mean "no
 *   idea what went wrong").
 *
 *   When a wallet becomes relevant enough to have a stable brand,
 *   move its rdns from "not in KNOWN_WALLETS" to an entry in
 *   `KNOWN_WALLETS` and add the brand name to the dictionary. Nothing
 *   else in the app changes.
 *
 * Adding a known wallet
 *   Append to `KNOWN_WALLETS`. Order matters: it is the order in
 *   which the UI renders known wallets when more than one is
 *   detected. `rdns` is the wallet's reverse-DNS identifier, unique
 *   per extension and stable across versions.
 *
 * The UI contract (informative, not enforced here)
 *   For each entry in `KNOWN_WALLETS`, the wallet list shows a row.
 *   The row renders `wallet.detected` (from a `getWalletById`
 *   lookup) as a "Detected" badge, or `wallet.install` as an
 *   "Install" badge when the wallet has not announced. Injected
 *   wallets without a brand slot appear under "More wallets" — the
 *   UI filters `getDiscoveredWallets()` for `id: "injected"` and
 *   renders them in a `<dialog>`.
 */

import { createStore, type EIP6963ProviderDetail } from "mipd";

/**
 * Stable identifier for a wallet. Known wallets have a fixed id;
 * anything that announces via 6963 but is not in `KNOWN_WALLETS` gets
 * `id: "injected"` — an injected provider whose brand is not in our
 * catalogue. Shown grouped under "More wallets".
 */
export type WalletId = "metamask" | "brave" | "rabby" | "injected";

export type KnownWallet = {
  /**
   * `Exclude<WalletId, "injected">` — a known wallet must have a
   * brand. The `"injected"` id is the generic slot for wallets we do
   * not recognise; it never has a fixed `KNOWN_WALLETS` entry, so
   * this type makes the invariant explicit.
   */
  id: Exclude<WalletId, "injected">;
  /** EIP-6963 reverse-DNS identifier. */
  rdns: string;
  /** Where to send the user when the wallet is not detected. */
  installUrl: string;
};

/**
 * Wallets we recognise by their RDNS. Adding a wallet here is what
 * makes its name, brand and install URL stable — an injected wallet
 * that announces via 6963 without a matching entry still appears
 * (under `id: "injected"`) but we do not know where to send a user
 * to install it.
 */
export const KNOWN_WALLETS: readonly KnownWallet[] = [
  {
    id: "metamask",
    rdns: "io.metamask",
    installUrl: "https://metamask.io/download/",
  },
  {
    id: "brave",
    rdns: "com.brave.wallet",
    installUrl: "https://brave.com/wallet/",
  },
  {
    id: "rabby",
    rdns: "io.rabby",
    installUrl: "https://rabby.io/",
  },
] as const;

export type DiscoveredWallet = {
  id: WalletId;
  rdns: string;
  /**
   * Name as announced by the wallet. Use the dictionary for known
   * brands; fall back to this for injected wallets without a brand
   * slot.
   */
  name: string;
  /** Data URI (SVG or PNG). Safe to render directly in `<img src>`. */
  icon: string;
  /**
   * The EIP-1193 provider instance. Call `provider.request({...})`
   * to talk to the wallet.
   */
  provider: EIP6963ProviderDetail["provider"];
};

/**
 * Frozen empty snapshot. Use this as `getServerSnapshot` in
 * `useSyncExternalStore` so React sees a stable reference during SSR
 * and hydration.
 */
export const EMPTY_DISCOVERY: readonly DiscoveredWallet[] = Object.freeze([]);

type DiscoveryListener = (wallets: readonly DiscoveredWallet[]) => void;

let store: ReturnType<typeof createStore> | null = null;
const listeners = new Set<DiscoveryListener>();
let current: readonly DiscoveredWallet[] = EMPTY_DISCOVERY;

function ensureStore(): void {
  if (store !== null) return;
  if (typeof window === "undefined") return;

  store = createStore();

  // `emitImmediately: true` delivers the current snapshot as the
  // first emission. Wallets that were present before this module
  // loaded have already re-announced synchronously inside
  // `createStore()` (it dispatches `eip6963:requestProvider` on
  // window). Without this flag, `current` would stay empty until the
  // next late announcement, and `getWalletById` would return
  // `undefined` for a wallet that is actually installed.
  store.subscribe(
    (details) => {
      current = Object.freeze(details.map(toDiscoveredWallet));
      for (const listener of listeners) {
        listener(current);
      }
    },
    { emitImmediately: true },
  );
}

function toDiscoveredWallet(
  detail: EIP6963ProviderDetail,
): DiscoveredWallet {
  const known = KNOWN_WALLETS.find((w) => w.rdns === detail.info.rdns);
  return {
    id: known?.id ?? "injected",
    rdns: detail.info.rdns,
    name: detail.info.name,
    icon: detail.info.icon,
    provider: detail.provider,
  };
}

/**
 * Subscribe to the current set of EIP-6963 wallets.
 *
 * The listener is invoked synchronously on subscription with the
 * current snapshot, then again on every change (wallet installed,
 * wallet removed, wallet announced after the fact). Returns an
 * unsubscribe function — always call it in `useEffect` cleanup or
 * pass it to `useSyncExternalStore`.
 *
 * SSR-safe: no-ops when `window` is undefined, and the first
 * emission is the frozen `EMPTY_DISCOVERY` array. This is a valid
 * "no wallets yet" state, not an error.
 */
export function subscribeDiscovery(
  listener: DiscoveryListener,
): () => void {
  ensureStore();
  listeners.add(listener);
  listener(current);
  return () => {
    listeners.delete(listener);
  };
}

/**
 * Read the current set of discovered wallets without subscribing.
 * Useful for event handlers that need a snapshot but do not need to
 * re-render on change.
 *
 * Calls `ensureStore()` so the first read after a page load
 * discovers wallets that were already installed — otherwise this
 * would return `EMPTY_DISCOVERY` until some other code subscribed.
 */
export function getDiscoveredWallets(): readonly DiscoveredWallet[] {
  ensureStore();
  return current;
}

/**
 * Look up a discovered wallet by its stable id. Returns `undefined`
 * if the wallet has not announced (the "Install" state). Also calls
 * `ensureStore()` for the same reason as `getDiscoveredWallets`.
 *
 * The parameter type is `WalletId` so callers using `WalletKind`
 * (which includes `"injected"` after the rename) do not need a cast.
 * **But `getWalletById("injected")` is not useful as a lookup** —
 * multiple injected wallets can share that id (they are the ones
 * without a brand slot). The call returns whichever one announced
 * first, which is arbitrary and could change between reloads. For
 * injected wallets, iterate `getDiscoveredWallets()` and filter on
 * `wallet.id === "injected"`.
 *
 * Resume-path note
 *   `WalletContext` resumes a persisted session by calling this with
 *   `session.wallet`. It already guards `session.wallet !== "ledger"`
 *   before the call. It must ALSO guard `session.wallet !== "injected"`
 *   in the next turn — resuming an `"injected"` session cannot rely
 *   on this function returning the same wallet that created the
 *   session (there is no stable id to key on). The next signing
 *   operation re-establishes the provider, exactly as for Ledger.
 *   See `WalletContext.tsx` ("Resume — auto-acquiring the provider").
 */
export function getWalletById(
  id: WalletId,
): DiscoveredWallet | undefined {
  ensureStore();
  return current.find((w) => w.id === id);
}
