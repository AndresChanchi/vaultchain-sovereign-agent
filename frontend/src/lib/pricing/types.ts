/**
 * Pricing types — the contract between the pure calculation layer, the
 * I/O layer, and the React hook.
 *
 * Types only. No imports from `@irys/sdk`, no fetch, no config values
 * (those arrive as inputs). This file is safe to import from any
 * environment (client, server, tests, workers).
 *
 * Dependencies: `CurrencyCode` from `@config/pricing` (type-only).
 */

import type { CurrencyCode } from "@config/pricing";

// ─── Term ──────────────────────────────────────────────────────────────

/**
 * How long the upload must remain retrievable.
 *
 * Modelled as a discriminated union so arbitrary durations are
 * expressible:
 *
 *   { kind: "permanent" }              → paid once, kept forever
 *   { kind: "term", days: 30 }         → Cascade term ledger, 30 days
 *   { kind: "term", days: 365 }        → 1 year
 *   { kind: "term", days: 7 }          → any positive integer
 *
 * Cascade currently exposes 30-day and 1-year ledgers at the protocol
 * level; other durations are forwarded to the bundler and either
 * accepted (when it supports them) or surfaced as `unavailable` in the
 * quote. The type does not constrain the value — that lets the UI offer
 * a "custom duration" control without changing this contract.
 */
export type Term =
  | { readonly kind: "permanent" }
  | { readonly kind: "term"; readonly days: number };

// ─── Irys price ────────────────────────────────────────────────────────

/**
 * Result of asking the Irys bundler how much storage costs.
 *
 * **`ethAtomic` is wei of ETH on Arbitrum.**
 *
 * The `arbitrum` token parameter means "pay with ETH on Arbitrum".
 * The endpoint returns the cost in that chain's native unit — wei.
 * Verified October 2026:
 *   1 GiB → 1284654946983374 wei = 0.00128 ETH ≈ $3.02/GiB.
 *
 * Do NOT interpret this as AR (the legacy `node2.irys.xyz` endpoint
 * returned AR winston; `uploader.irys.xyz` returns ETH wei). Do NOT
 * interpret as IRYS — the native IRYS token is not used as the REST
 * price unit for the `arbitrum` parameter.
 *
 * `termFallback` is `true` when the requested term price could not be
 * fetched from Irys and the permanent price is being used as an upper
 * bound. The public `?term=` parameter is **ignored** by the bundler
 * (verified: identical response for permanent, term:30, term:365), so
 * this is currently `true` for every term request.
 */
export type IrysPriceResult =
  | {
      readonly status: "ok";
      /** ETH amount in wei (1e18 wei = 1 ETH). */
      readonly ethAtomic: bigint;
      /**
       * True when the requested term price could not be fetched and
       * the permanent price is being returned as an upper bound.
       */
      readonly termFallback?: boolean;
    }
  | { readonly status: "free" }
  | { readonly status: "unavailable"; readonly reason: string };

// ─── FX ────────────────────────────────────────────────────────────────

/**
 * Exchange rates needed to convert an ETH quote into a display amount.
 *
 * `ethUsd` is the ETH/USD spot rate. It is the primary multiplier for
 * the storage price (see `computeQuote`).
 *
 * `fiatPerUsd` is keyed by currency code and always includes USD = 1
 * (see `fetchFiatRates`). Missing keys mean "not fetched yet" or "not
 * supported by the FX provider" — consumers must check before use.
 */
export type FxRates = {
  /** ETH/USD spot rate. Multiplier for the storage price. */
  readonly ethUsd: number;
  readonly fiatPerUsd: Readonly<Partial<Record<CurrencyCode, number>>>;
};

// ─── Quote ─────────────────────────────────────────────────────────────

/**
 * Everything `computeQuote` needs. Pure data — no functions, no class
 * instances, no SDK objects. Serializable, hence testable without mocks.
 */
export type QuoteInput = {
  readonly bytes: number;
  readonly term: Term;
  readonly currency: CurrencyCode;
  readonly irys: IrysPriceResult;
  readonly fx: FxRates;
  /**
   * Kipio protocol fee in basis points.
   *
   * `null` means "not yet known" (economics contract not deployed).
   * `0` means "no fee" — a valid value. Consumers MUST check `=== null`,
   * never truthiness.
   */
  readonly kipioFeeBps: number | null;
  /** Flat USD buffer for gas, absorbed into the total. */
  readonly gasBufferUsd: number;
};

/**
 * The result of a quote calculation.
 *
 * Two parallel views of every monetary field:
 *
 *   - `*Usd`     — always USD. Used internally (fee calculation) and
 *                  for debugging. Do NOT format these with the user's
 *                  display currency: `format.currency(3, "COP")` would
 *                  produce "COP 3", meaning 3 pesos, not 3 dollars.
 *
 *   - `*Display` — already converted to `currency` using the FX rate
 *                  from `fiatPerUsd[currency]`. Format these with
 *                  `format.currency(value, currency)`.
 *
 * The `*Display` fields are `null` when the underlying `*Usd` is null
 * OR when the FX provider does not return a rate for `currency`.
 * Consumers render `—` in either case. This is what prevents the
 * "COP 3" bug: the displayed value is `storageUsd * fiatRate`, not
 * `storageUsd`.
 *
 * Numbers are unrounded. Formatting (2–4 decimals, currency symbol,
 * locale) is the UI's responsibility via `Intl.NumberFormat`.
 *
 * These numbers are informational, not settlement-grade. The actual
 * amount charged is determined on-chain by `kipio_economics` and Irys
 * at transaction time.
 */
export type Quote = {
  readonly currency: CurrencyCode;
  /** True when the upload falls under Irys's free threshold. */
  readonly free: boolean;
  /** Storage cost in USD, or null if Irys could not price it. */
  readonly storageUsd: number | null;
  /** Kipio fee in USD, or null if the fee bps is not yet known. */
  readonly kipioFeeUsd: number | null;
  /** Gas buffer in USD. Always present (config-provided). */
  readonly gasBufferUsd: number;
  /** Sum in USD, or null if any component is null. */
  readonly totalUsd: number | null;

  /** Storage cost in `currency`, or null if storage or FX is missing. */
  readonly storageDisplay: number | null;
  /** Kipio fee in `currency`, or null if fee or FX is missing. */
  readonly kipioFeeDisplay: number | null;
  /** Total in `currency`, or null if total or FX is missing. */
  readonly totalDisplay: number | null;

  /** True if any of the component values is null. */
  readonly incomplete: boolean;
  /**
   * True when `storageUsd` was computed from the permanent price
   * because the requested term could not be priced. Propagated from
   * `IrysPriceResult.ok.termFallback`; rendered as
   * `pricing.termFallbackNote` in the UI.
   */
  readonly termFallback: boolean;
};
