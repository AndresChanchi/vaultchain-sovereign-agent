/**
 * Formatting helpers — thin wrappers over the native `Intl` APIs.
 *
 * Zero dependencies. Support verified against MDN/TestMu:
 *
 *   API                      Chrome  Firefox  Safari  Edge
 *   Intl.NumberFormat        24      29       10      12
 *   Intl.DateTimeFormat      24      29       10      12
 *   Intl.PluralRules         63      58       13      18
 *   Intl.RelativeTimeFormat  71      65       14      79
 *
 * Next.js 16 targets modern browsers (no IE11), so no polyfill is
 * needed. If IE11 ever enters the support matrix, add
 * `@formatjs/intl-pluralrules` and `@formatjs/intl-relativetimeformat`
 * at the app entry — but that is a future decision, not a current
 * concern.
 *
 * Why wrappers instead of calling `Intl.*` directly
 *   - Each function binds the locale once, so call sites read
 *     `format.number(1234)` instead of
 *     `new Intl.NumberFormat(bcp47).format(1234)`.
 *   - Caching: `Intl.NumberFormat` construction is expensive
 *     (~100µs). For 12 stats rendered per page, constructing 12
 *     formatters per render is wasteful. The cache below reuses
 *     formatters per (locale, options) pair.
 *   - Future-proofing: if a specific locale needs a custom plural
 *     rule that `Intl.PluralRules` gets wrong (rare but happens),
 *     the fix lives here, not in every caller.
 *
 * BCP47 tags
 *   The `locale` argument is the short code (`"en"`, `"es"`). The
 *   functions look up `LOCALE_META[locale].bcp47` for the formatting
 *   tag (`"en-US"`, `"es-CO"`). That separation lets the route stay
 *   short (`/es`) while formatting uses the regional variant
 *   (`es-CO` for Colombian number/date conventions).
 *
 * Plural categories
 *   `Intl.PluralRules` returns one of: zero, one, two, few, many,
 *   other. English/Spanish/Portuguese/German/French/Italian/Korean/
 *   Japanese/Chinese/Indonesian use only one/other. Russian uses
 *   one/few/many/other. Arabic uses zero/one/two/few/many/other.
 *
 *   The `plural` signature accepts `Partial<Record<LDMLPluralRule,
 *   string>>` with `other` required, so a Russian or Arabic
 *   dictionary can provide all its forms; any missing category falls
 *   back to `other`. This avoids the incorrect "5 книга" the
 *   one/other-only signature would produce for Russian.
 */

import type { Locale } from "./locales";
import { LOCALE_META } from "./locales";
import type { FormatFns } from "./types";

/**
 * Cache of `Intl` formatters keyed by `locale|options-json`.
 *
 * Bounded implicitly by the number of distinct (locale, options) pairs
 * the app uses — a handful. No eviction needed; if that assumption
 * ever breaks, replace with an LRU.
 */
const numberCache = new Map<string, Intl.NumberFormat>();
const dateCache = new Map<string, Intl.DateTimeFormat>();
const relativeCache = new Map<string, Intl.RelativeTimeFormat>();
const pluralCache = new Map<string, Intl.PluralRules>();

function getNumberFormatter(
  bcp47: string,
  opts: Intl.NumberFormatOptions,
): Intl.NumberFormat {
  const key = `${bcp47}|${JSON.stringify(opts)}`;
  let fmt = numberCache.get(key);
  if (!fmt) {
    fmt = new Intl.NumberFormat(bcp47, opts);
    numberCache.set(key, fmt);
  }
  return fmt;
}

function getDateFormatter(
  bcp47: string,
  opts: Intl.DateTimeFormatOptions,
): Intl.DateTimeFormat {
  const key = `${bcp47}|${JSON.stringify(opts)}`;
  let fmt = dateCache.get(key);
  if (!fmt) {
    fmt = new Intl.DateTimeFormat(bcp47, opts);
    dateCache.set(key, fmt);
  }
  return fmt;
}

function getRelativeFormatter(
  bcp47: string,
  opts: Intl.RelativeTimeFormatOptions,
): Intl.RelativeTimeFormat {
  const key = `${bcp47}|${JSON.stringify(opts)}`;
  let fmt = relativeCache.get(key);
  if (!fmt) {
    fmt = new Intl.RelativeTimeFormat(bcp47, opts);
    relativeCache.set(key, fmt);
  }
  return fmt;
}

function getPluralRules(bcp47: string): Intl.PluralRules {
  let fmt = pluralCache.get(bcp47);
  if (!fmt) {
    fmt = new Intl.PluralRules(bcp47);
    pluralCache.set(bcp47, fmt);
  }
  return fmt;
}

/**
 * Build the `FormatFns` object bound to a locale.
 *
 * The caller (provider or Server Component) calls this once per locale
 * and passes the result down. The cache makes repeated calls cheap.
 */
export function createFormatters(locale: Locale): FormatFns {
  const bcp47 = LOCALE_META[locale].bcp47;

  return {
    number(value, opts = {}) {
      return getNumberFormatter(bcp47, opts).format(value);
    },

    currency(value, currency, opts = {}) {
      return getNumberFormatter(bcp47, {
        style: "currency",
        currency,
        ...opts,
      }).format(value);
    },

    date(value, opts = {}) {
      return getDateFormatter(bcp47, opts).format(value);
    },

    relative(value, unit, opts = { numeric: "auto" }) {
      return getRelativeFormatter(bcp47, opts).format(value, unit);
    },

    plural(count, forms) {
      const rule = getPluralRules(bcp47).select(count);
      // `forms[rule]` may be undefined for locales that do not use
      // that category (e.g. English never returns `few`). `other` is
      // the mandatory fallback — always present, enforced by the type.
      return forms[rule] ?? forms.other;
    },
  };
}
