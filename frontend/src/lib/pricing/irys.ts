/**
 * Irys price fetch — asks the L1 uploader for the price of **1 GiB**
 * in ETH wei, then scales linearly to the requested byte count.
 *
 * **Endpoint: uploader.irys.xyz (L1) — NOT node2.irys.xyz (Bundlr)**
 *
 * The legacy Bundlr endpoint returns prices in the old AR-denominated
 * model, which is not what Irys charges today. The L1 endpoint returns
 * ETH wei when the token parameter is `"arbitrum"`.
 *
 * Verified October 2026:
 *   uploader.irys.xyz/price/arbitrum/1GiB → 1284654946983374 wei
 *   → 0.00128 ETH × $2353 ≈ $3.02/GiB (matches Irys's ~$2.50/GB
 *     planning estimate)
 *
 *   node2.irys.xyz/price/arbitrum/1GiB  → 58864981745681107
 *   → 0.0588 AR × $15 ≈ $0.88/GiB (old Bundlr model, deprecated)
 *
 * Reference size
 *   Irys pricing is linear per byte. Verified:
 *     1 GiB → 1284654946983374 wei
 *     1 MiB → 1254545846664 wei
 *     1284654946983374 / 1024 ≈ 1254545846664  (exact ratio)
 *
 *   Ask for 1 GiB once and multiply by `bytes / reference`:
 *     - Works for any size without depending on the endpoint accepting
 *       arbitrary byte counts.
 *     - One cache entry per term shared by every size.
 *
 * Term pricing
 *   The public `?term=` parameter is **ignored** by the bundler
 *   (verified: identical response for `permanent`, `term:30`,
 *   `term:365`). Every term request returns the permanent price for
 *   the reference size, which is a legitimate upper bound — terms
 *   cost less, not more. The result is marked `termFallback: true`
 *   so the UI shows `pricing.termFallbackNote`.
 *
 *   When Cascade exposes a working REST term endpoint, replace
 *   `fetchReferencePrice` and the fallback flag in one place.
 *
 * Free threshold
 *   Uploads under 100 KiB are free. Checked before the network call.
 */

import {
  IRYS_BUNDLER_URL,
  IRYS_FREE_UPLOAD_BYTES,
  IRYS_PRICE_REFERENCE_BYTES,
  IRYS_TOKEN,
} from "@config/pricing";
import type { IrysPriceResult, Term } from "./types";

function referencePriceUrl(): string {
  return `${IRYS_BUNDLER_URL}/price/${IRYS_TOKEN}/${IRYS_PRICE_REFERENCE_BYTES}`;
}

function termPriceUrl(days: number): string {
  // TODO: replace `?term={days}` with the exact parameter used by the
  // Cascade term-ledger price route once it is documented or exposed.
  // The bundler currently ignores this parameter and returns the
  // permanent price; the caller treats this as a fallback.
  return `${IRYS_BUNDLER_URL}/price/${IRYS_TOKEN}/${IRYS_PRICE_REFERENCE_BYTES}?term=${days}`;
}

function extractAtomicPrice(body: unknown): string | null {
  if (typeof body === "number" && Number.isFinite(body) && body > 0) {
    return String(Math.trunc(body));
  }
  if (typeof body === "string" && /^\d+$/.test(body)) {
    return body;
  }
  if (typeof body === "object" && body !== null) {
    const obj = body as Record<string, unknown>;
    for (const key of ["price", "amount"] as const) {
      const v = obj[key];
      if (typeof v === "number" && Number.isFinite(v) && v > 0) {
        return String(Math.trunc(v));
      }
      if (typeof v === "string" && /^\d+$/.test(v)) {
        return v;
      }
    }
  }
  return null;
}

function logDev(message: string, payload: Record<string, unknown>) {
  if (process.env.NODE_ENV === "development") {
    console.warn(`[irys] ${message}`, payload);
  }
}

async function fetchReferencePrice(url: string): Promise<bigint | null> {
  let response: Response;
  try {
    response = await fetch(url, { headers: { Accept: "application/json" } });
  } catch (err) {
    logDev("network error", { url, err: String(err) });
    return null;
  }

  if (!response.ok) {
    logDev("http error", { url, status: response.status });
    return null;
  }

  let body: unknown;
  try {
    body = await response.json();
  } catch (err) {
    logDev("invalid json", { url, err: String(err) });
    return null;
  }

  const raw = extractAtomicPrice(body);
  if (raw === null) {
    logDev("unexpected shape", { url, body });
    return null;
  }

  try {
    return BigInt(raw);
  } catch {
    logDev("non-integer price", { url, body, raw });
    return null;
  }
}

export async function fetchIrysPrice(
  bytes: number,
  term: Term,
): Promise<IrysPriceResult> {
  if (!Number.isFinite(bytes) || bytes < 0) {
    return { status: "unavailable", reason: "invalid-bytes" };
  }

  if (bytes <= IRYS_FREE_UPLOAD_BYTES) {
    return { status: "free" };
  }

  // ── 1. Reference price ──────────────────────────────────────────
  let referenceEthAtomic: bigint | null = null;
  let termFallback = false;

  if (term.kind === "permanent") {
    referenceEthAtomic = await fetchReferencePrice(referencePriceUrl());
  } else {
    // The bundler ignores `?term=` and returns the permanent price.
    // Fetch it explicitly, compare, and mark as fallback.
    const termResult = await fetchReferencePrice(termPriceUrl(term.days));
    const permanentResult = await fetchReferencePrice(referencePriceUrl());

    if (termResult === null) {
      referenceEthAtomic = permanentResult;
      termFallback = true;
    } else if (permanentResult !== null && termResult === permanentResult) {
      // Bundler ignored `?term=` — this is the permanent price, not
      // the term price. Use it as an upper bound with a note.
      referenceEthAtomic = termResult;
      termFallback = true;
    } else {
      referenceEthAtomic = termResult;
    }
  }

  if (referenceEthAtomic === null) {
    return { status: "unavailable", reason: "reference-price-unavailable" };
  }

  // ── 2. Scale linearly to requested bytes ────────────────────────
  const scaled =
    (referenceEthAtomic * BigInt(Math.round(bytes))) /
    BigInt(IRYS_PRICE_REFERENCE_BYTES);

  if (scaled <= 0n) {
    return { status: "unavailable", reason: "non-positive-scaled-price" };
  }

  logDev("ok", {
    term: term.kind === "permanent" ? "permanent" : `term:${term.days}`,
    termFallback,
    bytes,
    referenceEthAtomic: referenceEthAtomic.toString(),
    scaledEthAtomic: scaled.toString(),
  });

  return termFallback
    ? { status: "ok", ethAtomic: scaled, termFallback: true }
    : { status: "ok", ethAtomic: scaled };
}
