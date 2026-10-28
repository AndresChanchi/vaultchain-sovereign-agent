/**
 * FX fetches — ETH/USD and fiat rates, no API key required.
 *
 * Two providers, chosen for zero-config browser use:
 *
 *   ETH/USD   Coinbase public spot endpoint (`ETH-USD`).
 *             Primary multiplier for the storage quote — Irys returns
 *             prices in ETH wei for the `arbitrum` token parameter,
 *             and `computeQuote` converts via this rate.
 *
 *   Fiat      open.er-api.com Open Access endpoint.
 *             No key, updates daily. USD is always 1.
 *
 * Tradeoff acknowledged
 *   These are centralized reads. The quote is informational; the
 *   actual settlement price is fixed on-chain by `kipio_economics`
 *   and Irys at transaction time. A centralized FX read therefore
 *   cannot redirect funds. The path to full sovereignty is Chainlink
 *   on Arbitrum (on-chain read via viem), documented as a TODO per
 *   function.
 *
 * Failure handling
 *   Every function throws on hard failure. The hook wraps them in
 *   TanStack Query, which converts throws into the standard `isError`
 *   state. Consumers decide how to render (usually `—`).
 */

import type { CurrencyCode } from "@config/pricing";
import { SUPPORTED_CURRENCIES } from "@config/pricing";
import type { FxRates } from "./types";

const COINBASE_BASE = "https://api.coinbase.com/v2/prices";
const ER_API_LATEST_USD_URL = "https://open.er-api.com/v6/latest/USD";

/**
 * Fetch the ETH/USD spot rate. Primary multiplier for the storage
 * quote — Irys returns ETH wei, and the display USD price is
 * `ethAtomic / 1e18 × ethUsd`.
 *
 * @throws if the provider is unreachable or returns an unusable body.
 */
export async function fetchEthUsd(): Promise<number> {
  return fetchCoinbaseSpot("ETH-USD");
}

async function fetchCoinbaseSpot(pair: string): Promise<number> {
  const url = `${COINBASE_BASE}/${pair}/spot`;
  const response = await fetch(url, {
    headers: { Accept: "application/json" },
  });
  if (!response.ok) {
    throw new Error(`${pair}: HTTP ${response.status}`);
  }

  const body: unknown = await response.json();

  // Shape: { data: { amount: "<decimal string>", base, currency } }
  const amount =
    isObject(body) && isObject(body.data)
      ? (body.data as Record<string, unknown>).amount
      : undefined;

  const parsed = typeof amount === "string" ? Number(amount) : NaN;
  if (!Number.isFinite(parsed) || parsed <= 0) {
    throw new Error(`${pair}: invalid amount in response`);
  }
  return parsed;
}

/**
 * Fetch fiat rates relative to USD for the requested currencies.
 *
 * The returned map always includes `USD: 1`, so consumers never need
 * a "if currency is USD" branch.
 *
 * @throws if the provider is unreachable or the response is malformed.
 */
export async function fetchFiatRates(
  currencies: readonly CurrencyCode[],
): Promise<Partial<Record<CurrencyCode, number>>> {
  const response = await fetch(ER_API_LATEST_USD_URL, {
    headers: { Accept: "application/json" },
  });
  if (!response.ok) {
    throw new Error(`fiat-rates: HTTP ${response.status}`);
  }

  const body: unknown = await response.json();

  if (
    !isObject(body) ||
    body.result !== "success" ||
    !isObject(body.rates)
  ) {
    throw new Error("fiat-rates: unexpected response shape");
  }

  const rates = body.rates as Record<string, unknown>;
  const out: Partial<Record<CurrencyCode, number>> = { USD: 1 };

  for (const currency of currencies) {
    if (currency === "USD") continue;
    const raw = rates[currency];
    if (typeof raw === "number" && Number.isFinite(raw) && raw > 0) {
      out[currency] = raw;
    }
  }

  return out;
}

/**
 * Fetch ETH/USD and fiat rates in parallel.
 * Convenience wrapper for consumers that need both at once.
 */
export async function fetchFxRates(): Promise<FxRates> {
  const currencies = SUPPORTED_CURRENCIES.map((c) => c.code);
  const [ethUsd, fiatPerUsd] = await Promise.all([
    fetchEthUsd(),
    fetchFiatRates(currencies),
  ]);
  return { ethUsd, fiatPerUsd };
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
