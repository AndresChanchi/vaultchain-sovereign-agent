"use client";

import { useI18n } from "@context/I18nContext";

/**
 * "Not on our servers" — network visualization panel.
 *
 * A 520×360 SVG showing an emerald lock at the center, eight dashed
 * lines radiating to eight of the eighteen surrounding dots, and three
 * floating glass chips annotating the semantics:
 *
 *   - "Arbitrum · who it belongs to"      (top-left, violet)
 *   - "Locked copies · only your key opens them"  (bottom-left)
 *   - "Irys · where it is kept"           (bottom-right, emerald)
 *
 * The 10 dots not connected to the center are purely ambient — they
 * fill the composition to read as "many computers". They carry no
 * semantics and no interaction.
 *
 * Client Component
 *   `useI18n()` provides `t()` for the three chips. The coordinates
 *   are not translated (they are geometry, not prose); only the chip
 *   text changes on locale switch. Making this a Client Component
 *   adds a small amount of JS to the page, but the SSR output is
 *   identical — the initial HTML already carries the fully-rendered
 *   SVG and animated chips.
 *
 * Static coordinate data
 *   `LINE_ENDPOINTS` and `DOTS` are module-level `as const` arrays.
 *   They do not depend on state, locale, or props — moving them out
 *   of the render function means they are allocated once per module
 *   load instead of once per render (which fires on each locale
 *   switch, since `useI18n()` re-renders the tree). Same coordinates
 *   and same order as the previous in-render arrays.
 *
 * Chip text and the "·" separator
 *   The `Arbitrum` and `Irys` chips combine two dictionary keys
 *   (`*Label` for the proper noun, `*Annotation` for the muted
 *   description) with a literal ` · ` (middle dot with spaces)
 *   rendered in JSX. The `lockedCopies` chip is a single key that
 *   already includes the separator, so translators can adjust it.
 *
 *   Keeping the separator in JSX for the two labeled chips is a
 *   deliberate tradeoff: it lets the annotation be styled with its own
 *   class (`text-violet-text` / `text-emerald-text`) without needing
 *   HTML in the dictionary value. If a locale needs different spacing
 *   around the dot, the alternative is to make each chip a single
 *   dictionary key with placeholders (`"{label} · {annotation}"`) —
 *   change when a concrete case appears, not preemptively.
 *
 * CSS class fix (`mono` → `font-mono`)
 *   The previous version used `className="glass mono ..."` on the
 *   chips. `mono` is not a defined class in `globals.css` — the
 *   project's mono utility is Tailwind's `font-mono` (which consumes
 *   `--font-mono` from `@theme`). The chips were silently rendering
 *   in sans-serif. Corrected here as part of the migration.
 *
 * Reused classes from globals.css
 *   - `journey-line` — 3px dash / 7px gap with a 2.2s linear dash
 *     motion. Shared with `JourneyStage` and `SignIn`; a class change
 *     affects all three.
 *   - `network-node` — 3s ease-in-out opacity pulse (1 → 0.25 → 1).
 *     Distinct from `journey-node` (which scales); the standalone panel
 *     uses opacity, the slide uses scale.
 *
 * Reduced motion
 *   Under `prefers-reduced-motion: reduce`, both animations resolve to
 *   `animation: none` via the token overrides in globals.css. Dots
 *   sit at their base opacity (1), lines at their base opacity (0.7).
 *   The panel remains legible.
 *
 * Sizing
 *   `h-[300px] md:h-[380px]`, matching the mockup's mobile override.
 *   The SVG fills it with `preserveAspectRatio="xMidYMid slice"` so
 *   it scales to cover — never letterboxes. `overflow-hidden` on the
 *   container clips cleanly against the `rounded-card` radius.
 *
 * Stagger
 *   Dot pulse delay is `i * 0.1s` (i = 0..17), producing a real
 *   100ms step between consecutive dots. This is documented in the
 *   previous header as a fix for the mockup's `.1s`/`.10s` collision
 *   — retained unchanged.
 */

/** 8 line endpoints. Order matches the visual composition. */
const LINE_ENDPOINTS = [
  { x: 60, y: 60 },
  { x: 230, y: 70 },
  { x: 430, y: 70 },
  { x: 440, y: 250 },
  { x: 250, y: 330 },
  { x: 70, y: 250 },
  { x: 120, y: 150 },
  { x: 330, y: 250 },
] as const;

/**
 * 18 ambient dots, of which 8 overlap the line endpoints above. The
 * remaining 10 are decorative. Order defines the stagger sequence.
 */
const DOTS = [
  { x: 60, y: 60 },
  { x: 140, y: 40 },
  { x: 230, y: 70 },
  { x: 330, y: 40 },
  { x: 430, y: 70 },
  { x: 470, y: 150 },
  { x: 440, y: 250 },
  { x: 360, y: 310 },
  { x: 250, y: 330 },
  { x: 150, y: 300 },
  { x: 70, y: 250 },
  { x: 40, y: 160 },
  { x: 120, y: 150 },
  { x: 400, y: 160 },
  { x: 330, y: 250 },
  { x: 180, y: 230 },
  { x: 230, y: 120 },
  { x: 310, y: 110 },
] as const;

export function NetworkViz() {
  const { t } = useI18n();

  return (
    <div className="relative h-[300px] overflow-hidden rounded-card border border-hairline bg-card md:h-[380px]">
      <svg
        viewBox="0 0 520 360"
        preserveAspectRatio="xMidYMid slice"
        className="h-full w-full"
        aria-hidden="true"
      >
        {LINE_ENDPOINTS.map((p, i) => (
          <line
            key={`line-${i}`}
            x1="260"
            y1="180"
            x2={p.x}
            y2={p.y}
            className="journey-line stroke-emerald"
            strokeWidth="1.5"
          />
        ))}

        {DOTS.map((p, i) => (
          <circle
            key={`dot-${i}`}
            cx={p.x}
            cy={p.y}
            r="5"
            className="network-node fill-emerald-text"
            style={
              {
                "--network-node-delay": `${i * 0.1}s`,
              } as React.CSSProperties
            }
          />
        ))}

        {/* Center — solid emerald disc with a lock glyph. */}
        <circle cx="260" cy="180" r="30" className="fill-emerald" />
        <g
          transform="translate(248 168)"
          fill="none"
          stroke="#04130d"
          strokeWidth="2"
          strokeLinecap="round"
        >
          <rect x="2" y="10" width="20" height="14" rx="3" />
          <path d="M6 10V7a6 6 0 0 1 12 0v3" />
        </g>
      </svg>

      <span className="glass absolute left-3.5 top-3.5 rounded-full px-3 py-1.5 font-mono text-[12px]">
        <span className="text-violet-text">
          {t("landing.notOnServers.networkViz.arbitrumLabel")}
        </span>{" "}
        ·{" "}
        {t("landing.notOnServers.networkViz.arbitrumAnnotation")}
      </span>

      <span className="glass absolute bottom-14 left-3.5 rounded-full px-3 py-1.5 font-mono text-[12px]">
        {t("landing.notOnServers.networkViz.lockedCopies")}
      </span>

      <span className="glass absolute bottom-3.5 right-3.5 rounded-full px-3 py-1.5 font-mono text-[12px]">
        <span className="text-emerald-text">
          {t("landing.notOnServers.networkViz.irysLabel")}
        </span>{" "}
        ·{" "}
        {t("landing.notOnServers.networkViz.irysAnnotation")}
      </span>
    </div>
  );
}
