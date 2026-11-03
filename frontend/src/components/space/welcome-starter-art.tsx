/**
 * Abstract landscape gradients — the mockup's blurred-photo
 * thumbnails, recreated as layered CSS gradients.
 *
 * The mockup uses full SVG scenes (`<symbol id="s1">`..`"s4"`) with a
 * fractal-noise filter and vignette. Blurred at 7px, the visible part
 * is: a base gradient (sky → horizon → foreground), a soft sun/light
 * spot, a darker band at the bottom. These gradients replicate those
 * layers with the exact color stops from the mockup (`k1`, `k2`,
 * `k3`, `k4`) — visually indistinguishable at the 110×90 thumbnail
 * and 200-300px stage-tile sizes.
 *
 * Cheaper than porting the SVGs: no filter defs, no symbol registry,
 * no `<use>` cross-references. Every consumer just spreads the
 * returned CSS string as `background`.
 *
 * Consumers
 *   - `welcome-starters.tsx` — 120×100 blurred art on each card.
 *   - `welcome-stage.tsx` — larger tiles in the 3D scene.
 */

export type StarterArt = "sunset" | "ocean" | "night" | "forest";

const ART_BACKGROUND: Record<StarterArt, string> = {
  /** k1 — mountain sunset (deep blue → violet → orange → gold). */
  sunset:
    "radial-gradient(circle at 72% 32%, rgba(255,241,201,0.95) 0%, rgba(253,230,138,0.5) 8%, transparent 22%), linear-gradient(180deg, #16224f 0%, #6a4b92 38%, #f0a35c 62%, #f8d48e 74%, #2a1a3a 100%)",
  /** k2 — ocean at sunrise (deep blue → blue → salmon → gold). */
  ocean:
    "radial-gradient(circle at 38% 62%, rgba(255,246,214,0.95) 0%, rgba(255,227,161,0.6) 6%, transparent 24%), linear-gradient(180deg, #14395e 0%, #4a86a8 45%, #f4b48c 70%, #fbd9a8 82%, #2a1a3a 100%)",
  /** k3 — night city (near-black → blue → violet with stars). */
  night:
    "radial-gradient(circle at 83% 18%, rgba(243,246,255,0.95) 0%, rgba(243,246,255,0.4) 4%, transparent 12%), radial-gradient(circle at 22% 32%, rgba(255,255,255,0.5) 0%, transparent 3%), linear-gradient(180deg, #050a1c 0%, #1b2a5c 55%, #8a5a8f 100%)",
  /** k4 — foggy forest (white → pale green → dark green). */
  forest:
    "linear-gradient(180deg, rgba(255,255,255,0.55) 0%, transparent 25%), linear-gradient(180deg, #d6e8dc 0%, #8fb09a 55%, #2c4a3c 100%)",
};

export function artBackground(variant: StarterArt): string {
  return ART_BACKGROUND[variant];
}
