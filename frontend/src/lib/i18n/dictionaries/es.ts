/**
 * Spanish dictionary — aggregator.
 *
 * Mirrors `en.ts` one-to-one. The `satisfies Dictionary` clause is the
 * parity check: if `en.ts` grew a feature or a key and `es.ts` did not
 * follow, the compiler fails with a precise message ("property X is
 * missing in type … but required in type …").
 *
 * Adding a feature or key
 *   1. Add it to `en/<feature>.ts`.
 *   2. Add it here — `import { <feature> } from "./es/<feature>"` and
 *      the field on the aggregate.
 *   3. The compiler will not complain about the missing translation
 *      of a *string* — only about a missing *key*. But an English
 *      value left untranslated in a Spanish file is caught by copy
 *      review, which is where it belongs.
 */

import type { Dictionary } from "../types";
import { landing } from "./es/landing";
import { login } from "./es/login";

export const es = {
  landing,
  login,
} satisfies Dictionary;
