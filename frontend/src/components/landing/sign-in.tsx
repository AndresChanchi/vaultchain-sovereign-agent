"use client";

import type { CSSProperties } from "react";
import { useI18n } from "@context/I18nContext";

/**
 * "Sign in however you like" — landing section.
 *
 * Desktop (≥ md)
 *   Two rows of chips (methods emerald, wallets violet) + connector
 *   SVG + glass destination card. Unchanged from the previous pass —
 *   the connector visualizes the convergence and reads correctly at
 *   desktop width.
 *
 * Mobile (< md) — "cosmic convergence"
 *   The SVG connector is hidden (`hidden md:block`) because it cannot
 *   survive arbitrary chip wrapping. In its place, two coordinated,
 *   CSS-only effects that literalize the section's message ("many
 *   ways in, one space"):
 *
 *     - `.card-portal` — a conic gradient behind the destination
 *                        card that rotates slowly (22s) while
 *                        breathing (5s opacity 0.5 → 1.0). Reads as
 *                        "energy source" — the space attracts the
 *                        methods. No `filter: blur` (which would
 *                        force re-raster every rotation frame on
 *                        mobile); the soft alpha stops of the conic
 *                        gradient produce the same glow with paint
 *                        only.
 *
 *     - `.chip-pulse::after` — each chip emits a small dot in its
 *                        own color (`--chip-color`, so emerald for
 *                        methods, violet for wallets). The dot
 *                        charges up (scale 1.2 + glow), then falls
 *                        toward the card, dissolving on the way down.
 *                        Stagger of 0.6s per chip (via `--chip-i`)
 *                        means a continuous particle stream — one
 *                        chip "fires" every 0.6s, so at any moment
 *                        several particles are mid-fall at different
 *                        depths. This is the visual "many → one".
 *
 *   Why this over the previous "aura + beam"
 *     The previous iteration was decorative (a pulsing halo + a
 *     vertical line) but not semantic — a viewer had to be told what
 *     it meant. Particles *leaving* chips and *arriving* at the card
 *     need no caption: the motion itself is the message. The
 *     rotating portal doubles down on "the card is the source of
 *     gravity", which is what the section is actually claiming.
 *
 *   Space
 *     No new wrappers, no extra height. The portal sits behind the
 *     card at `inset: -30% -20% -20%` (bleeds visually upward into
 *     the chip area, clipped horizontally by `overflow-x-clip` on
 *     the section). The dots are 5px pseudo-elements emitted from
 *     existing chip positions. The section's vertical footprint is
 *     actually slightly shorter than before because the chips no
 *     longer carry `.chip-float` (which added a competing motion).
 *
 * Overflow safety
 *   `overflow-x-clip` on the `<section>` — belt and suspenders. The
 *   portal's horizontal bleed is clipped at the section boundary
 *   regardless of viewport width. `html { overflow-x: clip }` in
 *   globals.css already provides a page-level guard, but relying on
 *   a global rule for a component-specific effect hides intent; the
 *   section owns its own clip.
 *
 * Client Component
 *   `useI18n()` provides `t()` and the active dictionary. The
 *   component is `"use client"` because of that hook — no other
 *   state or effect lives here. All visible strings flow through the
 *   active dictionary; switching language re-renders the section
 *   with the target strings.
 *
 * Two ways of reading the dictionary
 *   - `t("landing.signIn.title")` — dot-path scalar strings
 *     (eyebrow, title, subtitle, cardTitle, cardBody).
 *   - `dictionary.landing.signIn.methods` — array reads. `t()` is
 *     typed against `Path<Dictionary>`, which only resolves leaf
 *     strings, so it cannot return arrays. Reading from `dictionary`
 *     directly is the idiomatic path for iterating translated lists.
 *
 * Chips as `<ul><li>`
 *   The mockup renders each chip as a `<span>`, which loses list
 *   semantics. Wrapping them in `<ul><li>` gives screen readers
 *   "list, 6 items" and "list, 4 items" before the items themselves.
 *   `role="list"` is kept explicit because some older VoiceOver
 *   versions drop list announcement when `list-style` is `none`
 *   (which `.chip-pulse` implies via `display: inline-flex`).
 *
 * Chip identity
 *   `key={i}` (index), not the string. Locale changes swap the text
 *   ("Email" → "Correo"); using the text as key would remount each
 *   `<li>`, restarting both the `chip-pulse` stagger AND the emitted
 *   particle animation. The lists are positional — method #1 stays
 *   method #1 in every language — so index is the semantically
 *   correct identity.
 *
 * Deferred
 *   Chips are decorative today. Fase 9 wraps each `<li>`'s text in a
 *   `<button>` that opens the login overlay. The particle animation
 *   is independent of the interaction and continues unchanged.
 *
 * Reduced motion
 *   `.card-portal` has its animation gated under
 *   `@media (prefers-reduced-motion: no-preference)`, so the portal
 *   renders statically (visible at base opacity 0.55, no rotation).
 *   `.chip-pulse::after` has no base opacity, so without the
 *   animation it is invisible — the section becomes a static stack
 *   of chips + card with the portal glow. No motion, no information
 *   lost (the section's message is in the copy).
 */
export function SignIn() {
  const { t, dictionary } = useI18n();
  const { methods, wallets } = dictionary.landing.signIn;

  return (
    <section className="relative mx-auto max-w-[1280px] overflow-x-clip px-6 py-24 md:px-10">
      <div className="mx-auto max-w-2xl text-center">
        <p className="label-mono text-emerald-text">
          {t("landing.signIn.eyebrow")}
        </p>
        <h2 className="mt-3 text-[30px] font-bold leading-tight tracking-[-0.025em] text-ink md:text-[40px]">
          {t("landing.signIn.title")}
        </h2>
        <p className="mx-auto mt-3 max-w-[480px] text-[16px] leading-[1.55] text-muted">
          {t("landing.signIn.subtitle")}
        </p>

        {/* ── Methods — emerald chips ──────────────────────────────
            Each `<li>` gets `.chip-pulse` (idle border+halo pulse)
            and its own emitted particle via `::after`. The particle
            animation is gated in globals.css to
            (max-width: 767px) + no reduced motion. */}
        <ul
          role="list"
          className="mt-9 flex flex-wrap justify-center gap-2 md:gap-3"
        >
          {methods.map((label, i) => (
            <li
              key={i}
              className="chip-pulse"
              style={{ "--chip-i": i } as CSSProperties}
            >
              {label}
            </li>
          ))}
        </ul>

        {/* ── Wallets — violet chips ───────────────────────────────
            `--chip-i` continues from the methods row (6..9) so the
            particle stream stays continuous across both rows. */}
        <ul
          role="list"
          className="mt-2 flex flex-wrap justify-center gap-2 md:mt-3 md:gap-3"
        >
          {wallets.map((label, i) => (
            <li
              key={i}
              className="chip-pulse"
              style={
                {
                  "--chip-i": i + methods.length,
                  "--chip-color": "var(--color-violet)",
                } as CSSProperties
              }
            >
              {label}
            </li>
          ))}
        </ul>

        {/* ── Connector (desktop only) ─────────────────────────────
            Hidden on < md; the mobile substitute is the portal +
            emitted particles. */}
        <svg
          aria-hidden="true"
          className="hidden h-[100px] w-full md:block"
          viewBox="0 0 1000 100"
          preserveAspectRatio="none"
        >
          <g fill="none" strokeWidth="1.5">
            <path
              className="journey-line"
              d="M200 0C200 70 500 30 500 98"
              stroke="var(--color-emerald)"
            />
            <path
              className="journey-line"
              d="M350 0C350 70 500 30 500 98"
              stroke="var(--color-emerald)"
            />
            <path
              className="journey-line"
              d="M500 0V98"
              stroke="var(--color-emerald)"
            />
            <path
              className="journey-line"
              d="M650 0C650 70 500 30 500 98"
              stroke="var(--color-violet)"
            />
            <path
              className="journey-line"
              d="M800 0C800 70 500 30 500 98"
              stroke="var(--color-violet)"
            />
          </g>
        </svg>

        {/* ── Destination card with mobile portal ──────────────────
            `.card-portal` is positioned absolute behind the card at
            `inset: -30% -20% -20%` — it bleeds upward into the
            gap toward the chips (visually receiving the particles),
            and horizontally beyond the card edges (soft glow). The
            section's `overflow-x-clip` guards the horizontal bleed;
            the vertical bleed stays inside the section's `py-24`. */}
        <div className="relative mt-6">
          <div aria-hidden="true" className="card-portal md:hidden" />

          <div className="glass relative z-10 mx-auto flex max-w-[560px] items-center gap-4 rounded-[24px] px-5 py-5 text-left md:gap-5 md:px-7 md:py-6">
            <div className="flex h-[52px] w-[52px] shrink-0 items-center justify-center rounded-[15px] bg-emerald text-on-emerald">
              <svg
                width="22"
                height="22"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.8"
                strokeLinecap="round"
                strokeLinejoin="round"
                aria-hidden="true"
              >
                <rect x="5" y="11" width="14" height="9" rx="2" />
                <path d="M8 11V8a4 4 0 0 1 8 0v3" />
              </svg>
            </div>
            <div>
              <div className="text-[20px] font-semibold text-ink">
                {t("landing.signIn.cardTitle")}
              </div>
              <div className="mt-1 text-[14px] text-muted">
                {t("landing.signIn.cardBody")}
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
