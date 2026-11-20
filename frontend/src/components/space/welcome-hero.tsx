"use client";

/**
 * Welcome hero — headline block for the empty state.
 *
 * Emotional goal
 *   The user just signed in. The space is empty. Instead of
 *   apologizing, turn the emptiness into an invitation.
 *
 * CTAs — both functional
 *   - "Upload your first photos" (primary, emerald + pulse ring):
 *     calls `openUpload()` from `UploadDialogContext`. The dialog is
 *     mounted at root (`providers.tsx`) and gates on session — the
 *     user is already signed in here, so it goes straight to review.
 *   - "Look around first" (secondary, glass): scrolls to the
 *     starters section (`#welcome-starters`) with `scrollIntoView`.
 *     Respects `prefers-reduced-motion` via the global
 *     `scroll-behavior: smooth` in `@layer base`.
 *
 *   Reversed from the earlier iteration where both were disabled.
 *   The primary pulse ring and emerald background were kept during
 *   the disabled phase for visual fidelity; they were never a
 *   promise the button would work. Now that it works, they are
 *   honest affordance signals.
 *
 * The glow — mirror of the mockup's `.glow`
 *   `radial-gradient` at 1200×900, centered on the hero, offset
 *   `top: -140px` upward. `isolate` on the wrapper creates a local
 *   stacking context so `-z-10` paints between the shell's `amb-bg`
 *   and the hero text (without it, the glow slides behind the
 *   background).
 */
import { useI18n } from "@context/I18nContext";
import { useUploadDialog } from "@context/UploadDialogContext";
import { PlayIcon } from "./space-icons";

const RISE = (delayMs: number) => ({ animationDelay: `${delayMs}ms` });

export function WelcomeHero() {
  const { t } = useI18n();
  const { open: openUpload } = useUploadDialog();

  const handleExplore = () => {
    document
      .getElementById("welcome-starters")
      ?.scrollIntoView({ block: "start" });
  };

  return (
    <div className="relative isolate max-w-[560px]">
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
          onClick={openUpload}
          className="animate-pulse-ring inline-flex h-[54px] items-center justify-center gap-2.5 rounded-[14px] bg-emerald px-[26px] text-[15px] font-semibold text-on-emerald transition-transform duration-200 ease-[cubic-bezier(0.34,1.4,0.5,1)] hover:scale-[1.02]"
        >
          <PlayIcon size={16} />
          {t("space.welcome.ctaUpload")}
        </button>
        <button
          type="button"
          onClick={handleExplore}
          className="glass inline-flex h-[54px] items-center justify-center rounded-[14px] px-[18px] text-[15px] font-medium text-ink transition-transform duration-200 ease-[cubic-bezier(0.34,1.4,0.5,1)] hover:scale-[1.02]"
        >
          {t("space.welcome.ctaExplore")}
        </button>
      </div>
    </div>
  );
}
