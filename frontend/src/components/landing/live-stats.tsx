import { useStats } from "@hooks/protocol/useStats";

/**
 * "Live from the network" — landing stats bar.
 *
 * Four figures counted from public contract events: photos kept,
 * spaces opened, data stored, photos shared. The `glass` surface +
 * pulsing emerald dot at the top are how the mockup communicates
 * "live" without any JS.
 *
 * Today every figure is null
 *   `useStats()` returns null for all four fields (see that hook's
 *   header for why: the current VaultChainMVP contract only emits
 *   `PhotoRegistered(user, contentHash, encryptedTxId)` — no size, no
 *   shares, and deriving counts requires an indexer over the full
 *   event history). Each cell therefore renders "—".
 *
 *   This is honest, not a placeholder for a fake value. The design
 *   system forbids hardcoded numbers dressed as real data. The
 *   `data-placeholder="hardcoded"` attribute on each cell is visible
 *   in devtools so a developer inspecting the DOM knows this is the
 *   current stub, without any copy saying so in the UI.
 *
 * Server Component
 *   `useStats()` is a plain function (no React hooks inside) despite
 *   its `use` prefix. It works in a Server Component. When the
 *   indexer lands and `useStats` becomes a `useQuery` call, this
 *   file becomes a client island — no other change to this file is
 *   needed then (the return shape is preserved).
 *
 * Motion
 *   - The emerald dot uses `animate-pulse-ring` (2.6s halo pulse).
 *     Resolves to `animation: none` under `prefers-reduced-motion:
 *     reduce` (globals.css token override), so the dot sits static —
 *     still "live" in meaning, just not moving.
 *   - No count-up on the numbers today. The count-up utility exists
 *     (`.count-up` + `@property --n`) but it needs a numeric target;
 *     with nulls there is nothing to count. When real data arrives,
 *     swapping `<span>{value.toLocaleString()}</span>` for
 *     `<span className="count-up" style={{ "--n": value }} />` is a
 *     one-line change.
 *
 * Glass surface
 *   The mockup wraps this section in `.gl` (the glass utility).
 *   DESIGN §4.4 reserves glass for sidebar, dock, slide-overs,
 *   popovers and chips — but the mockup is the source of truth, and
 *   here glass is the right choice: the section sits over the page's
 *   drifting orbs and the backdrop-filter lets them show through as
 *   a subtle life signal behind the numbers. Not nested inside any
 *   `preserve-3d` ancestor, so no blur degradation.
 *
 * Number formatting
 *   `value.toLocaleString()` uses the user's locale for thousands
 *   separators (`18,402` in en-US, `18.402` in es-CO). The mockup
 *   renders raw digits because `counter()` does not add separators,
 *   but readability wins for larger numbers — and this only affects
 *   real data, which is not rendering yet.
 */

export function LiveStats() {
  const stats = useStats();

  return (
    <section className="mx-auto max-w-[1280px] px-6 py-16 md:px-10">
      <div className="glass rounded-panel px-8 py-8 md:px-10">
        <div className="flex flex-wrap items-center gap-2.5">
          <span
            aria-hidden="true"
            className="animate-pulse-ring h-2 w-2 rounded-full bg-emerald"
          />
          <span className="label-mono text-emerald-text">
            Live from the network
          </span>
          <span className="font-mono text-[12px] text-muted">
            Counted from public contract events. No names. No files.
          </span>
        </div>

        <div className="mt-6 grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
          <StatCell label="Photos kept" value={stats.photosKept} />
          <StatCell label="Spaces opened" value={stats.spacesOpened} />
          <StatCell
            label="Data stored"
            value={stats.dataStoredGb}
            unit="GB"
          />
          <StatCell label="Photos shared" value={stats.photosShared} />
        </div>
      </div>
    </section>
  );
}

/**
 * One figure in the stats grid.
 *
 * Renders "—" when `value` is null. The `data-placeholder` attribute
 * is a devtools affordance: inspecting the DOM shows
 * `data-placeholder="hardcoded"`, which is how a future developer
 * distinguishes "currently a stub" from "value happens to be missing
 * for another reason". No visible copy claims the numbers are fake
 * — that would be meta-commentary on the product, not on the design.
 *
 * The unit suffix ("GB" for Data stored) sits inline, smaller and
 * muted, exactly like the mockup. It is rendered only when the value
 * is not null — showing "— GB" would imply "unknown GB amount" rather
 * than "no data yet", which is subtly wrong.
 */
function StatCell({
  label,
  value,
  unit,
}: {
  label: string;
  value: number | null;
  unit?: string;
}) {
  const isPlaceholder = value === null;

  return (
    <div data-placeholder={isPlaceholder ? "hardcoded" : undefined}>
      <div className="font-mono text-[30px] font-semibold leading-none tracking-[-0.03em] tabular-nums text-ink md:text-[44px]">
        {isPlaceholder ? "—" : value.toLocaleString()}
        {!isPlaceholder && unit && (
          <span className="ml-1 text-[18px] font-medium text-muted">
            {unit}
          </span>
        )}
      </div>
      <p className="label-mono mt-1.5 text-muted">{label}</p>
    </div>
  );
}
