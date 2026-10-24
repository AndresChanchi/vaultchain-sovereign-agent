"use client";

/**
 * useUploadQuote — orchestrates the pricing module.
 *
 * Responsibilities
 *   - Fetch the three external signals (Irys price, ETH/USD, fiat
 *     rates) with TanStack Query so each has its own cache TTL.
 *   - Combine them into a `Quote` via the pure `computeQuote`.
 *   - Surface loading/error states in a shape the UI can render
 *     without branching on TanStack internals.
 *
 * What this hook does NOT do
 *   - No formatting. The quote returns unrounded numbers; the UI
 *     formats with `Intl.NumberFormat`.
 *   - No currency conversion beyond the single multiply in
 *     `computeQuote`. If a UI wants "approximate USD, exact local",
 *     it reads both `totalUsd` and `totalDisplay`.
 *   - No upload. Fase 10 owns that; this hook is read-only.
 *
 * Cache strategy
 *   - Irys price per (bytes, term): 5 min. Irys anchors to USD, so the
 *     USD figure is stable; ETH-wei moves only with ETH/USD, handled
 *     separately.
 *   - ETH/USD: 1 min. Volatile enough to matter within a session.
 *   - Fiat rates: 1 hour. Provider updates daily; hourly is generous.
 *   - All queries are disabled when `enabled === false`, letting the
 *     PricingCard avoid fetching until the user opens it (optional).
 *
 * Failure handling
 *   Every fetch throws on hard failure. TanStack Query captures that
 *   in `isError` / `error`. The returned `quote` is null while loading
 *   or on error — consumers render their own skeleton / "—" state.
 *   Partial data (e.g. Irys ok but FX missing) is handled inside
 *   `computeQuote`: it produces a `Quote` with `incomplete: true` and
 *   the missing fields null. This lets the UI show "Storage: $X,
 *   Kipio fee: —, Total: —" honestly instead of blanking the whole
 *   card.
 *
 * Consumers
 *   - `components/landing/pricing-card.tsx` (Fase 6 polish — replacing
 *     the `[PRICE]` / `[FEE]` placeholders).
 *   - Upload review step (Fase 10).
 *   - Offers / checkout (later phases).
 */

import { useQuery } from "@tanstack/react-query";
import {
  ETH_USD_CACHE_TTL_MS,
  FIAT_RATES_CACHE_TTL_MS,
  GAS_BUFFER_USD,
  IRYS_PRICE_CACHE_TTL_MS,
  KIPIO_FEE_BPS,
  SUPPORTED_CURRENCIES,
} from "@config/pricing";
import { fetchFiatRates, fetchEthUsd } from "@lib/pricing/fx";
import { fetchIrysPrice } from "@lib/pricing/irys";
import { computeQuote } from "@lib/pricing/quote";
import type { Quote, Term } from "@lib/pricing/types";
import type { CurrencyCode } from "@config/pricing";

/**
 * All fiat currency codes known to the app. Computed once at module
 * load; used as the fetch argument for the FX provider so we never
 * request codes the app does not display.
 */
const ALL_CURRENCY_CODES = SUPPORTED_CURRENCIES.map((c) => c.code);

/**
 * Stable serialization of `Term` for the query key.
 *
 * Objects in query keys work but are compared by reference identity in
 * some TanStack versions; a string is unambiguously stable across
 * renders. Permanent is `"forever"` (matches the mockup copy); terms
 * are `"term:{days}"`.
 */
function termKey(term: Term): string {
  return term.kind === "permanent" ? "forever" : `term:${term.days}`;
}

export type UseUploadQuoteOptions = {
  /** Bytes to be stored. Use the *optimized* size for accurate quotes. */
  bytes: number;
  /** Storage duration. See `Term`. */
  term: Term;
  /** Display currency. USD by default in the UI; any `CurrencyCode` works. */
  currency: CurrencyCode;
  /**
   * When false, no network calls are made and the hook returns
   * `{ quote: null, isLoading: false }`. Useful for landing cards that
   * should defer fetching until the user opens them. Defaults to true.
   */
  enabled?: boolean;
};

export type UseUploadQuoteResult = {
  quote: Quote | null;
  isLoading: boolean;
  isError: boolean;
  error: Error | null;
};

export function useUploadQuote({
  bytes,
  term,
  currency,
  enabled = true,
}: UseUploadQuoteOptions): UseUploadQuoteResult {
  const irysQuery = useQuery({
    queryKey: ["irys-price", bytes, termKey(term)] as const,
    queryFn: () => fetchIrysPrice(bytes, term),
    staleTime: IRYS_PRICE_CACHE_TTL_MS,
    enabled,
  });

  const ethUsdQuery = useQuery({
    queryKey: ["eth-usd"] as const,
    queryFn: fetchEthUsd,
    staleTime: ETH_USD_CACHE_TTL_MS,
    enabled,
  });

  const fiatQuery = useQuery({
    queryKey: ["fiat-rates", ALL_CURRENCY_CODES] as const,
    queryFn: () => fetchFiatRates(ALL_CURRENCY_CODES),
    staleTime: FIAT_RATES_CACHE_TTL_MS,
    enabled,
  });

  const isLoading =
    enabled &&
    (irysQuery.isLoading || ethUsdQuery.isLoading || fiatQuery.isLoading);

  const firstError =
    (irysQuery.error as Error | null) ??
    (ethUsdQuery.error as Error | null) ??
    (fiatQuery.error as Error | null);

  const isError =
    enabled &&
    (irysQuery.isError || ethUsdQuery.isError || fiatQuery.isError);

  // Build the quote only when every dependency is present. Partial
  // data (Irys failed but FX ok, etc.) is handled *inside*
  // `computeQuote` — this branch requires the *inputs* to be
  // available, not the *quote* to be complete.
  const quote: Quote | null =
    enabled &&
    irysQuery.data !== undefined &&
    ethUsdQuery.data !== undefined &&
    fiatQuery.data !== undefined
      ? computeQuote({
          bytes,
          term,
          currency,
          irys: irysQuery.data,
          fx: {
            ethUsd: ethUsdQuery.data,
            fiatPerUsd: fiatQuery.data,
          },
          kipioFeeBps: KIPIO_FEE_BPS,
          gasBufferUsd: GAS_BUFFER_USD,
        })
      : null;

  return {
    quote,
    isLoading,
    isError,
    error: firstError,
  };
}
