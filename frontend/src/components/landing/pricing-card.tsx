"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { useI18n } from "@context/I18nContext";
import { useUploadQuote } from "@hooks/pricing/useUploadQuote";
import { CurrencyPicker } from "@components/ui/currency-picker";
import { PricingChart } from "@components/landing/pricing-chart";
import {
  DEFAULT_CURRENCY,
  IRYS_FREE_UPLOAD_BYTES,
  type CurrencyCode,
} from "@config/pricing";
import { LOCALE_META } from "@lib/i18n/locales";
import type { Term } from "@lib/pricing/types";

/**
 * Pricing card — real quotes from Irys + Kipio fee, multi-currency,
 * variable size via input + chart.
 *
 * Currency handling
 *   Every monetary field returned by `useUploadQuote` comes in two
 *   variants:
 *
 *     - `*Usd`     — the raw USD amount. Never formatted directly with
 *                    the picker's currency: `format.currency(3, "COP")`
 *                    renders "COP 3", meaning 3 pesos, not 3 dollars.
 *     - `*Display` — already converted to the picker's currency.
 *                    What the UI formats.
 *
 *   This component reads `*Display` for every line — storage, Kipio
 *   fee, and total. Switching the currency from USD to COP re-renders
 *   with the COP values of every line, not just the total.
 *
 * Unit persistence
 *   The user's chosen unit (KB / MB / GB / TB) lives in `unit` and is
 *   not reset when `bytes` changes externally (chart click, term
 *   change). Only the numeric field (`rawValue`) updates to reflect
 *   the new value in the current unit.
 *
 * Loading state
 *   While any of the three TanStack queries is in flight:
 *     - Breakdown rows render as a shimmer skeleton (`.skeleton`).
 *     - Mobile total shows a small spinner.
 *     - The `<dl>` carries `aria-live="polite"` + `aria-busy` so
 *       screen readers announce the update once.
 *
 * Unavailable state
 *   When `quote?.storageUsd === null` after the queries settle, the
 *   breakdown shows `—` and the chart shows the `priceUnavailable`
 *   placeholder. In dev, `irys.ts` logs the URL + body that caused it.
 *
 * Fee honesty
 *   `KIPIO_FEE_BPS = 0` today (`kipio_economics` not active). The
 *   `feePreviewNote` line under the breakdown explains the situation
 *   in the active locale. When the contract activates, `KIPIO_FEE_BPS`
 *   becomes positive and the note can be removed with a one-line
 *   change (dictionary key + `<p>` from this component).
 */

const KiB = 1024;
const MiB = 1024 * KiB;
const GiB = 1024 * MiB;
const TiB = 1024 * GiB;

type Unit = "KB" | "MB" | "GB" | "TB";

const UNIT_FACTOR: Record<Unit, number> = {
  KB: KiB,
  MB: MiB,
  GB: GiB,
  TB: TiB,
};

function defaultUnitFor(bytes: number): Unit {
  if (bytes >= TiB) return "TB";
  if (bytes >= GiB) return "GB";
  if (bytes >= MiB) return "MB";
  return "KB";
}

function numericInUnit(bytes: number, unit: Unit): string {
  const value = bytes / UNIT_FACTOR[unit];
  const rounded = Math.round(value * 100) / 100;
  return String(rounded);
}

function formatBytesShort(bytes: number, bcp47: string): string {
  const fmt = new Intl.NumberFormat(bcp47, { maximumFractionDigits: 0 });
  if (bytes >= TiB) return `${fmt.format(bytes / TiB)} TB`;
  if (bytes >= GiB) return `${fmt.format(bytes / GiB)} GB`;
  if (bytes >= MiB) return `${fmt.format(bytes / MiB)} MB`;
  return `${fmt.format(bytes / KiB)} KB`;
}

function useDebouncedValue<T>(value: T, ms: number): T {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const id = setTimeout(() => setDebounced(value), ms);
    return () => clearTimeout(id);
  }, [value, ms]);
  return debounced;
}

export function PricingCard() {
  const { t, locale, format } = useI18n();
  const bcp47 = LOCALE_META[locale].bcp47;

  const [termId, setTermId] = useState<"30d" | "1y" | "forever">("forever");
  const term = useMemo<Term>(
    () =>
      termId === "30d"
        ? { kind: "term", days: 30 }
        : termId === "1y"
          ? { kind: "term", days: 365 }
          : { kind: "permanent" },
    [termId],
  );

  const [bytes, setBytes] = useState<number>(5 * MiB);
  const [unit, setUnit] = useState<Unit>(() => defaultUnitFor(5 * MiB));
  const [rawValue, setRawValue] = useState<string>(() =>
    numericInUnit(5 * MiB, defaultUnitFor(5 * MiB)),
  );

  const skipNextSync = useRef(false);
  useEffect(() => {
    if (skipNextSync.current) {
      skipNextSync.current = false;
      return;
    }
    setRawValue(numericInUnit(bytes, unit));
  }, [bytes, unit]);

  function handleInputChange(v: string) {
    setRawValue(v);
    skipNextSync.current = true;
    const n = Number(v);
    if (Number.isFinite(n) && n >= 0) {
      setBytes(Math.round(n * UNIT_FACTOR[unit]));
    }
  }

  function handleUnitChange(next: Unit) {
    setUnit(next);
    setRawValue(numericInUnit(bytes, next));
    skipNextSync.current = true;
  }

  function handleChartChange(nextBytes: number) {
    setBytes(nextBytes);
  }

  const debouncedBytes = useDebouncedValue(bytes, 250);

  const [currency, setCurrency] = useState<CurrencyCode>(DEFAULT_CURRENCY);

  const { quote, isLoading } = useUploadQuote({
    bytes: debouncedBytes,
    term,
    currency,
  });

  // Read the `*Display` fields — these are already converted to
  // `currency` by `computeQuote`. Formatting the raw `*Usd` fields
  // with `format.currency(..., currency)` would produce the wrong
  // number (e.g. "COP 3" for $3).
  const storageDisplay =
    quote?.storageDisplay != null
      ? format.currency(quote.storageDisplay, currency)
      : t("landing.pricing.pending");
  const feeDisplay =
    quote?.kipioFeeDisplay != null
      ? format.currency(quote.kipioFeeDisplay, currency)
      : t("landing.pricing.pending");
  const totalDisplay =
    quote?.totalDisplay != null
      ? format.currency(quote.totalDisplay, currency)
      : t("landing.pricing.pending");

  const units: { id: Unit; label: string }[] = [
    { id: "KB", label: t("landing.pricing.unitKb") },
    { id: "MB", label: t("landing.pricing.unitMb") },
    { id: "GB", label: t("landing.pricing.unitGb") },
    { id: "TB", label: t("landing.pricing.unitTb") },
  ];

  return (
    <div className="overflow-hidden rounded-card border border-hairline bg-card p-5 sm:p-8">
      {/* Mobile — total protagonista */}
      <div className="mb-5 sm:hidden">
        <p className="label-mono text-muted">{t("landing.pricing.totalLabel")}</p>
        <div className="mt-1 flex items-baseline gap-2">
          <p
            className="font-mono text-[32px] font-semibold leading-none tracking-[-0.03em] text-ink"
            aria-busy={isLoading}
          >
            {isLoading ? "…" : totalDisplay}
          </p>
          {isLoading && <Spinner />}
        </div>
      </div>

      {/* Term segmented */}
      <div
        role="radiogroup"
        aria-label="Storage term"
        className="grid grid-cols-3 gap-1 rounded-button border border-hairline bg-elevated p-1"
      >
        {(["30d", "1y", "forever"] as const).map((id) => {
          const selected = id === termId;
          const label =
            id === "30d"
              ? t("landing.pricing.terms.days30")
              : id === "1y"
                ? t("landing.pricing.terms.year1")
                : t("landing.pricing.terms.forever");
          return (
            <button
              key={id}
              type="button"
              role="radio"
              aria-checked={selected}
              onClick={() => setTermId(id)}
              className={
                "rounded-[10px] px-3 py-2 text-sm font-medium transition-colors " +
                (selected
                  ? "bg-card text-ink ring-1 ring-emerald"
                  : "text-muted hover:text-ink")
              }
            >
              {label}
            </button>
          );
        })}
      </div>

      {/* Size input + unit */}
      <div className="mt-5">
        <div className="mb-2 flex items-baseline justify-between">
          <label htmlFor="pricing-size" className="text-[13px] text-muted">
            {t("landing.pricing.sizeLabel")}
          </label>
        </div>
        <div className="flex min-w-0 items-stretch gap-2">
          <input
            id="pricing-size"
            type="number"
            min={0}
            step="any"
            value={rawValue}
            onChange={(e) => handleInputChange(e.target.value)}
            className="h-10 min-w-0 flex-1 rounded-[10px] border border-hairline bg-elevated px-3 font-mono text-sm text-ink outline-none transition-colors focus:border-emerald"
          />
          <select
            value={unit}
            onChange={(e) => handleUnitChange(e.target.value as Unit)}
            aria-label={t("landing.pricing.sizeLabel")}
            className="h-10 max-w-[80px] shrink-0 rounded-[10px] border border-hairline bg-elevated px-2 font-mono text-sm text-ink outline-none transition-colors focus:border-emerald"
          >
            {units.map((u) => (
              <option key={u.id} value={u.id}>
                {u.label}
              </option>
            ))}
          </select>
        </div>
      </div>

      {/* Chart */}
      <PricingChart
        bytes={bytes}
        storageUsd={quote?.storageUsd ?? null}
        onChange={handleChartChange}
        unavailableLabel={
          isLoading
            ? t("landing.pricing.calculating")
            : t("landing.pricing.priceUnavailable")
        }
        minLabel={formatBytesShort(IRYS_FREE_UPLOAD_BYTES, bcp47)}
        midLabel={formatBytesShort(GiB, bcp47)}
        maxLabel={formatBytesShort(TiB, bcp47)}
      />

      {/* Currency picker */}
      <div className="mt-4 flex min-w-0 items-center justify-between gap-3">
        <span className="min-w-0 text-[13px] text-muted">
          {t("landing.pricing.currencyLabel")}
        </span>
        <CurrencyPicker value={currency} onChange={setCurrency} />
      </div>

      {/* Breakdown */}
      <dl
        className="mt-6 space-y-3 text-sm"
        aria-live="polite"
        aria-busy={isLoading}
      >
        <PriceRow
          label={t("landing.pricing.storageLabel")}
          value={isLoading ? null : storageDisplay}
        />
        <PriceRow
          label={t("landing.pricing.feeLabel")}
          value={isLoading ? null : feeDisplay}
        />
        <PriceRow
          label={t("landing.pricing.totalLabel")}
          value={isLoading ? null : totalDisplay}
          emphasize
        />
      </dl>

      {/* Term fallback note */}
      {quote?.termFallback && (
        <p className="mt-3 text-[11px] leading-[1.5] text-muted-soft">
          {t("landing.pricing.termFallbackNote")}
        </p>
      )}

      {/* Fee preview note */}
      <p className="mt-3 text-[11px] leading-[1.5] text-muted-soft">
        {t("landing.pricing.feePreviewNote")}
      </p>

      {/* Disclaimers */}
      <p className="mt-4 text-[12px] leading-[1.55] text-muted">
        {t("landing.pricing.shorterCostsLess")}
      </p>
      <p className="mt-2 text-[12px] leading-[1.55] text-muted">
        {t("landing.pricing.sponsorNote")}
      </p>
    </div>
  );
}

function PriceRow({
  label,
  value,
  emphasize = false,
}: {
  label: string;
  value: string | null;
  emphasize?: boolean;
}) {
  const isLoading = value === null;
  return (
    <div
      className={
        "flex min-w-0 items-baseline justify-between gap-3 " +
        (emphasize ? "border-t border-hairline pt-3" : "")
      }
    >
      <dt
        className={
          "min-w-0 " + (emphasize ? "font-medium text-ink" : "text-muted")
        }
      >
        {label}
      </dt>
      {isLoading ? (
        <dd className="shrink-0">
          <span className="skeleton inline-block h-4 w-16 rounded" />
        </dd>
      ) : (
        <dd className="shrink-0 text-end font-mono tabular-nums text-ink">
          {value}
        </dd>
      )}
    </div>
  );
}

function Spinner() {
  return (
    <span
      aria-hidden="true"
      className="inline-block h-3.5 w-3.5 animate-spin rounded-full border-2 border-hairline border-t-emerald"
    />
  );
}
