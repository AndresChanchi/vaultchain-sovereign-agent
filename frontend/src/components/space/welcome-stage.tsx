"use client";

/**
 * Welcome stage — the visual promise for the empty state.
 *
 * Two layouts, one component:
 *   - Compact (`< lg`): 2×2 grid, one is the target. Photo-arrive →
 *     lock-reveal → kept-badge loop. No cursor (cell too tight).
 *   - Spatial (`≥ lg`): 3D tilt scene from the mockup — five floating
 *     frames around a central target, plus the cursor.
 *
 * Stage height (desktop): `h-[400px]`.
 *   The mockup uses 540px, but its chrome is minimal (no
 *   shell padding). Ours adds ~112px of shell chrome on top of the
 *   same 900px viewport; a 540px stage would push the starters below
 *   the fold. 400 fits on all desktop heights ≥ 800px with the
 *   starters pinned at the bottom via the welcome's flex-1 spacer.
 *
 * Tile art
 *   Uses `artBackground` from `welcome-starter-art.tsx` — the same
 *   layered gradients the starter cards use, at larger scale.
 *
 * Cursor
 *   Stage-level, outside the perspective layer so it does not tilt
 *   with the scene. Slides in from bottom-right, "clicks" the target
 *   (scale pulse), holds, fades out. See `globals.css` for the exact
 *   10s loop timing shared with the photo arrival inside the frame.
 *
 * Reduced motion
 *   All animations resolve to `none`. The stage reads as a still
 *   composition: 5 dashed frames, one target with a breathing border.
 */
import { CursorIcon, LockIcon } from "./space-icons";
import { artBackground, type StarterArt } from "./welcome-starter-art";

export function WelcomeStage() {
  return (
    <>
      <StageCompact />
      <StageSpatial />
    </>
  );
}

function StageCompact() {
  return (
    <div aria-hidden="true" className="lg:hidden">
      <div className="mx-auto grid w-full max-w-[420px] grid-cols-2 gap-3 sm:gap-4">
        <Frame art="night" />
        <Frame art="ocean" />
        <Frame art="forest" />
        <TargetFrameCompact />
      </div>
    </div>
  );
}

function Frame({ art }: { art: StarterArt }) {
  return (
    <div className="relative aspect-square overflow-hidden rounded-[16px] border border-dashed border-emerald/25">
      <div
        aria-hidden="true"
        className="absolute inset-0 opacity-85 blur-[6px]"
        style={{ background: artBackground(art) }}
      />
    </div>
  );
}

function TargetFrameCompact() {
  return (
    <div className="relative aspect-square overflow-hidden rounded-[16px] border-2 border-dashed animate-breathe bg-emerald/[0.06]">
      <PhotoLayer />
      <LockRevealLayer lockSize={22} />
      <KeptBadge compact />
    </div>
  );
}

function StageSpatial() {
  return (
    <div aria-hidden="true" className="relative hidden h-[500px] lg:block">
      <div className="absolute inset-0 [perspective:1600px]">
        <div className="relative h-full w-full animate-stage-tilt [transform-style:preserve-3d]">
          <SpatialTile
            size="w-[220px] h-[280px]"
            transform="translate3d(-330px, -150px, -120px) rotateY(18deg)"
            delay="0s"
            art="ocean"
          />
          <SpatialTile
            size="w-[260px] h-[190px]"
            transform="translate3d(-90px, -190px, -40px)"
            delay="-0.7s"
            art="night"
          />
          <SpatialTile
            size="w-[200px] h-[250px]"
            transform="translate3d(200px, -170px, -160px) rotateY(-18deg)"
            delay="-1.4s"
            art="forest"
          />
          <SpatialTile
            size="w-[230px] h-[170px]"
            transform="translate3d(150px, 70px, -60px) rotateY(-8deg)"
            delay="-2.1s"
            art="sunset"
          />
          <SpatialTile
            size="w-[180px] h-[140px]"
            transform="translate3d(-330px, 90px, -20px) rotateY(10deg)"
            delay="-2.8s"
            art="ocean"
          />

          <div
            className="absolute left-1/2 top-1/2 h-[220px] w-[300px] -translate-x-1/2 -translate-y-1/2 animate-breathe overflow-hidden rounded-[18px] border-2 border-dashed bg-emerald/[0.06]"
            style={{ transform: "translate3d(-50%, -50%, 80px)" }}
          >
            <PhotoLayer />
            <LockRevealLayer lockSize={36} />
            <KeptBadge />
          </div>
        </div>
      </div>

      <div
        className="pointer-events-none absolute left-1/2 top-1/2 z-10 opacity-0 animate-cursor-drag text-white"
        style={{
          filter:
            "drop-shadow(0 1px 2px rgba(0,0,0,0.85)) drop-shadow(0 0 1px rgba(0,0,0,0.6))",
        }}
      >
        <CursorIcon size={24} />
      </div>
    </div>
  );
}

function PhotoLayer() {
  return (
    <div className="absolute inset-0 origin-top-left animate-photo-arrive bg-gradient-to-br from-emerald/50 via-violet/40 to-amber/40 opacity-0">
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_75%_25%,rgba(255,255,255,0.28),transparent_55%)]" />
    </div>
  );
}

function LockRevealLayer({ lockSize }: { lockSize: number }) {
  return (
    <div className="pointer-events-none absolute inset-y-0 left-0 w-0 animate-lock-reveal overflow-hidden">
      <div className="absolute inset-0 bg-gradient-to-br from-emerald/60 via-violet/50 to-amber/50 backdrop-blur-[2px]" />
      <div className="absolute inset-0 grid place-items-center">
        <LockIcon
          size={lockSize}
          className="text-white drop-shadow-[0_2px_4px_rgba(0,0,0,0.5)]"
        />
      </div>
    </div>
  );
}

function KeptBadge({ compact = false }: { compact?: boolean }) {
  const position = compact ? "right-2 top-2" : "right-3 top-3";
  const padding = compact ? "px-2 py-0.5 text-[9px]" : "px-2.5 py-1 text-[10px]";
  return (
    <div className={`absolute ${position} opacity-0 animate-kept-badge`}>
      <span
        className={`rounded-full bg-emerald font-mono font-semibold text-on-emerald ${padding}`}
      >
        Kept ✓
      </span>
    </div>
  );
}

function SpatialTile({
  size,
  transform,
  delay,
  art,
}: {
  size: string;
  transform: string;
  delay: string;
  art: StarterArt;
}) {
  return (
    <div
      className={
        "absolute left-1/2 top-1/2 animate-bob overflow-hidden rounded-[18px] border border-emerald/15 " +
        size
      }
      style={{
        transform: `translate(-50%, -50%) ${transform}`,
        animationDelay: delay,
      }}
    >
      <div
        aria-hidden="true"
        className="absolute inset-0 opacity-85 blur-[6px]"
        style={{ background: artBackground(art) }}
      />
    </div>
  );
}
