"use client";

import { useI18n } from "@context/I18nContext";

/**
 * Landing footer — brand, nav, copyright.
 *
 * Desktop (≥ md)
 *   A single horizontal row, three zones: brand + contract on the left,
 *   nav links in the middle, copyright on the right. `justify-between`
 *   distributes them; `md:flex-wrap` allows the row to wrap on narrow
 *   desktop widths (768–900px) without squashing. Unchanged from the
 *   pre-i18n version — the desktop layout already reads correctly.
 *
 * Mobile (< md)
 *   Left-aligned stack, three zones separated by spacing:
 *
 *     1. Brand block — `[icon] Kipio` on the first line, the contract
 *        link on the second, indented with `ms-[34px]` to sit visually
 *        under the "Kipio" text (icon 20px + gap 14px = 34px). This
 *        creates a "signature" block instead of a centered cluster.
 *
 *     2. Nav — a 2×2 grid with left-aligned cells. Each cell is a 44px
 *        tap target (WCAG 2.5.5 AAA) with a hover state that fills the
 *        cell surface. Left alignment (not centered) makes the grid
 *        feel like a proper menu, not a decorated two-column layout.
 *
 *     3. Copyright — left-aligned, small, mono, muted. A `border-t
 *        border-hairline` above gives the footer a clear closing rule.
 *        Left-aligned here matches the rest of the column — a centered
 *        copyright under a left-aligned brand reads as "not decided",
 *        not as "designed".
 *
 *   Before this change every zone was centered on mobile. Three
 *   independently centered blocks on a stacked layout produce exactly
 *   the effect users describe as "se ve raro": no vertical axis ties
 *   the column together. Left alignment gives the footer an axis.
 *
 * Why not center the brand on mobile
 *   Centered brand rows are a landing-page pattern (Apple, Airbnb).
 *   For product surfaces they read as a marketing "hero tail" glued to
 *   the bottom. Kipio is a product; left alignment matches the rest of
 *   the page (hero, sections, cards — all left-aligned). The navbar
 *   logo is left-aligned too; centering the footer would contradict it.
 *
 * Copy
 *   Every visible string comes from `t("landing.footer.*")`. The
 *   dictionaries (`en/footer`, `es/footer`, `_template/footer`) hold:
 *     - `contractPrefix` — "Contract " / "Contrato " (trailing space
 *       preserved; concatenated with the abbreviated address).
 *     - `contractAriaLabel` — full sentence with `{address}`
 *       placeholder; used for `aria-label` only.
 *     - `navAriaLabel` — the `<nav>` landmark name.
 *     - `docs`, `github`, `arbitrum`, `irys` — the four link labels.
 *     - `copyright` — "© {year} Kipio"; the `{year}` placeholder is
 *       preserved so translators can reorder `©`, the year and the
 *       brand name without touching code.
 *
 * `title` vs `aria-label` on the contract link
 *   - `aria-label` = full sentence in the active locale, with the full
 *     42-character address substituted. Describes the destination to
 *     assistive tech, spelled out — not abbreviated.
 *   - `title` = raw `CONTRACT_ADDRESS`. Shows the full address on hover,
 *     which the visible text (`Contract 0xfe76…7452`) abbreviates.
 *
 *   Two different audiences, so both stay. Unlike the theme toggle
 *   where `title` would have duplicated `aria-label` exactly.
 *
 * `id="docs"`
 *   Carried from the mockup so `#docs` resolves to the footer. The
 *   `scroll-margin-top: 5rem` rule in globals.css clears the sticky
 *   navbar when that anchor is used.
 *
 * Copyright year
 *   `new Date().getFullYear()` at module load. Frozen at build for a
 *   static export; refreshed on every rebuild. A `© 2026 Kipio` in
 *   the DOM in 2027 would be a one-year-stale artifact — the module
 *   evaluation avoids that.
 *
 * Semantics and a11y
 *   - `<footer>` — the document footer landmark (implicit
 *     `role="contentinfo"`).
 *   - `<nav aria-label={…}>` — landmark distinct from the header's
 *     primary nav.
 *   - `<ul><li>` — each link is a list item, screen readers announce
 *     "list, 4 items" before the links. The `<ul>` carries the layout
 *     (`grid` / `flex`); each `<a>` inside has the full tap surface.
 *   - `<small>` — semantic for legal fine print.
 *   - `target="_blank" rel="noopener noreferrer"` — all external
 *     links; no tabnabbing, no referrer leak.
 *   - `aria-hidden="true"` on the emerald mark SVG — decorative.
 *   - Left alignment throughout reads consistently in both LTR and
 *     RTL locales (logical properties `ms-*`, `text-start`).
 */

const CONTRACT_ADDRESS = "0xfe76a53e5cc1cc5136b7da6b6fcf6c593c767452";
const CONTRACT_SHORT = "0xfe76…7452";
const CONTRACT_URL = `https://sepolia.arbiscan.io/address/${CONTRACT_ADDRESS}`;

/**
 * Copyright year, evaluated once at module load.
 *
 * Static export: build time. SSR: request time. Either way, the
 * value is identical for every visitor of the same deployment, so
 * there is no hydration mismatch. A rebuild at the start of a new
 * year keeps it accurate without a code change.
 */
const COPYRIGHT_YEAR = new Date().getFullYear();

/**
 * The four footer links. `i18nKey` is the dictionary path for the
 * visible label; the compiler validates each value against
 * `Path<Dictionary>` (a typo fails the build).
 *
 * `Docs` and `GitHub` currently both point at the working repository
 * until a dedicated `/docs` route lands (see the mockup's `#docs`
 * placeholders and design system §3.7 "Docs externos"). When that
 * route exists, `Docs` gets `href="/docs"` and drops `target` +
 * `rel` (internal navigation).
 */
const FOOTER_LINKS = [
  {
    key: "docs",
    i18nKey: "landing.footer.docs",
    href: "https://github.com/AndresChanchi/vaultchain-sovereign-agent",
  },
  {
    key: "github",
    i18nKey: "landing.footer.github",
    href: "https://github.com/AndresChanchi/vaultchain-sovereign-agent",
  },
  {
    key: "arbitrum",
    i18nKey: "landing.footer.arbitrum",
    href: "https://arbitrum.io",
  },
  {
    key: "irys",
    i18nKey: "landing.footer.irys",
    href: "https://irys.xyz",
  },
] as const;

export function Footer() {
  const { t } = useI18n();

  return (
    <footer id="docs" className="border-t border-hairline">
      <div className="mx-auto max-w-[1280px] px-6 md:px-10">
        <div className="flex flex-col gap-8 py-10 md:flex-row md:flex-wrap md:items-center md:justify-between md:gap-6 md:py-8 md:pb-12">
          {/* ── Brand block — stacked on mobile, inline on desktop ── */}
          <div className="flex flex-col items-start gap-2 md:flex-row md:items-center md:gap-3.5">
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
            </div>
            <a
              href={CONTRACT_URL}
              target="_blank"
              rel="noopener noreferrer"
              aria-label={t("landing.footer.contractAriaLabel", {
                address: CONTRACT_ADDRESS,
              })}
              title={CONTRACT_ADDRESS}
              className="ms-[34px] font-mono text-[12px] text-muted transition-colors duration-200 hover:text-ink md:ms-0"
            >
              {t("landing.footer.contractPrefix")}
              {CONTRACT_SHORT}
            </a>
          </div>

          {/* ── Nav — 2×2 grid on mobile, inline row on desktop ── */}
          <nav
            aria-label={t("landing.footer.navAriaLabel")}
            className="w-full md:w-auto"
          >
            <ul className="grid grid-cols-2 gap-1 md:flex md:items-center">
              {FOOTER_LINKS.map((link) => (
                <li key={link.key}>
                  <a
                    href={link.href}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex h-11 items-center rounded-[10px] px-3 text-sm font-medium text-muted transition-colors duration-200 hover:bg-elevated hover:text-ink md:h-9"
                  >
                    {t(link.i18nKey)}
                  </a>
                </li>
              ))}
            </ul>
          </nav>

          {/* ── Copyright — closing row, left-aligned on mobile ── */}
          <small className="w-full border-t border-hairline pt-6 text-start font-mono text-[12px] text-muted/70 md:w-auto md:border-0 md:pt-0 md:text-start">
            {t("landing.footer.copyright", { year: COPYRIGHT_YEAR })}
          </small>
        </div>
      </div>
    </footer>
  );
}
