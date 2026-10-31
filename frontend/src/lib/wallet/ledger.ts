"use client";

/**
 * Ledger DMK adapter for the new login flow.
 *
 * The `WalletContext.connect(provider, wallet)` contract expects an
 * EIP-1193 provider (it calls `eth_requestAccounts` and `eth_chainId`).
 * The Ledger connector in `lib/ledger/connector.ts` is a wagmi
 * connector — it exposes `connect()`, `getClient()`, etc., but not an
 * EIP-1193 `request` method directly.
 *
 * This adapter bridges the two:
 *   1. Finds the wagmi Ledger connector by id (`ledger-physical` or
 *      `ledger-speculos`) from the existing `config/wagmi.ts`.
 *   2. Calls `connector.connect()` — this triggers DMK discovery and
 *      the device approval flow. The user sees the address on the
 *      device and confirms.
 *   3. Wraps the resulting `{ accounts, chainId }` in a minimal
 *      EIP-1193 provider that answers the two methods the login
 *      context uses. Any other method throws — the login ceremony
 *      does not sign anything.
 *
 * Why not call DMK directly
 *   `lib/ledger/connector.ts` already encapsulates the DMK session,
 *   transport fallback (Speculos URLs, WebHID), derivation path, and
 *   error normalisation. Duplicating it here would be a second source
 *   of truth for the same device flow. The adapter reuses the
 *   connector as-is; when Fase 10 wires real signing, the
 *   `WalletContext` will expose the underlying provider (or the
 *   `getClient()` result) without changing this file.
 *
 * Type shape — why `on` / `removeListener` are no-ops
 *   viem's `EIP1193Provider` is the intersection of `EIP1193Events`
 *   (`on` and `removeListener`, both required) and
 *   `{ request: EIP1193RequestFn }`. Skipping the two event methods
 *   produces:
 *
 *     Type '{ request: … }' is missing the following properties
 *     from type '…': on, removeListener
 *
 *   The login ceremony only invokes `request` (twice). The adapter
 *   is a one-shot handshake: it never registers a listener, and a
 *   session resumed from `sessionStorage` does not re-attach to the
 *   device — the next signing operation re-establishes the DMK
 *   session through the wagmi connector. So `on` / `removeListener`
 *   are implemented as no-ops with a comment explaining why. If a
 *   future caller needs real `accountsChanged` / `chainChanged`
 *   events, they must read them from the wagmi connector
 *   (`config.connectors`), not from this adapter. Documenting that
 *   here so the no-op is not mistaken for an oversight.
 *
 * Type shape — why `request` is cast
 *   `EIP1193Provider["request"]` is a generic function:
 *
 *     request: <T>(
 *       args: EIP1193RequestFnParameter<T>
 *     ) => Promise<T["ReturnType"]>
 *
 *   The return type depends on the method string via a compile-time
 *   lookup. Our adapter returns a union
 *   (`string | readonly `0x${string}`[]`) that, while structurally
 *   correct for `eth_requestAccounts` and `eth_chainId`, does not
 *   cover every `_returnType` the generic could instantiate. The
 *   cast is a single focused boundary: one line, one comment, no
 *   `unknown`, no `any`. Without it, TS rejects the assignment with
 *   "Type 'Promise<string | readonly `0x${string}`[]>' is not
 *   assignable to 'Promise<_returnType>'".
 *
 * Ledger is NOT in EIP-6963 discovery
 *   The device does not announce itself via `eip6963:announceProvider`.
 *   The wallet list renders the Ledger row separately and calls this
 *   adapter when the user clicks it.
 *
 * Transport selection
 *   `"physical"` uses WebHID (`ledger-physical`). `"speculos"` uses
 *   the configured Speculos URLs (`ledger-speculos`). The login
 *   panel renders only the physical entry today — the simulator is a
 *   dev-only path, exposed here for tests and future admin surfaces
 *   but not shown to end users. When we need it in the UI, add a
 *   second row keyed on `transport: "speculos"` guarded by an env
 *   check.
 */

import { config } from "@config/wagmi";
import type { EIP1193Provider } from "viem";

const LEDGER_CONNECTOR_IDS = {
  physical: "ledger-physical",
  speculos: "ledger-speculos",
} as const;

export type LedgerTransport = keyof typeof LEDGER_CONNECTOR_IDS;

export type LedgerConnectResult = {
  /** The EIP-1193 adapter. Pass to `WalletContext.connect`. */
  provider: EIP1193Provider;
  /** The wagmi connector id that produced the session. */
  connectorId: string;
};

/**
 * Connect a Ledger device and return an EIP-1193 adapter for the
 * login context.
 *
 * Throws a plain `Error` with a descriptive message when:
 *   - the connector is not registered in `config/wagmi.ts`
 *   - the DMK discovery times out or the device is not found
 *   - the user rejects the connection on the device
 *
 * The caller (`components/login/wallet-list.tsx`) normalises the
 * error into a `WalletError` before showing it.
 */
export async function connectLedger(
  transport: LedgerTransport,
): Promise<LedgerConnectResult> {
  const connectorId = LEDGER_CONNECTOR_IDS[transport];
  const connector = config.connectors.find((c) => c.id === connectorId);
  if (!connector) {
    throw new Error(
      `Ledger connector "${connectorId}" is not registered in config/wagmi.ts.`,
    );
  }

  const result = await connector.connect();

  const accounts = result.accounts as readonly `0x${string}`[];
  const chainId = result.chainId;

  // `request` cast — see "Type shape — why `request` is cast" in the
  // file header. The caller only calls these two methods.
  //
  // `on` / `removeListener` no-ops — see "Type shape — why
  // `on` / `removeListener` are no-ops" in the file header. The
  // login ceremony is a one-shot handshake; a session resumed from
  // `sessionStorage` re-establishes the DMK session through the
  // wagmi connector on the next signing operation, not through this
  // adapter.
  const provider: EIP1193Provider = {
    request: (async ({ method }: { method: string }) => {
      switch (method) {
        case "eth_requestAccounts":
        case "eth_accounts":
          return accounts;
        case "eth_chainId":
          return `0x${chainId.toString(16)}`;
        default:
          throw new Error(
            `Ledger adapter does not support "${method}" during login.`,
          );
      }
    }) as EIP1193Provider["request"],
    on: () => {
      /* no-op — see the file header */
    },
    removeListener: () => {
      /* no-op — see the file header */
    },
  };

  return { provider, connectorId };
}
