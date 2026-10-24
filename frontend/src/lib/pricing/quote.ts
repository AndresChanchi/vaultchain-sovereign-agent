/**
 * Pure quote calculation. No I/O, no React, no globals.
 *
 * Inputs come through `QuoteInput`; outputs through `Quote`. This is
 * the only file in the pricing module that can be unit-tested with
 * plain object literals — no fetch mocks, no SDK stubs, no React
 * Testing Library.
 *
 * Consumers
 *   - `hooks/pricing/useUploadQuote.ts` (production).
 *   - Unit tests (add `quote.test.ts` next to this file when the first
 *     regression appears; the pure shape makes it trivial).
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
 * BigInt → number loses precision beyond 2^53, which for wei means
 * amounts above ~9 ETH. A single photo's storage cost is orders of
 * magnitude below that, so the loss is irrelevant here. Documented so
 * a future reader does not "fix" it with a bignum library that would
 * add weight for no benefit in this context.
 */
function weiToEth(wei: bigint): number {
  return Number(wei) / Number(WEI_PER_ETH);
}

/**
 * Compute a display-ready quote from already-fetched inputs.
 *
 * Steps:
 *   1. Storage USD: from Irys (ETH atomic → ETH → USD) or 0 if free.
 *   2. Kipio fee USD: storage × feeBps / 10_000. Null if feeBps null.
 *   3. Gas buffer USD: passed through.
 *   4. Total USD: sum of the three, or null if any is null.
 *   5. Total in display currency: total × fiatPerUsd[currency].
 */
export function computeQuote(input: QuoteInput): Quote {
  const { irys, fx, currency, kipioFeeBps, gasBufferUsd } = input;

  // ── 1. Storage ────────────────────────────────────────────────────
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

  // ── 2. Kipio fee ──────────────────────────────────────────────────
  // Computed on storage only (not on gas). If storage is null or the
  // fee bps is unknown, the fee is null — never defaulted to 0, which
  // would hide the missing data.
  let kipioFeeUsd: number | null;
  if (storageUsd !== null && kipioFeeBps !== null) {
    kipioFeeUsd = (storageUsd * kipioFeeBps) / 10_000;
  } else {
    kipioFeeUsd = null;
  }

  // ── 3. Gas buffer ─────────────────────────────────────────────────
  const gasBufferUsdOut = gasBufferUsd;

  // ── 4. Total USD ──────────────────────────────────────────────────
  let totalUsd: number | null;
  if (
    storageUsd !== null &&
    kipioFeeUsd !== null
  ) {
    totalUsd = storageUsd + kipioFeeUsd + gasBufferUsdOut;
  } else {
    totalUsd = null;
  }

  // ── 5. Display currency ───────────────────────────────────────────
  let totalDisplay: number | null;
  if (totalUsd !== null) {
    // USD is always present in fiatPerUsd (see fetchFiatRates), so
    // the currency === "USD" case does not need a special branch.
    const rate = fx.fiatPerUsd[currency];
    totalDisplay = typeof rate === "number" ? totalUsd * rate : null;
  } else {
    totalDisplay = null;
  }

  const incomplete =
    storageUsd === null ||
    kipioFeeUsd === null ||
    totalUsd === null ||
    totalDisplay === null;

  return {
    currency,
    free,
    storageUsd,
    kipioFeeUsd,
    gasBufferUsd: gasBufferUsdOut,
    totalUsd,
    totalDisplay,
    incomplete,
  };
}
