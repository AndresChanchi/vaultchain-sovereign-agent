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
 * Three explicit states, not a nullable number:
 *
 *   "ok"          → `ethAtomic` is the cost in wei (ETH on Arbitrum).
 *                   Divide by 1e18 for ETH units.
 *   "free"        → upload is under the 100 KiB threshold; storage = 0.
 *   "unavailable" → the bundler could not price this request (network
 *                   error, unknown term endpoint, malformed response).
 *                   Consumers MUST render "—", never a guessed number.
 */
export type IrysPriceResult =
  | { readonly status: "ok"; readonly ethAtomic: bigint }
  | { readonly status: "free" }
  | { readonly status: "unavailable"; readonly reason: string };

// ─── FX ────────────────────────────────────────────────────────────────

/**
 * Exchange rates needed to convert an ETH quote into a display amount.
 *
 * `fiatPerUsd` is keyed by currency code and always includes USD = 1
 * (see `fetchFiatRates`). Missing keys mean "not fetched yet" or "not
 * supported by the FX provider" — consumers must check before use.
 */
export type FxRates = {
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
 * Fields can be `null` independently: if Irys is unavailable but the
 * fee is known, `storageUsd` is null while `kipioFeeUsd` is a number.
 * The UI can show partial data honestly. `incomplete` is a shortcut
 * for "at least one field is null" — useful for conditional rendering
 * of a warning badge.
 *
 * Numbers are unrounded. Formatting (2–4 decimals, currency symbol,
 * locale) is the UI's responsibility via `Intl.NumberFormat`. Keeping
 * full precision here means the UI can choose its rounding without
 * a second source of truth.
 *
 * These numbers are informational, not settlement-grade. The actual
 * amount charged is determined on-chain by `kipio_economics` and Irys
 * at transaction time. The quote approximates for display.
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
  /** Total converted to `currency`, or null if FX or total is missing. */
  readonly totalDisplay: number | null;
  /** True if any of the component values is null. */
  readonly incomplete: boolean;
};
