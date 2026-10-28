/**
 * Pricing configuration — single source of truth for every parameter
 * that feeds the upload quote calculation.
 *
 * This file contains no logic and imports nothing. It is data only.
 * Any change here propagates to every consumer of the pricing module
 * (landing PricingCard, upload review step, offers, checkout) without
 * touching components or hooks.
 *
 * Where these values come from
 *   - Irys parameters (bundler URL, token, free threshold, reference
 *     size) come from https://docs.irys.xyz. Irys is a programmable
 *     Layer-1 datachain with its own native token, IRYS — it is no
 *     longer an Arweave bundler. The `arbitrum` token parameter means
 *     "pay with ETH on Arbitrum"; the price endpoint returns wei.
 *
 *   - KIPIO_FEE_BPS will come from `kipio_economics` once deployed.
 *     The contract is currently inactive, so the fee is `0` — the
 *     protocol charges nothing during preview.
 *
 *   - GAS_BUFFER_USD is our own buffer so the user never sees a gas
 *     line. The on-ramp model means gas is absorbed into the total.
 *     TODO: replace with a gas oracle read once the settlement path
 *     is stable.
 *
 *   - Fiat currency list reflects Latam-first positioning. Extend
 *     `SUPPORTED_CURRENCIES` when expanding to a new region; the
 *     `primary` flag controls picker order.
 */

// ─── Protocol fee ──────────────────────────────────────────────────────

/**
 * Kipio protocol fee, in basis points (1 bps = 0.01%).
 *
 * Value `0` reflects **reality today**: `kipio_economics` is deployed
 * on Sepolia but inactive pending the Arbitrum Stylus activation pause,
 * so the protocol is not charging any fee. `0` is honest — a placeholder
 * like `250` would display "2.5%" when the actual charge is 0%.
 *
 * When the contract activates, replace with the fee read from the
 * contract. `pricing.feePreviewNote` explains the current 0% in the UI.
 *
 * A `null` value would propagate to `kipioFeeUsd: null` and then
 * `totalUsd: null`, producing `—` dashes. `0` keeps the arithmetic
 * valid (`storage + 0 + gasBuffer`) and the total is real.
 */
export const KIPIO_FEE_BPS: number = 0;

// ─── Gas buffer ────────────────────────────────────────────────────────

/**
 * Flat USD buffer added to every quote to absorb the on-chain gas cost
 * of the settlement transaction.
 *
 * Not shown as a separate line — the on-ramp model has the user pay
 * one total. A typical Arbitrum settlement tx costs $0.01–0.05 in ETH
 * at current gas prices.
 *
 * TODO: replace with a gas oracle read (`eth_gasPrice` ×
 * `eth_estimateGas` on the Gateway call) once the settlement path is
 * stable.
 */
export const GAS_BUFFER_USD = 0.05;

// ─── Irys ──────────────────────────────────────────────────────────────

/**
 * Irys L1 uploader base URL for price queries.
 *
 * `uploader.irys.xyz` is the current L1 endpoint. The legacy
 * `node2.irys.xyz` (Bundlr era) still responds but returns prices in
 * the old AR-denominated model, which is **not** what Irys charges
 * today. Do not point this constant at node2.
 *
 * Verified October 2026:
 *   uploader.irys.xyz/price/arbitrum/1GiB → 1284654946983374 wei
 *   → 0.00128 ETH × $2353 ≈ $3.02/GiB (matches Irys's ~$2.50/GB
 *     planning estimate)
 *   node2.irys.xyz/price/arbitrum/1GiB  → 58864981745681107
 *   → 0.0588 AR × $15 ≈ $0.88/GiB (old Bundlr model, deprecated)
 */
export const IRYS_BUNDLER_URL = "https://uploader.irys.xyz";

/**
 * Token symbol passed to the Irys price endpoint.
 *
 * `"arbitrum"` means "pay with ETH on Arbitrum". The endpoint returns
 * the cost in ETH wei. Irys also supports other chains/tokens
 * (`ethereum`, `polygon`, `usdc-eth`, …); for the current product the
 * settlement happens on Arbitrum, so this is the correct parameter.
 *
 * Do NOT pass `"irys"` — it is not a valid parameter for the REST
 * price route (returns a non-JSON error). The native IRYS token is
 * used internally by the network, but user-facing payments on
 * Arbitrum are denominated in ETH.
 */
export const IRYS_TOKEN = "arbitrum" as const;

/**
 * Irys uploads under this byte count are free (rate-limited to
 * 600 tx/min). Relevant for optimized photos: if browser-side
 * compression brings a file under 100 KiB, the storage portion of
 * the quote is $0 and only the Kipio fee + gas buffer remain.
 *
 * Irys policy — do not tune. If Irys changes the threshold, update
 * this value and every quote follows.
 */
export const IRYS_FREE_UPLOAD_BYTES = 100 * 1024;

/**
 * Reference size for price queries. Instead of asking Irys for the
 * exact byte count the user selected, `lib/pricing/irys.ts` asks for
 * the price of 1 GiB once and scales linearly.
 *
 * Why 1 GiB
 *   Irys pricing is linear per byte. Verified with:
 *     1 GiB → 1284654946983374 wei
 *     1 MiB → 1254545846664 wei
 *     1284654946983374 / 1024 ≈ 1254545846664  (exact linear ratio)
 *
 *   Asking for a fixed reference and multiplying by `bytes / reference`
 *   is mathematically identical to asking for `bytes`, but:
 *     - Works for any size without depending on the endpoint accepting
 *       arbitrary byte counts.
 *     - One cache entry per term shared by every size.
 *     - The reference price itself is well-known (~$3/GiB), so a
 *       broken response is easy to spot.
 *
 * Do NOT change to a smaller reference (1 MB, 1 KB) — Irys's minimum
 * charge floor could distort the ratio.
 */
export const IRYS_PRICE_REFERENCE_BYTES = 1024 * 1024 * 1024; // 1 GiB

// ─── Currencies ────────────────────────────────────────────────────────

export type Currency = {
  /** ISO 4217 code, uppercase. */
  code: string;
  /** Human label, English (used for tooltips, aria-labels). */
  label: string;
  /** Short symbol for tight inline display ($, R$, €, …). */
  symbol: string;
  /** BCP 47 locale for Intl.NumberFormat. */
  locale: string;
  /**
   * `true` → rendered at the top of any picker. Latam-first default
   * per product positioning. Add or demote based on target markets.
   */
  primary: boolean;
};

/**
 * Currencies offered in the UI. Not the full set the FX provider
 * supports — this is the curated picker list. Add new entries here
 * when expanding to a new region; the hook does not need to change.
 */
export const SUPPORTED_CURRENCIES: readonly Currency[] = [
  // Latam-first, USD at the top (matches the mockup's default display).
  { code: "USD", label: "US Dollar",         symbol: "$",  locale: "en-US", primary: true  },
  { code: "COP", label: "Colombian Peso",    symbol: "$",  locale: "es-CO", primary: true  },
  { code: "MXN", label: "Mexican Peso",      symbol: "$",  locale: "es-MX", primary: true  },
  { code: "BRL", label: "Brazilian Real",    symbol: "R$", locale: "pt-BR", primary: true  },
  { code: "ARS", label: "Argentine Peso",    symbol: "$",  locale: "es-AR", primary: true  },
  { code: "CLP", label: "Chilean Peso",      symbol: "$",  locale: "es-CL", primary: false },
  { code: "PEN", label: "Peruvian Sol",      symbol: "S/", locale: "es-PE", primary: false },
  { code: "UYU", label: "Uruguayan Peso",    symbol: "$U", locale: "es-UY", primary: false },
  { code: "BOB", label: "Bolivian Boliviano",symbol: "Bs", locale: "es-BO", primary: false },
  { code: "DOP", label: "Dominican Peso",    symbol: "RD$",locale: "es-DO", primary: false },
  { code: "GTQ", label: "Guatemalan Quetzal",symbol: "Q",  locale: "es-GT", primary: false },
  // Majors — secondary but common enough to keep one tap away.
  { code: "EUR", label: "Euro",              symbol: "€",  locale: "es-ES", primary: false },
  { code: "GBP", label: "British Pound",     symbol: "£",  locale: "en-GB", primary: false },
] as const;

/** Derived literal-union of codes; use for `CurrencyCode` typing. */
export type CurrencyCode = (typeof SUPPORTED_CURRENCIES)[number]["code"];

/**
 * Default display currency. Matches the mockup, which shows every
 * price as `USD [X]`. Users can switch via the picker; the underlying
 * quote is always computed in USD first (Irys anchors to USD), then
 * converted to the display currency — that ordering avoids
 * double-rounding drift.
 */
export const DEFAULT_CURRENCY: CurrencyCode = "USD";

// ─── Cache TTLs ────────────────────────────────────────────────────────

/**
 * How long each external signal is reused before refetching.
 *
 * Chosen to balance freshness (exchange rates move) with rate limits
 * (public FX APIs throttle aggressive clients) and UX latency (a
 * currency switch should not visibly wait). Values are conservative —
 * shorten only with a corresponding load-mitigation plan.
 */

/** ETH/USD spot rate. Volatile; refresh every minute. */
export const ETH_USD_CACHE_TTL_MS = 60_000;

/** Fiat rates (open.er-api.com or equivalent). Updates daily at source. */
export const FIAT_RATES_CACHE_TTL_MS = 60 * 60 * 1000;

/**
 * Irys price for a given reference size. Irys anchors to USD, so the
 * USD figure is stable; the ETH figure moves only when the ETH/USD
 * rate moves (handled above). Cache for 5 minutes to avoid spamming
 * the bundler with identical queries during a single user session.
 *
 * With the reference-size approach, the query key is `["irys-price",
 * "permanent"]` or `["irys-price", "term:30"]` — one entry per term,
 * shared by every user-selected byte count. Cache hit rate is high.
 */
export const IRYS_PRICE_CACHE_TTL_MS = 5 * 60 * 1000;
