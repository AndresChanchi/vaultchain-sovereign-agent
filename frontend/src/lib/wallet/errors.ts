/**
 * EIP-1193 error normalization.
 *
 * Wallets throw errors in a variety of shapes:
 *
 *   - Standard EIP-1193: `{ code: number, message: string, data?: unknown }`
 *   - Some wrap that shape in an `Error` subclass with `.code` attached
 *   - Some put a string code (`"ACTION_REJECTED"`) in the `code` field
 *   - Some throw a raw string or a plain `Error`
 *
 * `normalizeWalletError()` turns any of those into a `WalletError`
 * with four well-typed fields:
 *
 *   - `code`        typed union, for routing to a translated string
 *   - `rawCode`     the numeric code from the provider, for logs
 *   - `rawMessage`  the original message, never displayed to the user
 *   - `cancelled`   true when the user cancelled on purpose, so the
 *                   UI can dismiss silently instead of showing an
 *                   error banner for a click on "reject"
 *
 * Why `cancelled` is its own field
 *   Showing "Something went wrong" when the user clicked "reject" in
 *   their wallet is bad UX. Every consumer checks `error.cancelled`
 *   and does nothing (or shows a subtle hint) when true. This is the
 *   reason the type is an object and not a plain enum — the
 *   cancellation signal travels alongside the error code instead of
 *   being re-derived at every call site.
 *
 * Standard codes (EIP-1193)
 *   4001    user rejected the request
 *   4100    requested method or account not authorized
 *   4200    wallet does not support the requested method
 *   4900    wallet is disconnected from all chains
 *   4901    wallet is disconnected from the requested chain
 *   -32002  a request is already pending (e.g. MetaMask popup)
 *
 * Non-standard codes seen in the wild
 *   "ACTION_REJECTED"   ethers.js user rejection (string code)
 *
 * Custom errors — constructed via `noProviderError` and `networkError`,
 * not via `normalizeWalletError`:
 *   no_provider  we tried to use a provider that is not available
 *   network      fetch failed (RPC, Irys price, FX rates, …)
 *
 * UI integration
 *   Map `WalletError.code` to a translated string at the display
 *   site. The dictionary currently ships `login.error.generic`,
 *   `login.error.rejected`, `login.error.noAccount`,
 *   `login.error.network`. Codes without a dedicated key fall back
 *   to `login.error.generic`. Add keys as the surfaces that need
 *   them are built — do not pre-emptively add `unauthorized` etc.
 *   if no UI displays them.
 *
 * Do not log `rawMessage` to any observability service in
 * production without review — wallet error messages occasionally
 * include wallet identifiers or truncated RPC payloads. `code` and
 * `rawCode` are safe to log.
 *
 * Implementation note on casts
 *   TypeScript cannot narrow through a cast-in-expression: writing
 *   `typeof (error as { message?: unknown }).message === "string"
 *     ? (error as { message: string }).message
 *     : ""` fails, because the second cast is checked against the
 *   original `object & Record<"code", unknown>` type, which does not
 *   "sufficiently overlap" with `{ message: string }`. The clean
 *   approach is `asRecord` + `asString`: two narrow helpers that
 *   erase the `unknown` at the boundary, then the code works with
 *   local variables and never re-casts.
 */

export type WalletErrorCode =
  | "rejected"
  | "unauthorized"
  | "unsupported"
  | "disconnected"
  | "chain_disconnected"
  | "pending"
  | "no_provider"
  | "network"
  | "unknown";

export type WalletError = {
  code: WalletErrorCode;
  /** The numeric code from the provider, if any. */
  rawCode?: number;
  /** The original message, unmodified. Never display directly. */
  rawMessage: string;
  /**
   * True when the user cancelled the request on purpose. The UI
   * should treat cancellation as a no-op, not as an error.
   */
  cancelled: boolean;
};

/**
 * EIP-1193 numeric codes → typed error fields. Kept as a `Map`
 * instead of a plain object so that:
 *   - `-32002` can be a key without relying on computed-property
 *     string coercion,
 *   - lookups stay O(1) under `noUncheckedIndexedAccess` without
 *     `Object.hasOwn` guards.
 */
const CODE_MAP: Map<number, Pick<WalletError, "code" | "cancelled">> = new Map([
  [4001, { code: "rejected", cancelled: true }],
  [4100, { code: "unauthorized", cancelled: false }],
  [4200, { code: "unsupported", cancelled: false }],
  [4900, { code: "disconnected", cancelled: false }],
  [4901, { code: "chain_disconnected", cancelled: false }],
  [-32002, { code: "pending", cancelled: false }],
]);

export function normalizeWalletError(error: unknown): WalletError {
  const record = asRecord(error);
  if (record !== null && "code" in record) {
    const rawCode = record.code;
    const rawMessage = asString(record.message) ?? "";

    if (typeof rawCode === "number") {
      const mapped = CODE_MAP.get(rawCode);
      if (mapped) {
        return { ...mapped, rawCode, rawMessage };
      }
      return { code: "unknown", rawCode, rawMessage, cancelled: false };
    }

    // ethers.js and some others use a string code for user rejection.
    if (rawCode === "ACTION_REJECTED") {
      return { code: "rejected", rawMessage, cancelled: true };
    }
  }

  if (error instanceof Error) {
    return { code: "unknown", rawMessage: error.message, cancelled: false };
  }

  return { code: "unknown", rawMessage: String(error), cancelled: false };
}

/**
 * Construct a `no_provider` error when a wallet is missing. Call
 * this when the UI attempts to connect a wallet that did not
 * announce via 6963 — e.g. the user clicked a wallet before the
 * announcement arrived, or the extension is disabled.
 */
export function noProviderError(walletName: string): WalletError {
  return {
    code: "no_provider",
    rawMessage: `No provider available for ${walletName}.`,
    cancelled: false,
  };
}

/**
 * Construct a `network` error when a fetch or RPC call fails. The
 * caller passes the underlying exception; only `message` is kept.
 */
export function networkError(cause: unknown): WalletError {
  return {
    code: "network",
    rawMessage: cause instanceof Error ? cause.message : String(cause),
    cancelled: false,
  };
}

/* ──────────────────────────────────────────────────────────────
 * Narrowing helpers — not exported. They exist only to keep the
 * main function cast-free after the first `asRecord` boundary.
 * ────────────────────────────────────────────────────────────── */

function asRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === "object" && value !== null
    ? (value as Record<string, unknown>)
    : null;
}

function asString(value: unknown): string | null {
  return typeof value === "string" ? value : null;
}
