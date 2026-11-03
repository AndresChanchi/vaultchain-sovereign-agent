"use client";

/**
 * Welcome — the state shown when the space has 0 photos.
 *
 * Vertical budget (desktop, 900px viewport) — matches the mockup
 *   Shell p-6 top                     =  24px
 *   Header                            =  44px
 *   Shell gap-5                       =  20px
 *   Welcome pt-10                     =  40px   ← eyebrow at 128px
 *   Grid (stage 500px)                = 500px   ← counter at ~660px
 *   gap-4                             =  16px
 *   Counter                           =  20px
 *   gap-4                             =  16px
 *   Spacer (flex-1)                   =  46px
 *   Starters                          = 150px
 *   Shell pb-6                        =  24px
 *   ─────────────────────────────────────────
 *   Total fixed                       = 854px  →  fits 900px
 *
 *   The mockup places the eyebrow at 124px from viewport top and
 *   the counter at ~650px. Earlier versions of this file used
 *   `pt-6` (24px) → eyebrow at 112px (12px short) and `h-[400px]`
 *   stage → counter at ~525px (125px short). The compound effect
 *   read as "recortado": everything compressed into the top half.
 *
 *   `pt-10` (40px) brings the eyebrow to 128px (mockup: 124).
 *   `h-[500px]` stage (companion change in `welcome-stage.tsx`)
 *   brings the counter to ~660px (mockup: 650). Both within 5-10px
 *   of the mockup at typical desktop viewports.
 *
 * Layout — three blocks
 *   1. Hero + stage grid — `items-start` + `pt-10`. Both anchored
 *      to the top of their cells. The grid takes natural height
 *      (500px from the stage); the hero column is shorter but
 *      top-aligned so its content sits at the top edge, matching
 *      the mockup where the eyebrow is near the top of the stage
 *      container.
 *   2. Counter — right-aligned, immediately after the grid.
 *   3. Spacer — `flex-1` empty div. Pushes starters to the bottom.
 *   4. Starters — three cards at the shell's bottom padding.
 *
 * No `flex-1` on the grid: the grid takes natural height and the
 * spacer absorbs the difference. Adding `flex-1` to the grid would
 * expand it to fill any available space, producing the "centered
 * in a huge empty area" look that this file had a few iterations
 * ago (see git history) — not what the mockup shows.
 */

import { useI18n } from "@context/I18nContext";
import { WelcomeHero } from "./welcome-hero";
import { WelcomeStage } from "./welcome-stage";
import { WelcomeStarters } from "./welcome-starters";

export function SpaceWelcome() {
  const { t } = useI18n();

  return (
    <div className="flex flex-1 flex-col gap-4">
      <div className="grid items-start gap-8 pt-10 lg:grid-cols-[minmax(0,560px)_1fr] lg:gap-12">
        <WelcomeHero />
        <WelcomeStage />
      </div>

      <div className="flex justify-end">
        <div className="flex items-center gap-2 font-mono text-[12px] text-muted">
          <span
            aria-hidden="true"
            className="h-1.5 w-1.5 animate-pulse-ring rounded-full bg-emerald"
          />
          <span aria-hidden="true">—</span>
          <span>{t("space.welcome.keptByOthers")}</span>
        </div>
      </div>

      <div className="flex-1" />

      <WelcomeStarters />
    </div>
  );
}
