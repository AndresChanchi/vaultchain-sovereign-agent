/**
 * Theme-init script — inline JS injected into `<head>` before hydration.
 *
 * Reads `localStorage["kipio:theme"]` and sets `data-theme` on the
 * `<html>` element so the correct palette is applied on the very
 * first paint, before React mounts. Without it there would be a
 * flash of the wrong theme (FOUC) on every reload for anyone not on
 * the default.
 *
 * Why not in `globals.css`
 *   CSS cannot read `localStorage`, cannot assign an attribute to
 *   `<html>`, and cannot run before the first paint. Only a blocking
 *   inline script in `<head>` can do all three.
 *
 * Why `<Script strategy="beforeInteractive">` and not a raw `<script>`
 *   React 19 warns when it encounters a `<script>` tag inside the
 *   React tree: "Scripts inside React components are never executed
 *   when rendering on the client." `next/script` with
 *   `strategy="beforeInteractive"` injects the script into the
 *   initial HTML `<head>` (executes before paint — same FOUC-free
 *   behaviour) without re-rendering it in the React tree. No
 *   warning, same result.
 *
 * Validation
 *   Only the three known values (`dark`, `light`, `system`) are
 *   accepted from `localStorage`. Anything else falls back to
 *   `system`. Prevents a tampered value from ending up as a bogus
 *   `data-theme` attribute — the CSS selector would silently fail
 *   and the default palette would render, which is not what the
 *   user's stored preference says.
 *
 * `suppressHydrationWarning` on `<html>`
 *   Required because this script mutates `data-theme` before React
 *   hydrates. React sees a different attribute on the client vs the
 *   server, which is legitimate (client-side state) but would warn
 *   otherwise. Applies to `<html>` only.
 */
export const themeInitScript = `
(function(){
  try {
    var stored = localStorage.getItem("kipio:theme");
    var theme = (stored === "dark" || stored === "light" || stored === "system") ? stored : "system";
    document.documentElement.dataset.theme = theme;
  } catch (e) {
    document.documentElement.dataset.theme = "system";
  }
})();
`;
