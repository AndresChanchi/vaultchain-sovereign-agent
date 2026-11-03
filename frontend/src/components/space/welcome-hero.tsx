"use client";

/**
 * Welcome hero — headline block for the empty state.
 *
 * Emotional goal
 *   The user just signed in. The space is empty. Instead of
 *   apologizing, turn the emptiness into an invitation.
 *
 * Copy of the CTAs
 *   - "See how it works": a walkthrough of the flow (wired in 9.C).
 *     Kipio does NOT provide a sample photo — the user tries their
 *     own. The label says what it does, not what it invites.
 *   - "Upload yours": the primary action (wired in 9.D, opens the
 *     upload dialog).
 *
 *   Both CTAs are `disabled` today with the honest "coming in a
 *   later phase" tooltip. Visual fidelity wins over the dead-gray
 *   disabled convention — the primary keeps its pulse ring and the
 *   secondary keeps its glass surface, exactly like the mockup.
 *
 * The glow — mirror of the mockup's `.glow`
 *   `radial-gradient` (not a solid emerald blob + blur) at
 *   1200×900, centered on the hero, offset `top: -140px` upward.
 *   Three stops: 0.22 alpha at center, 0.06 at 55%, transparent at
 *   edge. Reads as ambient light, not as a green circle.
 *
 *   `isolate` on the wrapper is required — without it, `-z-10`
 *   slides behind the shell's `amb-bg` and the glow disappears.
 *   `isolation: isolate` creates a local stacking context that
 *   keeps the glow between the background and the hero text.
 *
 * Responsive
 *   H1 rises 44 → 56 → 68px across mobile → tablet → desktop.
 *   CTAs stack on `<sm`, row on `sm+`.
 */
import { useI18n } from "@context/I18nContext";
import { PlayIcon } from "./space-icons";

const RISE = (delayMs: number) => ({ animationDelay: `${delayMs}ms` });

export function WelcomeHero() {
  const { t } = useI18n();
  const soon = t("space.sidebar.comingSoon");

  return (
    <div className="relative isolate max-w-[560px]">
      {/* Glow — see "The glow" in the file header. */}
      <div
        aria-hidden="true"
        className="pointer-events-none absolute -z-10"
        style={{
          left: "50%",
          top: "-140px",
          width: "1200px",
          height: "900px",
          marginLeft: "-600px",
          background:
            "radial-gradient(closest-side, oklch(0.70 0.15 160 / 0.22), oklch(0.70 0.15 160 / 0.06) 55%, transparent)",
        }}
      />

      <div className="animate-rise flex items-center gap-2.5" style={RISE(0)}>
        <span aria-hidden="true" className="relative inline-flex h-2 w-2">
          <span className="absolute inline-flex h-full w-full animate-pulse-ring rounded-full bg-emerald opacity-60" />
          <span className="relative inline-flex h-2 w-2 rounded-full bg-emerald" />
        </span>
        <p className="label-mono text-emerald-text">
          {t("space.welcome.eyebrow")}
        </p>
      </div>

      <h1
        className="animate-rise mt-4 font-serif text-[44px] leading-[1.02] tracking-[-0.015em] text-ink sm:text-[56px] lg:text-[68px]"
        style={RISE(90)}
      >
        {t("space.welcome.headlineFirst")}
        <br />
        {t("space.welcome.headlineSecond")}
      </h1>

      <p
        className="animate-rise mt-[18px] max-w-[440px] text-pretty text-[16px] leading-[1.6] text-muted md:text-[17px]"
        style={RISE(180)}
      >
        {t("space.welcome.description")}
      </p>

      <div
        className="animate-rise mt-[26px] flex flex-col gap-3 sm:flex-row sm:flex-wrap"
        style={RISE(270)}
      >
        <button
          type="button"
          disabled
          aria-disabled="true"
          title={soon}
          className="animate-pulse-ring inline-flex h-[54px] cursor-not-allowed items-center justify-center gap-2.5 rounded-[14px] bg-emerald px-[26px] text-[15px] font-semibold text-on-emerald"
        >
          <PlayIcon size={16} />
          {t("space.welcome.ctaUpload")}
        </button>
        <button
          type="button"
          disabled
          aria-disabled="true"
          title={soon}
          className="glass inline-flex h-[54px] cursor-not-allowed items-center justify-center rounded-[14px] px-[18px] text-[15px] font-medium text-ink"
        >
          {t("space.welcome.ctaExplore")}
        </button>
      </div>
    </div>
  );
}
