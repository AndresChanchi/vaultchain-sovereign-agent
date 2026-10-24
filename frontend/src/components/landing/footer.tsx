/**
 * Landing footer — semantic, SEO-friendly, accessible.
 *
 * The mockup (Landing-dark.html / Landing-Light / Landing-Mobile) puts
 * a single horizontal bar at the bottom: bare Kipio mark + wordmark +
 * contract short-link on the left, four links on the right. This
 * component follows that structure, with four documented deviations
 * for production-readiness that the mockup omits as prototype
 * simplifications:
 *
 *   1. Copyright line (`© {year} Kipio`)
 *      The mockup does not show it. The earlier inline version of this
 *      footer did (`© 2026 Kipio`, hardcoded). Kept, with the year
 *      computed at render time so it does not silently rot:
 *      `new Date().getFullYear()` evaluates at build (static export) or
 *      request (SSR) time. A rebuild keeps it fresh; hardcoding would
 *      require a manual edit each January.
 *
 *      Standard practice for SEO/branding; omitting it in the mockup
 *      reads as a prototype simplification, not a design decision.
 *
 *   2. `id="docs"` on `<footer>`
 *      The mockup carries it (so its navbar "Docs" link, `#docs`,
 *      resolves). The inline version does not. Restored here so that
 *      any future `#docs` anchor resolves to the footer; the
 *      `[id] { scroll-margin-top: 5rem }` rule in globals.css makes
 *      the scroll land just below the sticky navbar. Harmless if
 *      unused — the id is not a heading target, just an anchor.
 *
 *   3. Bare 20px SVG instead of `KipioMark`
 *      `KipioMark` renders a 34px SVG inside a rounded elevated
 *      square (navbar style). The footer uses a bare 20px SVG on the
 *      page background, matching the mockup. Inlining is simpler than
 *      adding a `variant="bare"` prop for a single consumer; extract
 *      a shared primitive when a third place needs it.
 *
 *   4. Real URLs instead of mockup `#docs` placeholders
 *      The mockup's `Docs` and `GitHub` both point at `#docs`
 *      (self-referential — they were placeholders for a docs route
 *      that does not exist yet). Using the working repository URL is
 *      honest: clicking "GitHub" goes somewhere real. A dedicated
 *      `/docs` route (see design system §3.7 "Docs externos") will
 *      replace these when it lands.
 *
 * Anchors and semantics
 *   - `<footer>` — the document footer landmark.
 *   - `<nav aria-label="Footer">` — distinguishes this nav from the
 *     primary nav in the header.
 *   - `<a>` for each link, `<span>` for the wordmark (not a link — the
 *     wordmark is decorative identity, and the landing is `/` anyway;
 *     a self-referencing home link from the home footer adds no SEO
 *     value).
 *   - `<small>` for the copyright — semantically the correct element
 *     for legal fine print; the visual size is set explicitly, so the
 *     UA default `80%` does not win.
 *   - External links carry `target="_blank"` + `rel="noopener
 *     noreferrer"` (tabnabbing mitigation, referrer privacy). The
 *     contract link is external (Arbiscan) so it follows the same
 *     rule, with an `aria-label` that spells out the full address
 *     because the visible text is abbreviated.
 *
 * Server Component
 *   No state, no effects, no handlers. `new Date()` runs at build
 *   time (static) or request time (SSR) — either way, a plain value
 *   with no hydration mismatch: the year is identical for every
 *   visitor in the same deployment.
 *
 * Mobile
 *   Column stack below `md:` — brand+contract on top, nav+copyright
 *   below. `flex-wrap` on the nav handles the four links wrapping to
 *   a second line on narrow viewports (e.g. 320px). Copyright sits
 *   beside the nav on the same flex row when it fits, otherwise wraps
 *   below — matches the mockup's `flex-wrap` behavior.
 */

const CONTRACT_ADDRESS = "0xfe76a53e5cc1cc5136b7da6b6fcf6c593c767452";
const CONTRACT_SHORT = "0xfe76…7452";
const CONTRACT_URL = `https://sepolia.arbiscan.io/address/${CONTRACT_ADDRESS}`;

/**
 * Today's year for the copyright line. Evaluated at module load —
 * which is build time for a static export, request time for SSR.
 * Either way, a rebuild at the start of a new year keeps it accurate.
 */
const COPYRIGHT_YEAR = new Date().getFullYear();

/**
 * Links that appear in the footer nav. All external.
 *
 * `Docs` and `GitHub` both point at the working repository until a
 * dedicated `/docs` route exists (design system §3.7 places it under
 * `Docs externos`). When that route lands, `Docs` gets `href="/docs"`
 * and drops `target`/`rel` (internal).
 */
const FOOTER_LINKS = [
  { label: "Docs", href: "https://github.com/AndresChanchi/vaultchain-sovereign-agent" },
  { label: "GitHub", href: "https://github.com/AndresChanchi/vaultchain-sovereign-agent" },
  { label: "Arbitrum", href: "https://arbitrum.io" },
  { label: "Irys", href: "https://irys.xyz" },
] as const;

export function Footer() {
  return (
    <footer id="docs" className="border-t border-hairline">
      <div className="mx-auto flex max-w-[1280px] flex-col gap-6 px-6 py-8 pb-12 md:flex-row md:flex-wrap md:items-center md:justify-between md:px-10">
        {/* Left — brand + contract. The SVG is decorative; "Kipio"
            and the contract link are the readable content. */}
        <div className="flex items-center gap-3.5">
          <span className="flex text-emerald-text" aria-hidden="true">
            <svg
              width="20"
              height="20"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2.5"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <path d="M4 4v16" />
              <path d="M4 12h5l7-8" />
              <path d="M9 12l7 8" />
            </svg>
          </span>
          <span className="text-sm font-semibold text-ink">Kipio</span>
          <a
            href={CONTRACT_URL}
            target="_blank"
            rel="noopener noreferrer"
            aria-label={`Contract ${CONTRACT_ADDRESS} on Arbiscan`}
            title={CONTRACT_ADDRESS}
            className="font-mono text-[12px] text-muted transition-colors duration-200 hover:text-ink"
          >
            Contract {CONTRACT_SHORT}
          </a>
        </div>

        {/* Right — nav + copyright. On mobile, wraps below the brand. */}
        <div className="flex flex-wrap items-center gap-x-6 gap-y-1">
          <nav
            aria-label="Footer"
            className="flex flex-wrap items-center gap-y-1"
          >
            {FOOTER_LINKS.map((link) => (
              <a
                key={link.label}
                href={link.href}
                target="_blank"
                rel="noopener noreferrer"
                className="flex h-11 items-center px-3.5 text-sm font-medium text-muted transition-colors duration-200 hover:text-ink"
              >
                {link.label}
              </a>
            ))}
          </nav>
          <small className="font-mono text-[12px] text-muted/70">
            © {COPYRIGHT_YEAR} Kipio
          </small>
        </div>
      </div>
    </footer>
  );
}
