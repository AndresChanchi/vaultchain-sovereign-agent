/**
 * Translate — pure function, no React, no Next.js, no globals.
 *
 * Takes a loaded dictionary, a dot-path key, and optional variables.
 * Returns the string with `{var}` placeholders substituted.
 *
 * Why pure
 *   This is the only file that "does" translation. The React provider
 *   binds it to a dictionary and a locale; Server Components call it
 *   directly with the dictionary they imported. Both share the same
 *   behavior, and unit tests can cover it with plain objects.
 *
 * Interpolation
 *   `{name}` is replaced with `vars.name`. Missing variables are left
 *   as the literal `{name}` so a broken string is visible in the UI
 *   instead of silently rendering `undefined`. This is a deliberate
 *   "fail loud" choice — silent substitution hides bugs.
 *
 *   Placeholder names are restricted to `\w+` (letters, digits,
 *   underscore). No dots, hyphens or spaces inside `{…}`. Use
 *   `{userName}`, not `{user.name}`.
 *
 *   No HTML escaping. The output is rendered as React text (which
 *   escapes by default) or as a DOM text node, never as raw HTML.
 *   If a future caller needs `dangerouslySetInnerHTML`, it must escape
 *   itself — this function does not produce HTML.
 */

import type { Path, TranslateVars, ValueAt } from "./types";

const PLACEHOLDER = /\{(\w+)\}/g;

/**
 * Resolve a dot-path against a nested object.
 *
 * Returns `undefined` when any segment is missing or when the final
 * value is not a string. That lets `t()` detect broken keys and throw
 * a clear error instead of returning `[object Object]`.
 */
function resolvePath(obj: unknown, path: string): unknown {
  let current: unknown = obj;
  for (const segment of path.split(".")) {
    if (typeof current !== "object" || current === null) return undefined;
    current = (current as Record<string, unknown>)[segment];
  }
  return current;
}

/**
 * Translate a key against a dictionary.
 *
 * @param dictionary  The locale dictionary (already loaded).
 * @param key         Dot-path to the string, e.g. `"landing.hero.title"`.
 * @param vars        Optional interpolation variables.
 * @returns           The translated, interpolated string.
 *
 * @throws  When the key does not resolve to a string. In development
 *          this surfaces typos immediately. In production the throw
 *          surfaces the bug in error telemetry instead of silently
 *          rendering `[object Object]` or an empty string.
 */
export function t<D, P extends Path<D>>(
  dictionary: D,
  key: P,
  vars?: TranslateVars,
): ValueAt<D, P> & string {
  const raw = resolvePath(dictionary, key as string);

  if (typeof raw !== "string") {
    throw new Error(
      `i18n: key "${String(key)}" did not resolve to a string. ` +
        `Check the dictionary shape and the key spelling.`,
    );
  }

  if (!vars) return raw as ValueAt<D, P> & string;

  return raw.replace(PLACEHOLDER, (match, name: string) => {
    const value = vars[name];
    // Missing variable → leave `{name}` visible. Fail-loud, not silent.
    return value === undefined ? match : String(value);
  }) as ValueAt<D, P> & string;
}
