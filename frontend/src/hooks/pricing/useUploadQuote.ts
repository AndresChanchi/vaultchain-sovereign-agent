"use client";

/**
 * useUploadQuote — orchestrates the pricing module.
 *
 * Fetches three signals (Irys price, ETH/USD, fiat rates) with
 * TanStack Query so each has its own cache TTL, and combines them into
 * a `Quote` via the pure `computeQuote`.
 *
 * Why ETH/USD
 *   Irys returns storage prices in ETH wei for the `arbitrum` token
 *   parameter, so ETH/USD is the primary multiplier for storage cost.
 *   The native IRYS token is not used as the REST price unit.
 *
 * Cache strategy
 *   - Irys price per (bytes, term): 5 min. Irys anchors to USD, so the
 *     USD figure is stable; ETH amount moves only with ETH/USD.
 *   - ETH/USD: 1 min. Volatile enough to matter.
 *   - Fiat rates: 1 hour. Provider updates daily.
 *   - All queries disabled when `enabled === false`.
 *
 * Failure handling
 *   Every fetch throws on hard failure. TanStack Query captures that
 *   in `isError` / `error`. The returned `quote` is null while loading
 *   or on error — consumers render their own skeleton / "—" state.
 *   Partial data (Irys ok but FX missing) is handled inside
 *   `computeQuote`: it produces a `Quote` with `incomplete: true` and
 *   the missing fields null.
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
import { fetchEthUsd, fetchFiatRates } from "@lib/pricing/fx";
import { fetchIrysPrice } from "@lib/pricing/irys";
import { computeQuote } from "@lib/pricing/quote";
import type { Quote, Term } from "@lib/pricing/types";
import type { CurrencyCode } from "@config/pricing";

const ALL_CURRENCY_CODES = SUPPORTED_CURRENCIES.map((c) => c.code);

function termKey(term: Term): string {
  return term.kind === "permanent" ? "forever" : `term:${term.days}`;
}

export type UseUploadQuoteOptions = {
  bytes: number;
  term: Term;
  currency: CurrencyCode;
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
