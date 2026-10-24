/**
 * "Open by design" — landing section.
 *
 * Two columns: copy on the left, a three-row "repos" card on the right.
 * The card groups the three pieces of the protocol that are publicly
 * readable (contracts, frontend, economics) so the claim "Kipio is open
 * source" points at something concrete.
 *
 * Copy source of truth
 *   The mockup (Landing-dark.html / Landing-Light / Landing-Mobile).
 *   Changes relative to the inline version this replaces:
 *     - Two paragraphs, not one. The second carries the emerald
 *       fragment "Kipio is open source." — the visible claim.
 *     - Three rows, not two. The mockup adds "Economics / Fees,
 *       subsidy and where they go" to match the "Sovereign by design"
 *       and "Where the money goes" sections above.
 *     - Card style. The inline rendered each repo as its own card with
 *       hover `bg-elevated`; the mockup uses a single card containing
 *       three rows separated by `border-b`. Deliberate — the three
 *       pieces are facets of one claim, not three features.
 *
 * Repo slugs — placeholder until the public org is live
 *   The mockup uses `[org]/contracts`, `[org]/frontend`, `[org]/docs`
 *   as display labels. These are literal placeholders — the public
 *   GitHub org has not been decided. The component preserves them
 *   verbatim (mockup is the source of truth, and the brackets
 *   communicate "fill me in") while the `href` points at the working
 *   repository today. When the org is decided, update the display
 *   strings — no other change needed.
 *
 *   `aria-label` on each link is the semantic title ("Contracts —
 *   View on GitHub"), not the slug. Screen readers skip the bracket
 *   notation; the title is what the user understands.
 *
 * Layout
 *   `grid gap-12 lg:grid-cols-2 lg:items-center` mirrors the mockup's
 *   `.g2` (`grid-template-columns: 1fr 1fr; align-items: center;
 *   gap: 48px`). On < lg, one column; the copy stacks above the card.
 *
 *   The card's `py-1.5` (6px) plus each row's `py-4` (16px) gives the
 *   visual top/bottom of 22px the mockup produces via `padding: 6px
 *   22px` on `.cd` and `padding: 16px 0` on each row. The three rows
 *   all carry `border-b` — including the last, matching the mockup's
 *   floating separator. Not removing it: the mockup chose it.
 *
 * Server Component
 *   No state, no effects, no handlers. Three links to public URLs.
 *   `target="_blank"` + `rel="noopener noreferrer"` for external
 *   navigation.
 *
 * Mobile
 *   Card `px-[22px]` keeps horizontal breathing room; the slug column
 *   stays `w-[118px]`, the title/body column is `flex-1 min-w-0` (the
 *   `min-w-0` matters — without it, long titles push "View ↗" off the
 *   row on 320px viewports).
 *
 * TODO: replace `GITHUB_URL` with the real org URLs (contracts,
 *       frontend, docs) once the public org is announced. The
 *       `[org]/…` slugs and the URL are the only two places to edit.
 */

/**
 * Single repository the mockup's three rows point at today. All three
 * rows share it until the public org splits them into three repos.
 *
 * Not centralized in `@config/links` yet — this is the only consumer.
 * When `footer.tsx` (Fase 7) also needs it, extract at that point.
 */
const GITHUB_URL =
  "https://github.com/AndresChanchi/vaultchain-sovereign-agent";

/**
 * The three rows in the card. Order matches the mockup: contracts
 * (what), frontend (how you use it), economics (how it is paid for).
 */
const REPOS: readonly {
  /** Display slug. Placeholder until the public org is decided. */
  readonly slug: string;
  /** Human title, used by `aria-label`. */
  readonly title: string;
  /** One-line description under the title. */
  readonly body: string;
  /** External URL. Same for all three today; see TODO above. */
  readonly href: string;
}[] = [
  {
    slug: "[org]/contracts",
    title: "Contracts",
    body: "How ownership is recorded",
    href: GITHUB_URL,
  },
  {
    slug: "[org]/frontend",
    title: "Frontend",
    body: "The app you are using",
    href: GITHUB_URL,
  },
  {
    slug: "[org]/docs",
    title: "Economics",
    body: "Fees, subsidy and where they go",
    href: GITHUB_URL,
  },
];

export function OpenByDesign() {
  return (
    <section className="mx-auto max-w-[1280px] px-6 py-24 md:px-10">
      <div className="grid gap-12 lg:grid-cols-2 lg:items-center">
        <div>
          <p className="label-mono text-emerald-text">Open by design</p>
          <h2 className="mt-3 text-[30px] font-bold leading-tight tracking-[-0.025em] text-ink md:text-[40px]">
            Works even if Kipio disappears.
          </h2>
          <p className="mt-4 text-[16px] leading-[1.6] text-muted">
            Your photos live on public networks, and the contracts that guard
            them are open. If we stopped tomorrow, your space would keep
            working. You could still open, move and share everything.
          </p>
          <p className="mt-3.5 text-[16px] leading-[1.6] text-ink">
            <span className="text-emerald-text">Kipio is open source.</span>{" "}
            Anyone can read the code and check how it is paid for.
          </p>
        </div>

        <div className="rounded-card border border-hairline bg-card px-[22px] py-1.5">
          {REPOS.map((repo) => (
            <a
              key={repo.slug}
              href={repo.href}
              target="_blank"
              rel="noopener noreferrer"
              aria-label={`${repo.title} — View on GitHub`}
              className="group flex items-center gap-3.5 border-b border-hairline py-4 last:border-b-0"
            >
              <span className="w-[118px] flex-none font-mono text-[12px] text-emerald-text">
                {repo.slug}
              </span>
              <div className="min-w-0 flex-1">
                <div className="text-[15px] font-medium text-ink">
                  {repo.title}
                </div>
                <div className="mt-0.5 text-[13px] text-muted">
                  {repo.body}
                </div>
              </div>
              <span className="flex-none font-mono text-[12px] text-muted transition-colors duration-200 group-hover:text-ink">
                View ↗
              </span>
            </a>
          ))}
        </div>
      </div>
    </section>
  );
}
