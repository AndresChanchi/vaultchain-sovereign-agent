"use client";

/**
 * Pricing chart — a clickable cost curve for the pricing card.
 *
 * Renders an SVG line chart: X axis is byte size (logarithmic, from
 * `MIN_BYTES` to `MAX_BYTES`), Y axis is the storage cost in USD
 * (linear, 0 to the cost at `MAX_BYTES`). The current selection is
 * highlighted with a filled dot.
 *
 * Interaction
 *   Clicking anywhere on the SVG sets the size to the corresponding
 *   byte value. Touch works the same. Keyboard control is handled by
 *   the number input in `PricingCard` — the chart is `aria-hidden`
 *   and purely visual, so screen-reader users interact through the
 *   number input, not the SVG. Standard split for charts that would
 *   otherwise be an unusual `role="slider"` on an SVG.
 *
 * Curve model — linear approximation anchored at the current quote
 *   `cost(bytes) = perByte × (bytes − IRYS_FREE)` for
 *   `bytes > IRYS_FREE`, `0` below the free threshold. `perByte` is
 *   derived from the current quote: `storageUsd / (bytes − IRYS_FREE)`.
 *
 *   Irys's pricing is approximately linear per byte above the free
 *   tier, so the curve is exact near the anchor point and a plausible
 *   extrapolation away from it. The alternative — querying Irys for
 *   every chart sample — would fire 32 requests per render for a curve
 *   visually indistinguishable from linear. Documented approximation,
 *   not a bug.
 *
 * Edge case — bytes ≤ free threshold
 *   When the user selects a size at or below Irys's free tier
 *   (`bytes ≤ IRYS_FREE`), `perByte` cannot be derived (there is no
 *   paid byte to divide by). The chart falls back to the same
 *   unavailable placeholder used when Irys fails. This is a rare
 *   case (the default is 5 MiB) and avoids inventing a rate.
 *
 * Overflow safety
 *   The wrapper is `max-w-full overflow-hidden` and the SVG uses
 *   `display: block` (via `block` class) plus `w-full` — combining
 *   these prevents the sub-pixel rounding that SVG inline-block
 *   descendants can introduce (a few pixels of horizontal overflow on
 *   some viewports) and clips any future overbleed. `html { overflow-x:
 *   clip }` in globals.css is the page-level backstop; this wrapper
 *   makes the fix local and reliable even if the global rule ever
 *   changes.
 *
 * Unavailable state
 *   When `storageUsd === null` (Irys not reachable) or the edge case
 *   above applies, the component renders a placeholder rectangle
 *   with `priceUnavailable` text. No curve, no dot, no click handler.
 *
 * Locale
 *   Byte-count labels below the chart come from the parent's
 *   `formatBytesShort`, so all byte strings in the card share the
 *   same formatting. The chart itself carries no text.
 */

import { useMemo } from "react";
import { IRYS_FREE_UPLOAD_BYTES } from "@config/pricing";

const MiB = 1024 * 1024;
const GiB = 1024 * MiB;
const TiB = 1024 * GiB;

/** Chart X range: 100 KiB → 1 TiB. The number input can go higher. */
const MIN_BYTES = IRYS_FREE_UPLOAD_BYTES;
const MAX_BYTES = TiB;

const LOG_MIN = Math.log(MIN_BYTES);
const LOG_MAX = Math.log(MAX_BYTES);
const LOG_RANGE = LOG_MAX - LOG_MIN;

/** SVG canvas size. Rendered scaled to the card width. */
const W = 320;
const H = 88;

type Props = {
  /** Current byte selection. */
  bytes: number;
  /** Storage-only cost in USD at `bytes`. `null` when Irys failed. */
  storageUsd: number | null;
  /** Called with the byte value corresponding to a click position. */
  onChange: (bytes: number) => void;
  /** i18n strings (already resolved by the parent). */
  unavailableLabel: string;
  minLabel: string;
  midLabel: string;
  maxLabel: string;
};

/**
 * Linear per-byte rate derived from the current anchor. Returns
 * `null` when the anchor is at or below the free threshold (no paid
 * bytes → no rate to derive) or when the quote is unavailable.
 */
function derivePerByteRate(
  bytes: number,
  storageUsd: number | null,
): number | null {
  if (storageUsd == null) return null;
  const paidBytes = bytes - IRYS_FREE_UPLOAD_BYTES;
  if (paidBytes <= 0) return null;
  return storageUsd / paidBytes;
}

/** Cost at `targetBytes` under the linear model anchored on `perByte`. */
function costAt(targetBytes: number, perByte: number): number {
  if (targetBytes <= IRYS_FREE_UPLOAD_BYTES) return 0;
  return perByte * (targetBytes - IRYS_FREE_UPLOAD_BYTES);
}

export function PricingChart({
  bytes,
  storageUsd,
  onChange,
  unavailableLabel,
  minLabel,
  midLabel,
  maxLabel,
}: Props) {
  const perByte = useMemo(
    () => derivePerByteRate(bytes, storageUsd),
    [bytes, storageUsd],
  );

  const svgPoints = useMemo(() => {
    if (perByte == null) return null;
    const maxCost = costAt(MAX_BYTES, perByte);
    if (maxCost <= 0) return null;
    const arr: { x: number; y: number }[] = [];
    const samples = 32;
    for (let i = 0; i <= samples; i++) {
      const t = i / samples;
      const b = Math.exp(LOG_MIN + LOG_RANGE * t);
      const c = costAt(b, perByte);
      arr.push({ x: t * W, y: H - (c / maxCost) * H });
    }
    return arr;
  }, [perByte]);

  const currentPoint = useMemo(() => {
    if (perByte == null) return null;
    const maxCost = costAt(MAX_BYTES, perByte);
    if (maxCost <= 0) return null;
    const clampedBytes = Math.max(MIN_BYTES, Math.min(MAX_BYTES, bytes));
    const t = (Math.log(clampedBytes) - LOG_MIN) / LOG_RANGE;
    return {
      x: t * W,
      y: H - (costAt(clampedBytes, perByte) / maxCost) * H,
    };
  }, [perByte, bytes]);

  function handleClick(e: React.MouseEvent<SVGSVGElement>) {
    const rect = e.currentTarget.getBoundingClientRect();
    const t = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width));
    onChange(Math.round(Math.exp(LOG_MIN + LOG_RANGE * t)));
  }

  if (svgPoints == null || currentPoint == null) {
    return (
      <div className="mt-4 flex h-[120px] max-w-full items-center justify-center overflow-hidden rounded-[10px] border border-dashed border-hairline bg-elevated/30">
        <span className="text-[12px] text-muted-soft">{unavailableLabel}</span>
      </div>
    );
  }

  const polyline = svgPoints
    .map((p) => `${p.x.toFixed(1)},${p.y.toFixed(1)}`)
    .join(" ");

  return (
    <div className="mt-4 max-w-full overflow-hidden">
      <svg
        viewBox={`0 0 ${W} ${H}`}
        preserveAspectRatio="none"
        role="img"
        aria-hidden="true"
        onClick={handleClick}
        className="block h-[88px] w-full cursor-pointer"
      >
        {/* baseline */}
        <line
          x1={0}
          y1={H}
          x2={W}
          y2={H}
          stroke="currentColor"
          strokeWidth={1}
          className="text-hairline"
        />
        {/* midpoint guide */}
        <line
          x1={0}
          y1={H / 2}
          x2={W}
          y2={H / 2}
          stroke="currentColor"
          strokeWidth={0.5}
          strokeDasharray="2 3"
          className="text-hairline"
        />
        {/* curve */}
        <polyline
          points={polyline}
          fill="none"
          stroke="var(--color-emerald)"
          strokeWidth={1.6}
          strokeLinejoin="round"
        />
        {/* current point */}
        <circle
          cx={currentPoint.x}
          cy={currentPoint.y}
          r={4}
          fill="var(--color-emerald)"
        />
        <circle
          cx={currentPoint.x}
          cy={currentPoint.y}
          r={8}
          fill="var(--color-emerald)"
          opacity={0.18}
        />
      </svg>
      <div className="mt-1 flex justify-between font-mono text-[10px] text-muted-soft">
        <span>{minLabel}</span>
        <span>{midLabel}</span>
        <span>{maxLabel}</span>
      </div>
    </div>
  );
}
