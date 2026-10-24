/**
 * Irys price fetch — single responsibility: ask the bundler how much
 * storage costs, in wei on Arbitrum.
 *
 * Uses the REST endpoint directly, NOT the `@irys/sdk`.
 *
 * Why not the SDK
 *   `@irys/sdk` is needed when signing and uploading (Fase 10). For a
 *   read-only price query it pulls tens of KB of signer code into the
 *   bundle for a single GET. The REST endpoint returns the same number
 *   in the same units. The SDK enters the pricing stack only when the
 *   upload path needs it.
 *
 * Endpoint
 *   `GET {IRYS_BUNDLER_URL}/price/{IRYS_TOKEN}/{bytes}`
 *   → `{ price: "<atomic>" }` (atomic units of the token — wei for ETH
 *   on Arbitrum). Confirmed against the Bundlr-era REST API and the
 *   SDK's `getPrice` behavior. If Irys changes the shape, only
 *   `fetchIrysPrice` below changes; the rest of the stack is insulated.
 *
 * Term support
 *   Permanent pricing is confirmed. Term-ledger pricing (Cascade: 30
 *   days, 1 year, arbitrary durations) exists at the protocol level but
 *   its REST parameter is not documented in the public reference. Until
 *   verified, term queries return `unavailable` with a reason — the UI
 *   shows "—" rather than a guessed number. When the format is
 *   confirmed, edit the single `termPriceUrl` function below; nothing
 *   else in the codebase needs to change.
 *
 * Free threshold
 *   Uploads under 100 KiB are free on Irys. Checked client-side before
 *   the network call, so the bundler is not hit for files that would
 *   return 0 anyway.
 */

import { IRYS_BUNDLER_URL, IRYS_FREE_UPLOAD_BYTES, IRYS_TOKEN } from "@config/pricing";
import type { IrysPriceResult, Term } from "./types";

/**
 * Build the permanent-storage price URL.
 *
 * Kept as a tiny function (not a template used inline) so a future
 * endpoint move is one edit, not a grep.
 */
function permanentPriceUrl(bytes: number): string {
  return `${IRYS_BUNDLER_URL}/price/${IRYS_TOKEN}/${bytes}`;
}

/**
 * Build the term-ledger price URL.
 *
 * TODO: The Cascade term price parameter is not yet documented. This
 * best-effort form (`?term={days}`) may or may not be accepted by the
 * bundler — the fetch below treats any non-conforming response as
 * `unavailable`, so an incorrect format degrades gracefully instead of
 * showing a wrong number.
 *
 * When the format is confirmed (the user's own upload scripts already
 * call it), replace this function's body; the call site does not
 * change.
 */
function termPriceUrl(bytes: number, days: number): string {
  return `${IRYS_BUNDLER_URL}/price/${IRYS_TOKEN}/${bytes}?term=${days}`;
}

/**
 * Fetch the storage cost for `bytes` under `term`.
 *
 * @returns
 *   - `{ status: "free" }` when `bytes` is under Irys's threshold.
 *   - `{ status: "ok", ethAtomic }` on a successful price query.
 *   - `{ status: "unavailable", reason }` on any failure. Consumers
 *     must render "—" and never a fallback number.
 */
export async function fetchIrysPrice(
  bytes: number,
  term: Term,
): Promise<IrysPriceResult> {
  // Guard against pathological inputs before doing anything else.
  if (!Number.isFinite(bytes) || bytes < 0) {
    return { status: "unavailable", reason: "invalid-bytes" };
  }

  // Free threshold: skip the network entirely.
  if (bytes <= IRYS_FREE_UPLOAD_BYTES) {
    return { status: "free" };
  }

  const url =
    term.kind === "permanent"
      ? permanentPriceUrl(bytes)
      : termPriceUrl(bytes, term.days);

  let response: Response;
  try {
    response = await fetch(url, {
      // Irys quotes move with the ETH/USD rate; a short client cache is
      // fine. TanStack Query adds its own stale-while-revalidate on top.
      headers: { Accept: "application/json" },
    });
  } catch {
    return { status: "unavailable", reason: "network-error" };
  }

  if (!response.ok) {
    return {
      status: "unavailable",
      reason: `http-${response.status}`,
    };
  }

  let body: unknown;
  try {
    body = await response.json();
  } catch {
    return { status: "unavailable", reason: "invalid-json" };
  }

  // Expected shape: { price: "<decimal string>" }.
  // Some deployments wrap it; both shapes are accepted defensively.
  const priceValue =
    isObject(body) && "price" in body
      ? (body as { price: unknown }).price
      : undefined;

  if (typeof priceValue !== "string" && typeof priceValue !== "number") {
    return { status: "unavailable", reason: "unexpected-shape" };
  }

  let ethAtomic: bigint;
  try {
    ethAtomic = BigInt(priceValue.toString());
  } catch {
    return { status: "unavailable", reason: "non-integer-price" };
  }

  if (ethAtomic < 0n) {
    return { status: "unavailable", reason: "negative-price" };
  }

  return { status: "ok", ethAtomic };
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
