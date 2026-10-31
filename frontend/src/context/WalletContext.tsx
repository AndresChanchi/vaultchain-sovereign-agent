"use client";

/**
 * Wallet session — state, persistence, provider listeners.
 *
 * This context owns one thing: the session. A session is the
 * historical fact that "at some point, this identity proved itself
 * (with this wallet, or with this OAuth provider)". It is *not* a
 * live connection — the wallet extension can be uninstalled, the
 * OAuth token can expire, and the session remains a valid identifier
 * for the UI until the user signs out or closes the tab.
 *
 * Divisions of responsibility
 *   - Discovery of which wallets exist  → `lib/wallet/discovery.ts`
 *   - Acquisition of the provider and
 *     the wallet connection ceremony    → `hooks/web3/useWalletConnection.ts`
 *   - OAuth ceremony (redirect + PKCE)  → `hooks/web3/useOAuthLogin.ts`
 *   - Session, persistence, listeners   → THIS FILE
 *   - Modal open/close, return-to       → `LoginModalContext`
 *
 * Keeping the session separate from the connection hooks is what
 * lets the navbar show "Signed in as 0xabc…" on page reload without
 * re-prompting the wallet. The hooks run ceremonies; the context
 * remembers the outcome.
 *
 * Session shape — discriminated union with two variants
 *
 *     { kind: "wallet"; wallet; address; chainId; … }
 *     { kind: "oauth";  provider; subject?; address; chainId;
 *       walletSource; … }
 *
 *   Both variants carry an `address` and a `chainId`. The provenance
 *   differs:
 *
 *   - Wallet session: address owned by the wallet extension, private
 *     key never touches the page. Real EOA. Can sign today. The
 *     `wallet` field distinguishes the brand slot: `"metamask"`,
 *     `"brave"`, `"rabby"` (known brands), `"ledger"` (hardware),
 *     and `"injected"` (an EIP-6963 provider whose brand is not in
 *     `KNOWN_WALLETS` — Phantom, Trust, Coinbase Wallet, …). See
 *     "Resume — auto-acquiring the provider" for why `"injected"`
 *     does not re-attach a provider on reload.
 *
 *   - OAuth session: address is *ephemeral* until the contract layer
 *     derives the real CREATE2 address. The frontend generates a
 *     local keypair (`viem/accounts`), stores it in `sessionStorage`
 *     for the lifetime of the tab, and uses it for demo uploads on
 *     Sepolia. When `kipio_execution_gateway` activates
 *     (`kipio_account` derives the CREATE2 address), `setOAuthAddress`
 *     replaces the ephemeral address and clears the key.
 *
 *   `subject` is the OIDC `sub` claim from the ID token. It is the
 *   correlation key the contract layer will use to map the OAuth
 *   identity to a deterministic CREATE2 address (Fase 9+). It is
 *   optional because:
 *     - X (Twitter) does not return an `id_token` for the scopes we
 *       request, so no `sub` exists for that provider.
 *     - Providers that require a serverless relay (GitHub, Apple,
 *       Twitch) will populate it once the relay lands; today the
 *       ceremony for those providers is reported as
 *       `relay_required`, and no session is created.
 *   It is *persisted in the session*, not in a parallel
 *   `sessionStorage` key, so a single `disconnect()` clears it and
 *   the contract layer reads it from the same place it reads the
 *   address.
 *
 * Why the ephemeral wallet is honest, not a lie
 *   The alternative — an OAuth session with no `address` — forces
 *   every consumer to branch on `session.kind === "oauth"` before
 *   rendering an address, a balance, or anything space-shaped. That
 *   is worse: it makes the "explorer" (the user who logs in with
 *   Google without uploading anything) look like a second-class
 *   citizen in the UI. The ephemeral wallet gives them a real,
 *   signable EVM address today. That it is not the final identity is
 *   a detail the UI does not need to expose until the user tries to
 *   upload something (Fase 10), where the upload flow surfaces
 *   "funding this demo address" as an explicit, honest step.
 *
 *   `walletSource: "ephemeral" | "create2"` is the discriminant the
 *   UI uses to decide whether to show "demo" hints. `"create2"`
 *   appears only after the contract layer runs; it is not settable
 *   by the user.
 *
 * Why the ephemeral key is persisted in `sessionStorage`
 *   The alternative — memory only — breaks resume: a tab reload
 *   would lose the key while keeping the address, and the next
 *   upload would fail without a clear reason. The demo has no real
 *   funds (testnet ETH only), the key never leaves the origin, and
 *   the tab closes it. This is the demo tradeoff. When the contract
 *   layer lands, `setOAuthAddress` wipes the key immediately. Do
 *   NOT extend this pattern to production identity — the CREATE2
 *   path is the production answer.
 *
 *   Key: `kipio:wallet:ephemeral`. Separate from the session key so
 *   a `disconnect()` can clear both in one place and a future
 *   migration can clear one without touching the other.
 *
 * Persistence — why sessionStorage
 *   `localStorage` would persist across tabs and days; a user could
 *   return a week later and see themselves as "connected" to a wallet
 *   they never re-authorized. `sessionStorage` dies with the tab.
 *   No cookie, no server, no telemetry. Fleek-safe (`output:
 *   'export'` untouched because nothing server-side is involved).
 *
 *   Key: `kipio:wallet:session`. Values are the JSON-serialised
 *   `Session`.
 *
 * Validation on read
 *   `sessionStorage` is user-writable. Every read passes through
 *   `validateSession`, which rejects:
 *     - unknown `kind`
 *     - malformed address (via `getAddress`)
 *     - non-integer, non-positive `chainId`
 *     - unknown `wallet` kinds / `oauth` providers
 *     - unknown `walletSource`
 *     - non-finite `authenticatedAt`
 *     - non-string `subject` on OAuth sessions (if present)
 *   A tampered value degrades to `null` (disconnected). No path where
 *   a malformed value reaches the app.
 *
 * Provider listeners
 *   Wallet sessions only. OAuth sessions have no provider to listen
 *   to. For wallet sessions, `accountsChanged` and `chainChanged`
 *   keep the session in sync. Zero accounts (revoked access in the
 *   extension) → full disconnect, same as clicking "Log out".
 *
 *   viem's `EIP1193Provider` type declares both events with their
 *   correct signatures. We use the type directly; do NOT intersect
 *   it with a looser `(event: string, ...args: unknown[]) => void`
 *   shape — the signatures become incompatible and TypeScript
 *   produces `never` for `on`, which surfaces as "provider is not
 *   assignable" when assigning a discovered wallet's provider.
 *
 *   Cleanup captures `on` and `removeListener` in local consts after
 *   the runtime guard, so the returned cleanup closure has both
 *   narrowed. No non-null assertions needed.
 *
 *   Attach and detach are wrapped in try/catch
 *     MetaMask 11.x can throw from inside `provider.on(...)` when
 *     the EIP-6963 provider has announced itself *before* the
 *     extension finished initialising its internal event emitter.
 *     The stack trace points at the wallet's own `inpage.js`
 *     (`_warnOfDeprecation` undefined at call time), not at Kipio
 *     code. Reproduced in dev and in production builds; also seen
 *     with a few forks of MetaMask's codebase.
 *
 *     The session remains valid in that case — the address and
 *     chainId are correct — we simply lose live sync for that
 *     wallet. The next signing operation re-establishes the
 *     provider through `useWalletConnection`, which is the correct
 *     surface for a provider that is not ready yet.
 *
 *     `removeListener` gets the same treatment: a wallet can also
 *     throw from `removeListener` if it has already torn down its
 *     emitter (extension reloaded, device disconnected, page
 *     navigation). The cleanup is best-effort.
 *
 * Resume — auto-acquiring the provider
 *   On mount, after restoring a *wallet* session, we try to look up
 *   the provider via `getWalletById(session.wallet)`. If found, it
 *   is stored in `providerRef` so listeners attach on the next
 *   effect pass.
 *
 *   Two kinds are excluded from this lookup:
 *
 *     - `"ledger"`: the provider comes from DMK
 *       (`lib/ledger/connector.ts`), not from `mipd`. A resumed
 *       Ledger session has no provider until `useWalletConnection`
 *       re-establishes the DMK session on the next signing
 *       operation.
 *
 *     - `"injected"`: `getWalletById("injected")` returns whichever
 *       injected wallet announced *first*, which is arbitrary and
 *       can change between reloads (see `lib/wallet/discovery.ts`,
 *       `getWalletById`). Attaching listeners to that provider would
 *       mean watching a wallet the user did not connect with. The
 *       next signing operation re-establishes the provider, exactly
 *       as for Ledger.
 *
 *   For both excluded kinds, the session remains a valid identifier
 *   (address, chainId) — only the live provider is absent. When
 *   `walletName` is added to `WalletSession` (see the TODO at the
 *   end of this header), `"injected"` sessions can resume by
 *   matching the name against `getDiscoveredWallets()`.
 *
 *   OAuth sessions skip this step entirely — no provider exists.
 *   The ephemeral key (if any) is restored separately.
 *
 *   Note on listener attach timing: the resume effect sets
 *   `setSession` and `setStatus("connected")`, but the listener
 *   effect runs on the *next* render. An `accountsChanged` fired in
 *   between is missed. In practice this is harmless: the session
 *   already holds the address from storage, so the missed event
 *   would have set the same value. Do NOT "fix" this by moving
 *   `setSession` inside the listener effect — that breaks restoration
 *   for wallets that never fire events after reload.
 *
 * `disconnect` semantics
 *   Clears the local session, the provider reference, the ephemeral
 *   key, and both `sessionStorage` entries. Does **not** call
 *   `wallet_revokePermissions` on the wallet (support is
 *   inconsistent, and a failed revoke should never block local
 *   logout). Does **not** call the OAuth provider's revocation
 *   endpoint — that is a network call owned by `useOAuthLogin`, and
 *   it must not block local logout either.
 *
 * `connect` / `connectOAuth` / `setOAuthAddress`
 *   `connect(provider, wallet)` — wallet session. Calls
 *   `eth_requestAccounts` and `eth_chainId`, normalises the address,
 *   persists. Returns the `WalletSession`. `wallet` may be any
 *   `WalletKind`, including `"injected"` for wallets without a
 *   brand slot.
 *
 *   `connectOAuth(provider, subject?)` — OAuth session. Generates an
 *   ephemeral keypair, persists both the key and the session, and
 *   includes `subject` when provided. The OAuth *ceremony* (redirect,
 *   PKCE, token exchange) lives in `useOAuthLogin`; by the time this
 *   method is called, the provider has already confirmed the user's
 *   identity. This method only records the result. `subject` is the
 *   OIDC `sub` claim (absent for X and for relay-only providers).
 *
 *   `setOAuthAddress(address, chainId)` — called by the contract
 *   layer once `kipio_account` derives the CREATE2 address. Replaces
 *   the ephemeral address in the session and clears the ephemeral
 *   key. No-op for wallet sessions. Documented as Fase 9+.
 *
 * TODO: when the route restructure (Fase 9) ships, nothing in this
 *       file moves — the session has no route knowledge.
 *
 * TODO: when the navbar needs to show the brand name of an
 *       `"injected"` wallet (e.g. "Phantom"), add
 *       `walletName?: string` to `WalletSession`, extend
 *       `connect(provider, wallet, walletName?)`, and pass
 *       `wallet.name` from `useWalletConnection.connectProvider`.
 *       Persisting `walletName` also enables resuming an
 *       `"injected"` session by matching against
 *       `getDiscoveredWallets()` — today the resume effect skips
 *       provider lookup for `"injected"` because there is no stable
 *       key to match on.
 */

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react";
import {
  getAddress,
  type Address,
  type EIP1193Provider,
} from "viem";
import { generatePrivateKey, privateKeyToAccount } from "viem/accounts";
import { getWalletById } from "@lib/wallet/discovery";
import { normalizeWalletError, type WalletError } from "@lib/wallet/errors";

/* ──────────────────────────────────────────────────────────────────
 * Types
 * ────────────────────────────────────────────────────────────────── */

export type WalletKind =
  | "metamask"
  | "brave"
  | "rabby"
  | "ledger"
  | "injected";

/**
 * OAuth providers shipped by the login surface. Mirrors
 * `login.social.*` in the dictionary. `github` and `apple` are
 * present even though their ceremonies need a serverless relay (see
 * Handoff v2.0 §3.4) — the session type does not distinguish them.
 */
export type OAuthProvider =
  | "google"
  | "x"
  | "microsoft"
  | "apple"
  | "github"
  | "twitch";

export type WalletSession = {
  kind: "wallet";
  /**
   * The wallet brand slot: a known brand (`"metamask"`,
   * `"brave"`, `"rabby"`), hardware (`"ledger"`), or the generic
   * injected slot (`"injected"`) for EIP-6963 providers whose brand
   * is not in `KNOWN_WALLETS`.
   */
  wallet: WalletKind;
  /** Checksummed EVM address (`getAddress` output). */
  address: `0x${string}`;
  chainId: number;
  /** Unix epoch ms, when `connect` succeeded. */
  authenticatedAt: number;
};

export type OAuthSession = {
  kind: "oauth";
  provider: OAuthProvider;
  /**
   * OIDC `sub` claim. Present when the provider returns an ID token
   * (Google, Microsoft). Absent for X and for relay-only providers
   * (GitHub, Apple, Twitch). Used by the contract layer to map the
   * OAuth identity to a CREATE2 address (Fase 9+).
   */
  subject?: string;
  /**
   * Checksummed EVM address. `"ephemeral"` today (locally generated
   * keypair); `"create2"` once `setOAuthAddress` replaces it with the
   * address derived by `kipio_account`.
   */
  address: `0x${string}`;
  chainId: number;
  /**
   * Provenance of `address`. The UI uses this to decide whether to
   * show "demo" hints on upload surfaces. `"create2"` is set only by
   * `setOAuthAddress`, never by the user.
   */
  walletSource: "ephemeral" | "create2";
  /** Unix epoch ms, when the OAuth ceremony completed. */
  authenticatedAt: number;
};

export type Session = WalletSession | OAuthSession;

/**
 * Three-state model so the UI can distinguish "still hydrating" from
 * "confirmed signed-out". Without `restoring`, a reload of a signed-in
 * page flashes the signed-out UI for one frame.
 */
export type WalletStatus = "restoring" | "connected" | "disconnected";

export type WalletContextValue = {
  /** The current session, or `null` when signed out. */
  session: Session | null;
  /** Distinguishes hydration from signed-out. */
  status: WalletStatus;
  /** Run the wallet connection ceremony. Rejects with `WalletError`. */
  connect: (
    provider: EIP1193Provider,
    wallet: WalletKind,
  ) => Promise<WalletSession>;
  /**
   * Persist an OAuth session with a freshly generated ephemeral
   * wallet. `subject` is the OIDC `sub` claim when the provider
   * returns one; omitted otherwise.
   */
  connectOAuth: (
    provider: OAuthProvider,
    subject?: string,
  ) => Promise<OAuthSession>;
  /**
   * Replace the OAuth session's ephemeral address with the CREATE2
   * address derived by the contract layer. No-op for wallet sessions.
   * Documented as Fase 9+.
   */
  setOAuthAddress: (address: `0x${string}`, chainId: number) => void;
  /** Clear the local session. Never throws. */
  disconnect: () => void;
};

/* ──────────────────────────────────────────────────────────────────
 * Persistence
 * ────────────────────────────────────────────────────────────────── */

const SESSION_KEY = "kipio:wallet:session";
const EPHEMERAL_KEY_KEY = "kipio:wallet:ephemeral";

/**
 * Default chain for the ephemeral wallet. Sepolia (421614) matches
 * `config/wagmi.ts` and the current contract deployment. When the
 * contract layer sets the CREATE2 address, `setOAuthAddress` supplies
 * the real chain id — do not hardcode elsewhere.
 */
const DEFAULT_CHAIN_ID = 421614;

const WALLET_KINDS: readonly WalletKind[] = [
  "metamask",
  "brave",
  "rabby",
  "ledger",
  "injected",
];

const OAUTH_PROVIDERS: readonly OAuthProvider[] = [
  "google",
  "x",
  "microsoft",
  "apple",
  "github",
  "twitch",
];

function isWalletKind(value: unknown): value is WalletKind {
  return (
    typeof value === "string" &&
    (WALLET_KINDS as readonly string[]).includes(value)
  );
}

function isOAuthProvider(value: unknown): value is OAuthProvider {
  return (
    typeof value === "string" &&
    (OAUTH_PROVIDERS as readonly string[]).includes(value)
  );
}

function walletError(
  code: WalletError["code"],
  rawMessage: string,
  cancelled = false,
): WalletError {
  return { code, rawMessage, cancelled };
}

function validateSession(value: unknown): Session | null {
  if (typeof value !== "object" || value === null) return null;
  const v = value as Record<string, unknown>;

  if (
    typeof v.authenticatedAt !== "number" ||
    !Number.isFinite(v.authenticatedAt)
  ) {
    return null;
  }

  if (v.kind === "wallet") {
    if (typeof v.address !== "string") return null;
    let address: `0x${string}`;
    try {
      address = getAddress(v.address);
    } catch {
      return null;
    }
    if (
      typeof v.chainId !== "number" ||
      !Number.isInteger(v.chainId) ||
      v.chainId <= 0
    ) {
      return null;
    }
    if (!isWalletKind(v.wallet)) return null;

    return {
      kind: "wallet",
      wallet: v.wallet,
      address,
      chainId: v.chainId,
      authenticatedAt: v.authenticatedAt,
    };
  }

  if (v.kind === "oauth") {
    if (!isOAuthProvider(v.provider)) return null;
    if (typeof v.address !== "string") return null;
    let address: `0x${string}`;
    try {
      address = getAddress(v.address);
    } catch {
      return null;
    }
    if (
      typeof v.chainId !== "number" ||
      !Number.isInteger(v.chainId) ||
      v.chainId <= 0
    ) {
      return null;
    }
    if (v.walletSource !== "ephemeral" && v.walletSource !== "create2") {
      return null;
    }
    // `subject` is optional. If present, must be a string.
    const subject =
      typeof v.subject === "string" ? v.subject : undefined;
    if (v.subject !== undefined && subject === undefined) {
      return null;
    }

    return {
      kind: "oauth",
      provider: v.provider,
      ...(subject !== undefined ? { subject } : {}),
      address,
      chainId: v.chainId,
      walletSource: v.walletSource,
      authenticatedAt: v.authenticatedAt,
    };
  }

  return null;
}

function readStoredSession(): Session | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = window.sessionStorage.getItem(SESSION_KEY);
    if (raw === null) return null;
    return validateSession(JSON.parse(raw));
  } catch {
    return null;
  }
}

function writeStoredSession(session: Session): void {
  if (typeof window === "undefined") return;
  try {
    window.sessionStorage.setItem(SESSION_KEY, JSON.stringify(session));
  } catch {
    // Private mode or storage disabled. Session lives in memory for
    // this tab's lifetime — acceptable. Do NOT throw: the caller
    // would have to undo a successful login.
  }
}

function clearStoredSession(): void {
  if (typeof window === "undefined") return;
  try {
    window.sessionStorage.removeItem(SESSION_KEY);
  } catch {
    // Ignore.
  }
}

/**
 * Read the ephemeral private key. Returns `null` when absent —
 * either a wallet session, an OAuth session that has already been
 * promoted to CREATE2, or a tab where the key was never written.
 */
function readEphemeralKey(): `0x${string}` | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = window.sessionStorage.getItem(EPHEMERAL_KEY_KEY);
    if (raw === null) return null;
    // Sanity check: hex-encoded 32-byte key.
    return /^0x[0-9a-fA-F]{64}$/.test(raw) ? (raw as `0x${string}`) : null;
  } catch {
    return null;
  }
}

function writeEphemeralKey(key: `0x${string}`): void {
  if (typeof window === "undefined") return;
  try {
    window.sessionStorage.setItem(EPHEMERAL_KEY_KEY, key);
  } catch {
    // Same rationale as writeStoredSession.
  }
}

function clearEphemeralKey(): void {
  if (typeof window === "undefined") return;
  try {
    window.sessionStorage.removeItem(EPHEMERAL_KEY_KEY);
  } catch {
    // Ignore.
  }
}

/* ──────────────────────────────────────────────────────────────────
 * Context
 * ────────────────────────────────────────────────────────────────── */

const WalletContext = createContext<WalletContextValue | null>(null);

export function WalletProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [status, setStatus] = useState<WalletStatus>("restoring");

  /**
   * Live provider for the current *wallet* session. OAuth sessions
   * never populate this. Ref, not state: mutations happen inside
   * handlers that must read the latest value synchronously.
   */
  const providerRef = useRef<EIP1193Provider | null>(null);

  const clearSession = useCallback(() => {
    setSession(null);
    setStatus("disconnected");
    providerRef.current = null;
    clearStoredSession();
    clearEphemeralKey();
  }, []);

  // ── Resume on mount ─────────────────────────────────────────────
  useEffect(() => {
    const stored = readStoredSession();
    if (!stored) {
      setStatus("disconnected");
      return;
    }

    setSession(stored);
    setStatus("connected");

    // Provider lookup is only safe for known brands. `"ledger"`
    // (DMK) and `"injected"` (no stable key to disambiguate which
    // injected wallet created the session) skip the lookup — the
    // next signing operation re-establishes the provider. See
    // "Resume — auto-acquiring the provider" in the file header.
    if (
      stored.kind === "wallet" &&
      stored.wallet !== "ledger" &&
      stored.wallet !== "injected"
    ) {
      const discovered = getWalletById(stored.wallet);
      if (discovered) {
        providerRef.current = discovered.provider;
      }
    }
    // OAuth sessions: the ephemeral key (if any) is still in
    // sessionStorage from the original `connectOAuth`. No action
    // needed here — `readEphemeralKey()` at the signing site reads
    // it directly.
  }, []);

  // ── Provider listeners (wallet sessions only) ───────────────────
  // For `"ledger"` and `"injected"` sessions resumed from storage,
  // `providerRef.current` is null — the listener effect exits on the
  // `if (!provider)` guard. That is the intended behaviour; see
  // "Resume — auto-acquiring the provider".
  const walletKind = session?.kind === "wallet" ? session.wallet : null;

  useEffect(() => {
    if (walletKind === null) return;
    const provider = providerRef.current;
    if (!provider) return;

    // Capture in locals so the cleanup closure narrows both without
    // non-null assertions.
    const on = provider.on;
    const removeListener = provider.removeListener;
    if (!on || !removeListener) return;

    const handleAccountsChanged = (accounts: Address[]) => {
      if (accounts.length === 0) {
        clearSession();
        return;
      }
      const first = accounts[0];
      if (!first) return;
      try {
        const address = getAddress(first);
        setSession((prev) =>
          prev?.kind === "wallet" ? { ...prev, address } : prev,
        );
      } catch {
        // Invalid address from the wallet — ignore; keep the old one.
      }
    };

    const handleChainChanged = (chainIdHex: string) => {
      const chainId = parseInt(chainIdHex, 16);
      if (!Number.isInteger(chainId) || chainId <= 0) return;
      setSession((prev) =>
        prev?.kind === "wallet" ? { ...prev, chainId } : prev,
      );
    };

    // Attach inside try/catch — see "Attach and detach are wrapped
    // in try/catch" in the file header. If the wallet's emitter is
    // not ready (MetaMask 11.x race during EIP-6963 announcement),
    // the session remains valid and we simply skip live sync.
    try {
      on("accountsChanged", handleAccountsChanged);
      on("chainChanged", handleChainChanged);
    } catch {
      return;
    }

    return () => {
      // Best-effort detach. A wallet can also throw from
      // `removeListener` if it has already torn down its emitter.
      try {
        removeListener("accountsChanged", handleAccountsChanged);
      } catch {
        /* already torn down */
      }
      try {
        removeListener("chainChanged", handleChainChanged);
      } catch {
        /* already torn down */
      }
    };
  }, [walletKind, clearSession]);

  // ── connect (wallet) ────────────────────────────────────────────
  const connect = useCallback(
    async (
      provider: EIP1193Provider,
      wallet: WalletKind,
    ): Promise<WalletSession> => {
      let accounts: unknown;
      try {
        accounts = await provider.request({ method: "eth_requestAccounts" });
      } catch (error) {
        throw normalizeWalletError(error);
      }
      if (!Array.isArray(accounts) || accounts.length === 0) {
        throw walletError("unauthorized", "Wallet returned no accounts.");
      }
      const first: unknown = accounts[0];
      if (typeof first !== "string") {
        throw walletError(
          "unauthorized",
          "Wallet returned an invalid account.",
        );
      }

      let address: `0x${string}`;
      try {
        address = getAddress(first);
      } catch (error) {
        throw normalizeWalletError(error);
      }

      let hexChainId: unknown;
      try {
        hexChainId = await provider.request({ method: "eth_chainId" });
      } catch (error) {
        throw normalizeWalletError(error);
      }
      if (typeof hexChainId !== "string") {
        throw walletError(
          "unsupported",
          "Wallet did not return a chain id.",
        );
      }
      const chainId = parseInt(hexChainId, 16);
      if (!Number.isInteger(chainId) || chainId <= 0) {
        throw walletError(
          "unsupported",
          `Wallet returned an invalid chain id: ${hexChainId}`,
        );
      }

      const nextSession: WalletSession = {
        kind: "wallet",
        wallet,
        address,
        chainId,
        authenticatedAt: Date.now(),
      };

      providerRef.current = provider;
      writeStoredSession(nextSession);
      setSession(nextSession);
      setStatus("connected");

      return nextSession;
    },
    [],
  );

  // ── connectOAuth ────────────────────────────────────────────────
  const connectOAuth = useCallback(
    async (
      provider: OAuthProvider,
      subject?: string,
    ): Promise<OAuthSession> => {
      // Generate the ephemeral wallet BEFORE writing the session.
      // If anything fails between the two writes, we end up with an
      // orphaned ephemeral key — harmless. The reverse (session
      // without key) would leave a resumed OAuth session unable to
      // sign, with no clear error path.
      const privateKey = generatePrivateKey();
      const account = privateKeyToAccount(privateKey);

      writeEphemeralKey(privateKey);

      const nextSession: OAuthSession = {
        kind: "oauth",
        provider,
        ...(subject !== undefined ? { subject } : {}),
        address: account.address,
        chainId: DEFAULT_CHAIN_ID,
        walletSource: "ephemeral",
        authenticatedAt: Date.now(),
      };

      writeStoredSession(nextSession);
      setSession(nextSession);
      setStatus("connected");

      return nextSession;
    },
    [],
  );

  // ── setOAuthAddress ─────────────────────────────────────────────
  // Called by the contract layer (Fase 9+) once `kipio_account`
  // derives the CREATE2 address. Replaces the ephemeral address and
  // clears the ephemeral key. No-op for wallet sessions.
  const setOAuthAddress = useCallback(
    (address: `0x${string}`, chainId: number) => {
      let checked: `0x${string}`;
      try {
        checked = getAddress(address);
      } catch {
        // Invalid address — refuse to mutate the session. The caller
        // (contract layer) is the source of truth; a malformed value
        // there is a bug, not a user error.
        return;
      }
      if (!Number.isInteger(chainId) || chainId <= 0) return;

      setSession((prev) => {
        if (prev?.kind !== "oauth") return prev;
        const next: OAuthSession = {
          ...prev,
          address: checked,
          chainId,
          walletSource: "create2",
        };
        writeStoredSession(next);
        return next;
      });

      clearEphemeralKey();
    },
    [],
  );

  const value = useMemo<WalletContextValue>(
    () => ({
      session,
      status,
      connect,
      connectOAuth,
      setOAuthAddress,
      disconnect: clearSession,
    }),
    [session, status, connect, connectOAuth, setOAuthAddress, clearSession],
  );

  return (
    <WalletContext.Provider value={value}>{children}</WalletContext.Provider>
  );
}

/**
 * Access the wallet session. Throws when called outside the provider
 * — the provider must be mounted once, at the root, and every
 * consumer shares the same state. No `null` return, no optional
 * chaining at every call site.
 */
export function useWallet(): WalletContextValue {
  const ctx = useContext(WalletContext);
  if (ctx === null) {
    throw new Error("useWallet must be used inside <WalletProvider>.");
  }
  return ctx;
}
