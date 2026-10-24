/**
 * FX fetches — ETH/USD spot and fiat rates, no API key required.
 *
 * Two providers, chosen for zero-config browser use:
 *
 *   ETH/USD   Coinbase public spot endpoint.
 *             `GET https://api.coinbase.com/v2/prices/ETH-USD/spot`
 *             → `{ data: { amount: "2500.00" } }`
 *             No key, CORS-enabled, generous rate limits. The amount
 *             is a decimal string.
 *
 *   Fiat      open.er-api.com Open Access endpoint.
 *             `GET https://open.er-api.com/v6/latest/USD`
 *             → `{ result: "success", rates: { COP: 4000, … } }`
 *             No key, updates daily. USD is always 1.
 *
 * Tradeoff acknowledged
 *   These are centralized reads. The quote is informational; the
 *   actual settlement price is fixed on-chain by `kipio_economics`
 *   and Irys at transaction time. A centralized FX read therefore
 *   cannot redirect funds — at worst it shows a slightly off display
 *   amount for a few minutes. The path to full sovereignty is
 *   Chainlink on Arbitrum (on-chain read via viem), documented as a
 *   TODO per function. Do not over-engineer that now; a Chainlink
 *   read adds an RPC round-trip and a contract address that would
 *   need pinning per chain.
 *
 * Both functions throw on hard failure. The hook wraps them in
 * TanStack Query, which converts throws into the standard `isError`
 * state. Consumers decide how to render (usually "—").
 */

import type { CurrencyCode } from "@config/pricing";
import { SUPPORTED_CURRENCIES } from "@config/pricing";
import type { FxRates } from "./types";

const COINBASE_ETH_USD_URL =
  "https://api.coinbase.com/v2/prices/ETH-USD/spot";
const ER_API_LATEST_USD_URL = "https://open.er-api.com/v6/latest/USD";

/**
 * Fetch the current ETH/USD spot rate.
 *
 * @throws if the provider is unreachable or returns an unusable body.
 *   Callers convert to a UI state; this function does not swallow.
 *
 * TODO (sovereignty): replace with a Chainlink `AggregatorV3Interface`
 * read on Arbitrum via viem. The feed address would move to
 * `@config/pricing` and this function would take a viem public client
 * as input. Not done now — the config does not yet have an RPC URL
 * for the read path, and the landing quote does not need on-chain
 * freshness.
 */
export async function fetchEthUsd(): Promise<number> {
  const response = await fetch(COINBASE_ETH_USD_URL, {
    headers: { Accept: "application/json" },
  });
  if (!response.ok) {
    throw new Error(`eth-usd: HTTP ${response.status}`);
  }

  const body: unknown = await response.json();

  // Shape: { data: { amount: "<decimal string>", base, currency } }
  const amount =
    isObject(body) && isObject(body.data)
      ? (body.data as Record<string, unknown>).amount
      : undefined;

  const parsed = typeof amount === "string" ? Number(amount) : NaN;
  if (!Number.isFinite(parsed) || parsed <= 0) {
    throw new Error("eth-usd: invalid amount in response");
  }
  return parsed;
}

/**
 * Fetch fiat rates relative to USD for the requested currencies.
 *
 * The returned map always includes `USD: 1`, so consumers never need
 * a "if currency is USD" branch.
 *
 * Unknown currency codes (not returned by the provider) are simply
 * absent from the map — consumers check `typeof rate === "number"`
 * before use.
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

  // Shape: { result: "success", base_code: "USD", rates: { ... } }
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
    if (currency === "USD") continue; // already set
    const raw = rates[currency];
    if (typeof raw === "number" && Number.isFinite(raw) && raw > 0) {
      out[currency] = raw;
    }
  }

  return out;
}

/**
 * Fetch ETH/USD and fiat rates in parallel.
 *
 * Convenience wrapper for consumers that need both at once (a Server
 * Component prefetch, a test harness). The React hook uses two
 * separate `useQuery` calls instead, so each rate has its own TTL
 * (see `@config/pricing`).
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
