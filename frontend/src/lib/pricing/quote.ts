/**
 * Pure quote calculation. No I/O, no React, no globals.
 *
 * Inputs come through `QuoteInput`; outputs through `Quote`. This is
 * the only file in the pricing module that can be unit-tested with
 * plain object literals — no fetch mocks, no SDK stubs, no React
 * Testing Library.
 *
 * Two views per monetary field
 *   Every field appears twice in `Quote`:
 *     - `*Usd`     — the raw USD amount (used internally, for the fee
 *                    calculation, and for debugging).
 *     - `*Display` — the same amount converted to `currency` via
 *                    `fx.fiatPerUsd[currency]`.
 *
 *   The UI must format the `*Display` fields. Formatting `*Usd` with
 *   the target currency's formatter produces the classic
 *   `COP 3`-for-`$3` bug: the formatter treats the raw number as if
 *   it were already in the target currency.
 *
 * Storage pricing
 *   Irys returns ETH wei for the `arbitrum` token parameter (see
 *   `IrysPriceResult.ethAtomic`). The storage cost in USD is:
 *
 *     storageUsd = (ethAtomic / 1e18) × fx.ethUsd
 *
 *   Do NOT multiply by an AR rate — Irys L1 is not Arweave. Do NOT
 *   multiply by an IRYS rate — the native IRYS token is not the
 *   payment unit for `arbitrum`.
 *
 * Rounding
 *   No rounding here. `storageUsd` for a small photo can be $0.0003;
 *   rounding to 2 decimals at this layer would collapse it to $0.00
 *   and hide the real cost from the UI. Consumers format.
 */

import type { Quote, QuoteInput } from "./types";

/** 1 ETH = 1e18 wei. Named so call sites read clearly. */
const WEI_PER_ETH = 1_000_000_000_000_000_000n;

/**
 * Convert wei (bigint) to ETH (number).
 *
 * BigInt → number loses precision beyond 2^53. For 1 GiB the value is
 * ~1.28e15 wei, which is under 2^53 (~9e15). For very large uploads
 * (100+ TiB) precision could degrade, but a single photo is orders of
 * magnitude below that threshold. Documented for future readers.
 */
function weiToEth(wei: bigint): number {
  return Number(wei) / Number(WEI_PER_ETH);
}

/**
 * Compute a display-ready quote from already-fetched inputs.
 *
 * Steps:
 *   1. Storage USD: from Irys (ETH wei → ETH → USD) or 0 if free.
 *   2. Kipio fee USD: storage × feeBps / 10_000.
 *   3. Gas buffer USD: passed through.
 *   4. Total USD: sum of the three, or null if any is null.
 *   5. For every monetary field, produce the `*Display` variant by
 *      multiplying by `fx.fiatPerUsd[currency]`. USD has rate 1, so
 *      the USD case falls through the same path without a branch.
 */
export function computeQuote(input: QuoteInput): Quote {
  const { irys, fx, currency, kipioFeeBps, gasBufferUsd } = input;

  // ── 1. Storage (USD) ──────────────────────────────────────────────
  let storageUsd: number | null;
  let free = false;

  if (irys.status === "free") {
    storageUsd = 0;
    free = true;
  } else if (irys.status === "ok") {
    storageUsd = weiToEth(irys.ethAtomic) * fx.ethUsd;
  } else {
    storageUsd = null;
  }

  // ── 2. Kipio fee (USD) ────────────────────────────────────────────
  let kipioFeeUsd: number | null;
  if (storageUsd !== null && kipioFeeBps !== null) {
    kipioFeeUsd = (storageUsd * kipioFeeBps) / 10_000;
  } else {
    kipioFeeUsd = null;
  }

  // ── 3. Gas buffer (USD) ───────────────────────────────────────────
  const gasBufferUsdOut = gasBufferUsd;

  // ── 4. Total (USD) ────────────────────────────────────────────────
  let totalUsd: number | null;
  if (storageUsd !== null && kipioFeeUsd !== null) {
    totalUsd = storageUsd + kipioFeeUsd + gasBufferUsdOut;
  } else {
    totalUsd = null;
  }

  // ── 5. Convert every monetary field to `currency` ─────────────────
  // `fiatPerUsd` always has `USD: 1`, so the USD case is not special.
  // A missing rate (unsupported currency) produces `null` for the
  // `*Display` fields, and the UI renders `—`.
  const fiatRate = fx.fiatPerUsd[currency];
  const rate = typeof fiatRate === "number" ? fiatRate : null;

  const storageDisplay =
    storageUsd !== null && rate !== null ? storageUsd * rate : null;
  const kipioFeeDisplay =
    kipioFeeUsd !== null && rate !== null ? kipioFeeUsd * rate : null;
  const totalDisplay =
    totalUsd !== null && rate !== null ? totalUsd * rate : null;

  const incomplete =
    storageUsd === null ||
    kipioFeeUsd === null ||
    totalUsd === null ||
    storageDisplay === null ||
    kipioFeeDisplay === null ||
    totalDisplay === null;

  const termFallback = irys.status === "ok" && irys.termFallback === true;

  return {
    currency,
    free,
    storageUsd,
    kipioFeeUsd,
    gasBufferUsd: gasBufferUsdOut,
    totalUsd,
    storageDisplay,
    kipioFeeDisplay,
    totalDisplay,
    incomplete,
    termFallback,
  };
}
