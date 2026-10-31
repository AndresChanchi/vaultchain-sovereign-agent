/**
 * Translation template — aggregator.
 *
 * The template lives in two files per feature:
 *   - this one (the aggregator, which imports the pieces)
 *   - `_template/<feature>.ts` (the pieces themselves)
 *
 * When starting a new locale, copy both:
 *
 *   cp -r dictionaries/_template dictionaries/zh
 *   cp dictionaries/_template.ts dictionaries/zh.ts
 *
 * Then in `zh.ts`:
 *   - change `import { landing } from "./_template/landing"` to
 *     `"./zh/landing"`, and the same for every other feature;
 *   - change `export const xx = { … }` to `export const zh = { … }`;
 *   - the `satisfies Dictionary` clause stays — it enforces parity.
 *
 * Then in `zh/<feature>.ts`, replace every `TODO translate` with the
 * target-language string. Placeholders (`{count}`, `{year}`,
 * `{index}`, `{total}`, `{title}`) stay verbatim.
 *
 * Then in `locales.ts`:
 *   - add `"zh"` to `LOCALES`;
 *   - add its `LOCALE_META` entry;
 *   - add it to `AVAILABLE_LOCALES`.
 *
 * Then in `I18nContext.tsx`'s `loadDictionary`, add `case "zh"`.
 *
 * Nothing else. The picker, sitemap and `<html lang>` pick up the
 * locale automatically.
 */

import type { Dictionary } from "../types";
import { landing } from "./_template/landing";
import { login } from "./_template/login";

export const xx = {
  landing,
  login,
} satisfies Dictionary;
