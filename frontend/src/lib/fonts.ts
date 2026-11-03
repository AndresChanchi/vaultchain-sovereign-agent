/**
 * Font configuration — self-hosted by `next/font/google` at build time.
 *
 * Each call to a `next/font/google` function downloads the woff2,
 * hashes the URL, injects `<link rel="preload">` for the subsets used
 * on the page, and exposes a CSS variable that `globals.css` consumes
 * as `--font-sans` / `--font-mono` / `--font-serif`.
 *
 * Why not in `globals.css`
 *   `next/font/google` is a Node.js function that runs during the
 *   build. It emits file hashes, preload tags, and font-face rules
 *   that cannot be authored by hand. Static CSS cannot replicate the
 *   self-hosting + subsetting + preload behaviour. The fonts must be
 *   declared in TypeScript.
 *
 * `display: "swap"`
 *   Avoids invisible text during font load. CLS is bounded because
 *   the fallback metrics (system-ui / Georgia) are close enough that
 *   the swap causes negligible layout shift for the sizes used.
 *
 * Consumers
 *   `src/app/layout.tsx` applies the three CSS variables to `<html>`
 *   via `className`. Any component that needs the font uses the
 *   Tailwind classes (`font-sans`, `font-mono`, `font-serif`) which
 *   resolve through `globals.css` @theme.
 */

import { Geist, Geist_Mono, Instrument_Serif } from "next/font/google";

export const geistSans = Geist({
  subsets: ["latin"],
  variable: "--font-geist-sans",
  display: "swap",
});

export const geistMono = Geist_Mono({
  subsets: ["latin"],
  variable: "--font-geist-mono",
  display: "swap",
});

export const instrumentSerif = Instrument_Serif({
  subsets: ["latin"],
  weight: "400",
  variable: "--font-instrument-serif",
  display: "swap",
});
