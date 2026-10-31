/**
 * English dictionary — aggregator.
 *
 * Re-exports the per-feature English dictionaries under one object so
 * `Dictionary = typeof en` (see `types.ts`) has a stable, single
 * shape. Each feature lives in its own file under `en/`:
 *
 *   en/landing.ts   → `en.landing`
 *   en/login.ts     → `en.login`
 *   en/dashboard.ts → `en.dashboard`   (when it exists)
 *   …
 *
 * Adding a feature
 *   1. Create `en/<feature>.ts` exporting a `<feature>`-shaped object.
 *   2. Import it here and add it to the aggregate.
 *   3. Add the same feature to `es.ts`, `_template.ts` and every other
 *      locale's aggregate. The `satisfies Dictionary` check on those
 *      files fails the build if any locale is missing the new feature.
 *
 * No `as const`
 *   `as const` would make every string a literal type, and every
 *   locale's `satisfies Dictionary` would then require the exact
 *   English literal — impossible. Plain object literals keep the leaf
 *   types as `string`, which is what the parity check needs. Arrays
 *   widen to `string[]`, which `Path<T>` excludes from valid keys
 *   anyway (iterables are read via `.map()`, not via `t()`).
 */

import { landing } from "./en/landing";
import { login } from "./en/login";

export const en = {
  landing,
  login,
};
