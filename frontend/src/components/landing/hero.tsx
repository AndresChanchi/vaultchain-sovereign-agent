"use client";

import { useI18n } from "@context/I18nContext";

/**
 * Landing hero.
 *
 * Layout
 *   - eyebrow: "Digital property, not rental"
 *   - H1: Instrument Serif, 54 → 104px, tracking -0.015em, emerald glint
 *   - H2: Geist Sans, 22 → 30px, tracking -0.02em, muted
 *   - sub: 16 → 17px, muted, max-w-xl
 *   - drop zone: dashed emerald frame with pulsing primary CTA inside
 *   - ghost link: "Or look around first"
 *
 * Full-viewport layout
 *   The section carries `hero-viewport` (globals.css), which sets
 *   `min-height: calc(100dvh - 84px)` with `svh` and `vh` fallbacks.
 *   Combined with `flex flex-col justify-center` here, the hero fills
 *   at least one viewport minus the sticky navbar (84px) and centers
 *   its content vertically. This matters most at tablet (768–1024):
 *   previously the hero ended at the natural content height, leaving
 *   a gap above the fold. Now the hero covers the fold and the next
 *   section starts cleanly below it.
 *
 *   If content ever exceeds the viewport (very short landscape phones
 *   or a future addition), `min-height` grows to fit — the section
 *   never clips. `justify-center` has no effect when content is taller
 *   than the min-height, so overflow flows naturally.
 *
 * i18n
 *   All visible strings come from `landing.hero.*`:
 *     - eyebrow, title, subtitle, lede
 *     - dropPhoto (desktop-only hint inside the drop zone)
 *     - uploadCta (primary button label)
 *     - noAccount (with `{count}` placeholder for the batch limit)
 *     - orLookAround (ghost link below the drop zone)
 *
 *   The H1 and H2 also use `text-balance` so longer translations
 *   (German "Deine Fotos gehören dir", French "Vos photos sont à
 *   vous") break at balanced points without leaving a widow word.
 *
 * Atmospheric layer
 *   The page-wide glow + two drifting orbs come from <PageBackground />
 *   at the page level (see (public)/page.tsx). Hero does NOT paint a
 *   local glow — a local radial on top of `.page-glow` made the top
 *   of the page read denser than the mockup.
 *
 * Motion
 *   - `animate-rise` on every block except the H1 (see LCP note).
 *   - `shn-shine` on the H1 — emerald sweep from the mockup's `.shn`.
 *     Only `background-position` animates; no opacity, no fill-mode.
 *   - `animate-pulse-ring` on the primary CTA (halo pulse).
 *   - Hover lift (scale 1.02) on the CTA. Hovering the drop zone
 *     brightens the dashed border and the emerald tint.
 *   - Under `prefers-reduced-motion`, `--animate-*` tokens resolve to
 *     `none`; `shn-shine` falls back to solid ink automatically. No
 *     `!important`.
 *
 * LCP note
 *   The H1 is the LCP candidate. Two rules protect that:
 *
 *     1. `animate-rise` (which uses `animation-fill-mode: both`, so it
 *        starts at `opacity: 0`) is intentionally omitted from the H1.
 *        Chromium postpones the LCP metric until the fill ends,
 *        compounding with the serif font swap. Stagger still applies
 *        to the H2, the sub, the drop zone and the ghost link.
 *
 *     2. `shn-shine` animates only `background-position` — no
 *        `opacity`, no `visibility`. Both the 0% and 100% keyframes
 *        resolve to a solid ink slice of the gradient, so there is no
 *        frame in which the H1 is transparent. LCP fires on first
 *        paint. If a future change to `shn-shine` introduces opacity
 *        or visibility animation, it must NOT be applied to the H1.
 *
 * Drop zone anatomy
 *   The outer frame is a `<div>`, not a `<button>`:
 *     - the CTA is the real interactive target (keyboard focus, and
 *       assistive-technology name);
 *     - drag & drop handlers can live on the wrapper later without
 *       hijacking click semantics;
 *     - the copy below the CTA stays readable text.
 *
 * SEO
 *   - The H1 is the only `<h1>` on the page, in the primary locale
 *     (matches `<html lang>`). After the route restructure it becomes
 *     the H1 for `/` (en) and `/es/` (es) — never both on one route.
 *   - The ghost link is a real `<a href="#journey">` (crawlable anchor,
 *     matches in-page navigation, correct semantics).
 *   - The CTA is a `<button>` today because `/upload` does not exist;
 *     it becomes a `<Link href="/upload">` when the intercepted route
 *     lands. Buttons are appropriate for JS-only actions; links for
 *     navigation.
 *
 * TODO: open /upload intercepted route on drop-zone click.
 * TODO: accept actual drag & drop on the wrapper.
 */

const MAX_BATCH_SIZE = 10; // TODO: derive from device class.

const RISE = (delayMs: number) => ({ animationDelay: `${delayMs}ms` });

export function Hero() {
  const { t } = useI18n();

  return (
    <section className="hero-viewport relative mx-auto flex max-w-[1280px] flex-col justify-center px-6 py-16 md:px-10 md:py-20">
      <div className="mx-auto max-w-3xl text-center">
        <p
          className="label-mono animate-rise text-emerald-text"
          style={RISE(0)}
        >
          {t("landing.hero.eyebrow")}
        </p>

        {/* LCP element. No `animate-rise`; `shn-shine` drives only the
            gradient's `background-position` and resolves to solid ink
            at both animation endpoints. See the LCP note in the file
            header. `text-ink` is intentionally absent: `shn-shine`
            sets `color: transparent` and provides the visible color
            via the gradient clipped to the text. */}
        <h1 className="shn-shine mt-8 font-serif text-balance text-[54px] leading-[1.02] tracking-[-0.015em] md:text-[104px]">
          {t("landing.hero.title")}
        </h1>

        <h2
          className="animate-rise mt-8 text-balance text-[22px] font-semibold leading-[1.3] tracking-[-0.02em] text-muted md:text-[30px]"
          style={RISE(160)}
        >
          {t("landing.hero.subtitle")}
        </h2>

        <p
          className="animate-rise mx-auto mt-6 max-w-xl text-pretty text-[16px] leading-[1.6] text-muted md:text-[17px]"
          style={RISE(240)}
        >
          {t("landing.hero.lede")}
        </p>
      </div>

      <div className="mx-auto mt-14 max-w-[560px]">
        {/* Outer frame: static chrome only. See "Drop zone anatomy" in
            the file header for why this is a `<div>`. */}
        <div
          className="animate-rise flex flex-col items-center gap-3 rounded-[28px] border-[1.5px] border-dashed border-emerald/[0.55] bg-emerald/[0.07] px-[22px] py-[22px] text-center transition-[border-color,background-color] duration-300 ease-[cubic-bezier(0.2,0.8,0.2,1)] hover:border-emerald/80 hover:bg-emerald/[0.10] md:px-9 md:py-7"
          style={RISE(400)}
        >
          {/* Arrow + hint are desktop-only — same behaviour as the
              mockup's `.hm` utility (`display: none` under 700px). On
              mobile the CTA alone is enough. */}
          <div className="hidden flex-col items-center gap-3 md:flex">
            <svg
              aria-hidden="true"
              width="22"
              height="22"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="1.8"
              strokeLinecap="round"
              strokeLinejoin="round"
              className="text-emerald-text"
            >
              <path d="M12 16V4M7 9l5-5 5 5" />
              <path d="M5 20h14" />
            </svg>
            <p className="text-[15px] text-muted">
              {t("landing.hero.dropPhoto")}
            </p>
          </div>

          <button
            type="button"
            onClick={() => {
              // TODO: router.push("/upload") via intercepted route.
            }}
            className="animate-pulse-ring inline-flex h-14 max-w-full items-center justify-center rounded-[14px] bg-emerald px-8 text-[16px] font-semibold text-on-emerald transition-transform duration-200 ease-[cubic-bezier(0.34,1.4,0.5,1)] hover:scale-[1.02] focus-visible:scale-[1.02]"
          >
            {t("landing.hero.uploadCta")}
          </button>

          <p className="text-[13px] text-muted">
            {t("landing.hero.noAccount", { count: MAX_BATCH_SIZE })}
          </p>
        </div>

        <div className="mt-6 text-center" style={RISE(560)}>
          <a
            href="#journey"
            className="animate-rise text-sm text-muted underline decoration-hairline decoration-1 underline-offset-4 transition-colors duration-200 hover:text-ink hover:decoration-emerald/60"
          >
            {t("landing.hero.orLookAround")}
          </a>
        </div>
      </div>
    </section>
  );
}
