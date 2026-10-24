/**
 * "Where the money goes" — landing section.
 *
 * Two columns: the allocation breakdown on the left (label + pct + bar,
 * three rows), the universal-subsidy card on the right. On < lg the
 * copy stacks above the card.
 *
 * Copy source of truth
 *   The mockup (Landing-dark.html / Landing-Light / Landing-Mobile).
 *   Changes relative to the inline version this replaces:
 *     - Paragraph rewritten. The mockup explains *what* is being split
 *       ("Storage is paid to the network that keeps your photos…")
 *       rather than merely labelling the bars as illustrative. The
 *       "Illustrative" caveat moves below the bars, where it belongs
 *       (adjacent to the data it qualifies).
 *     - Bar labels shortened: "Storage network" / "Kipio interface" /
 *       "Universal subsidy" — no parenthetical.
 *     - Percentages become `[X]%` placeholders instead of `72/18/10`.
 *       Those numbers in the earlier inline were illustrative widths
 *       dressed as real percentages. The design system forbids that;
 *       `[X]` is honest about being unknown. The visible bar widths
 *       (72/18/10) still convey the *relative* split — they are
 *       layout, not data.
 *     - Bar colors: emerald / muted / violet. The earlier inline used
 *       emerald / violet / emerald, which read as "two emerald
 *       categories, one violet" — the mockup's tone choice is
 *       storage=emerald (the big one), kipio=muted (the quiet fee),
 *       subsidy=violet (the intentional side pool).
 *     - The subsidy card is enriched: pulsing violet dot before the
 *       eyebrow, USD `[X]` figure, "enough for `[N]` first uploads"
 *       subtext, a progress bar (38% width), two buttons (Donate +
 *       Read the contract), and the contract address. The earlier
 *       inline had eyebrow + one paragraph + one button.
 *
 * Placeholders `[X]`, `[N]`
 *   These are literal mockup placeholders, not numbers dressed as
 *   real. `kipio_economics` is deployed on Sepolia but inactive
 *   pending the Arbitrum Stylus activation pause. When it goes live,
 *   `useProtocolEconomics()` (Fase 11+) will feed real values and the
 *   `[X]` / `[N]` strings become `{value}` interpolations. Copy stays.
 *
 *   Unlike the LiveStats numbers (which the mockup dressed as real
 *   data and were replaced with `—`), these are visibly placeholders
 *   already — `[X]` on its own communicates "unknown". Preserving
 *   them is honest; replacing them with `—` would delete the mockup's
 *   emphasis on *which* values are coming.
 *
 * `.grow-bar` utility
 *   Each bar renders `<div className="grow-bar" style={{ width: "N%" }}/>`
 *   and the CSS animates from `width: 0` to the inline width on mount
 *   (1.4s, `cubic-bezier(0.2, 0.8, 0.2, 1)`, `both` fill). One-shot,
 *   not scroll-tied — matches the mockup's `.grow` exactly.
 *
 *   Why not scroll-tied: the mockup is one-shot at mount. If a future
 *   iteration wants a view-timeline reveal, wrap the animation in
 *   `@supports (animation-timeline: view())` and set
 *   `animation-timeline: view()` + `animation-range: entry 10% cover
 *   50%`. The component's `className="grow-bar"` does not need to
 *   change. Until then, keep it simple.
 *
 *   Under `prefers-reduced-motion: reduce`, the `--animate-grow-bar`
 *   token resolves to `none`, so bars render at full width
 *   immediately. No loss of information.
 *
 * Pulse dot
 *   The subsidy card carries a 7px violet dot with `animate-pulse-ring`
 *   (the same halo used by LiveStats and Hero). The mockup's `.pu`
 *   keyframe hardcodes an emerald halo — pairing it with a violet dot
 *   is the mockup's own slight inconsistency. Kept as-is because
 *   re-toning the halo would require a separate `--pulse-color` token
 *   whose only consumer is this one dot. If the discrepancy ever
 *   matters visually, add a `pulse-ring-violet` utility; the fix is
 *   three lines.
 *
 * Buttons
 *   Both are inert. "Donate" would open a funding flow (Fase 12+);
 *   "Read the contract" would link to the economics contract on
 *   Arbiscan once deployed. No `onClick` yet — a click does nothing,
 *   which is honest. When either lands, they gain a handler or an
 *   `href` respectively. `aria-label` is unnecessary today because
 *   the text is already descriptive.
 *
 * Server Component
 *   No state, no effects, no handlers. Under reduced motion, nothing
 *   here has motion to disable besides the dot (already covered by
 *   `--animate-pulse-ring`) and the bars (already covered by
 *   `--animate-grow-bar`).
 */

/**
 * The three allocation bars. `widthPct` is the visual proportion
 * (layout, matching the mockup's inline widths). `pctLabel` is the
 * numeric label — a placeholder until the economics contract is
 * active. Do not merge them: the layout ratio (72/18/10) and the
 * numeric split (once known) are independent concerns.
 */
const ALLOCATION_BARS = [
  {
    label: "Storage network",
    pctLabel: "[X]%",
    widthPct: 72,
    tone: "emerald" as const,
  },
  {
    label: "Kipio interface",
    pctLabel: "[X]%",
    widthPct: 18,
    tone: "muted" as const,
  },
  {
    label: "Universal subsidy",
    pctLabel: "[X]%",
    widthPct: 10,
    tone: "violet" as const,
  },
];

const TONE_CLASS: Record<(typeof ALLOCATION_BARS)[number]["tone"], string> = {
  emerald: "bg-emerald",
  muted: "bg-muted",
  violet: "bg-violet",
};

export function Economy() {
  return (
    <section className="mx-auto max-w-[1280px] px-6 py-24 md:px-10">
      <div className="grid gap-12 lg:grid-cols-2 lg:items-start">
        {/* Left column — allocation breakdown */}
        <div>
          <p className="label-mono text-emerald-text">Where the money goes</p>
          <h2 className="mt-3 text-[30px] font-bold leading-tight tracking-[-0.025em] text-ink md:text-[40px]">
            No hidden business. See every dollar.
          </h2>
          <p className="mt-4 text-[16px] leading-[1.6] text-muted">
            Storage is paid to the network that keeps your photos. Kipio adds a
            small fee for running the interface. A share of fees funds a
            universal subsidy, so more people can start for free.
          </p>

          <div className="mt-[26px]">
            {ALLOCATION_BARS.map((bar) => (
              <div key={bar.label} className="mt-[18px] first:mt-0">
                <div className="mb-2 flex items-center justify-between text-[14px]">
                  <span className="text-ink">{bar.label}</span>
                  <span className="font-mono tabular-nums text-muted">
                    {bar.pctLabel}
                  </span>
                </div>
                <div className="h-2.5 overflow-hidden rounded-[5px] bg-hairline">
                  <div
                    className={`grow-bar h-full rounded-[5px] ${TONE_CLASS[bar.tone]}`}
                    style={{ width: `${bar.widthPct}%` }}
                  />
                </div>
              </div>
            ))}
          </div>

          <p className="mt-3.5 text-[12px] text-muted">
            Illustrative. Live numbers come straight from the contracts.
          </p>
        </div>

        {/* Right column — subsidy pool card */}
        <div className="rounded-card border border-violet/40 bg-card p-7">
          <div className="flex items-center gap-2">
            <span
              aria-hidden="true"
              className="animate-pulse-ring h-[7px] w-[7px] rounded-full bg-violet"
            />
            <span className="label-mono text-violet-text">
              Universal subsidy
            </span>
          </div>

          <div className="mt-3.5 font-mono text-[40px] font-semibold leading-none tracking-[-0.03em] text-ink">
            USD [X]
          </div>

          <p className="mt-1 text-[14px] leading-[1.5] text-muted">
            in the pool today. Enough for{" "}
            <span className="font-mono tabular-nums">[N]</span> first uploads.
          </p>

          <div className="my-5 h-2 overflow-hidden rounded-[4px] bg-hairline">
            <div
              className="grow-bar h-full rounded-[4px] bg-violet"
              style={{ width: "38%" }}
            />
          </div>

          <div className="flex flex-wrap gap-2.5">
            <button
              type="button"
              className="inline-flex h-12 items-center justify-center rounded-[14px] bg-emerald px-7 text-[15px] font-semibold text-on-emerald transition-transform duration-200 ease-[cubic-bezier(0.34,1.4,0.5,1)] hover:scale-[1.02] focus-visible:scale-[1.02]"
            >
              Donate
            </button>
            <button
              type="button"
              className="glass inline-flex h-12 items-center justify-center rounded-[14px] px-4 text-[14px] font-medium text-ink transition-colors duration-200 hover:bg-elevated"
            >
              Read the contract
            </button>
          </div>

          <p className="mt-4 text-[12px] leading-[1.5] text-muted">
            Donations go to the protocol&rsquo;s subsidy pool, not to
            Kipio&rsquo;s team.
          </p>
          <p className="mt-2 font-mono text-[11px] text-muted">
            Contract 0x93b4…4F8a
          </p>
        </div>
      </div>
    </section>
  );
}
