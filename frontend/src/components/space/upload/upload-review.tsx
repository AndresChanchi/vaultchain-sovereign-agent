"use client";

/**
 * Upload step 1 — review the batch before committing.
 *
 * Sub-states
 *   - Empty (0 files): a large dashed dropzone that opens the native
 *     file picker. Uses the same visual language as the landing's
 *     upload CTA, so the two flows feel consistent.
 *   - Filled: previews row (72×72 thumbnails + "+" to add more),
 *     locked-note, term selector, price breakdown, Continue.
 *
 * Local file state
 *   `useUploadFlow.state.files` is empty until `start()` runs. The
 *   review keeps its OWN local list (with previewUrls) for the
 *   pre-commit UI. When Continue is clicked, the raw `File[]` is
 *   passed to `start()` — the flow creates its own preview URLs for
 *   the progress / kept steps. Review unmounts when the flow starts,
 *   its useEffect cleanup revokes its local URLs.
 *
 * Terms selector
 *   Forever is active. 30 days / 1 year are disabled with an honest
 *   tooltip ("Only with the new contract"). When the new contracts
 *   activate, dropping the `disabled` flag enables them without
 *   changing the layout.
 *
 * Price
 *   `useUploadQuote({ bytes, term: "permanent", currency: "USD" })`
 *   reuses the landing's pricing engine. `bytes` is the sum of the
 *   raw file sizes — an upper bound because compression happens in
 *   the flow. The actual cost is re-queried during upload with the
 *   real encrypted size.
 *
 *   Formatting lives in a local `formatUSD` helper (below) instead of
 *   `@lib/i18n/format` so this component has zero coupling to the
 *   i18n format API. The review always shows USD — the currency
 *   picker is a landing-only surface; the upload modal shows the
 *   network-denominated price for maximum clarity.
 *
 * OAuth
 *   The dialog gates OAuth BEFORE mounting this component (10.4).
 *   Review assumes a wallet session and does not check again.
 */
import { useCallback, useEffect, useRef, useState } from "react";
import { useI18n } from "@context/I18nContext";
import type { useUploadFlow } from "@hooks/vault/useUploadFlow";
import { useUploadQuote } from "@hooks/pricing/useUploadQuote";
import { DEFAULT_CURRENCY, type CurrencyCode } from "@config/pricing";
import type { Term } from "@lib/pricing/types";
import { PlusIcon } from "@components/space/space-icons";
import { MAX_BATCH_SIZE } from "./upload-types";

type LocalFile = {
  id: string;
  file: File;
  previewUrl: string;
};

type UploadReviewProps = {
  flow: ReturnType<typeof useUploadFlow>;
};

/**
 * Only `permanent` is active today. The other two are visible but
 * disabled — the current contract stores every upload "forever" with
 * no term concept.
 */
const TERM: Term = { kind: "permanent" };
const CURRENCY: CurrencyCode = DEFAULT_CURRENCY;

const USD_2DP = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD",
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

const USD_4DP = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD",
  minimumFractionDigits: 4,
  maximumFractionDigits: 4,
});

/**
 * Format a USD amount. Uses 4 decimals under $0.01 so a real
 * storage cost (e.g. $0.003) does not collapse to "$0.00" — the
 * whole point of showing the price is that it is honest about the
 * number.
 */
function formatUSD(value: number | null | undefined): string {
  if (value === null || value === undefined) return "—";
  if (value > 0 && value < 0.01) return USD_4DP.format(value);
  return USD_2DP.format(value);
}

export function UploadReview({ flow }:UploadReviewProps) {
  const { t } = useI18n();

  const [files, setFiles] = useState<LocalFile[]>([]);
  const filesRef = useRef<LocalFile[]>(files);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    filesRef.current = files;
  }, [files]);

  // Revoke every local preview URL when review unmounts (Continue,
  // cancel, or page nav). The flow owns its own URLs.
  useEffect(() => {
    return () => {
      for (const f of filesRef.current) {
        URL.revokeObjectURL(f.previewUrl);
      }
    };
  }, []);

  const handleFilesPicked = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const picked = e.target.files;
      if (!picked) return;

      const room = MAX_BATCH_SIZE - files.length;
      const additions: LocalFile[] = [];
      for (let i = 0; i < picked.length && additions.length < room; i++) {
        const file = picked[i];
        if (!file) continue;
        if (!file.type.startsWith("image/")) continue;
        additions.push({
          id: crypto.randomUUID(),
          file,
          previewUrl: URL.createObjectURL(file),
        });
      }

      if (additions.length > 0) {
        setFiles((prev) => [...prev, ...additions]);
      }

      // Reset input value so selecting the same file again fires
      // onChange (browsers de-dupe by value otherwise).
      e.target.value = "";
    },
    [files.length],
  );

  const handleRemove = useCallback((id: string) => {
    setFiles((prev) => {
      const target = prev.find((f) => f.id === id);
      if (target) URL.revokeObjectURL(target.previewUrl);
      return prev.filter((f) => f.id !== id);
    });
  }, []);

  const totalBytes = files.reduce((sum, f) => sum + f.file.size, 0);

  const { quote } = useUploadQuote({
    bytes: totalBytes,
    term: TERM,
    currency: CURRENCY,
    enabled: totalBytes > 0,
  });

  const handleContinue = useCallback(() => {
    if (files.length === 0) return;
    const raw = files.map((f) => f.file);
    // Flow will own its own preview URLs; drop our locals now.
    for (const f of files) URL.revokeObjectURL(f.previewUrl);
    setFiles([]);
    void flow.start(raw);
  }, [files, flow]);

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between">
        <span className="label-mono text-emerald-text">
          {t("space.upload.reviewTitle")}
        </span>
        <span className="font-mono text-[11px] text-muted">
          {t("space.upload.reviewOfTotal", {
            current: files.length,
            total: MAX_BATCH_SIZE,
          })}
        </span>
      </div>

      {/* Files row / empty dropzone */}
      {files.length === 0 ? (
        <button
          type="button"
          onClick={() => inputRef.current?.click()}
          className="flex h-[180px] w-full flex-col items-center justify-center gap-2 rounded-[14px] border-[1.5px] border-dashed border-emerald/55 bg-emerald/[0.06] text-center transition-colors hover:border-emerald/80 hover:bg-emerald/[0.10]"
        >
          <span className="text-[15px] font-medium text-ink">
            {t("space.upload.button")}
          </span>
          <span className="font-mono text-[11px] text-muted">
            {t("space.upload.reviewOfTotal", {
              current: 0,
              total: MAX_BATCH_SIZE,
            })}
          </span>
        </button>
      ) : (
        <div className="flex flex-wrap gap-2">
          {files.map((f) => (
            <div
              key={f.id}
              className="group relative h-[72px] w-[72px] overflow-hidden rounded-[14px]"
            >
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={f.previewUrl}
                alt=""
                className="h-full w-full object-cover"
              />
              <button
                type="button"
                onClick={() => handleRemove(f.id)}
                aria-label={t("space.upload.error.cancel")}
                className="absolute right-1 top-1 grid h-5 w-5 place-items-center rounded-full bg-black/60 text-[13px] leading-none text-white opacity-0 transition-opacity group-hover:opacity-100 focus-visible:opacity-100"
              >
                ×
              </button>
            </div>
          ))}
          {files.length < MAX_BATCH_SIZE && (
            <button
              type="button"
              onClick={() => inputRef.current?.click()}
              className="grid h-[72px] w-[72px] place-items-center rounded-[14px] border-[1.5px] border-dashed border-hairline text-muted transition-colors hover:border-emerald/50 hover:text-ink"
              aria-label={t("space.upload.button")}
            >
              <PlusIcon size={22} />
            </button>
          )}
        </div>
      )}

      <input
        ref={inputRef}
        type="file"
        accept="image/*"
        multiple
        className="hidden"
        onChange={handleFilesPicked}
      />

      {files.length > 0 && (
        <>
          <p className="flex items-center gap-2 font-mono text-[12px] text-muted">
            <span
              aria-hidden="true"
              className="h-1.5 w-1.5 rounded-full bg-emerald"
            />
            {t("space.upload.reviewLockedNote")}
          </p>

          <div>
            <p className="mb-2 font-mono text-[11px] uppercase tracking-[0.12em] text-muted">
              {t("space.upload.reviewTermsLabel")}
            </p>
            <div className="grid grid-cols-3 gap-2">
              <DisabledTerm
                label={t("space.upload.reviewTerm30")}
                hint={t("space.upload.reviewTermFutureHint")}
              />
              <DisabledTerm
                label={t("space.upload.reviewTerm1y")}
                hint={t("space.upload.reviewTermFutureHint")}
              />
              <div className="rounded-[14px] border border-emerald bg-emerald/[0.08] px-2 py-2.5 text-center">
                <div className="text-[13px] font-medium text-ink">
                  {t("space.upload.reviewTermForever")}
                </div>
              </div>
            </div>
            <p className="mt-2 text-[12px] leading-[1.5] text-muted">
              {t("space.upload.reviewTermsHint")}
            </p>
          </div>

          <div className="border-t border-hairline pt-3">
            <div className="flex justify-between py-1.5 text-[14px] text-muted">
              <span>{t("space.upload.reviewStorageLabel")}</span>
              <span className="font-mono text-ink">
                {formatUSD(quote?.storageDisplay)}
              </span>
            </div>
            <div className="flex justify-between py-1.5 text-[14px] text-muted">
              <span>{t("space.upload.reviewFeeLabel")}</span>
              <span className="font-mono text-ink">
                {formatUSD(quote?.kipioFeeDisplay)}
              </span>
            </div>
            <div className="mt-1 flex items-baseline justify-between border-t border-hairline pt-3">
              <span className="text-[15px] font-semibold text-ink">
                {t("space.upload.reviewTotalLabel")}
              </span>
              <span className="font-mono text-[17px] font-semibold text-ink">
                {formatUSD(quote?.totalDisplay)}
              </span>
            </div>
            <p className="mt-1 text-[12px] text-muted">
              {t("space.upload.reviewEachPhotoNote")}
            </p>
          </div>
        </>
      )}

      <button
        type="button"
        onClick={handleContinue}
        disabled={files.length === 0}
        className="mt-2 inline-flex h-[48px] w-full items-center justify-center rounded-[14px] bg-emerald text-[15px] font-semibold text-on-emerald transition-transform duration-200 ease-[cubic-bezier(0.34,1.4,0.5,1)] hover:scale-[1.01] disabled:cursor-not-allowed disabled:opacity-50 disabled:hover:scale-100"
      >
        {t("space.upload.reviewContinue")}
      </button>
    </div>
  );
}

/**
 * Disabled term card. Kept as a separate component so the tooltip
 * + disabled styling stay in one place when the future terms
 * activate.
 */
function DisabledTerm({ label, hint }: { label: string; hint: string }) {
  return (
    <div
      title={hint}
      aria-disabled="true"
      className="cursor-not-allowed rounded-[14px] border border-hairline bg-card px-2 py-2.5 text-center opacity-50"
    >
      <div className="text-[13px] font-medium text-muted">{label}</div>
      <div className="mt-0.5 font-mono text-[10px] uppercase tracking-[0.1em] text-muted/70">
        {hint}
      </div>
    </div>
  );
}
