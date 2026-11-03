"use client";

import { useI18n } from "@context/I18nContext";

/**
 * "Any device" — landing section.
 *
 * Centered copy + a five-node "device rail" — iPhone, Android,
 * Windows, Mac, Web — connected by a hairline with a small emerald
 * dot traveling its length. The dot literalizes the section's claim:
 * your photo moves between devices, the rail is the path.
 *
 * Device rail (the section's innovation)
 *   Desktop (≥ md)
 *     Five nodes in a horizontal row, evenly spaced (`justify-between`).
 *     Each node: a 44px circle with the brand icon on top, the device
 *     name below. A 1px hairline runs behind the circles from first
 *     center to last center. An emerald dot (6px) travels the line on
 *     an 8s loop, fading in at the first node and out at the last.
 *
 *   Mobile (< md)
 *     The row collapses to a vertical rail. Each node is a horizontal
 *     row: 44px circle left, label right. The hairline runs vertically
 *     behind the icons, dot travels top→bottom. Reads as a timeline of
 *     devices rather than a wrapped chip cloud — much clearer
 *     semantically than five chips at arbitrary positions on a 320px
 *     viewport.
 *
 *   Both layouts live in `globals.css` under "AnyDevice — device rail".
 *   The JSX only cares about the two structural containers
 *   (`.device-rail-line`, `.device-rail-dot`); the media queries in CSS
 *   handle the horizontal ↔ vertical switch. No JS breakpoint logic.
 *
 * i18n layout stability
 *   Device names (iPhone, Android, Windows, Mac, Web) are proper nouns
 *   — identical in every locale. Layout is guaranteed by design, not
 *   by `text-balance`.
 *
 *   The H2 and subtitle DO translate; both carry `text-balance` so
 *   line lengths stay even in the longer locales (German "Ihre
 *   Qualität reist mit Ihnen", French "Votre qualité vous suit") and
 *   no single word is orphaned on its own line. `text-balance` is
 *   supported in every browser Next.js 16 targets (Chrome 114+,
 *   Safari 17.5+, Firefox 121+).
 *
 *   Labels use `whitespace-nowrap` — even a hypothetical long
 *   translation cannot push the row wider than the 44px icon because
 *   the label truncates at the node boundary on mobile and clips its
 *   grid cell on desktop. In practice the proper nouns fit on one
 *   line for every locale.
 *
 * Brand icons
 *   Inline SVGs, no icon library. Five recognizable marks:
 *     Apple     → apple silhouette (iPhone)
 *     Android   → android head (Android)
 *     Windows   → four-pane logo (Windows)
 *     Mac       → laptop outline (Mac)
 *     Web       → globe (Web / any browser)
 *
 *   All `fill="currentColor"` or `stroke="currentColor"`, so they
 *   inherit `text-ink` and stay readable in both themes. No brand
 *   colors: the section describes compatibility, not endorsement —
 *   full-color brand marks would compete with the emerald/violet
 *   palette, which is not the tone of this page.
 *
 *   Real brand logos are trademarks. Their use in a "supported on"
 *   context is the common, accepted convention; the page does not
 *   imply partnership or endorsement.
 *
 * Chips → `<ul><li>`
 *   The mockup renders each device as a `<span>`. Semantically, five
 *   supported devices form a list, and the previous chips-as-spans
 *   treatment in this component lost that. `<ul role="list">` plus
 *   `<li>` per node gives screen readers "list, 5 items" before the
 *   content — same pattern as `SignIn`, which was migrated first.
 *
 * Icon order
 *   `DEVICE_ICONS` is positional (index 0 = iPhone icon, etc.).
 *   Indexing by position — not by label — means the icons stay
 *   attached to their intended device even if a future locale
 *   decides to translate the label to something else (it should not,
 *   they are proper nouns, but defensive against future editorial
 *   drift). A missing icon at a given index falls back to the globe,
 *   so a 6th device added to the dictionary renders as Web until its
 *   icon is defined.
 *
 * Client Component
 *   `useI18n()` provides `t()` and the active dictionary. No state,
 *   no effects, no refs — this file is client only because of i18n.
 *
 * Reduced motion
 *   The traveling dot has `opacity: 0` under
 *   `prefers-reduced-motion: reduce` and no animation
 *   (globals.css). The rail line stays visible, the nodes stay
 *   visible — the section is fully readable, just still.
 */

const DEVICE_ICONS = [
  AppleIcon,
  AndroidIcon,
  WindowsIcon,
  MacIcon,
  WebIcon,
] as const;

export function AnyDevice() {
  const { t, dictionary } = useI18n();
  const devices = dictionary.landing.anyDevice.devices;

  return (
    <section className="mx-auto max-w-[1280px] px-6 py-24 text-center md:px-10">
      <p className="label-mono text-emerald-text">
        {t("landing.anyDevice.eyebrow")}
      </p>
      <h2 className="mt-4 text-balance text-[30px] font-bold leading-tight tracking-[-0.025em] text-ink md:text-[40px]">
        {t("landing.anyDevice.title")}
      </h2>
      <p className="mx-auto mt-4 max-w-[520px] text-balance text-[16px] leading-[1.6] text-muted">
        {t("landing.anyDevice.subtitle")}
      </p>

      <div className="device-rail mx-auto mt-14 max-w-[760px]">
        <div className="device-rail-line" aria-hidden="true" />
        <div className="device-rail-dot" aria-hidden="true" />
        <ul
          role="list"
          className="relative flex flex-col gap-6 md:flex-row md:items-start md:justify-between md:gap-4"
        >
          {devices.map((label, i) => {
            const Icon = DEVICE_ICONS[i] ?? WebIcon;
            return (
              <li
                key={i}
                className="flex flex-row items-center gap-3 md:flex-col md:items-center md:gap-3"
              >
                <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full border border-hairline bg-card text-ink">
                  <Icon />
                </div>
                <span className="whitespace-nowrap text-start text-[13px] font-medium text-muted md:text-center md:text-[14px]">
                  {label}
                </span>
              </li>
            );
          })}
        </ul>
      </div>
    </section>
  );
}

/* ── Brand icons ───────────────────────────────────────────────────────
 * Inline, monochrome, all `fill="currentColor"` or `stroke="currentColor"`.
 * 20px nominal size for the glyph; the 44px circle wrapper supplies
 * the tap/visual target. See the file header for tone/colour reasoning.
 * ─────────────────────────────────────────────────────────────────── */

function AppleIcon() {
  return (
    <svg
      width="20"
      height="20"
      viewBox="0 0 24 24"
      fill="currentColor"
      aria-hidden="true"
    >
      <path d="M17.05 20.28c-.98.95-2.05.8-3.08.35-1.09-.46-2.09-.48-3.24 0-1.44.62-2.2.44-3.06-.35C2.79 15.25 3.51 7.59 9.05 7.31c1.35.07 2.29.74 3.08.8 1.18-.24 2.31-.93 3.57-.84 1.51.12 2.65.72 3.4 1.8-3.12 1.87-2.38 5.98.48 7.13-.57 1.5-1.31 2.99-2.53 4.08M12.03 7.25c-.15-2.23 1.66-4.07 3.74-4.25.29 2.58-2.34 4.5-3.74 4.25" />
    </svg>
  );
}

function AndroidIcon() {
  return (
    <svg
      width="20"
      height="20"
      viewBox="0 0 24 24"
      fill="currentColor"
      aria-hidden="true"
    >
      <path d="M17.6 9.48l1.84-3.18c.16-.31.04-.69-.26-.85-.29-.15-.65-.06-.83.22l-1.88 3.24a11.463 11.463 0 00-8.94 0L5.65 5.67c-.19-.29-.58-.38-.87-.2-.28.18-.37.54-.22.83L6.4 9.48A10.78 10.78 0 001 18h22a10.78 10.78 0 00-5.4-8.52M7 15.25a1.25 1.25 0 110-2.5 1.25 1.25 0 010 2.5m10 0a1.25 1.25 0 110-2.5 1.25 1.25 0 010 2.5" />
    </svg>
  );
}

function WindowsIcon() {
  return (
    <svg
      width="18"
      height="18"
      viewBox="0 0 24 24"
      fill="currentColor"
      aria-hidden="true"
    >
      <path d="M3 5.548L10.094 4.59v6.949H3V5.548zm0 12.904l7.094.958v-6.881H3v5.923zm8.35 1.128l9.65 1.303V12.628h-9.65v6.952zm0-13.882v6.949h9.65V2.35L11.35 3.698z" />
    </svg>
  );
}

function MacIcon() {
  return (
    <svg
      width="20"
      height="20"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <rect x="4" y="4" width="16" height="11" rx="1.5" />
      <path d="M2 19h20" />
    </svg>
  );
}

function WebIcon() {
  return (
    <svg
      width="20"
      height="20"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.6"
      strokeLinecap="round"
      aria-hidden="true"
    >
      <circle cx="12" cy="12" r="9" />
      <path d="M3 12h18M12 3c3 3 3 15 0 18M12 3c-3 3-3 15 0 18" />
    </svg>
  );
}
