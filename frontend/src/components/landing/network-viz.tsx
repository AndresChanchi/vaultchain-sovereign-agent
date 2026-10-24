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
 * Reused classes from globals.css
 *   - `journey-line` — 3px dash / 7px gap with a 2.2s linear dash
 *     motion. The mockup defines this as `.ln` and shares it with the
 *     JourneyStage network slide; reusing the same class keeps both
 *     visuals in lockstep. If the dash style ever changes, both panels
 *     update together.
 *   - `network-node` — 3s ease-in-out opacity pulse (1 → 0.25 → 1).
 *     Distinct from `journey-node` (which scales 0.92 → 1); the mockup
 *     uses opacity for the standalone panel and scale for the slide.
 *     Stagger comes from `--network-node-delay` set inline per dot.
 *
 * Motion is CSS-only
 *   Both animations are declared in globals.css. This component is a
 *   Server Component — no `"use client"`, no state, no effects, no
 *   refs. The pulse and dash-motion start on page load and loop until
 *   unload, matching the mockup's continuous behavior.
 *
 * Reduced motion
 *   Under `prefers-reduced-motion: reduce`, both animations resolve to
 *   `animation: none` via the token overrides in globals.css. Dots
 *   sit at their base opacity (1), lines at their base opacity (0.7).
 *   The panel remains legible — no interaction is lost because there
 *   is none to lose.
 *
 * Sizing
 *   The outer container is `h-[300px] md:h-[380px]`, matching the
 *   mockup's `@media (max-width: 700px) { .nv { height: 300px } }`
 *   override. The SVG fills it with `preserveAspectRatio="xMidYMid
 *   slice"`, so it scales to cover — never letterboxes. `overflow-hidden`
 *   on the container clips the SVG's corners cleanly against the
 *   `rounded-card` radius.
 *
 *   Coordinates and stagger: the mockup has a bug in its animation
 *   delays (`.10s`, `.11s`, etc. in the inline style collide with
 *   `.1s`, `.2s`, etc.). The stagger here uses `i * 0.1s` for i=0..17,
 *   producing a real 100ms step between consecutive dots. Visually
 *   this reads as a wave that travels around the composition; the
 *   mockup's bug produced clusters at 100ms, 200ms, ... with no
 *   distinction between `.1s` and `.10s`.
 *
 * Consumer contract
 *   Renders a self-contained block. Parent decides the width; the
 *   component is a full-width block at its own natural height. Canonical
 *   usage:
 *
 *     <div className="lg:w-1/2">
 *       <NetworkViz />
 *     </div>
 */
export function NetworkViz() {
  // 8 line endpoints. The other 10 of the 18 dots are not connected to
  // the center; they are ambient. Order matches the mockup's line
  // order so the visual arrangement of connected vs. disconnected
  // dots is preserved.
  const lineEndpoints = [
    { x: 60, y: 60 },
    { x: 230, y: 70 },
    { x: 430, y: 70 },
    { x: 440, y: 250 },
    { x: 250, y: 330 },
    { x: 70, y: 250 },
    { x: 120, y: 150 },
    { x: 330, y: 250 },
  ] as const;

  // 18 ambient dots, of which 8 overlap the line endpoints above. The
  // remaining 10 are decorative. Order defines the stagger sequence
  // (`--network-node-delay`): a dot's delay is `index * 0.1s`.
  const dots = [
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

  return (
    <div className="relative h-[300px] overflow-hidden rounded-card border border-hairline bg-card md:h-[380px]">
      <svg
        viewBox="0 0 520 360"
        preserveAspectRatio="xMidYMid slice"
        className="h-full w-full"
        aria-hidden="true"
      >
        {lineEndpoints.map((p, i) => (
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

        {dots.map((p, i) => (
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

        {/* Center — solid emerald disc with a lock glyph. Position and
            size match the mockup's `<circle cx="260" cy="180" r="30">`
            with the lock icon centered at (248, 168). */}
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

      <span className="glass mono absolute left-3.5 top-3.5 rounded-full px-3 py-1.5 text-[12px]">
        <span className="text-violet-text">Arbitrum</span> · who it belongs to
      </span>

      <span className="glass mono absolute bottom-14 left-3.5 rounded-full px-3 py-1.5 text-[12px]">
        Locked copies · only your key opens them
      </span>

      <span className="glass mono absolute bottom-3.5 right-3.5 rounded-full px-3 py-1.5 text-[12px]">
        <span className="text-emerald-text">Irys</span> · where it is kept
      </span>
    </div>
  );
}
