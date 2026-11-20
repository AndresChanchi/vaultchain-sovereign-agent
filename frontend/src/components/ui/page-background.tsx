/**
 * Page background — the atmospheric substrate behind app content.
 *
 * Three layers:
 *   - a 1200×900 radial glow anchored above the viewport, centered
 *     horizontally (`.glow` in the mockup);
 *   - an emerald halo drifting slowly toward bottom-right (`.orb.o1`);
 *   - a violet halo drifting slowly toward top-left (`.orb.o2`).
 *
 * Why radial-gradient and not blur()
 *   The previous implementation used `bg-emerald/[0.16] blur-[90px]` on
 *   360-420px circles. The GPU cost of a 90px blur on a 400px surface
 *   at 60fps is enormous on Safari, and the effect is exactly the
 *   same: a soft, diffuse halo. `radial-gradient` achieves the visual
 *   result with zero filter cost — the browser rasterises the
 *   gradient once and only `transform` (translate) animates, which
 *   stays entirely on the compositor.
 *
 *   Rule of thumb that this component now follows: never animate a
 *   `blur()`/`backdrop-filter` surface larger than 20px, and never on
 *   iOS. See `globals.css` for the remaining `blur-[90px]` on
 *   `.device-rail-dot` (a 6px element, negligible).
 *
 * Parent requirements
 *   The parent must be `position: relative` and create a stacking
 *   context (`isolate`) so the layers sit above the page colour but
 *   below the content.
 *
 * Motion
 *   Both halos drift on `--animate-orb-drift-*` tokens, overridden to
 *   `none` under `prefers-reduced-motion: reduce`. The central glow
 *   gets `scroll()`-driven parallax via `page-glow`, gated behind
 *   `@supports (animation-timeline: scroll())` and
 *   `prefers-reduced-motion: no-preference`.
 */
export function PageBackground() {
  return (
    <div
      aria-hidden="true"
      className="pointer-events-none absolute inset-0 -z-10 overflow-hidden"
    >
      {/* Central hero glow — parallax on scroll (where supported). */}
      <div
        className="page-glow absolute -top-[140px] left-1/2 -ml-[600px] h-[900px] w-[1200px]"
        style={{
          background:
            "radial-gradient(closest-side, oklch(0.70 0.15 160 / 0.22), oklch(0.70 0.15 160 / 0.06) 55%, transparent)",
        }}
      />

      {/* Emerald halo — drifts toward bottom-right.
          Radial gradient from 0.16 to transparent at 70%. The circle
          is larger (600px) than the old 420px + blur(90px) so the
          falloff reads the same without the filter. */}
      <div
        className="animate-orb-drift-1 absolute left-[6%] top-[120px] h-[600px] w-[600px]"
        style={{
          background:
            "radial-gradient(circle, oklch(0.70 0.15 160 / 0.16) 0%, oklch(0.70 0.15 160 / 0.08) 35%, transparent 70%)",
        }}
      />

      {/* Violet halo — drifts toward top-left. */}
      <div
        className="animate-orb-drift-2 absolute right-[4%] top-[380px] h-[520px] w-[520px]"
        style={{
          background:
            "radial-gradient(circle, oklch(0.65 0.18 290 / 0.14) 0%, oklch(0.65 0.18 290 / 0.06) 35%, transparent 70%)",
        }}
      />
    </div>
  );
}
