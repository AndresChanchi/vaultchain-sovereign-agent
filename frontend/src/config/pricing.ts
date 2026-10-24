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
 *   - Irys parameters (bundler URL, token, free threshold) come from
 *     https://docs.irys.xyz. The price is anchored in USD by Irys and
 *     adjusted per block against the native token (ETH on Arbitrum),
 *     so the USD figure is stable while the ETH figure fluctuates.
 *
 *   - KIPIO_FEE_BPS will come from `kipio_economics` once deployed.
 *     The contract is currently inactive pending the Arbitrum Stylus
 *     activation pause, so this is `null` — consumers must treat it
 *     as "unknown", not zero.
 *
 *   - GAS_BUFFER_USD is our own buffer so the user never sees a gas
 *     line. The on-ramp model means gas is absorbed into the total.
 *     TODO: replace with a gas oracle read once `kipio_execution_gateway`
 *     exposes one; until then this flat estimate is conservative.
 *
 *   - Fiat currency list reflects Latam-first positioning. Extend
 *     `SUPPORTED_CURRENCIES` when a new region becomes a target
 *     market. The `primary` flag controls which codes appear at the
 *     top of any currency picker.
 */

// ─── Protocol fee ──────────────────────────────────────────────────────

/**
 * Kipio protocol fee, in basis points (1 bps = 0.01%).
 *
 * `null` means "not yet known" — the economics contract is not active.
 * Consumers MUST check `=== null`, not `!KIPIO_FEE_BPS`, because a
 * legitimate zero fee (`0`) is falsy in JavaScript.
 *
 * When `kipio_economics` deploys, this becomes a positive integer.
 * Example: `250` would mean a 2.5% fee.
 */
export const KIPIO_FEE_BPS: number | null = null;

// ─── Gas buffer ────────────────────────────────────────────────────────

/**
 * Flat USD buffer added to every quote to absorb the on-chain gas cost
 * of the settlement transaction.
 *
 * Not shown to the user as a separate line — the on-ramp model has
 * the user pay one total. Chosen conservatively: a typical Arbitrum
 * settlement tx costs $0.01–0.05 in ETH at current gas prices.
 *
 * TODO: replace with a gas oracle read (`eth_gasPrice` ×
 * `eth_estimateGas` on the Gateway call) once the settlement path is
 * stable. Keeping a flat value lets the landing quote without an RPC
 * round-trip.
 */
export const GAS_BUFFER_USD = 0.05;

// ─── Irys ──────────────────────────────────────────────────────────────

/**
 * Irys bundler base URL for price queries.
 *
 * Mainnet bundler. Used only for the `GET /price/{token}/{bytes}`
 * endpoint during quoting. Real uploads to testnet (Fase 10) will
 * use a devnet URL — a separate constant added when that phase
 * starts. Do not point this at testnet: the landing quote should
 * reflect what a real upload would cost on mainnet, not the
 * (practically zero) testnet price.
 */
export const IRYS_BUNDLER_URL = "https://node2.irys.xyz";

/**
 * Token symbol passed to the Irys price endpoint.
 *
 * "arbitrum" means ETH on Arbitrum — Irys does not support USDC on
 * Arbitrum today (only on Ethereum, Polygon, Solana). Any USD/COP/…
 * figure is therefore derived by multiplying the ETH quote by an
 * ETH/USD rate. See `lib/pricing/fx.ts` (Fase 5).
 */
export const IRYS_TOKEN = "arbitrum" as const;

/**
 * Irys uploads under this byte count are free (rate-limited to
 * 600 tx/min). Relevant for optimized photos: if browser-side
 * compression brings a file under 100 KiB, the storage portion of
 * the quote is $0 and only the Kipio fee + gas buffer remain.
 *
 * Irys policy, not ours — do not tune. If Irys changes the threshold,
 * update this value and every quote in the app follows.
 */
export const IRYS_FREE_UPLOAD_BYTES = 100 * 1024;

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
 * Irys price for a given byte count. Irys anchors to USD, so the USD
 * figure is stable; the ETH figure moves only when the ETH/USD rate
 * moves (handled above). Cache for 5 minutes to avoid spamming the
 * bundler with identical queries during a single user session.
 */
export const IRYS_PRICE_CACHE_TTL_MS = 5 * 60 * 1000;
