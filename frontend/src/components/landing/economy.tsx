"use client";

import { useI18n } from "@context/I18nContext";

/**
 * "Where the money goes" — landing section.
 *
 * Desktop (≥ md)
 *   Two columns: three allocation bars on the left (label + pct + bar,
 *   one row each), subsidy card on the right. Unchanged from the mockup
 *   layout — the visual rhythm works at desktop width.
 *
 * Mobile (< md) — "the split ribbon"
 *   Three stacked bars would be ~140px tall with their two-row-per-bar
 *   layout (label + pct above, bar below). On mobile that reads as
 *   three separate facts rather than one division of a whole. Instead,
 *   the three bars collapse into a **single stacked ribbon** (12px tall,
 *   full width) with a compact three-row legend below.
 *
 *   The metaphor is literal: one dollar, split 72/18/10. The eye reads
 *   the whole first, then the legend tells it what each segment means.
 *   Compared to three separate bars, this:
 *
 *     - saves ~50px of vertical height;
 *     - communicates "one total, three parts" without a caption;
 *     - gives the section a distinct mobile silhouette, matching what
 *       the SignIn section does with its cosmic portal (each section
 *       has its own mobile identity, not the same shrunken desktop).
 *
 *   The ribbon grows in with the same `grow-bar` animation used on
 *   desktop (width 0 → 100% over 1.4s, ease-out). Once it finishes, a
 *   one-shot `.ribbon-sweep` overlay travels across it — "the money
 *   catches the light". It is a single beat, not a loop: the section's
 *   job is to explain the split, and a continuous sweep would compete
 *   with the numbers below for attention.
 *
 * Bar widths vs. percentages
 *   `WIDTH_SEQUENCE = [72, 18, 10]` are the mockup's visual proportions
 *   (they define how wide each segment looks). The visible percentages
 *   are `[X]%` placeholders from the dictionary — the economics contract
 *   is not active yet, so the real numbers are unknown. The two are
 *   independent on purpose:
 *
 *     - WIDTH_SEQUENCE describes layout (visual proportions).
 *     - bars[i].pct is data (rendered as `[X]%` until known).
 *
 *   Do NOT merge them. Changing the visual split to match future
 *   numbers (e.g. 65/25/10) is a layout change; updating `[X]%` to a
 *   real value is a data change. They live in different layers for a
 *   reason.
 *
 * Semantic HTML
 *   Both layouts use `<dl>`:
 *     - Desktop: `<dl>` wrapping three `<div>`s, each a `dt` (label) +
 *       `dd` (pct) pair plus a bar.
 *     - Mobile: `<dl>` with the same structure but the ribbon above
 *       the list. Screen readers hear "list, 3 items" then
 *       "Storage network: [X]%. Kipio interface: [X]%..." — the
 *       accessible data is in the `<dl>`, the ribbon is decorative
 *       (`aria-hidden`), the `<small>` "illustrative" caption comes
 *       after and qualifies the numbers.
 *
 *   The ribbon is `<div aria-hidden="true">` because its information
 *   is fully repeated by the `<dl>` below. Keeping it visible to
 *   assistive tech would announce the same colors twice.
 *
 * `[X]%` placeholders
 *   These are literal mockup placeholders, not invented numbers. The
 *   economics contract (`kipio_economics`) is deployed but inactive
 *   pending the Arbitrum Stylus activation pause. When it goes live,
 *   a future `useProtocolEconomics()` hook (Phase 11+) will feed real
 *   percentages, replacing the dictionary values.
 *
 * Subsidy card — action buttons
 *   On mobile (< md) the two buttons stack vertically; on desktop
 *   (≥ md) they sit side by side in a wrapping row.
 *
 *   Why stacked on mobile
 *     Two inline buttons whose combined width varies by locale
 *     ("Donate" / "Read the contract" in English, "Donar" / "Leer el
 *     contrato" in Spanish, longer still in Russian) cannot stay
 *     side-by-side across 12 languages without a fixed-width layout
 *     that breaks other languages. In English the row fits at 375px
 *     but wraps at 320px; in Spanish it fits at 320px but barely. The
 *     variance is per-language and not resolvable with breakpoint
 *     tuning.
 *
 *     Stacking on mobile removes the variance entirely: both buttons
 *     are always full-width, both are always the same target height,
 *     both are always on their own line. The reader sees "primary
 *     action, secondary action" in a consistent vertical rhythm
 *     regardless of the active language.
 *
 *     Cost: +52px vertical height on mobile (44 + 8 + 44 vs 44).
 *     Acceptable — the section already carries `py-24` and the card
 *     sits above the illustrative caption with room to spare.
 *
 *   On desktop the right column is ~460px wide (half of 1280px minus
 *   gutters), comfortable for the row in every supported locale.
 *   `md:flex-wrap` is kept as a defensive measure for a hypothetical
 *   future translation longer than the current longest; if it ever
 *   wraps, it wraps into a stacked pair — the graceful degradation
 *   instead of overflow.
 *
 * Client Component
 *   `"use client"` because of `useI18n()`. No state, no effects, no
 *   refs — everything else is static.
 *
 * Two ways of reading the dictionary
 *   - `t("landing.economy.subsidy.donate")` — dot-path scalar strings.
 *   - `dictionary.landing.economy.bars` — array reads. `t()` only
 *     resolves leaf strings, not arrays; iterating from the dictionary
 *     is the idiomatic path for translated lists.
 *
 * Reduced motion
 *   - `grow-bar` resolves to no animation (`--animate-grow: none`).
 *   - `ribbon-sweep` is `display: none` (globals.css).
 *   - `.animate-pulse-ring` on the violet dot resolves to `none`.
 *   - Everything else (text, layout, colors) is static.
 *
 * Deferred
 *   Both buttons are inert today. `Donate` will open a funding flow
 *   (Phase 12+); `Read the contract` will link to the economics
 *   contract on Arbiscan once deployed. `aria-disabled` is NOT added
 *   because the labels already communicate what they would do; when
 *   either is wired up in a future phase, they gain the handler /
 *   href respectively.
 */

/**
 * Visual widths for the three allocation segments, in order.
 *
 * Layout values, not data. The dictionary's `bars[i].pct` carries the
 * numeric label (`[X]%` until the economics contract is active); this
 * array carries only how wide each segment renders. Changing the split
 * (e.g. 65/25/10) means editing this array; changing the *displayed*
 * value means editing the dictionary. Independent concerns, kept
 * independent.
 */
const WIDTH_SEQUENCE = [72, 18, 10] as const;

/**
 * Tone per segment. Order must match `WIDTH_SEQUENCE` and
 * `dictionary.landing.economy.bars`. The tone maps to a Tailwind
 * background class via `TONE_CLASS` below.
 */
const TONE_SEQUENCE = ["emerald", "muted", "violet"] as const;

/**
 * Tailwind class per tone. Explicit strings (not template
 * concatenation) so the JIT compiler sees them and emits the CSS.
 * Adding a tone means adding a class here.
 */
const TONE_CLASS = {
  emerald: "bg-emerald",
  muted: "bg-muted",
  violet: "bg-violet",
} as const;

export function Economy() {
  const { t, dictionary } = useI18n();
  const bars = dictionary.landing.economy.bars;

  // Pre-merge the dictionary's labels/pcts with the layout's
  // widths/tones. Doing it once at the top keeps both layouts
  // reading the same `segments` array — no index juggling at the
  // JSX level.
  const segments = bars.map((bar, i) => ({
    label: bar.label,
    pct: bar.pct,
    width: WIDTH_SEQUENCE[i] ?? 0,
    tone: TONE_SEQUENCE[i] ?? "muted",
  }));

  return (
    <section className="mx-auto max-w-[1280px] px-6 py-24 md:px-10">
      <div className="grid gap-10 lg:grid-cols-2 lg:items-start lg:gap-12">
        {/* ── Left column — allocation split ─────────────────────── */}
        <div>
          <p className="label-mono text-emerald-text">
            {t("landing.economy.eyebrow")}
          </p>
          <h2 className="mt-3 text-[30px] font-bold leading-tight tracking-[-0.025em] text-ink md:text-[40px]">
            {t("landing.economy.title")}
          </h2>
          <p className="mt-4 text-[16px] leading-[1.6] text-muted">
            {t("landing.economy.subtitle")}
          </p>

          {/* ── Desktop — three stacked bars ───────────────────── */}
          <dl className="mt-6 hidden md:mt-[26px] md:block">
            {segments.map((seg, i) => (
              <div key={i} className="mt-[18px] first:mt-0">
                <div className="mb-2 flex items-center justify-between text-[14px]">
                  <dt className="text-ink">{seg.label}</dt>
                  <dd className="font-mono tabular-nums text-muted">
                    {seg.pct}
                  </dd>
                </div>
                <div className="h-2.5 overflow-hidden rounded-[5px] bg-hairline">
                  <div
                    className={`grow-bar h-full rounded-[5px] ${TONE_CLASS[seg.tone]}`}
                    style={{ width: `${seg.width}%` }}
                  />
                </div>
              </div>
            ))}
          </dl>

          {/* ── Mobile — stacked ribbon + compact legend ───────── */}
          <div className="mt-6 md:hidden">
            {/* Ribbon: one stacked bar. Grows in as a single unit
                (proportions preserved) — the reader sees "one
                dollar, split three ways", not "three separate
                dollars". */}
            <div className="grow-bar relative h-3 overflow-hidden rounded-full">
              <div className="flex h-full" aria-hidden="true">
                {segments.map((seg, i) => (
                  <div
                    key={i}
                    className={`h-full ${TONE_CLASS[seg.tone]}`}
                    style={{ width: `${seg.width}%` }}
                  />
                ))}
              </div>
              {/* One-shot light sweep after the ribbon finishes
                  growing. Decorative; `display: none` under
                  prefers-reduced-motion. */}
              <div
                aria-hidden="true"
                className="ribbon-sweep pointer-events-none absolute inset-0 bg-gradient-to-r from-transparent via-white/25 to-transparent"
              />
            </div>

            {/* Legend: three compact rows, one per segment. Screen
                readers hear "Storage network: [X]%. Kipio
                interface: [X]%. Universal subsidy: [X]%." — the
                accessible data, in reading order. */}
            <dl className="mt-3 space-y-1.5">
              {segments.map((seg, i) => (
                <div key={i} className="flex items-center gap-2 text-[13px]">
                  <dt className="flex items-center gap-1.5 text-muted">
                    <span
                      aria-hidden="true"
                      className={`h-1.5 w-1.5 shrink-0 rounded-full ${TONE_CLASS[seg.tone]}`}
                    />
                    {seg.label}
                  </dt>
                  <dd className="ml-auto font-mono tabular-nums text-ink">
                    {seg.pct}
                  </dd>
                </div>
              ))}
            </dl>
          </div>

          <p className="mt-3.5 text-[12px] text-muted">
            {t("landing.economy.illustrative")}
          </p>
        </div>

        {/* ── Right column — subsidy card (compact on mobile) ─────── */}
        <div className="rounded-card border border-violet/40 bg-card p-5 md:p-7">
          <div className="flex items-center gap-2">
            <span
              aria-hidden="true"
              className="animate-pulse-ring h-[7px] w-[7px] rounded-full bg-violet"
            />
            <span className="label-mono text-violet-text">
              {t("landing.economy.subsidy.eyebrow")}
            </span>
          </div>

          <div className="mt-3 font-mono text-[32px] font-semibold leading-none tracking-[-0.03em] text-ink md:mt-3.5 md:text-[40px]">
            {t("landing.economy.subsidy.amount")}
          </div>

          <p className="mt-1 text-[13px] leading-[1.5] text-muted md:text-[14px]">
            {t("landing.economy.subsidy.bodyBefore")}
            <span className="font-mono tabular-nums">
              {t("landing.economy.subsidy.bodyEmphasis")}
            </span>
            {t("landing.economy.subsidy.bodyAfter")}
          </p>

          <div className="my-4 h-2 overflow-hidden rounded-[4px] bg-hairline md:my-5">
            <div
              className="grow-bar h-full rounded-[4px] bg-violet"
              style={{ width: "38%" }}
            />
          </div>

          {/* ── Action buttons ────────────────────────────────────
              Mobile (< md): stacked vertically. Each button is
              full-width via flex-col's default stretch, giving
              identical tap targets and identical layout regardless
              of language. Desktop (≥ md): side-by-side row with
              `flex-wrap` as a defensive measure for a hypothetical
              future translation longer than current longest.

              This is the fix for the "Read the contract wraps below
              Donate in English but not in Spanish" issue: instead of
              tuning the breakpoint (which only shifts the failure
              threshold to a different locale), the mobile layout
              stops depending on button width entirely. */}
          <div className="flex flex-col gap-2 md:flex-row md:flex-wrap md:gap-2.5">
            <button
              type="button"
              className="inline-flex h-11 items-center justify-center rounded-[14px] bg-emerald px-6 text-[14px] font-semibold text-on-emerald transition-transform duration-200 ease-[cubic-bezier(0.34,1.4,0.5,1)] hover:scale-[1.02] focus-visible:scale-[1.02] md:h-12 md:px-7 md:text-[15px]"
            >
              {t("landing.economy.subsidy.donate")}
            </button>
            <button
              type="button"
              className="glass inline-flex h-11 items-center justify-center rounded-[14px] px-4 text-[13px] font-medium text-ink transition-colors duration-200 hover:bg-elevated md:h-12 md:text-[14px]"
            >
              {t("landing.economy.subsidy.readContract")}
            </button>
          </div>

          <p className="mt-3 text-[11px] leading-[1.5] text-muted md:mt-4 md:text-[12px]">
            {t("landing.economy.subsidy.disclaimer")}
          </p>
          <p className="mt-1.5 font-mono text-[11px] text-muted md:mt-2">
            {t("landing.economy.subsidy.contract")}
          </p>
        </div>
      </div>
    </section>
  );
}
