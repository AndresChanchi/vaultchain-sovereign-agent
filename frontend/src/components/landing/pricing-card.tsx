"use client";

import { useMemo, useState } from "react";

type TermId = "30d" | "1y" | "forever";

type Term = {
  id: TermId;
  label: string;
  storageUsd: number;
  feeUsd: number;
  copUsdRate: number;
};

/**
 * PLACEHOLDER numbers. Wire to `usePrice()` once the Irys price API and the
 * Kipio fee contract are queried. Never hardcode in production.
 *
 * Stored as a Record so `TERMS[selectedId]` is typed as `Term` (never
 * undefined) without non-null assertions, even under `noUncheckedIndexedAccess`.
 */
const TERMS = {
  "30d":     { id: "30d",     label: "30 days", storageUsd: 0.6, feeUsd: 0.15, copUsdRate: 4200 },
  "1y":      { id: "1y",      label: "1 year",  storageUsd: 4.5, feeUsd: 0.75, copUsdRate: 4200 },
  "forever": { id: "forever", label: "Forever", storageUsd: 18,  feeUsd: 2.5,  copUsdRate: 4200 },
} as const satisfies Record<TermId, Term>;

/** Display order of terms in the segmented control. */
const TERM_ORDER: readonly TermId[] = ["30d", "1y", "forever"];

const USD = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD",
  minimumFractionDigits: 2,
});
const COP = new Intl.NumberFormat("es-CO", {
  style: "currency",
  currency: "COP",
  maximumFractionDigits: 0,
});

export function PricingCard() {
  const [selectedId, setSelectedId] = useState<TermId>("1y");

  // Record access — always `Term`, never `Term | undefined`.
  const term = useMemo(() => TERMS[selectedId], [selectedId]);

  const totalUsd = term.storageUsd + term.feeUsd;
  const totalCop = totalUsd * term.copUsdRate;

  return (
    <div className="rounded-card border border-hairline bg-card p-6 sm:p-8">
      <div
        role="radiogroup"
        aria-label="Storage term"
        className="grid grid-cols-3 gap-1 rounded-button border border-hairline bg-elevated p-1"
      >
        {TERM_ORDER.map((id) => {
          const t = TERMS[id];
          const selected = id === selectedId;
          return (
            <button
              key={id}
              type="button"
              role="radio"
              aria-checked={selected}
              onClick={() => setSelectedId(id)}
              className={
                "rounded-[10px] px-3 py-2 text-sm font-medium transition-colors " +
                (selected
                  ? "bg-card text-ink ring-1 ring-emerald/60"
                  : "text-muted hover:text-ink")
              }
            >
              {t.label}
            </button>
          );
        })}
      </div>

      <dl className="mt-6 space-y-3 text-sm">
        <div className="flex items-center justify-between">
          <dt className="text-muted">Storage (from the network)</dt>
          <dd className="font-mono tabular-nums text-ink">
            {USD.format(term.storageUsd)}
          </dd>
        </div>
        <div className="flex items-center justify-between">
          <dt className="text-muted">Kipio fee</dt>
          <dd className="font-mono tabular-nums text-ink">
            {USD.format(term.feeUsd)}
          </dd>
        </div>
        <div className="flex items-center justify-between border-t border-hairline pt-3">
          <dt className="font-medium text-ink">Total</dt>
          <dd className="font-mono tabular-nums text-ink">
            {USD.format(totalUsd)}
          </dd>
        </div>
        <div className="flex items-center justify-between text-xs text-muted">
          <dt className="sr-only">Total in Colombian pesos</dt>
          <dd className="ml-auto font-mono tabular-nums">
            ≈ {COP.format(totalCop)}
          </dd>
        </div>
      </dl>

      <p className="mt-6 text-xs leading-relaxed text-muted">
        You can extend any time, but never shorten.
      </p>
      <p className="mt-2 text-xs leading-relaxed text-muted/80">
        Illustrative. Live numbers come straight from the contracts.
      </p>
    </div>
  );
}
