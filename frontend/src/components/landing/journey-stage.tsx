"use client";

import {
  useCallback,
  useEffect,
  useRef,
  useState,
  type CSSProperties,
} from "react";
import { JourneySamples } from "./journey-samples";

/**
 * Landing — "Your photo's journey" 3D stage.
 *
 * A four-slide, auto-advancing carousel of the four steps described in
 * the copy. Each slide is positioned in 3D space (`translate3d +
 * rotateY`) inside a `perspective` parent with `transform-style:
 * preserve-3d`. Sizing is responsive (see "Slide sizing" below);
 * positioning is defined in `globals.css` under `.journey-stage` as CSS
 * variables, so desktop and mobile can use different offsets without
 * duplicating JSX.
 *
 * Autoplay + manual controls (hybrid)
 *   The mockup uses a 20s CSS keyframe loop. That is elegant for a
 *   passive viewer but does not let a reader control the flow — which
 *   matters when the same visitor uses the section to *explain* the
 *   product to someone else. Therefore:
 *
 *     - The step advances every 5s while playing.
 *     - Prev / Pause / Next and four progress-bar buttons allow the
 *       visitor to jump to any step.
 *     - The transitions between steps are pure CSS `transition` on
 *       `transform` and `opacity`.
 *     - Progress bars animate 0→100% over the current step duration.
 *       Pause freezes the bar; unpausing restarts bar + timer in
 *       lockstep (see "Progress sync").
 *
 * Progress sync
 *   Bar and timer must restart together when the user unpauses. A
 *   `generation` state is bumped on every pause→play transition, and
 *   the progress buttons key on `${index}-${active}-${generation}`, so
 *   on unpause they remount fresh at 0%. The autoplay effect re-arms
 *   on `paused` change, so the timer also restarts from
 *   `STEP_DURATION_MS`.
 *
 *   While paused, the bar freezes via the CSS var
 *   `--journey-progress-play-state`.
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
 *      Z = 0. `--pos-*-z` values below are the mockup's, shifted by
 *      −120. Do NOT restore the mockup's raw Z values — that would
 *      bring back the front-blurry / back-sharp asymmetry.
 *
 *   2. `scale-[0.78]` on the tilt layer. `scale` is applied by the
 *      compositor AFTER raster; on high-DPR devices (mobile, DPR 2–3),
 *      raster happens at 1× CSS px, then `scale 0.78 → display at
 *      DPR` upscales the raster → blurry. Desktop (DPR 1) happened to
 *      look sharp because display ended at < 1× (downscale). Tablet at
 *      `md:` breakpoint had `scale-100` → sharp by coincidence.
 *
 *      Fix: no `scale` on the tilt layer. Slides have their own
 *      responsive `w-[calc] max-w-[460px] aspect-[460/380]` — sizing
 *      happens at layout, not by raster-then-upscale. This is the
 *      single most important fix for mobile sharpness. If a future
 *      change re-adds `scale` (in any form) to any ancestor, mobile
 *      blur returns.
 *
 *   3. `backface-visibility: hidden` on each slide. Combined with the
 *      absence of `scale`, this nudges Chromium to raster each slide at
 *      native DPR (instead of 1× CSS px). It was tried without removing
 *      `scale` and did NOT help — because `scale` overrode its effect.
 *      Now that #2 is fixed, `backface-visibility: hidden` is kept as
 *      a stabilizer against future Chromium heuristic changes.
 *
 *   Do NOT add:
 *     - `will-change: transform` on any slide or the tilt layer.
 *       Previously froze the tilt keyframe and re-introduced 1× raster
 *       blur on desktop.
 *     - `scale` (property or `transform: scale()`) on the tilt layer.
 *     - `overflow-hidden` on the stage wrapper *without* `w-screen`
 *       (would re-clip slides at ~1200px instead of the viewport).
 *     - `translateZ` > 0 on any slide.
 *     - `image-rendering` / `shape-rendering` on SVGs (no-op for
 *       layer-level rasterization).
 *
 * Slide sizing
 *   `w-[calc(100vw-60px)] max-w-[460px] aspect-[460/380]` — 330px on a
 *   390px mobile viewport, 460px on desktop, capped at 460px on
 *   anything wider. Content inside was designed for 460×380; at 330px
 *   the inner padding (14px × 2 = 28px) leaves 302px of content space,
 *   which fits the widest internal element (the notary icon row at
 *   ~202px). Verified by inspection, not measurement.
 *
 * Stage overflow
 *   Slides at `n1`/`n2` extend up to ~770px from center on desktop.
 *   The stage wrapper is `w-screen` (100vw) with `overflow-hidden`, so
 *   clipping happens at the viewport boundary — same as the mockup's
 *   `.kv { overflow: hidden }`. Header, captions and controls each
 *   carry their own `mx-auto max-w-*` so only the stage is full-bleed.
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
 *   viewport edges instead of being pushed off-screen. Z and rotation
 *   are reduced in proportion so foreshortening stays similar.
 *
 *   Z values are the mockup's, shifted by −120 (active at Z = 0). See
 *   "Rasterization quality" #1.
 *
 * Micro-animations
 *   Each slide's inner elements carry `journey-*` classes that run
 *   continuously (mockup behavior — no `[data-active]` gate). Rules
 *   live in globals.css ("Journey micro-animations & progress bars").
 *   `data-active` on the slide is used only for `aria-hidden` semantics.
 *
 *     - `journey-shrink`  → two bars in SlideOptimize (breathing)
 *     - `journey-sweep`   → overlay in SlideLock (loops)
 *     - `journey-beacon`  → last node chip in SlideNotary (pulses)
 *     - `journey-bar`     → three content bars in SlideNotary, delay
 *                           from `--journey-bar-delay` inline (three
 *                           bars in separate parent `<div>`s cannot be
 *                           staggered via `:nth-of-type`).
 *     - `journey-line`    → eight dashed lines in SlideNetwork
 *                           (continuous dash motion)
 *     - `journey-node`    → eight satellite groups in SlideNetwork,
 *                           delay from `--journey-node-delay` inline
 *                           (same `:nth-of-type` constraint).
 *
 * Stage tilt
 *   The 3D drift (`rotateX(8°→4°) rotateY(-7°→6°)`) is applied via the
 *   `.journey-tilt` CSS class, not inline style. Rationale: it must be
 *   disabled on mobile via media query (see next paragraph) and gate-able
 *   via `prefers-reduced-motion` in CSS. Inline style would override
 *   both. Only `transform-style: preserve-3d` is inline — that is a
 *   structural property, not a tunable.
 *
 *   On mobile (< 768px), the tilt is disabled. The continuous 14s
 *   keyframe cycle forces the compositor to re-raster the tilt layer
 *   every frame it advances, and on mobile GPUs that raster competes
 *   with the render budget enough to re-introduce the sharp→blurry
 *   swap this component spent multiple iterations fixing. Desktop and
 *   tablet keep the tilt. Re-enabling on mobile means accepting either
 *   the blur regression or a full compositor-promotion trial (see
 *   "Rasterization quality" for the reasons `will-change` is not the
 *   answer).
 *
 * Reduced motion
 *   `prefers-reduced-motion: reduce` disables autoplay, applies
 *   `transition: none` to every slide, and (via CSS) disables the
 *   stage tilt. The carousel becomes a static stage on step 0 that the
 *   visitor can navigate with the controls.
 *
 * Accessibility
 *   - Non-active slides carry `aria-hidden="true"`.
 *   - The four progress-bar segments are buttons ("Show step N of 4").
 *   - Prev / Pause / Next buttons carry `aria-label`s.
 *   - `aria-current="step"` marks the active segment.
 *   - Focus ring comes from `:focus-visible` in globals.css.
 *
 * Known limitation — wrap transition
 *   When the cycle wraps (step 3 → 0 or 0 → 3), at least one slide
 *   transitions between a "past" slot (P1) and a "future" slot (N2)
 *   while still visible, crossing the center of the stage. The mockup
 *   hides this by fading to 0 before the jump; a two-phase transition
 *   would be required to match exactly.
 *
 * Slide fidelity notes
 *   - SlideLock contains three layers matching the mockup's `.vl v2`:
 *     a blurred duplicate, a darkening overlay, and a lock icon. The
 *     emerald "sweep cursor" dot sits on the sweep's right edge.
 *   - SlideNetwork renders eight blurred satellite thumbnails of the
 *     four journey photos (mockup `.pp`), clipped to rounded rects.
 *   - The blurred duplicate in SlideLock hardcodes `w-[432px]` (inner
 *     slide width at desktop, 460 − 2×14 padding). On mobile, the
 *     slide is narrower, so the blurred duplicate overflows the
 *     sweep's clip and is only shown inside the sweep's expanding
 *     width — visually correct because the sweep never exceeds the
 *     inner width.
 */

const STEP_DURATION_MS = 5000;
const TRANSITION_MS = 400;
const SLIDE_COUNT = 4;
const SLIDE_INNER_WIDTH_PX = 432; // 460 - 2 × 14 (p-3.5)

const SLIDES = [
  { kind: "optimize" as const },
  { kind: "lock" as const },
  { kind: "notary" as const },
  { kind: "network" as const },
];

/**
 * Per-slot opacity. X/Z/rotation live in CSS variables
 * (`--pos-<slot>-{x,z,ry}`) so a single media query can retune mobile
 * offsets without duplicating JSX. See the file header.
 */
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

const CAPTIONS = [
  {
    title: "Each photo, optimized.",
    body: "Every photo is tidied and made lighter on your device, then stored on its own.",
    hood: "Under the hood · per-photo optimization",
  },
  {
    title: "Locked on your device.",
    body: "Scrambled with a key only you hold, before anything leaves.",
    hood: "Under the hood · symmetric encryption",
  },
  {
    title: "Noted by a blind notary.",
    body: "A public contract records that it is yours. It cannot see what it is.",
    hood: "Under the hood · Arbitrum smart contract",
  },
  {
    title: "Kept in many places.",
    body: "Locked copies on computers around the world, for good or for the time you choose. Nobody hosting one can see inside.",
    hood: "Under the hood · Irys storage network",
  },
] as const;

export function JourneyStage() {
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
        <p className="label-mono text-emerald-text">How it works</p>
        <h2 className="mt-4 text-[30px] font-bold leading-tight tracking-[-0.025em] text-ink md:text-[40px]">
          Your photo&apos;s journey.
        </h2>
        <p className="mt-4 text-[15px] leading-relaxed text-muted md:text-[16px]">
          One approval, and all four steps happen together. If one fails,
          none of them do.
        </p>
      </div>

      {/* Symbols defined once per page. The slides' `<use href="#sN" />`
          resolve against this instance. */}
      <JourneySamples />

      {/* Stage wrapper — w-screen + centered via left-1/2 -translate-x-1/2,
          overflow-hidden so slides clip at the viewport (like the mockup's
          `.kv { overflow: hidden }`). */}
      <div className="relative left-1/2 mt-7 h-[410px] w-screen -translate-x-1/2 overflow-hidden md:h-[520px]">
        {/* Perspective — more foreshortening on mobile (1200px) makes
            the 3D layering visible at small sizes; desktop uses the
            mockup's 1800px. */}
        <div className="absolute inset-0 [perspective:1200px] md:[perspective:1800px]">
          {/* Tilt layer. `preserve-3d` and the tilt animation class.
              The animation is applied via CSS (globals.css `.journey-tilt`)
              so it can be disabled below `md:` and under reduced motion
              without fighting inline styles. */}
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
                    // `translate(-50%, -50%)` centers the slide
                    // regardless of its responsive width/height; the
                    // `translate3d` then offsets in 3D. Position X/Z/ry
                    // come from `--pos-<slot>-{x,z,ry}` (globals.css),
                    // which are retuned under `@media (max-width: 767px)`.
                    transform: `translate(-50%, -50%) translate3d(var(--pos-${pos}-x), 0, var(--pos-${pos}-z)) rotateY(var(--pos-${pos}-ry))`,
                    opacity,
                    transition: transitionStyle,
                    // See "Rasterization quality" #3.
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

      <div className="relative mx-auto mt-3 h-[170px] max-w-[620px] text-center md:h-[150px]">
        {CAPTIONS.map((cap, i) => (
          <div
            key={cap.title}
            className="absolute inset-0 transition-opacity duration-300 ease-out"
            style={{
              opacity: i === current ? 1 : 0,
              pointerEvents: i === current ? "auto" : "none",
            }}
            aria-hidden={i !== current}
          >
            <p className="text-[26px] font-semibold tracking-[-0.02em] text-ink">
              {cap.title}
            </p>
            <p className="mx-auto mt-2 max-w-[560px] text-[15px] leading-[1.55] text-muted">
              {cap.body}
            </p>
            <p className="mt-2.5 font-mono text-[11px] text-muted/70">
              {cap.hood}
            </p>
          </div>
        ))}
      </div>

      <div className="mt-4 flex flex-col items-center gap-4">
        <div
          className="flex w-full max-w-[360px] gap-2"
          role="group"
          aria-label="Journey steps"
        >
          {CAPTIONS.map((cap, i) => {
            const isActive = i === current;
            return (
              <button
                key={`${i}-${isActive ? "active" : "inactive"}-${generation}`}
                type="button"
                onClick={() => goTo(i)}
                aria-label={`Show step ${i + 1} of ${SLIDE_COUNT}: ${cap.title}`}
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
          <TransportButton onClick={retreat} label="Previous step">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
              <path d="M15 18l-6-6 6-6" />
            </svg>
          </TransportButton>
          <TransportButton
            onClick={handleTogglePause}
            label={paused ? "Play" : "Pause"}
          >
            {paused ? (
              <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                <path d="M8 5v14l11-7z" />
              </svg>
            ) : (
              <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                <rect x="6" y="4" width="4" height="16" rx="1" />
                <rect x="14" y="4" width="4" height="16" rx="1" />
              </svg>
            )}
          </TransportButton>
          <TransportButton onClick={advance} label="Next step">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
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
 * Structural replicas of the mockup's four slides. Elements that are
 * animated carry `journey-*` classes; the rules key off the parent
 * slide's `data-active` attribute. See the component header.
 * ─────────────────────────────────────────────────────────────────── */

function SlideOptimize() {
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
          Size
          <span className="h-1.5 flex-1 overflow-hidden rounded-full bg-hairline">
            <span className="journey-shrink block h-full w-full rounded-full bg-emerald" />
          </span>
        </div>
        <div className="mt-2.5 flex items-center gap-2 font-mono text-[11px] font-medium text-slate-300">
          Price
          <span className="h-1.5 flex-1 overflow-hidden rounded-full bg-hairline">
            <span className="journey-shrink block h-full w-full rounded-full bg-emerald" />
          </span>
        </div>
      </div>

      <span className="journey-chip absolute right-3.5 top-3.5 rounded-full border border-hairline bg-card px-4 py-2 font-mono text-[12px] text-ink">
        Optimized · one photo at a time
      </span>
    </>
  );
}

function SlideLock() {
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
          className="absolute left-1/2 top-1/2 -mt-3 -ml-3 h-6 w-6 text-white drop-shadow-[0_2px_8px_rgba(0,0,0,0.6)]"
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
          className="absolute top-1/2 -right-[13px] -mt-[13px] h-[26px] w-[26px] rounded-full bg-emerald"
          style={{ boxShadow: "0 0 0 6px oklch(0.70 0.15 160 / 0.25)" }}
        />
      </div>

      <span className="journey-chip absolute bottom-3.5 left-3.5 inline-flex items-center gap-1.5 rounded-full border border-hairline bg-card px-4 py-2 font-mono text-[12px] text-ink">
        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" className="text-emerald-text" aria-hidden="true">
          <rect x="5" y="11" width="14" height="9" rx="2" />
          <path d="M8 11V8a4 4 0 0 1 8 0v3" />
        </svg>
        Key stays on this device
      </span>
    </>
  );
}

function SlideNotary() {
  return (
    <div className="relative h-full bg-elevated p-6">
      <p className="mb-3.5 font-mono text-[11px] uppercase tracking-[0.1em] text-muted">
        Public notary · smart contract
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
        owner
        <span className="text-emerald-text">0x7a3F…c91E</span>
      </div>
      <div className="mb-2.5 flex items-center gap-2 font-mono text-[13px] text-muted">
        content
        <span
          className="journey-bar inline-block h-[9px] w-[110px] rounded-[5px] bg-violet/80"
          style={{ "--journey-bar-delay": "0.3s" } as CSSProperties}
        />
      </div>
      <div className="mb-2.5 flex items-center gap-2 font-mono text-[13px] text-muted">
        name
        <span
          className="journey-bar inline-block h-[9px] w-[110px] rounded-[5px] bg-violet/80"
          style={{ "--journey-bar-delay": "0.5s" } as CSSProperties}
        />
      </div>
      <div className="flex items-center gap-2 font-mono text-[13px] text-muted">
        type
        <span
          className="journey-bar inline-block h-[9px] w-[110px] rounded-[5px] bg-violet/80"
          style={{ "--journey-bar-delay": "0.7s" } as CSSProperties}
        />
      </div>
      <p className="mt-4 font-mono text-[12px] text-violet-text">
        It cannot see inside.
      </p>
    </div>
  );
}

function SlideNetwork() {
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
      <span className="absolute bottom-3.5 left-3.5 rounded-full border border-hairline bg-card px-4 py-2 font-mono text-[12px] text-ink">
        Locked copies, worldwide
      </span>
    </>
  );
}
