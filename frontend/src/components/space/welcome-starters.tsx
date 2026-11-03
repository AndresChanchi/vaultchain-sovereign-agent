"use client";

/**
 * Welcome starters — three milestone cards below the hero.
 *
 * Fidelity to the mockup (`Welcome.dc.html`)
 *   - Card: `rounded-[20px]` + `p-[18px]` + `overflow-hidden`.
 *   - Label: mono 11px uppercase, muted, no icon beside it.
 *   - Title: 17px semibold, `mt-2.5 mb-1.5`.
 *   - Body: 13px, `leading-[1.5]`, `max-w-[230px]`.
 *   - Slots: `mt-3.5`, `gap-1`, `h-1`, `rounded-[2px]` (nearly
 *     rectangular, not pills).
 *   - Art: `-right-[10px] -top-[10px] h-[100px] w-[120px] blur-[7px]`
 *     — no border-radius, clipped by the card's `overflow-hidden`.
 *
 *   Slots per card: 1 / 5 / 1 (share is a single bar, not two).
 *
 * Why the border and slots are brighter than the mockup's literal
 * `rgba(255,255,255,0.08)`
 *   The mockup's blurred-photo SVGs (`#s2`, `#s3`, `#s4`) carry high
 *   contrast — a sun, dark sky, orange horizon. That contrast anchors
 *   each card visually and the border + slots get read as "framing"
 *   against it. Our gradient stand-ins (`welcome-starter-art.tsx`)
 *   are deliberately softer — no false photo content — and at the
 *   same `0.08` alpha the border and slots become nearly invisible
 *   against the flat card background: the cards read as "flat gray
 *   rectangles" instead of "framed cards with progress".
 *
 *   Compensating: border bumped to `white/[0.12]`, slots to
 *   `white/[0.16]`. Same visual weight as the mockup, restored
 *   without depending on the art's contrast. On light theme the
 *   `white/...` values are effectively invisible — but so was the
 *   mockup's own `rgba(12,19,36,0.10)` hairline, and the pattern
 *   holds there too (light theme uses brighter borders via `ring`
 *   in the shell, not per-card). If a light-theme override is
 *   needed later, switch to `border-hairline` on the whole article
 *   and lift the slots to `bg-muted/20`.
 *
 * Art
 *   Uses `artBackground` from `welcome-starter-art.tsx` — layered
 *   gradients matching the mockup's blurred photo SVG symbols.
 *   Card 1 = ocean, card 2 = night, card 3 = forest.
 *
 * Animation
 *   Staggered `animate-rise` per card (60ms apart, starting 400ms
 *   after the hero). Hover lift `-translate-y-0.5` at 300ms.
 */

import { useI18n } from "@context/I18nContext";
import { artBackground, type StarterArt } from "./welcome-starter-art";

type Starter = {
  key: "onePhoto" | "fivePhotos" | "share";
  slots: number;
  art: StarterArt;
};

const STARTERS: readonly Starter[] = [
  { key: "onePhoto", slots: 1, art: "ocean" },
  { key: "fivePhotos", slots: 5, art: "night" },
  { key: "share", slots: 1, art: "forest" },
];

const RISE = (delayMs: number) => ({ animationDelay: `${delayMs}ms` });

export function WelcomeStarters() {
  const { t } = useI18n();

  return (
    <div className="grid gap-4 sm:grid-cols-3">
      {STARTERS.map((starter, index) => {
        const label = t(`space.welcome.starter.${starter.key}.label`);
        const title = t(`space.welcome.starter.${starter.key}.title`);
        const body = t(`space.welcome.starter.${starter.key}.body`);
        return (
          <article
            key={starter.key}
            className="animate-rise relative overflow-hidden rounded-[20px] border border-white/[0.12] bg-card p-[18px] shadow-[inset_0_1px_0_0_rgba(255,255,255,0.05)] transition-transform duration-300 ease-[cubic-bezier(0.2,0.8,0.2,1)] hover:-translate-y-0.5"
            style={RISE(400 + 60 * index)}
          >
            <div
              aria-hidden="true"
              className="pointer-events-none absolute -right-[10px] -top-[10px] h-[100px] w-[120px] blur-[7px]"
              style={{ background: artBackground(starter.art) }}
            />

            <p className="label-mono relative text-muted">{label}</p>
            <h3 className="relative mt-2.5 mb-1.5 text-[17px] font-semibold text-ink">
              {title}
            </h3>
            <p className="relative max-w-[230px] text-[13px] leading-[1.5] text-muted">
              {body}
            </p>

            <div aria-hidden="true" className="relative mt-3.5 flex gap-1">
              {Array.from({ length: starter.slots }).map((_, i) => (
                <span
                  key={i}
                  className="h-1 flex-1 rounded-[2px] bg-white/[0.16]"
                />
              ))}
            </div>
          </article>
        );
      })}
    </div>
  );
}
