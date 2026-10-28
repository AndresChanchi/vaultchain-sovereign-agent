"use client";

/**
 * I18n provider — binds a dictionary and a locale to the React tree
 * and exposes `useI18n()` to any descendant.
 *
 * Two modes of operation, one implementation
 *   A. **Pre-restructure** (now): the server passes `en` as the
 *      initial dictionary. Client-side switching loads the target
 *      dictionary dynamically and updates state + `<html lang/dir>` +
 *      storage. No navigation, because there are no `[locale]` routes
 *      yet.
 *
 *   B. **Post-restructure** (later): the root layout for each group
 *      passes the locale + dictionary matching the URL, so the first
 *      paint is already in the right language. Client-side switching
 *      additionally navigates (`router.push`), which triggers a fresh
 *      server render in the target locale.
 *
 * Initial-locale detection
 *   The server does not know the user's preference (static export has
 *   no middleware and no cookies at request time). So on mount, this
 *   provider calls `detectLocale()` (localStorage → cookie → browser
 *   → default) and, if the answer differs from the server-provided
 *   `locale` AND the answer has a real dictionary
 *   (`AVAILABLE_LOCALES.includes(preferred)`), loads the correct
 *   dictionary and swaps.
 *
 *   The availability guard matters: a Chinese-browser visitor on a
 *   build that only ships `en` + `es` would otherwise set
 *   `locale: "zh"` while the loaded dictionary is English — a state
 *   that renders English strings under a `<html lang="zh">`
 *   attribute, which is both a UX lie and an SEO contradiction.
 *   Returning early on an unavailable locale keeps the state
 *   coherent: `en` until `zh` is translated.
 *
 *   The flash for users whose preference is a supported non-default
 *   locale (e.g. stored `es`) is a documented trade-off of static
 *   export, not something a different design would fix without a
 *   server. Post-restructure, navigating directly to `/es/...`
 *   serves Spanish HTML from the build, so no flash on that route.
 *
 * Dictionary loading
 *   `en` is eager (bundled with this file). All other locales load via
 *   `await import("./dictionaries/<code>")`, which Next.js splits into
 *   per-locale chunks — a visitor who never changes language never
 *   downloads them. There is no explicit cache: the module system
 *   already caches dynamic imports, so switching back and forth is
 *   free after the first load.
 *
 * Format
 *   `format` is a memoised `FormatFns` bound to the current locale.
 *   Memoisation matters because consumers pass it into child
 *   components; a new object each render would defeat `React.memo`
 *   everywhere downstream.
 */

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import {
  AVAILABLE_LOCALES,
  detectLocale,
  isLocale,
  LOCALE_META,
  persistLocale,
  type Locale,
} from "@lib/i18n/locales";
import { createFormatters } from "@lib/i18n/format";
import { t as translate } from "@lib/i18n/translate";
import { en as enDictionary } from "@lib/i18n/dictionaries/en";
import type { Dictionary, FormatFns, TranslateFn } from "@lib/i18n/types";

/**
 * The context surface. Anything a consumer needs goes here:
 *   - `locale` — the active code (useful for `lang`, `dir`, links).
 *   - `dictionary` — the active dictionary object (for iterating
 *     arrays like `journey.steps` that are not addressable via `t()`).
 *   - `setLocale` — async because of the dynamic import; callers may
 *     `await` if they need to sequence side effects.
 *   - `t` — pure translator bound to `dictionary`.
 *   - `format` — locale-bound `Intl` helpers.
 */
type I18nContextValue = {
  locale: Locale;
  dictionary: Dictionary;
  setLocale: (locale: Locale) => Promise<void>;
  t: TranslateFn;
  format: FormatFns;
};

const I18nContext = createContext<I18nContextValue | null>(null);

/**
 * Lazily load a dictionary by locale code. Falls back to `en` for
 * codes without a dedicated file.
 *
 * Add a `case` here when a new `dictionaries/<code>.ts` lands. The
 * mount effect below guards against calling this with a code not in
 * `AVAILABLE_LOCALES`, so the `default` branch is defensive only — it
 * exists because TS exhaustiveness over a widening union (`Locale`)
 * would require a case for every locale in `LOCALES`, most of which
 * do not have dictionaries yet.
 */
async function loadDictionary(locale: Locale): Promise<Dictionary> {
  switch (locale) {
    case "en":
      return (await import("@lib/i18n/dictionaries/en")).en;
    case "es":
      return (await import("@lib/i18n/dictionaries/es")).es;
    default:
      return (await import("@lib/i18n/dictionaries/en")).en;
  }
}

type I18nProviderProps = {
  /** Server-provided initial locale. Defaults to `en`. */
  initialLocale?: Locale;
  /** Server-provided initial dictionary. Defaults to the `en` import. */
  initialDictionary?: Dictionary;
  children: ReactNode;
};

export function I18nProvider({
  initialLocale = "en",
  initialDictionary = enDictionary,
  children,
}: I18nProviderProps) {
  // Single state blob so locale + dictionary cannot drift out of sync.
  const [state, setState] = useState<{
    locale: Locale;
    dictionary: Dictionary;
  }>({
    locale: initialLocale,
    dictionary: initialDictionary,
  });

  // ── Detect preference on first mount ─────────────────────────────
  // Runs once. Guarded three ways:
  //   1. `preferred === initialLocale` → already correct, no swap.
  //   2. `!AVAILABLE_LOCALES.includes(preferred)` → no dictionary
  //      exists for that locale yet; keep `en` (see file header).
  //   3. `cancelled` → the component unmounted before the dynamic
  //      import resolved; drop the result to avoid a setState on an
  //      unmounted component.
  useEffect(() => {
    const preferred = detectLocale();
    if (preferred === initialLocale) return;
    if (!AVAILABLE_LOCALES.includes(preferred)) return;

    let cancelled = false;
    (async () => {
      const dictionary = await loadDictionary(preferred);
      if (cancelled) return;
      setState({ locale: preferred, dictionary });
    })();

    return () => {
      cancelled = true;
    };
    // `initialLocale` is a mount-time value; re-running on it would
    // undo manual switches. Intentionally empty deps.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // ── Keep <html lang> and <html dir> in sync ──────────────────────
  // The build sets these on the server per route (post-restructure).
  // This effect covers client-side switches and the mount-time
  // preference apply.
  useEffect(() => {
    document.documentElement.lang = state.locale;
    document.documentElement.dir = LOCALE_META[state.locale].dir;
  }, [state.locale]);

  // ── Exposed switch ───────────────────────────────────────────────
  // Persists the choice, loads the target dictionary, updates state.
  // Returns a promise so callers can await (the picker awaits before
  // closing the menu, to avoid a flash of the old dictionary).
  const setLocale = useCallback(
    async (next: Locale) => {
      if (!isLocale(next) || next === state.locale) return;
      persistLocale(next);
      const dictionary = await loadDictionary(next);
      setState({ locale: next, dictionary });
    },
    [state.locale],
  );

  // ── Bound helpers ────────────────────────────────────────────────
  // `t` and `format` are memoised on their inputs so passing them to
  // children does not defeat `React.memo`.
  const t = useMemo<TranslateFn>(() => {
    const translator: TranslateFn = (key, vars) =>
      translate(state.dictionary, key, vars);
    return translator;
  }, [state.dictionary]);

  const format = useMemo<FormatFns>(
    () => createFormatters(state.locale),
    [state.locale],
  );

  const value = useMemo<I18nContextValue>(
    () => ({
      locale: state.locale,
      dictionary: state.dictionary,
      setLocale,
      t,
      format,
    }),
    [state.locale, state.dictionary, setLocale, t, format],
  );

  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

/**
 * Access the i18n context. Throws when called outside a provider —
 * this is a programming error, not a runtime condition, so throwing
 * is correct (silent `null` would turn into a much harder bug to
 * diagnose later).
 */
export function useI18n(): I18nContextValue {
  const ctx = useContext(I18nContext);
  if (!ctx) {
    throw new Error("useI18n must be used within an I18nProvider");
  }
  return ctx;
}
