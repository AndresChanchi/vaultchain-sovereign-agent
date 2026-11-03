/**
 * Page background — the atmospheric substrate behind app content.
 *
 * Mirrors the mockup's three-layer atmosphere:
 *   - a 1200×900 radial glow anchored above the viewport, centered
 *     horizontally (`.glow` in the mockup);
 *   - an emerald orb (420×420) drifting slowly toward bottom-right
 *     (`.orb.o1`);
 *   - a violet orb (360×360) drifting slowly toward top-left
 *     (`.orb.o2`).
 *
 * Parent requirements
 *   The parent must be `position: relative` and create a stacking
 *   context (`isolate`) so the layers sit above the page colour but
 *   below the content. Canonical usage:
 *
 *     <main className="relative isolate bg-bg">
 *       <PageBackground />
 *       …sections…
 *     </main>
 *
 *   `overflow-hidden` is applied inside the component, so the caller
 *   does not have to remember it. It is required because the glow is
 *   intentionally oversized and its top edge (`-top-[140px]`) must be
 *   clipped, exactly as the mockup's `.kv` clips it.
 *
 * Why a component and not a utility
 *   - CSS pseudo-elements give at most two layers per element; three
 *     are needed. A wrapper div would be required either way.
 *   - The layer names (`page-glow`, `animate-orb-drift-1/2`) are
 *     intended to be consumed here, not sprinkled on arbitrary
 *     elements elsewhere. A component makes that intent explicit
 *     (Scream Architecture — the file screams "page background").
 *   - `pointer-events-none`, `overflow-hidden` and `aria-hidden` live
 *     in one place instead of being repeated on three siblings.
 *
 * Replaces `amb-bg`
 *   The `amb-bg` utility (two static radial glows baked into a
 *   background shorthand) was an earlier approximation of this same
 *   layer. The mockup uses discrete animated elements instead. The
 *   utility stays defined in `globals.css` because the legacy
 *   dashboard may still reference it; it will be removed once that
 *   page is migrated. On the landing page, `bg-bg` (flat colour) plus
 *   `<PageBackground />` is the correct composition.
 *
 * Motion
 *   - Both orbs drift on their own `--animate-orb-drift-*` tokens
 *     (globals.css), overridden to `none` under
 *     `prefers-reduced-motion: reduce`. No `!important`.
 *   - The central glow gets a `scroll()`-driven parallax via the
 *     `page-glow` class, gated behind
 *     `@supports (animation-timeline: scroll())` AND
 *     `prefers-reduced-motion: no-preference`. Browsers without
 *     `animation-timeline` keep the glow static — the mockup behaves
 *     identically.
 *
 * Performance note
 *   The orbs use `filter: blur(90px)` on 360–420px circles, matching
 *   the mockup. On modern devices this stays on the compositor; on
 *   low-end mobile it is the heaviest piece on the page. If profiling
 *   later shows it as a bottleneck, a radial gradient from
 *   `oklch(… / 0.16)` to transparent gives a visually equivalent
 *   falloff with no filter cost. Not optimised prematurely.
 *
 * Typographic caveat on `bg-emerald/[0.16]`
 *   The mockup specifies `oklch(0.70 0.15 160 / .16)`. Tailwind's
 *   opacity modifier `/[0.16]` produces exactly that — `color-mix`
 *   against transparent. Do not round to `/[15]`; the mockup is
 *   precise.
 */
export function PageBackground() {
  return (
    <div
      aria-hidden="true"
      className="pointer-events-none absolute inset-0 -z-10 overflow-hidden"
    >
      {/* Central hero glow. Centered via `left-1/2 -ml-[600px]` rather
          than `-translate-x-1/2` so `translate` remains owned by the
          parallax animation below (animating both `transform` and
          `translate` independently is confusing, and the mockup already
          resolves it with a negative margin). */}
      <div
        className="page-glow absolute -top-[140px] left-1/2 -ml-[600px] h-[900px] w-[1200px]"
        style={{
          background:
            "radial-gradient(closest-side, oklch(0.70 0.15 160 / 0.22), oklch(0.70 0.15 160 / 0.06) 55%, transparent)",
        }}
      />

      {/* Emerald orb — drifts toward bottom-right (mockup `dr1`:
          `translate: 120px 80px`). */}
      <div className="animate-orb-drift-1 absolute left-[6%] top-[120px] h-[420px] w-[420px] rounded-full bg-emerald/[0.16] blur-[90px]" />

      {/* Violet orb — drifts toward top-left (mockup `dr2`:
          `translate: -140px -60px`). */}
      <div className="animate-orb-drift-2 absolute right-[4%] top-[380px] h-[360px] w-[360px] rounded-full bg-violet/[0.14] blur-[90px]" />
    </div>
  );
}
