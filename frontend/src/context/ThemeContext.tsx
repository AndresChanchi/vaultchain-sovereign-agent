"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";

export type Theme = "dark" | "light" | "system";
export type ResolvedTheme = "dark" | "light";

const STORAGE_KEY = "kipio:theme";
const DEFAULT_THEME: Theme = "system";

type ThemeContextValue = {
  /** The user's explicit choice (may be "system"). */
  theme: Theme;
  /** The theme actually in effect right now ("dark" or "light"). */
  resolvedTheme: ResolvedTheme;
  /** Persists and applies a new theme. */
  setTheme: (theme: Theme) => void;
};

const ThemeContext = createContext<ThemeContextValue | null>(null);

function readStoredTheme(): Theme {
  if (typeof window === "undefined") return DEFAULT_THEME;
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (raw === "dark" || raw === "light" || raw === "system") return raw;
  } catch {
    /* Storage blocked — fall through to default. */
  }
  return DEFAULT_THEME;
}

function resolveTheme(theme: Theme): ResolvedTheme {
  if (theme !== "system") return theme;
  if (typeof window === "undefined") return "dark";
  return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
}

/**
 * Provides the active theme to the app. Persists the choice in
 * localStorage under `kipio:theme`, applies it to
 * `document.documentElement.dataset.theme` (which `globals.css` reads
 * through `:root[data-theme=...]`), and keeps `resolvedTheme` in sync
 * when the OS preference changes for "system".
 *
 * Default theme
 *   `"system"` — not `"dark"`. The user's OS preference drives the
 *   initial paint (via `light-dark()` CSS once `data-theme="system"`
 *   is set on `<html>`), so a first visit on a light-OS browser shows
 *   light, and a first visit on a dark-OS browser shows dark. There is
 *   no flash because the init script in `layout.tsx` applies the
 *   stored-or-default theme before first paint — see that file.
 *
 *   Before this change the default was `"dark"`, which meant every
 *   first visit ignored the user's OS preference. That contradicted
 *   the product's stated intent ("the browser tries to guess what the
 *   user was") and was fixed.
 *
 * "System" is never shown in the UI
 *   The visible toggle exposes only two states (`light` and `dark`)
 *   and renders the icon for `resolvedTheme`, not `theme`. A user in
 *   the `"system"` state sees the icon matching their effective
 *   appearance — sun on a light-OS browser, moon on a dark-OS one.
 *   "System" is a valid theme value (Settings can expose it in a
 *   future phase), but the toggle never surfaces it.
 *
 * The initial paint is handled by an inline script in the root layout
 * so the user never sees a flash of the wrong theme on reload.
 */
export function ThemeProvider({ children }: { children: ReactNode }) {
  const [theme, setThemeState] = useState<Theme>(DEFAULT_THEME);
  const [resolvedTheme, setResolvedTheme] = useState<ResolvedTheme>("dark");

  // Hydrate from storage on mount to avoid touching localStorage during SSR.
  useEffect(() => {
    const stored = readStoredTheme();
    setThemeState(stored);
    setResolvedTheme(resolveTheme(stored));
    document.documentElement.dataset.theme = stored;
  }, []);

  // Apply and persist whenever the choice changes.
  useEffect(() => {
    document.documentElement.dataset.theme = theme;
    setResolvedTheme(resolveTheme(theme));
    try {
      window.localStorage.setItem(STORAGE_KEY, theme);
    } catch {
      /* Storage blocked — the choice simply won't persist. */
    }
  }, [theme]);

  // Keep "system" in sync with OS changes.
  useEffect(() => {
    if (theme !== "system") return;
    const mq = window.matchMedia("(prefers-color-scheme: dark)");
    const onChange = () => {
      setResolvedTheme(mq.matches ? "dark" : "light");
      document.documentElement.dataset.theme = "system";
    };
    mq.addEventListener("change", onChange);
    return () => mq.removeEventListener("change", onChange);
  }, [theme]);

  const setTheme = useCallback((next: Theme) => setThemeState(next), []);

  const value = useMemo<ThemeContextValue>(
    () => ({ theme, resolvedTheme, setTheme }),
    [theme, resolvedTheme, setTheme],
  );

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme(): ThemeContextValue {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error("useTheme must be used within a ThemeProvider");
  return ctx;
}
