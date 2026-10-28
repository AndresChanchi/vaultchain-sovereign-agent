/**
 * Locale registry — single source of truth for supported languages.
 *
 * Adding a language is two steps:
 *   1. Create `dictionaries/xx.ts` with `satisfies Dictionary`.
 *   2. Add `"xx"` to `LOCALES` and its entry to `LOCALE_META`.
 * Routes, sitemap and hreflang iterates over this registry and picks
 * up the new locale automatically.
 *
 * URL strategy — static-export compatible
 *   The default locale (`en`) is served at `/`. Every other locale is
 *   served at `/<code>/…`. `generateStaticParams` prerenders each
 *   locale at build time; `dynamicParams = false` makes any
 *   unsupported code a 404.
 *
 *   There is no middleware and no server-side negotiation: with
 *   `output: 'export'`, the presence of `middleware.ts` (Next.js ≤15)
 *   or `proxy.ts` (Next.js 16+) fails the build. Locale detection
 *   runs client-side after hydration (see `detectLocale`), and
 *   `<html lang>` is written by the per-group root layout at build
 *   time — never patched by JavaScript.
 *
 * Persistence
 *   The user's explicit choice is stored in `localStorage`
 *   (`kipio:locale`) and the `NEXT_LOCALE` cookie. The cookie is what
 *   other tools (future analytics, crawlers that respect it) read;
 *   `localStorage` survives third-party cookie-blocking. Both are
 *   best-effort: if either is unavailable, the choice does not
 *   persist, but the session still works.
 */

/**
 * Supported locale codes, in display order. The default is first.
 *
 * `as const` makes `Locale` a union of literals (not `string`), which
 * gives autocomplete and exhaustive checks everywhere a locale is
 * accepted.
 *
 * The set covers >80% of native speakers globally. Languages outside
 * this list are handled by the browser's built-in translation. Adding
 * one here requires a matching `dictionaries/<code>.ts` — the
 * `satisfies Dictionary` on that file is what guarantees parity, not
 * this array.
 */
export const LOCALES = [
  "en", // English          — default
  "es", // Español
  "zh", // 中文
  "hi", // हिन्दी
  "ar", // العربية          — rtl
  "pt", // Português
  "ru", // Русский
  "ja", // 日本語
  "de", // Deutsch
  "fr", // Français
  "ko", // 한국어
  "id", // Bahasa Indonesia
] as const;

/** Union of supported locale codes. Derived — never hand-maintained. */
export type Locale = (typeof LOCALES)[number];

/** Locale used at `/` and as the fallback for any missing translation. */
export const DEFAULT_LOCALE: Locale = "en";

/**
 * Locales other than the default — the ones that get a URL prefix.
 * Exported so the route layer can pass exactly this list to
 * `generateStaticParams` (the default group does not need a locale
 * param).
 */
export const PREFIXED_LOCALES = LOCALES.filter(
  (l): l is Exclude<Locale, typeof DEFAULT_LOCALE> => l !== DEFAULT_LOCALE,
);

/**
 * Display metadata for each locale. Consumed by:
 *   - the language picker (label, native name),
 *   - the per-group root layout (`<html lang>` and `<html dir>`),
 *   - `generateMetadata` (hreflang alternates).
 *
 * `label` is the short code shown on the button ("EN", "ES", "中文").
 * `nativeName` is the full name shown in the picker dropdown.
 * `dir` drives `<html dir="rtl">` for Arabic (and any future rtl
 * language).
 * `bcp47` is the full tag used by `Intl.*` for number/date/currency
 * formatting. It may carry a region suffix (`pt-BR`) even though the
 * route segment is the short code (`pt`): the route identifies the
 * language, the BCP47 tag identifies the formatting locale.
 * `ogLocale` is the Open Graph locale used in `openGraph.locale` —
 * separate from BCP47 because OG uses underscores, not hyphens.
 */
export const LOCALE_META: Readonly<
  Record<
    Locale,
    {
      readonly label: string;
      readonly nativeName: string;
      readonly dir: "ltr" | "rtl";
      readonly bcp47: string;
      readonly ogLocale: string;
    }
  >
> = {
  en: { label: "EN", nativeName: "English", dir: "ltr", bcp47: "en-US", ogLocale: "en_US" },
  es: { label: "ES", nativeName: "Español", dir: "ltr", bcp47: "es-CO", ogLocale: "es_CO" },
  zh: { label: "中文", nativeName: "中文", dir: "ltr", bcp47: "zh-CN", ogLocale: "zh_CN" },
  hi: { label: "हिं", nativeName: "हिन्दी", dir: "ltr", bcp47: "hi-IN", ogLocale: "hi_IN" },
  ar: { label: "AR", nativeName: "العربية", dir: "rtl", bcp47: "ar-SA", ogLocale: "ar_AR" },
  pt: { label: "PT", nativeName: "Português", dir: "ltr", bcp47: "pt-BR", ogLocale: "pt_BR" },
  ru: { label: "RU", nativeName: "Русский", dir: "ltr", bcp47: "ru-RU", ogLocale: "ru_RU" },
  ja: { label: "日本", nativeName: "日本語", dir: "ltr", bcp47: "ja-JP", ogLocale: "ja_JP" },
  de: { label: "DE", nativeName: "Deutsch", dir: "ltr", bcp47: "de-DE", ogLocale: "de_DE" },
  fr: { label: "FR", nativeName: "Français", dir: "ltr", bcp47: "fr-FR", ogLocale: "fr_FR" },
  ko: { label: "한국", nativeName: "한국어", dir: "ltr", bcp47: "ko-KR", ogLocale: "ko_KR" },
  id: { label: "ID", nativeName: "Bahasa Indonesia", dir: "ltr", bcp47: "id-ID", ogLocale: "id_ID" },
};

/** True when `value` is one of the supported locale codes. */
export function isLocale(value: unknown): value is Locale {
  return typeof value === "string" && (LOCALES as readonly string[]).includes(value);
}

/**
 * The path for a given locale. The default locale keeps the root path
 * clean (`/`), every other locale is prefixed (`/es`, `/es/...`).
 *
 * `path` must start with `/`. `localePath("en", "/pricing")` → `/pricing`;
 * `localePath("es", "/pricing")` → `/es/pricing`.
 *
 * This is the single function that defines the URL scheme. If a future
 * design wants every locale prefixed (including the default), only this
 * function and the route-group layout change.
 */
export function localePath(locale: Locale, path: string): string {
  if (!path.startsWith("/")) {
    throw new Error(`localePath: path must start with "/", got "${path}"`);
  }
  if (locale === DEFAULT_LOCALE) return path;
  return path === "/" ? `/${locale}` : `/${locale}${path}`;
}

/**
 * Inverse of `localePath` — extracts the locale from a pathname.
 *
 * `localeFromPath("/es/pricing")` → `"es"`.
 * `localeFromPath("/pricing")` → `"en"` (default).
 * `localeFromPath("/xx/...")` → `"en"` (unsupported → default).
 */
export function localeFromPath(pathname: string): Locale {
  const first = pathname.split("/")[1];
  return isLocale(first) ? first : DEFAULT_LOCALE;
}

const STORAGE_KEY = "kipio:locale";
const COOKIE_KEY = "NEXT_LOCALE";

/**
 * Read the persisted locale, if any.
 *
 * Priority: localStorage → cookie → null. Both reads are wrapped in
 * try/catch because localStorage throws in private mode / blocked
 * storage contexts, and `document.cookie` is empty when all cookies
 * are blocked.
 *
 * Server-safe: returns `null` when `window` is undefined.
 */
export function readPersistedLocale(): Locale | null {
  if (typeof window === "undefined") return null;

  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (isLocale(raw)) return raw;
  } catch {
    /* Storage blocked — fall through to cookie. */
  }

  const cookiePrefix = `${COOKIE_KEY}=`;
  const cookie = document.cookie
    .split("; ")
    .find((c) => c.startsWith(cookiePrefix));
  if (cookie) {
    const value = cookie.slice(cookiePrefix.length);
    if (isLocale(value)) return value;
  }

  return null;
}

/**
 * Persist the user's explicit choice. Best-effort: writes both stores,
 * ignoring failures individually so one blocked store does not prevent
 * the other.
 *
 * Cookie: `Max-Age=1 year`, `SameSite=Lax`, `Path=/`. `Secure` is
 * omitted so the cookie works on localhost (http). On production over
 * HTTPS, `SameSite=Lax` still sends it — the only cost of not setting
 * `Secure` is that a hypothetical http downgrade would also send it,
 * which is irrelevant here.
 */
export function persistLocale(locale: Locale): void {
  if (typeof window === "undefined") return;

  try {
    window.localStorage.setItem(STORAGE_KEY, locale);
  } catch {
    /* Storage blocked — cookie still attempted below. */
  }

  try {
    const maxAge = 60 * 60 * 24 * 365; // 1 year
    document.cookie = `${COOKIE_KEY}=${locale}; Max-Age=${maxAge}; Path=/; SameSite=Lax`;
  } catch {
    /* Cookies blocked — localStorage above may have succeeded. */
  }
}

/**
 * Detect the best locale for a first visit.
 *
 * Priority: persisted choice → browser language → default.
 *
 * The browser preference is derived from `navigator.languages` (a list,
 * most-preferred first) with `navigator.language` as fallback. Each
 * candidate is normalized to its base language (`es-CO` → `es`) before
 * matching against `LOCALES`. Intentionally simpler than full BCP47
 * negotiation (which would need `Intl.Locale` matchers): for a fixed
 * 12-locale registry, a base-language match is accurate and has no
 * edge cases that matter.
 *
 * Client-only: returns the default when `window` is undefined, so it
 * is safe to call from a component that may render on the server (the
 * result is ignored until hydration).
 */
export function detectLocale(): Locale {
  if (typeof window === "undefined") return DEFAULT_LOCALE;

  const persisted = readPersistedLocale();
  if (persisted) return persisted;

  const candidates = [
    ...(navigator.languages ?? []),
    navigator.language,
  ].filter(Boolean);

  for (const tag of candidates) {
    const base = tag.split("-")[0]?.toLowerCase();
    if (isLocale(base)) return base;
  }

  return DEFAULT_LOCALE;
}

/**
 * Locales that already have a dictionary file. This is what the
 * language picker shows, and what the sitemap (once it exists)
 * should iterate — NOT the full `LOCALES` list.
 *
 * Why a separate constant: `LOCALES` is the roadmap (12 planned
 * languages, drives types and `LOCALE_META`), while this list is
 * reality (which files exist right now). Showing a 12-item picker
 * when 10 of them silently fall back to English is a UX lie. When a
 * new `dictionaries/<code>.ts` lands, add the code here — nothing
 * else changes.
 */
export const AVAILABLE_LOCALES: readonly Locale[] = ["en", "es"];
