"use client";

import { useI18n } from "@context/I18nContext";
import { useStats } from "@hooks/protocol/useStats";

/**
 * "Live from the network" — landing stats bar.
 *
 * Four figures counted from public contract events: photos kept,
 * spaces opened, data stored, photos shared. The `glass` surface +
 * pulsing emerald dot at the top are how the mockup communicates
 * "live" without any JS.
 *
 * Client Component
 *   `"use client"` because of `useI18n()`. The section reads its four
 *   labels, subtitle and placeholder from the active dictionary.
 *   `useStats()` is a plain function (no React hooks inside) despite
 *   its `use` prefix — it works in a Client Component exactly as it
 *   did in a Server one.
 *
 *   When the indexer lands and `useStats` becomes a `useQuery` call,
 *   this file needs no change: `useQuery` also runs in client
 *   components, the return shape stays the same, and the consumer
 *   contract (four fields, `number | null`) does not move.
 *
 * Today every figure is null
 *   `useStats()` returns null for all four fields. Each cell renders
 *   `landing.liveStats.notAvailable` (`—`). This is honest, not a
 *   placeholder for a fake value — the design system forbids
 *   hardcoded numbers dressed as real data. The
 *   `data-placeholder="hardcoded"` attribute on each cell remains,
 *   visible in devtools only.
 *
 * i18n
 *   Everything visible reads from `landing.liveStats.*`:
 *     eyebrow, subtitle, photosKept, spacesOpened, dataStored,
 *     photosShared, notAvailable, unitGb.
 *
 *   `notAvailable` (`—`) and `unitGb` (`GB`) are technically
 *   translatable but stay identical in every locale by editorial
 *   choice — they are symbols, not words. Translators are free to
 *   adjust `unitGb` in locales where a different glyph is conventional
 *   (e.g. some scripts prefer "GB" written in the local form).
 *
 * Number formatting
 *   `value.toLocaleString()` uses the user's locale for thousands
 *   separators (`18,402` en-US, `18.402` es-CO). The current data is
 *   `null`, so this branch is dormant — but it is the right behaviour
 *   once the indexer lands.
 *
 * Motion
 *   The emerald dot uses `animate-pulse-ring` (2.6s halo pulse).
 *   Under `prefers-reduced-motion: reduce` the token resolves to
 *   `none`, so the dot is static. No count-up today: `--n` needs a
 *   numeric target and there is nothing to count yet.
 *
 * Layout stability
 *   `text-balance` on the eyebrow row would break the monospace
 *   rhythm (label + subtitle run inline). Left as-is.
 */

export function LiveStats() {
  const { t } = useI18n();
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
            {t("landing.liveStats.eyebrow")}
          </span>
          <span className="font-mono text-[12px] text-muted">
            {t("landing.liveStats.subtitle")}
          </span>
        </div>

        <div className="mt-6 grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
          <StatCell
            label={t("landing.liveStats.photosKept")}
            value={stats.photosKept}
            placeholder={t("landing.liveStats.notAvailable")}
          />
          <StatCell
            label={t("landing.liveStats.spacesOpened")}
            value={stats.spacesOpened}
            placeholder={t("landing.liveStats.notAvailable")}
          />
          <StatCell
            label={t("landing.liveStats.dataStored")}
            value={stats.dataStoredGb}
            unit={t("landing.liveStats.unitGb")}
            placeholder={t("landing.liveStats.notAvailable")}
          />
          <StatCell
            label={t("landing.liveStats.photosShared")}
            value={stats.photosShared}
            placeholder={t("landing.liveStats.notAvailable")}
          />
        </div>
      </div>
    </section>
  );
}

/**
 * One figure in the stats grid.
 *
 * Renders `placeholder` (`—`) when `value` is null. The
 * `data-placeholder` attribute is a devtools affordance: inspecting
 * the DOM shows `data-placeholder="hardcoded"`, distinguishing
 * "currently a stub" from "value happens to be missing for another
 * reason". No visible copy claims the numbers are fake.
 *
 * `unit` (e.g. "GB") renders only when `value` is not null — showing
 * "— GB" would imply "unknown number of GB" rather than "no data
 * yet", which is subtly wrong.
 */
function StatCell({
  label,
  value,
  unit,
  placeholder,
}: {
  label: string;
  value: number | null;
  unit?: string;
  placeholder: string;
}) {
  const isPlaceholder = value === null;

  return (
    <div data-placeholder={isPlaceholder ? "hardcoded" : undefined}>
      <div className="font-mono text-[30px] font-semibold leading-none tracking-[-0.03em] tabular-nums text-ink md:text-[44px]">
        {isPlaceholder ? placeholder : value.toLocaleString()}
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
