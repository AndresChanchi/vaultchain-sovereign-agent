"use client";

import { useI18n } from "@context/I18nContext";

/**
 * "Open by design" — landing section.
 *
 * Two columns: copy on the left, a three-row "repos" card on the right.
 * The card groups the three pieces of the protocol that are publicly
 * readable (contracts, frontend, economics) so the claim "Kipio is
 * open source" points at something concrete.
 *
 * Layout — desktop (≥ md)
 *   Three-column rows inside a single card:
 *
 *     [ slug column: 118px ]  [ title + body: flex-1 ]  [ view label ]
 *
 *   Same arrangement as the mockup. The slug is truncated if a locale
 *   produces a longer identifier than the English baseline (e.g.
 *   German "Verträge" instead of "Contracts" in a hypothetical
 *   re-slug); the title/body column is `min-w-0 flex-1` so it shrinks
 *   correctly when the slug pushes.
 *
 * Layout — mobile (< md)
 *   The three-column row collapses to a vertical block per repo:
 *
 *     ┌─────────────────────────────────────────────┐
 *     │ [org]/contracts                          → │
 *     │ Contracts                                  │
 *     │ How ownership is recorded                  │
 *     └─────────────────────────────────────────────┘
 *
 *   - Slug moves to the top as a small mono label.
 *   - Title follows (semibold, larger).
 *   - Body follows (muted, smaller).
 *   - Chevron `→` at the top-right is the tap affordance; the entire
 *     row is inside the `<a>`, so tapping anywhere fires the link.
 *
 *   The previous horizontal layout on mobile forced the title/body
 *   column to ~40px on a 320px viewport once the 118px slug and the
 *   "View ↗" label claimed their space — unreadable. Vertical
 *   stacking gives each element the full row width, and eliminates
 *   any locale-dependent failure: German compound titles, French
 *   verbose bodies, and Spanish "Ver ↗" all fit without changing the
 *   structure.
 *
 * i18n layout stability
 *   Three protections, applied per element type:
 *
 *     - `text-balance` on `<h2>` and each row title — evens out the
 *       line lengths so 2-line titles in longer locales do not leave
 *       a one-word widow.
 *     - `truncate` on the slug — monospace identifiers (slugs,
 *       addresses) are the only strings that can overflow silently.
 *       Truncation with ellipsis is better than pushing the layout.
 *     - `min-w-0` on the flex child that holds title + body — without
 *       this, `overflow-wrap` rules never kick in because the flex
 *       item refuses to shrink below its content's intrinsic width.
 *
 *   `text-balance` is supported in every browser Next.js 16 targets
 *   (Chrome 114+, Safari 17.5+, Firefox 121+). No fallback needed —
 *   unsupported browsers simply wrap text normally, which is the
 *   behavior before this change.
 *
 * Readability
 *   The two copy paragraphs on the left live inside `lg:grid-cols-2`,
 *   which at max-width 1280px with `gap-12` yields a ~600px column
 *   (~45–50ch at 16px Geist Sans). That is inside the 45–75 range
 *   that Bringhurst, USWDS and WCAG 1.4.8 converge on. No
 *   `prose-measure` utility needed here — that utility exists for
 *   long-form surfaces (docs, legal) that have no other wrapper
 *   providing a max-width. Landing prose is already constrained by
 *   its grid.
 *
 * `repoAriaLabel`
 *   The `aria-label` on each link comes from the dictionary
 *   (`t("landing.openByDesign.repoAriaLabel", { title: repo.title })`).
 *   `repo.title` is already translated; the rest of the template
 *   ("— View on GitHub" / "— Ver en GitHub") is provided per locale.
 *   No hardcoded English remains in the accessible name.
 *
 * Repo slugs — placeholder until the public org is live
 *   The mockup uses `[org]/contracts`, `[org]/frontend`, `[org]/docs`
 *   as display labels. These are literal placeholders — the public
 *   GitHub org has not been decided. They live in the dictionary so
 *   translators can leave them untouched (they are proper-noun-shaped
 *   identifiers, not readable prose). When the org is chosen, update
 *   the three dictionaries and every locale follows.
 *
 * Client Component
 *   `useI18n()` provides `t()` and the active dictionary. No state,
 *   no effects, no refs — this file is client only because of i18n.
 *
 * TODO: replace `GITHUB_URL` with the real org URLs (contracts,
 *       frontend, docs) once the public org is announced. The
 *       `[org]/…` slugs and the URL are the only two places to edit.
 */

const GITHUB_URL =
  "https://github.com/AndresChanchi/vaultchain-sovereign-agent";

export function OpenByDesign() {
  const { t, dictionary } = useI18n();
  const repos = dictionary.landing.openByDesign.repos;

  return (
    <section className="mx-auto max-w-[1280px] px-6 py-24 md:px-10">
      <div className="grid gap-12 lg:grid-cols-2 lg:items-center">
        <div>
          <p className="label-mono text-emerald-text">
            {t("landing.openByDesign.eyebrow")}
          </p>
          <h2 className="mt-3 text-balance text-[30px] font-bold leading-tight tracking-[-0.025em] text-ink md:text-[40px]">
            {t("landing.openByDesign.title")}
          </h2>
          <p className="mt-4 text-[16px] leading-[1.6] text-muted">
            {t("landing.openByDesign.paragraph1")}
          </p>
          <p className="mt-3.5 text-[16px] leading-[1.6] text-ink">
            <span className="text-emerald-text">
              {t("landing.openByDesign.paragraph2Emphasis")}
            </span>
            {t("landing.openByDesign.paragraph2After")}
          </p>
        </div>

        <div className="rounded-card border border-hairline bg-card">
          {repos.map((repo) => (
            <a
              key={repo.slug}
              href={GITHUB_URL}
              target="_blank"
              rel="noopener noreferrer"
              aria-label={t("landing.openByDesign.repoAriaLabel", {
                title: repo.title,
              })}
              className="group flex items-start gap-3 border-b border-hairline px-4 py-4 transition-colors duration-200 last:border-b-0 hover:bg-elevated/40 md:items-center md:gap-3.5 md:px-[22px]"
            >
              {/* Desktop-only slug column. Hidden on mobile — the slug
                  renders as a top label inside the content column below. */}
              <span className="hidden w-[118px] flex-none truncate font-mono text-[12px] text-emerald-text md:block">
                {repo.slug}
              </span>

              {/* Title + body. On mobile this column also carries the
                  slug (as a small label at the top). On desktop the
                  slug column at the left covers that role. */}
              <div className="min-w-0 flex-1">
                <span className="mb-1 block truncate font-mono text-[11px] text-emerald-text md:hidden">
                  {repo.slug}
                </span>
                <div className="text-balance text-[15px] font-medium text-ink">
                  {repo.title}
                </div>
                <div className="mt-0.5 text-balance text-[13px] text-muted">
                  {repo.body}
                </div>
              </div>

              {/* Right-side affordance. Desktop shows the localized
                  "View ↗" label; mobile shows a neutral chevron (the
                  label is announced by `aria-label` already). */}
              <span className="mt-1 hidden flex-none font-mono text-[12px] text-muted transition-colors duration-200 group-hover:text-ink md:mt-0 md:block">
                {repo.view}
              </span>
              <svg
                aria-hidden="true"
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
                className="mt-0.5 flex-none text-muted transition-colors duration-200 group-hover:text-ink md:hidden"
              >
                <path d="M9 6l6 6-6 6" />
              </svg>
            </a>
          ))}
        </div>
      </div>
    </section>
  );
}
