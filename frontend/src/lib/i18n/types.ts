/**
 * i18n types — the contract between dictionaries, the translate
 * function, and React consumers.
 *
 * `Dictionary` is not written by hand. It is the inferred type of the
 * English dictionary (`dictionaries/en.ts`) via `satisfies`. That
 * means:
 *
 *   - Adding a key to `en.ts` makes it required in every other locale
 *     at compile time.
 *   - Removing a key from `en.ts` breaks the build if any other locale
 *     still has it (excess property check).
 *   - Typos in a key are caught at the `t()` call site, because
 *     `Path<Dictionary>` is a union of valid dot-paths.
 *
 * The dictionary shape is nested by UI section (navbar, hero, journey,
 * …) so both humans and LLMs can see the context of a string from its
 * key alone.
 */

import type { en } from "./dictionaries/en";

/**
 * The canonical dictionary shape, inferred from English.
 *
 * Consumers must not import this directly to type their own locale —
 * they use `satisfies Dictionary` so the compiler checks parity.
 * Importing the type is fine for `t()` generics and for tests.
 */
export type Dictionary = typeof en;

/**
 * Dot-path of all leaf keys in `T`, recursively.
 *
 * `Path<{ a: { b: string; c: string } }>` → `"a.b" | "a.c"`.
 *
 * Only leaf (string) values are included — intermediate object keys
 * are not valid translation targets. Arrays of strings are treated as
 * leaves would be but are not traversed as objects; array elements
 * (e.g. `hero.steps`) are not addressable as dot-paths because they
 * are read in a loop, not by key.
 */
export type Path<T, Prefix extends string = ""> = T extends string
  ? Prefix extends ""
    ? never
    : Prefix
  : {
      [K in keyof T & string]: T[K] extends string
        ? Prefix extends ""
          ? K
          : `${Prefix}.${K}`
        : T[K] extends readonly unknown[]
          ? never
          : Path<T[K], Prefix extends "" ? K : `${Prefix}.${K}`>;
    }[keyof T & string];

/**
 * Extracts the value type at a dot-path.
 *
 * `ValueAt<Dict, "landing.hero.title">` → `string`.
 * Used by `t()` to guarantee the key exists and is a string.
 */
export type ValueAt<T, P extends string> = P extends `${infer Head}.${infer Rest}`
  ? Head extends keyof T
    ? ValueAt<T[Head], Rest>
    : never
  : P extends keyof T
    ? T[P]
    : never;

/**
 * Variables passed to `t()`. Keys must match the `{name}` placeholders
 * in the string. The type is intentionally permissive
 * (`Record<string, string | number>`) — enforcing placeholder parity
 * at the type level would require parsing template strings, which is
 * out of scope and brittle. Documentation in the dictionary is the
 * contract for placeholders.
 *
 * Placeholder names use `\w+` (letters, digits, underscore). No dots,
 * hyphens, or spaces inside `{…}` — `{user.name}` would not resolve.
 * Use `{userName}` instead.
 */
export type TranslateVars = Record<string, string | number>;

/**
 * Signature of the translate function bound to a dictionary. This is
 * what `useI18n().t` returns.
 */
export type TranslateFn = <P extends Path<Dictionary>>(
  key: P,
  vars?: TranslateVars,
) => string;

/**
 * Signature of the format helpers, bound to a locale. This is what
 * `useI18n().format` returns.
 *
 * `plural` accepts every category of `Intl.LDMLPluralRule` so that
 * languages with more than `one`/`other` (Russian: one/few/many/other,
 * Arabic: zero/one/two/few/many/other) can provide all their forms.
 * `other` is required as the mandatory fallback — `Intl.PluralRules`
 * guarantees it exists for every locale. Missing categories fall back
 * to `other`.
 */
export type FormatFns = {
  readonly number: (value: number, opts?: Intl.NumberFormatOptions) => string;
  readonly currency: (
    value: number,
    currency: string,
    opts?: Intl.NumberFormatOptions,
  ) => string;
  readonly date: (value: Date | number, opts?: Intl.DateTimeFormatOptions) => string;
  readonly relative: (
    value: number,
    unit: Intl.RelativeTimeFormatUnit,
    opts?: Intl.RelativeTimeFormatOptions,
  ) => string;
  readonly plural: (
    count: number,
    forms: Partial<Record<Intl.LDMLPluralRule, string>> & { other: string },
  ) => string;
};
