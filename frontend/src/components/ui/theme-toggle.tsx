"use client";

/**
 * Theme toggle — flips between light and dark.
 *
 * Consumes `useTheme()` from `@context/ThemeContext`, which owns
 * persistence (`localStorage["kipio:theme"]`), DOM application
 * (`document.documentElement.dataset.theme`), and OS-preference sync
 * for the "system" value. This component is *only* the UI.
 *
 * Why two states, not three
 *   The mockup shows no theme control, so the pattern is ours to
 *   choose. Three-state cycles (`light → dark → system → light`) are
 *   confusing for the same reason submenus inside toggles are: the
 *   user has to model what "system" means at every render, and the
 *   "desktop" icon has no self-evident meaning. In contrast, a
 *   sun ↔ moon flip is what every consumer app ships (Linear, Notion,
 *   VS Code, shadcn/ui). Two states, no cycle, no third icon to
 *   explain.
 *
 *   `"system"` remains a valid value of the theme context — it is what
 *   the app uses when no explicit choice exists — but this component
 *   never enters that state *as the source of a render*. The visible
 *   icon is `resolvedTheme` (dark → moon, light → sun), which is the
 *   same visual a user would see if the theme were explicitly
 *   `"light"` or `"dark"`. Clicking always sets an explicit choice.
 *
 * Clicking while in "system"
 *   If the user has never made an explicit choice (`theme === "system"`)
 *   and the OS is currently dark, the first click sets `"light"`. If
 *   the OS is currently light, the first click sets `"dark"`. In both
 *   cases the result matches what the user sees happening — a
 *   sun-to-moon or moon-to-sun flip. There is no invisible third hop.
 *
 * Returning to "system"
 *   Not exposed in the toggle. A future Settings page (Fase 12) can
 *   offer a "Use system setting" row for users who want the automatic
 *   behavior back. Until then, an explicit choice persists — which is
 *   the correct default: most users prefer determinism over
 *   auto-detection once they have touched the control.
 *
 * Icons
 *   Inline SVGs, no icon library. 18×18 to match the globe and lock
 *   icons in the navbar. `aria-hidden` — the button's `aria-label`
 *   carries the readable state.
 *
 * Accessibility
 *   - `aria-label` describes the *action*: "Switch to light theme"
 *     when the resolved theme is dark, "Switch to dark theme" when it
 *     is light. Dynamic labels keep the button truthful to what the
 *     next click does.
 *   - No `title` attribute. The `aria-label` already carries the
 *     readable state; `title` would duplicate it as a native tooltip
 *     (delayed, inconsistent across browsers) without adding
 *     information.
 *   - Focus ring comes from `:focus-visible` in globals.css.
 *   - The button is 40×40 (matches the other glass controls).
 *
 * Rendering before hydration
 *   `useTheme()` starts with `theme: "system"` and `resolvedTheme:
 *   "dark"` during SSR. The first client paint inherits those values,
 *   then the hydrate effect reads localStorage + `matchMedia` and
 *   swaps. If the user is on a light-OS browser, they see the icon
 *   flip sun on the first client frame — acceptable, and identical to
 *   the pre-existing behaviour with `"dark"` default. The *page*
 *   theme itself never flashes (the init script in `layout.tsx` runs
 *   before first paint).
 *
 * Placements
 *   - Navbar (this phase): a glass button alongside the language
 *     picker, before "Log in".
 *   - Settings page (Fase 12): can consume the same component, or use
 *     `useTheme()` directly for a segmented control. No changes needed
 *     to this file for that.
 */

import { useTheme } from "@context/ThemeContext";

export function ThemeToggle() {
  const { resolvedTheme, setTheme } = useTheme();
  const isDark = resolvedTheme === "dark";

  function toggle() {
    // `resolvedTheme` already resolves `"system"` to the OS preference.
    // Flipping from the resolved value makes the click match what the
    // user sees, whether the underlying theme was `"system"` or an
    // explicit `"dark"` / `"light"`.
    setTheme(isDark ? "light" : "dark");
  }

  return (
    <button
      type="button"
      onClick={toggle}
      aria-label={isDark ? "Switch to light theme" : "Switch to dark theme"}
      className="glass inline-flex h-10 w-10 items-center justify-center rounded-[14px] text-ink transition-colors duration-200 hover:bg-elevated"
    >
      {isDark ? <MoonIcon /> : <SunIcon />}
    </button>
  );
}

function MoonIcon() {
  return (
    <svg
      width="18"
      height="18"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" />
    </svg>
  );
}

function SunIcon() {
  return (
    <svg
      width="18"
      height="18"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <circle cx="12" cy="12" r="4" />
      <path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41" />
    </svg>
  );
}
