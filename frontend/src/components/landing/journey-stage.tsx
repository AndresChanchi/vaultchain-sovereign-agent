"use client";

import {
  useCallback,
  useEffect,
  useRef,
  useState,
  type CSSProperties,
} from "react";
import { useI18n } from "@context/I18nContext";
import { JourneySamples } from "./journey-samples";

/**
 * Landing — "Your photo's journey" 3D stage.
 *
 * A four-slide, auto-advancing carousel. Each slide is positioned in
 * 3D space (`translate3d + rotateY`) inside a `perspective` parent
 * with `transform-style: preserve-3d`. Sizing is responsive (see
 * "Slide sizing"); positioning is defined in `globals.css` under
 * `.journey-stage` as CSS variables, so desktop and mobile use
 * different offsets without duplicating JSX.
 *
 * Autoplay + manual controls (hybrid)
 *   - Auto-advance every 5s while playing.
 *   - Prev / Pause / Next + four progress-bar buttons.
 *   - Pure CSS transitions on `transform` and `opacity`.
 *   - Progress bars animate 0→100% over the current step. Pause
 *     freezes; unpause restarts bar + timer in lockstep.
 *
 * i18n
 *   Every visible string comes from `useI18n()`:
 *     - Section header (eyebrow, title, subtitle) — `landing.journey.*`.
 *     - Caption title/body/hood — `dictionary.landing.journey.steps[i]`
 *       (array read, not `t()`, because `t()` resolves only leaf strings).
 *     - Slide overlays — `landing.journey.slideOverlays.<slide>.*`.
 *     - Transport controls — `landing.journey.{previous,pause,play,next}`.
 *     - Progress-bar aria-labels — `landing.journey.showStep` with
 *       `{index}`, `{total}`, `{title}` placeholders.
 *
 *   Each slide calls `useI18n()` directly. They are children of the
 *   same file — prop drilling 8+ translated strings through props
 *   would be noise without benefit. The hook reads from the same
 *   context, so there is exactly one dictionary load per locale
 *   change, shared by parent and slides.
 *
 * Captions — grid layout (i18n safety)
 *   The caption area uses `grid` with all captions stacked at
 *   `col-start-1 row-start-1` and cross-faded via `opacity`. This
 *   solves two i18n problems in one move:
 *
 *     1. **No fixed height.** A fixed height would clip longer
 *        translations (German captions wrap to more lines than
 *        English). The grid container auto-sizes to the tallest
 *        caption, so every locale fits.
 *     2. **No layout shift on switch.** Because all captions are
 *        rendered simultaneously (only one visible), the container
 *        height is always the max. Switching from a short caption to
 *        a long one does not push the controls below down — the
 *        space was already reserved.
 *
 *   `text-balance` on the title and `text-pretty` on the body even
 *   out line lengths so no single word is orphaned on its own line
 *   in any locale.
 *
 * Chips inside slides — responsive + i18n safety
 *   Each chip carries `max-w-[calc(100%-28px)]` (28px = the
 *   `right-3.5` or `left-3.5` offset on both sides of the slide).
 *
 *   **Font and padding shrink at mobile (< sm).** At 320px the slide
 *   inner width is ~232px and the chip's usable area after padding
 *   is ~212px. At `text-[12px]` mono, "Optimized · one photo at a
 *   time" (30 chars) needs ~216px and would truncate; at
 *   `text-[11px]` it needs ~198px and fits on one line. The `sm:`
 *   variants restore the original sizes (12px / 16px padding) so the
 *   desktop look is unchanged.
 *
 *   **`rounded-2xl` at mobile, `rounded-full` at `sm:`.** A chip
 *   that fits on one line at 11px still looks right with
 *   `rounded-full`; the only case where `rounded-full` looks wrong is
 *   a 2-line wrap (which the padding at `rounded-full` would clip
 *   visually). `rounded-2xl` handles both cases, and `sm:rounded-full`
 *   restores the mockup's pill at desktop where 2-line wraps do not
 *   occur.
 *
 *   **No `truncate`.** `truncate` = `overflow: hidden; text-overflow:
 *   ellipsis; white-space: nowrap`. Removing it lets the chip grow
 *   vertically (wrapping) when a future translation exceeds the fit
 *   width. `overflow-hidden` stays as a defensive clip — if a
 *   pathological translation (100+ chars) ever lands, it clips the
 *   chip's content rather than breaking the slide layout, but normal
 *   translations wrap gracefully.
 *
 *   **`title={chip}`** stays for hover on desktop — redundant now
 *   that text fits, but a free fallback if a future locale wraps
 *   unpredictably. On mobile `title` does nothing (no hover) but
 *   costs nothing to keep.
 *
 *   **Icon-bearing chip (Lock)** adds `items-start sm:items-center`
 *   so the icon aligns to the first line when the text wraps, and
 *   `mt-[1px]` on the SVG nudges it to optical center against the
 *   text baseline. At desktop (`sm:`) the layout reverts to
 *   `items-center` — single-line, icon and text vertically centered.
 *
 * Rasterization quality — history of the "sharp then blurry" defect
 *   Three separate causes were identified and fixed. Do NOT regress:
 *
 *   1. `translateZ(+120px)` on the active slide. Perspective 1800px →
 *      effective 1.07× upscale → 1×-raster then 1.07× project → blur.
 *      The back slides (Z < 0) looked sharp because they projected at
 *      < 1×, so Chromium rastered at DPR and downscaled.
 *
 *      Fix: shift the `translateZ` values so the active slide sits at
 *      Z = 0. Do NOT restore the mockup's raw Z values.
 *
 *   2. `scale-[0.78]` on the tilt layer. `scale` is applied by the
 *      compositor AFTER raster; on high-DPR devices the raster is at
 *      1× CSS px then upscaled → blurry.
 *
 *      Fix: no `scale` on the tilt layer. Slides have their own
 *      responsive `w-[calc] max-w-[460px] aspect-[460/380]` — sizing
 *      happens at layout, not by raster-then-upscale. If a future
 *      change re-adds `scale` (in any form) to any ancestor, mobile
 *      blur returns.
 *
 *   3. `backface-visibility: hidden` on each slide. Combined with the
 *      absence of `scale`, nudges Chromium to raster each slide at
 *      native DPR. Kept as a stabilizer against future Chromium
 *      heuristic changes.
 *
 *   Do NOT add:
 *     - `will-change: transform` on any slide or the tilt layer.
 *     - `scale` on the tilt layer.
 *     - `overflow-hidden` on the stage wrapper *without* `w-screen`.
 *     - `translateZ` > 0 on any slide.
 *     - `image-rendering` / `shape-rendering` on SVGs.
 *
 * Stage overflow
 *   The stage wrapper is `w-screen` (100vw) with `overflow-hidden`, so
 *   slides clip at the viewport boundary — same as the mockup's
 *   `.kv { overflow: hidden }`. Header, captions and controls each
 *   carry their own `mx-auto max-w-*`, so only the stage is full-bleed.
 *
 * Position model
 *   Each slide's slot is derived from its signed distance to the
 *   current step. Opacity is defined here (JS); X/Z/rotation come from
 *   `--pos-<slot>-{x,z,ry}` CSS vars (globals.css), overridable per
 *   breakpoint:
 *
 *       delta  0 → "a"   (active, front, full opacity)
 *       delta  1 → "n1"  (next, right, 0.55)
 *       delta  2 → "n2"  (next-next, far right, 0.30)
 *       delta  3 → "n3"  (far right, hidden)
 *       delta -1 → "p1"  (past, left, 0.45)
 *       delta -2 → "p2"  (far left, hidden)
 *
 *   Mobile overrides in globals.css (`@media (max-width: 767px)`) use
 *   smaller X distances so adjacent slides visibly peek from the
 *   viewport edges instead of being pushed off-screen.
 *
 * Micro-animations
 *   Inner elements carry `journey-*` classes (globals.css):
 *     - `journey-shrink`  → two bars in SlideOptimize (breathing)
 *     - `journey-sweep`   → overlay in SlideLock (loops)
 *     - `journey-beacon`  → last node chip in SlideNotary (pulses)
 *     - `journey-bar`     → three content bars in SlideNotary, stagger
 *                           via `--journey-bar-delay` inline
 *     - `journey-line`    → eight dashed lines in SlideNetwork
 *     - `journey-node`    → eight satellites in SlideNetwork, stagger
 *                           via `--journey-node-delay` inline
 *
 * Stage tilt
 *   The 3D drift (`rotateX(8°→4°) rotateY(-7°→6°)`) is applied via
 *   `.journey-tilt` (globals.css), not inline style — must be
 *   disabled on mobile via media query and gate-able via
 *   `prefers-reduced-motion`. Inline style would override both. Only
 *   `transform-style: preserve-3d` is inline (structural, not tunable).
 *
 * Reduced motion
 *   `prefers-reduced-motion: reduce` disables autoplay, applies
 *   `transition: none` to every slide, and disables the stage tilt
 *   via CSS. The carousel becomes a static stage on step 0 that the
 *   visitor can navigate with the controls.
 *
 * Accessibility
 *   - Non-active slides carry `aria-hidden="true"`.
 *   - Progress-bar segments are buttons with `aria-label` (translated,
 *     with `{index}`, `{total}`, `{title}` placeholders).
 *   - Prev / Pause / Next buttons carry translated `aria-label`s.
 *   - `aria-current="step"` marks the active segment.
 *   - Focus ring comes from `:focus-visible` in globals.css.
 *
 * Known limitation — wrap transition
 *   When the cycle wraps (step 3 → 0 or 0 → 3), at least one slide
 *   transitions between a "past" slot (P1) and a "future" slot (N2)
 *   while still visible, crossing the center of the stage. The mockup
 *   hides this by fading to 0 before the jump; a two-phase transition
 *   would be required to match exactly. Documented; not fixed.
 *
 * Slide fidelity notes
 *   - SlideLock contains three layers matching the mockup's `.vl v2`:
 *     a blurred duplicate, a darkening overlay, and a lock icon.
 *   - SlideNetwork renders eight blurred satellite thumbnails of the
 *     four journey photos (mockup `.pp`), clipped to rounded rects.
 *   - The blurred duplicate in SlideLock hardcodes `w-[432px]` (inner
 *     slide width at desktop, 460 − 2×14 padding). On mobile the slide
 *     is narrower, so the blurred duplicate overflows the sweep's clip
 *     and is only shown inside the sweep's expanding width — visually
 *     correct because the sweep never exceeds the inner width.
 */

const STEP_DURATION_MS = 5000;
const TRANSITION_MS = 400;
const SLIDE_COUNT = 4;
const SLIDE_INNER_WIDTH_PX = 432;

const SLIDES = [
  { kind: "optimize" as const },
  { kind: "lock" as const },
  { kind: "notary" as const },
  { kind: "network" as const },
];

const POSITIONS = {
  a: { opacity: 1 },
  n1: { opacity: 0.55 },
  n2: { opacity: 0.3 },
  n3: { opacity: 0 },
  p1: { opacity: 0.45 },
  p2: { opacity: 0 },
} as const;

type SlidePos = keyof typeof POSITIONS;

function getSlidePos(index: number, current: number): SlidePos {
  const delta = index - current;
  if (delta === 0) return "a";
  if (delta === 1) return "n1";
  if (delta === 2) return "n2";
  if (delta >= 3) return "n3";
  if (delta === -1) return "p1";
  return "p2";
}

export function JourneyStage() {
  const { t, dictionary } = useI18n();
  const steps = dictionary.landing.journey.steps;

  const [current, setCurrent] = useState(0);
  const [paused, setPaused] = useState(false);
  const [generation, setGeneration] = useState(0);
  const [reducedMotion, setReducedMotion] = useState(false);
  const timeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    const mq = window.matchMedia("(prefers-reduced-motion: reduce)");
    setReducedMotion(mq.matches);
    const handler = (e: MediaQueryListEvent) => setReducedMotion(e.matches);
    mq.addEventListener("change", handler);
    return () => mq.removeEventListener("change", handler);
  }, []);

  const goTo = useCallback((target: number) => {
    const next = ((target % SLIDE_COUNT) + SLIDE_COUNT) % SLIDE_COUNT;
    setCurrent(next);
  }, []);

  const advance = useCallback(() => goTo(current + 1), [current, goTo]);
  const retreat = useCallback(() => goTo(current - 1), [current, goTo]);

  useEffect(() => {
    if (paused || reducedMotion) return;
    if (timeoutRef.current) clearTimeout(timeoutRef.current);
    timeoutRef.current = setTimeout(advance, STEP_DURATION_MS);
    return () => {
      if (timeoutRef.current) clearTimeout(timeoutRef.current);
    };
  }, [current, paused, reducedMotion, advance]);

  const handleTogglePause = useCallback(() => {
    if (paused) {
      setGeneration((g) => g + 1);
      setPaused(false);
    } else {
      setPaused(true);
    }
  }, [paused]);

  const transitionStyle = reducedMotion
    ? "none"
    : `transform ${TRANSITION_MS}ms cubic-bezier(0.34, 1.4, 0.5, 1), opacity ${TRANSITION_MS}ms ease-out`;

  return (
    <section id="journey" className="journey-stage py-24">
      <div className="mx-auto max-w-2xl px-6 text-center md:px-10">
        <p className="label-mono text-emerald-text">
          {t("landing.journey.eyebrow")}
        </p>
        <h2 className="mt-4 text-balance text-[30px] font-bold leading-tight tracking-[-0.025em] text-ink md:text-[40px]">
          {t("landing.journey.title")}
        </h2>
        <p className="mt-4 text-balance text-[15px] leading-relaxed text-muted md:text-[16px]">
          {t("landing.journey.subtitle")}
        </p>
      </div>

      {/* Symbols defined once per page. */}
      <JourneySamples />

      {/* Stage wrapper — clips slides at viewport. See header. */}
      <div className="relative left-1/2 mt-7 h-[410px] w-screen -translate-x-1/2 overflow-hidden md:h-[520px]">
        <div className="absolute inset-0 [perspective:1200px] md:[perspective:1800px]">
          <div
            className="journey-tilt absolute inset-0"
            style={{ transformStyle: "preserve-3d" }}
          >
            {SLIDES.map((slide, i) => {
              const pos = getSlidePos(i, current);
              const { opacity } = POSITIONS[pos];
              return (
                <div
                  key={slide.kind}
                  data-active={i === current ? "true" : "false"}
                  aria-hidden={i !== current}
                  className="journey-slide absolute left-1/2 top-1/2 w-[calc(100vw-60px)] max-w-[460px] aspect-[460/380] overflow-hidden rounded-[28px] border border-hairline bg-card p-3.5 shadow-[0_30px_60px_-24px_light-dark(rgba(12,19,36,0.3),rgba(0,0,0,0.6))]"
                  style={{
                    transform: `translate(-50%, -50%) translate3d(var(--pos-${pos}-x), 0, var(--pos-${pos}-z)) rotateY(var(--pos-${pos}-ry))`,
                    opacity,
                    transition: transitionStyle,
                    backfaceVisibility: "hidden",
                    WebkitBackfaceVisibility: "hidden",
                  }}
                >
                  <div className="relative h-full overflow-hidden rounded-[18px]">
                    {slide.kind === "optimize" && <SlideOptimize />}
                    {slide.kind === "lock" && <SlideLock />}
                    {slide.kind === "notary" && <SlideNotary />}
                    {slide.kind === "network" && <SlideNetwork />}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>

      {/* Captions — grid stacked, no fixed height. See header. */}
      <div className="relative mx-auto mt-3 grid max-w-[620px] px-6 text-center md:px-0">
        {steps.map((cap, i) => {
          const isActive = i === current;
          return (
            <div
              key={i}
              className="col-start-1 row-start-1 transition-opacity duration-300 ease-out"
              style={{
                opacity: isActive ? 1 : 0,
                pointerEvents: isActive ? "auto" : "none",
              }}
              aria-hidden={!isActive}
            >
              <p className="text-balance text-[26px] font-semibold tracking-[-0.02em] text-ink">
                {cap.title}
              </p>
              <p className="mx-auto mt-2 max-w-[560px] text-pretty text-[15px] leading-[1.55] text-muted">
                {cap.body}
              </p>
              <p className="mt-2.5 font-mono text-[11px] text-muted-soft">
                {cap.hood}
              </p>
            </div>
          );
        })}
      </div>

      <div className="mt-4 flex flex-col items-center gap-4">
        <div
          className="flex w-full max-w-[360px] gap-2 px-6 md:px-0"
          role="group"
          aria-label={t("landing.journey.stepsLabel")}
        >
          {steps.map((cap, i) => {
            const isActive = i === current;
            return (
              <button
                key={`${i}-${isActive ? "active" : "inactive"}-${generation}`}
                type="button"
                onClick={() => goTo(i)}
                aria-label={t("landing.journey.showStep", {
                  index: i + 1,
                  total: SLIDE_COUNT,
                  title: cap.title,
                })}
                aria-current={isActive ? "step" : undefined}
                className={`h-1 flex-1 rounded-full ${
                  isActive
                    ? "journey-progress"
                    : "bg-hairline transition-colors duration-300 hover:bg-muted/40"
                }`}
                style={
                  isActive
                    ? ({
                        "--journey-progress-duration": `${STEP_DURATION_MS}ms`,
                        "--journey-progress-play-state": paused
                          ? "paused"
                          : "running",
                      } as CSSProperties)
                    : undefined
                }
              />
            );
          })}
        </div>
        <div className="flex items-center gap-2">
          <TransportButton
            onClick={retreat}
            label={t("landing.journey.previous")}
          >
            <svg
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
              aria-hidden="true"
            >
              <path d="M15 18l-6-6 6-6" />
            </svg>
          </TransportButton>
          <TransportButton
            onClick={handleTogglePause}
            label={
              paused
                ? t("landing.journey.play")
                : t("landing.journey.pause")
            }
          >
            {paused ? (
              <svg
                width="14"
                height="14"
                viewBox="0 0 24 24"
                fill="currentColor"
                aria-hidden="true"
              >
                <path d="M8 5v14l11-7z" />
              </svg>
            ) : (
              <svg
                width="14"
                height="14"
                viewBox="0 0 24 24"
                fill="currentColor"
                aria-hidden="true"
              >
                <rect x="6" y="4" width="4" height="16" rx="1" />
                <rect x="14" y="4" width="4" height="16" rx="1" />
              </svg>
            )}
          </TransportButton>
          <TransportButton onClick={advance} label={t("landing.journey.next")}>
            <svg
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
              aria-hidden="true"
            >
              <path d="M9 6l6 6-6 6" />
            </svg>
          </TransportButton>
        </div>
      </div>
    </section>
  );
}

function TransportButton({
  onClick,
  label,
  children,
}: {
  onClick: () => void;
  label: string;
  children: React.ReactNode;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={label}
      className="inline-flex h-9 w-9 items-center justify-center rounded-full border border-hairline bg-card text-muted transition-colors duration-200 hover:text-ink"
    >
      {children}
    </button>
  );
}

/* ── Slide content ─────────────────────────────────────────────────────
 * Structural replicas of the mockup's four slides. Each calls
 * `useI18n()` directly for its own overlay strings — they are children
 * of this file, so prop drilling would add noise without benefit.
 *
 * Chips carry `max-w-[calc(100%-28px)]`, `text-[11px] sm:text-[12px]`,
 * `rounded-2xl sm:rounded-full` and `overflow-hidden` (no `truncate`).
 * At 320px the text fits on one line; if a future translation is
 * longer it wraps to 2 lines instead of ellipsizing. See the file
 * header ("Chips inside slides") for the full reasoning.
 * ─────────────────────────────────────────────────────────────────── */

function SlideOptimize() {
  const { t } = useI18n();
  const sizeLabel = t("landing.journey.slideOverlays.optimize.sizeLabel");
  const priceLabel = t("landing.journey.slideOverlays.optimize.priceLabel");
  const chip = t("landing.journey.slideOverlays.optimize.chip");

  return (
    <>
      <svg
        viewBox="0 0 400 300"
        preserveAspectRatio="xMidYMid slice"
        className="absolute inset-0 h-full w-full"
        aria-hidden="true"
      >
        <use href="#s1" />
      </svg>

      <div className="absolute inset-x-3.5 bottom-3.5 rounded-2xl bg-[rgba(10,16,30,0.75)] p-3.5">
        <div className="flex items-center gap-2 font-mono text-[11px] font-medium text-slate-300">
          {sizeLabel}
          <span className="h-1.5 flex-1 overflow-hidden rounded-full bg-hairline">
            <span className="journey-shrink block h-full w-full rounded-full bg-emerald" />
          </span>
        </div>
        <div className="mt-2.5 flex items-center gap-2 font-mono text-[11px] font-medium text-slate-300">
          {priceLabel}
          <span className="h-1.5 flex-1 overflow-hidden rounded-full bg-hairline">
            <span className="journey-shrink block h-full w-full rounded-full bg-emerald" />
          </span>
        </div>
      </div>

      <span
        title={chip}
        className="journey-chip absolute right-3.5 top-3.5 max-w-[calc(100%-28px)] overflow-hidden rounded-2xl border border-hairline bg-card px-2.5 py-1.5 font-mono text-[11px] leading-[1.3] text-ink sm:rounded-full sm:px-4 sm:py-2 sm:text-[12px]"
      >
        {chip}
      </span>
    </>
  );
}

function SlideLock() {
  const { t } = useI18n();
  const chip = t("landing.journey.slideOverlays.lock.chip");

  return (
    <>
      <svg
        viewBox="0 0 400 300"
        preserveAspectRatio="xMidYMid slice"
        className="absolute inset-0 h-full w-full"
        aria-hidden="true"
      >
        <use href="#s1" />
      </svg>

      <div
        aria-hidden="true"
        className="journey-sweep pointer-events-none absolute inset-y-0 left-0 border-r border-emerald"
      >
        <div className="absolute inset-y-0 left-0 w-full overflow-hidden">
          <svg
            viewBox="0 0 400 300"
            preserveAspectRatio="xMidYMid slice"
            className="absolute inset-y-0 left-0 h-full scale-110"
            style={{
              width: `${SLIDE_INNER_WIDTH_PX}px`,
              filter: "blur(16px) saturate(0.85)",
            }}
          >
            <use href="#s1" />
          </svg>
          <div className="absolute inset-0 bg-[rgba(10,16,30,0.35)]" />
        </div>

        <svg
          className="absolute left-1/2 top-1/2 -ml-3 -mt-3 h-6 w-6 text-white drop-shadow-[0_2px_8px_rgba(0,0,0,0.6)]"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
          aria-hidden="true"
        >
          <rect x="5" y="11" width="14" height="9" rx="2" />
          <path d="M8 11V8a4 4 0 0 1 8 0v3" />
        </svg>

        <span
          className="absolute -right-[13px] top-1/2 -mt-[13px] h-[26px] w-[26px] rounded-full bg-emerald"
          style={{ boxShadow: "0 0 0 6px oklch(0.70 0.15 160 / 0.25)" }}
        />
      </div>

      <span
        title={chip}
        className="journey-chip absolute bottom-3.5 left-3.5 inline-flex max-w-[calc(100%-28px)] items-start gap-1.5 overflow-hidden rounded-2xl border border-hairline bg-card px-2.5 py-1.5 font-mono text-[11px] leading-[1.3] text-ink sm:items-center sm:rounded-full sm:px-4 sm:py-2 sm:text-[12px]"
      >
        <svg
          width="12"
          height="12"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2.4"
          strokeLinecap="round"
          className="mt-[1px] shrink-0 text-emerald-text sm:mt-0"
          aria-hidden="true"
        >
          <rect x="5" y="11" width="14" height="9" rx="2" />
          <path d="M8 11V8a4 4 0 0 1 8 0v3" />
        </svg>
        <span className="min-w-0">{chip}</span>
      </span>
    </>
  );
}

function SlideNotary() {
  const { t } = useI18n();
  const o = {
    eyebrow: t("landing.journey.slideOverlays.notary.eyebrow"),
    owner: t("landing.journey.slideOverlays.notary.ownerLabel"),
    content: t("landing.journey.slideOverlays.notary.contentLabel"),
    name: t("landing.journey.slideOverlays.notary.nameLabel"),
    type: t("landing.journey.slideOverlays.notary.typeLabel"),
    cannotSee: t("landing.journey.slideOverlays.notary.cannotSee"),
  };

  return (
    <div className="relative h-full bg-elevated p-6">
      <p className="mb-3.5 font-mono text-[11px] uppercase tracking-[0.1em] text-muted">
        {o.eyebrow}
      </p>
      <div className="mb-6 flex items-center" aria-hidden="true">
        <span className="h-[34px] w-[34px] flex-none rounded-[9px] border border-hairline bg-card" />
        <span className="h-[2px] w-[22px] flex-none bg-hairline" />
        <span className="h-[34px] w-[34px] flex-none rounded-[9px] border border-hairline bg-card" />
        <span className="h-[2px] w-[22px] flex-none bg-hairline" />
        <span className="h-[34px] w-[34px] flex-none rounded-[9px] border border-hairline bg-card" />
        <span className="h-[2px] w-[22px] flex-none bg-hairline" />
        <span className="journey-beacon h-[34px] w-[34px] flex-none rounded-[9px] border border-violet bg-violet/25" />
      </div>
      <div className="mb-2.5 flex items-center gap-2 font-mono text-[13px] text-muted">
        <span className="shrink-0">{o.owner}</span>
        <span className="text-emerald-text">0x7a3F…c91E</span>
      </div>
      <div className="mb-2.5 flex items-center gap-2 font-mono text-[13px] text-muted">
        <span className="shrink-0">{o.content}</span>
        <span
          className="journey-bar inline-block h-[9px] w-[110px] rounded-[5px] bg-violet/80"
          style={{ "--journey-bar-delay": "0.3s" } as CSSProperties}
        />
      </div>
      <div className="mb-2.5 flex items-center gap-2 font-mono text-[13px] text-muted">
        <span className="shrink-0">{o.name}</span>
        <span
          className="journey-bar inline-block h-[9px] w-[110px] rounded-[5px] bg-violet/80"
          style={{ "--journey-bar-delay": "0.5s" } as CSSProperties}
        />
      </div>
      <div className="flex items-center gap-2 font-mono text-[13px] text-muted">
        <span className="shrink-0">{o.type}</span>
        <span
          className="journey-bar inline-block h-[9px] w-[110px] rounded-[5px] bg-violet/80"
          style={{ "--journey-bar-delay": "0.7s" } as CSSProperties}
        />
      </div>
      <p className="mt-4 font-mono text-[12px] text-violet-text">
        {o.cannotSee}
      </p>
    </div>
  );
}

function SlideNetwork() {
  const { t } = useI18n();
  const chip = t("landing.journey.slideOverlays.network.chip");

  const satellites = [
    { x: 216, y: 40 },
    { x: 330, y: 80 },
    { x: 380, y: 176 },
    { x: 330, y: 272 },
    { x: 216, y: 312 },
    { x: 100, y: 272 },
    { x: 50, y: 176 },
    { x: 100, y: 80 },
  ];
  const symbolIds = ["#s1", "#s2", "#s3", "#s4"] as const;

  return (
    <>
      <svg
        viewBox="0 0 432 352"
        preserveAspectRatio="xMidYMid slice"
        className="h-full w-full"
        aria-hidden="true"
      >
        <circle cx="216" cy="176" r="100" fill="none" className="stroke-hairline" />
        <circle cx="216" cy="176" r="150" fill="none" className="stroke-hairline" />

        {satellites.map((s, i) => (
          <line
            key={`line-${i}`}
            x1="216"
            y1="176"
            x2={s.x}
            y2={s.y}
            className="journey-line stroke-emerald"
            strokeWidth="1.5"
          />
        ))}

        {satellites.map((s, i) => {
          const symbolId = symbolIds[i % symbolIds.length];
          return (
            <g
              key={`sat-${i}`}
              className="journey-node"
              style={
                {
                  "--journey-node-delay": `${i * 0.12}s`,
                } as CSSProperties
              }
            >
              <clipPath id={`sat-clip-${i}`}>
                <rect x={s.x - 20} y={s.y - 20} width="40" height="40" rx="10" />
              </clipPath>
              <svg
                x={s.x - 20}
                y={s.y - 20}
                width="40"
                height="40"
                viewBox="0 0 400 300"
                preserveAspectRatio="xMidYMid slice"
                clipPath={`url(#sat-clip-${i})`}
                style={{ filter: "blur(2.5px)" }}
              >
                <use href={symbolId} />
              </svg>
            </g>
          );
        })}

        <circle cx="216" cy="176" r="30" className="fill-emerald" />
        <g
          transform="translate(204 164)"
          fill="none"
          stroke="#04130d"
          strokeWidth="2"
          strokeLinecap="round"
        >
          <rect x="2" y="10" width="20" height="14" rx="3" />
          <path d="M6 10V7a6 6 0 0 1 12 0v3" />
        </g>
      </svg>
      <span
        title={chip}
        className="journey-chip absolute bottom-3.5 left-3.5 max-w-[calc(100%-28px)] overflow-hidden rounded-2xl border border-hairline bg-card px-2.5 py-1.5 font-mono text-[11px] leading-[1.3] text-ink sm:rounded-full sm:px-4 sm:py-2 sm:text-[12px]"
      >
        {chip}
      </span>
    </>
  );
}
