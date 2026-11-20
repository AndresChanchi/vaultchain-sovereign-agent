"use client";

/**
 * Wallet session — state, persistence, provider listeners, signer.
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
 * Session shape — discriminated union with two variants
 *
 *     { kind: "wallet"; wallet; address; chainId; … }
 *     { kind: "oauth";  provider; subject?; address; chainId;
 *       walletSource; … }
 *
 *   Wallet session: address owned by the wallet extension, private
 *   key never touches the page. Real EOA. Can sign today.
 *
 *   OAuth session: address is *ephemeral* until the contract layer
 *   derives the real CREATE2 address. The frontend generates a local
 *   keypair (`viem/accounts`), stores it in `sessionStorage` for the
 *   lifetime of the tab, and uses it for demo uploads on Sepolia.
 *
 * Why the ephemeral wallet is honest, not a lie
 *   The alternative — an OAuth session with no `address` — forces
 *   every consumer to branch on `session.kind === "oauth"` before
 *   rendering an address, a balance, or anything space-shaped. That
 *   is worse. The ephemeral wallet gives them a real, signable EVM
 *   address today.
 *
 * Why the ephemeral key is persisted in `sessionStorage`
 *   Memory-only would break resume: a tab reload would lose the key
 *   while keeping the address, and the next signing operation would
 *   fail without a clear reason. The demo has no real funds (testnet
 *   ETH only), the key never leaves the origin, and the tab closes
 *   it. When the contract layer lands, `setOAuthAddress` wipes the
 *   key immediately.
 *
 * Persistence — why sessionStorage
 *   `localStorage` would persist across tabs and days; a user could
 *   return a week later and see themselves as "connected" to a wallet
 *   they never re-authorized. `sessionStorage` dies with the tab.
 *
 * Validation on read
 *   `sessionStorage` is user-writable. `validateSession` rejects
 *   anything malformed — a tampered value degrades to `null`.
 *
 * Provider listeners
 *   Wallet sessions only. `accountsChanged` / `chainChanged` keep the
 *   session in sync. Zero accounts (revoked access) → full disconnect.
 *   Attach/detach are wrapped in try/catch (MetaMask 11.x can throw
 *   from `provider.on` during EIP-6963 announcement).
 *
 * Resume — auto-acquiring the provider
 *   On mount, after restoring a wallet session, `getWalletById` looks
 *   up the provider. `"ledger"` and `"injected"` are excluded.
 *
 * `disconnect` semantics
 *   Clears the local session, provider ref, ephemeral key, and both
 *   `sessionStorage` entries. Does NOT call `wallet_revokePermissions`
 *   or the OAuth provider's revocation endpoint.
 *
 * `connect` / `connectOAuth` / `setOAuthAddress`
 *   `connect(provider, wallet)` — wallet session. Calls
 *   `eth_requestAccounts` and `eth_chainId`, normalises, persists.
 *
 *   `connectOAuth(provider, subject?)` — OAuth session. Generates an
 *   ephemeral keypair, persists both the key and the session.
 *
 *   `setOAuthAddress(address, chainId)` — called by the contract
 *   layer once `kipio_account` derives the CREATE2 address.
 *
 * `getEip1193Provider`
 *   Raw EIP-1193 provider getter, used by `useIrys` and `useVault`.
 *   Re-derives from `mipd` when the ref is empty (resume path).
 *   Returns `null` for OAuth, Ledger and `"injected"`.
 *
 * `signTypedData`
 *   Session-aware EIP-712 signer, consumed by
 *   `KipioContext.unlockVault` to derive the AES master key.
 *
 *   Wallet: `provider.request("eth_signTypedData_v4")` after
 *   augmenting `types` with `EIP712Domain` derived from `domain` —
 *   **the same augmentation viem performs internally**. Skipping it
 *   produces a different hash, a different signature, and a different
 *   HKDF key, which is what broke decryption of photos encrypted by
 *   the legacy dashboard.
 *
 *   OAuth: signs locally with the ephemeral account via
 *   `viem/accounts.signTypedData`, which also augments `types`.
 *
 *   Ledger: throws `unsupported` until the DMK signer is wired into
 *   KipioContext (Fase 10).
 *
 *   Stale-permission retry — the 4100 fix
 *     MetaMask 12.x (and forks) can leave a sticky "connected for
 *     reads but not for signing" state after a rejected signature.
 *     The origin stays authorized for `eth_accounts` but the next
 *     `eth_signTypedData_v4` returns 4100 without opening a popup.
 *     This is a known issue (wevm/wagmi#4131) and reproduces on Brave
 *     as well (community.brave.app/t/649840). It cannot be worked
 *     around at the UI layer — the retry must happen at the provider.
 *
 *     The chain:
 *       1. First `eth_signTypedData_v4` → if 4100:
 *       2. `eth_requestAccounts` — cheap reset (no popup when already
 *          connected), re-establishes the signing permission for the
 *          current account.
 *       3. Retry the sign. If still 4100:
 *       4. `wallet_requestPermissions({ eth_accounts: {} })` — forces
 *          a fresh permission prompt. MetaMask's PermissionController
 *          clears the stale slot when this runs.
 *       5. Retry the sign one last time. Any remaining 4100 is a real
 *          authorization failure and propagates as `WalletError`.
 *
 *     The order matters: `eth_requestAccounts` is silent when it
 *     works, `wallet_requestPermissions` only fires when the silent
 *     reset did not. A user who is fully authorized never sees
 *     either — the first sign succeeds.
 *
 *     If the retry still fails, the error surfaces as
 *     `code: "unauthorized"`. The upload flow classifies it as
 *     `WALLET_UNAUTHORIZED` so the UI can show an actionable message
 *     ("Open your wallet and reconnect this site") instead of a
 *     generic "Try again".
 *
 * TODO: when the route restructure (Fase 9) ships, nothing in this
 *       file moves — the session has no route knowledge.
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
  getTypesForEIP712Domain,
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

export type OAuthProvider =
  | "google"
  | "x"
  | "microsoft"
  | "apple"
  | "github"
  | "twitch";

export type WalletSession = {
  kind: "wallet";
  wallet: WalletKind;
  address: `0x${string}`;
  chainId: number;
  authenticatedAt: number;
};

export type OAuthSession = {
  kind: "oauth";
  provider: OAuthProvider;
  subject?: string;
  address: `0x${string}`;
  chainId: number;
  walletSource: "ephemeral" | "create2";
  authenticatedAt: number;
};

export type Session = WalletSession | OAuthSession;

export type WalletStatus = "restoring" | "connected" | "disconnected";

export type TypedDataPayload = {
  domain: Record<string, unknown>;
  types: Readonly<
    Record<string, ReadonlyArray<{ name: string; type: string }>>
  >;
  primaryType: string;
  message: Record<string, unknown>;
};

type ViemDomain = Parameters<typeof getTypesForEIP712Domain>[0]["domain"];

export type WalletContextValue = {
  session: Session | null;
  status: WalletStatus;
  connect: (
    provider: EIP1193Provider,
    wallet: WalletKind,
  ) => Promise<WalletSession>;
  connectOAuth: (
    provider: OAuthProvider,
    subject?: string,
  ) => Promise<OAuthSession>;
  setOAuthAddress: (address: `0x${string}`, chainId: number) => void;
  signTypedData: (typedData: TypedDataPayload) => Promise<`0x${string}`>;
  getEip1193Provider: () => EIP1193Provider | null;
  disconnect: () => void;
};

/* ──────────────────────────────────────────────────────────────────
 * Persistence
 * ────────────────────────────────────────────────────────────────── */

const SESSION_KEY = "kipio:wallet:session";
const EPHEMERAL_KEY_KEY = "kipio:wallet:ephemeral";

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
    /* private mode or storage disabled */
  }
}

function clearStoredSession(): void {
  if (typeof window === "undefined") return;
  try {
    window.sessionStorage.removeItem(SESSION_KEY);
  } catch {
    /* ignore */
  }
}

function readEphemeralKey(): `0x${string}` | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = window.sessionStorage.getItem(EPHEMERAL_KEY_KEY);
    if (raw === null) return null;
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
    /* ignore */
  }
}

function clearEphemeralKey(): void {
  if (typeof window === "undefined") return;
  try {
    window.sessionStorage.removeItem(EPHEMERAL_KEY_KEY);
  } catch {
    /* ignore */
  }
}

function withEip712Domain(typedData: TypedDataPayload): {
  types: Record<string, Array<{ name: string; type: string }>>;
} {
  const types: Record<string, Array<{ name: string; type: string }>> = {};
  for (const [key, value] of Object.entries(typedData.types)) {
    types[key] = [...value];
  }
  if (!types.EIP712Domain) {
    types.EIP712Domain = getTypesForEIP712Domain({
      domain: typedData.domain as ViemDomain,
    });
  }
  return { types };
}

/* ──────────────────────────────────────────────────────────────────
 * Context
 * ────────────────────────────────────────────────────────────────── */

const WalletContext = createContext<WalletContextValue | null>(null);

export function WalletProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [status, setStatus] = useState<WalletStatus>("restoring");

  const providerRef = useRef<EIP1193Provider | null>(null);

  const clearSession = useCallback(() => {
    setSession(null);
    setStatus("disconnected");
    providerRef.current = null;
    clearStoredSession();
    clearEphemeralKey();
  }, []);

  useEffect(() => {
    const stored = readStoredSession();
    if (!stored) {
      setStatus("disconnected");
      return;
    }

    setSession(stored);
    setStatus("connected");

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
  }, []);

  const walletKind = session?.kind === "wallet" ? session.wallet : null;

  useEffect(() => {
    if (walletKind === null) return;
    const provider = providerRef.current;
    if (!provider) return;

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
        /* invalid address from the wallet — ignore */
      }
    };

    const handleChainChanged = (chainIdHex: string) => {
      const chainId = parseInt(chainIdHex, 16);
      if (!Number.isInteger(chainId) || chainId <= 0) return;
      setSession((prev) =>
        prev?.kind === "wallet" ? { ...prev, chainId } : prev,
      );
    };

    try {
      on("accountsChanged", handleAccountsChanged);
      on("chainChanged", handleChainChanged);
    } catch {
      return;
    }

    return () => {
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

  const connectOAuth = useCallback(
    async (
      provider: OAuthProvider,
      subject?: string,
    ): Promise<OAuthSession> => {
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

  const setOAuthAddress = useCallback(
    (address: `0x${string}`, chainId: number) => {
      let checked: `0x${string}`;
      try {
        checked = getAddress(address);
      } catch {
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

  const getProvider = useCallback((): EIP1193Provider | null => {
    if (providerRef.current) return providerRef.current;
    if (
      session?.kind === "wallet" &&
      session.wallet !== "ledger" &&
      session.wallet !== "injected"
    ) {
      const discovered = getWalletById(session.wallet);
      if (discovered) {
        providerRef.current = discovered.provider;
        return discovered.provider;
      }
    }
    return null;
  }, [session]);

  const signTypedData = useCallback(
    async (typedData: TypedDataPayload): Promise<`0x${string}`> => {
      if (!session) {
        throw walletError("unauthorized", "No active session.");
      }

      const { types } = withEip712Domain(typedData);

      if (session.kind === "wallet") {
        if (session.wallet === "ledger") {
          throw walletError(
            "unsupported",
            "Ledger signing is not wired into this flow yet.",
          );
        }
        const provider = getProvider();
        if (!provider) {
          throw walletError(
            "no_provider",
            "The wallet is not available to sign. Try again from the wallet extension.",
          );
        }

        const signCall = () =>
          provider.request({
            method: "eth_signTypedData_v4",
            params: [
              session.address,
              JSON.stringify({
                domain: typedData.domain,
                types,
                primaryType: typedData.primaryType,
                message: typedData.message,
              }),
            ],
          });

        let signature: unknown;
        try {
          signature = await signCall();
        } catch (firstError) {
          const normalized = normalizeWalletError(firstError);

          if (normalized.code !== "unauthorized") {
            throw normalized;
          }

          // Stale-permission retry — see "Stale-permission retry"
          // in the file header. Two escalating attempts:
          //   1. `eth_requestAccounts` — silent reset when already
          //      connected.
          //   2. `wallet_requestPermissions` — forced prompt when the
          //      silent reset was not enough.
          // Any error in the resets themselves propagates as a normal
          // wallet error; the caller treats 4100 as a definitive
          // authorization failure.
          let recovered = false;

          try {
            await provider.request({ method: "eth_requestAccounts" });
            signature = await signCall();
            recovered = true;
          } catch {
            /* fall through to wallet_requestPermissions */
          }

          if (!recovered) {
            try {
              await provider.request({
                method: "wallet_requestPermissions",
                params: [{ eth_accounts: {} }],
              });
              signature = await signCall();
              recovered = true;
            } catch (retryError) {
              throw normalizeWalletError(retryError);
            }
          }
        }

        if (typeof signature !== "string" || !signature.startsWith("0x")) {
          throw walletError(
            "unknown",
            "Wallet returned an invalid signature.",
          );
        }
        return signature as `0x${string}`;
      }

      const ephemeralKey = readEphemeralKey();
      if (!ephemeralKey) {
        throw walletError(
          "unsupported",
          "The ephemeral key for this OAuth session is no longer available.",
        );
      }
      const account = privateKeyToAccount(ephemeralKey);
      return account.signTypedData({
        domain: typedData.domain,
        types,
        primaryType: typedData.primaryType,
        message: typedData.message,
      } as Parameters<typeof account.signTypedData>[0]);
    },
    [session, getProvider],
  );

  const value = useMemo<WalletContextValue>(
    () => ({
      session,
      status,
      connect,
      connectOAuth,
      setOAuthAddress,
      signTypedData,
      getEip1193Provider: getProvider,
      disconnect: clearSession,
    }),
    [
      session,
      status,
      connect,
      connectOAuth,
      setOAuthAddress,
      signTypedData,
      getProvider,
      clearSession,
    ],
  );

  return (
    <WalletContext.Provider value={value}>{children}</WalletContext.Provider>
  );
}

export function useWallet(): WalletContextValue {
  const ctx = useContext(WalletContext);
  if (ctx === null) {
    throw new Error("useWallet must be used inside <WalletProvider>.");
  }
  return ctx;
}
