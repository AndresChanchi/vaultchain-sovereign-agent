"use client";

/**
 * Upload step 3 — success confirmation with per-file references.
 *
 * Content
 *   - Previews row (all successfully uploaded files) with "Kept ✓"
 *     badge overlay.
 *   - "Kept. They are yours." headline + one-line body.
 *   - Three-item checklist, all completed (Locked / Kept / Noted).
 *   - Owner address (shared) + one line per photo:
 *       "Photo 1 · irys://<truncated hash>"
 *       "Photo 2 · irys://<truncated hash>"
 *   - Primary "Open my space" → `reset()` + `onClose()` (parent
 *     dialog closes and the overview shows the new photos already,
 *     because `bump()` fired inside `registerUpload`).
 *   - Ghost "Upload more" → `reset()`, stays in modal (dialog
 *     re-renders review).
 *
 * Top label — `keptStepDone`, not `keptTitle`
 *   The h3 below shows `keptTitle` ("Kept. They are yours."). The
 *   small label at the top of the panel is a step indicator, in the
 *   same slot as `reviewTitle` / `progressTitle` in the earlier
 *   steps. Using `keptTitle` there duplicated the headline in two
 *   different typographic treatments. `keptStepDone` ("Done") is
 *   the correct step label — short, matches the "Step N of N · Done"
 *   pattern from the mockup, does not repeat the success headline.
 *
 * Owner display
 *   Uses `session.address` — the file upload happened under this
 *   identity, so it is the owner of every photo in this batch. Not
 *   per-file because the contract records the caller once.
 *
 * Irys reference truncation
 *   `irysId` is a base58 string ~44 chars. Show first 6 + last 4
 *   (`irys://9xQabc…k2f`) — same visual weight as the mockup and
 *   enough to identify the photo in the gallery later.
 */
import { useI18n } from "@context/I18nContext";
import { useWallet } from "@context/WalletContext";
import type { useUploadFlow } from "@hooks/vault/useUploadFlow";

type UploadKeptProps = {
  /** Called by the primary CTA. The dialog closes and shows overview. */
  flow: ReturnType<typeof useUploadFlow>;
  onClose: () => void;
};

export function UploadKept({ flow, onClose }: UploadKeptProps) {
  const { t } = useI18n();
  const { session } = useWallet();
  const { state, reset } = flow;

  const ownerAddress = session?.address ?? "";
  const ownerShort =
    ownerAddress.length > 0
      ? `${ownerAddress.slice(0, 6)}…${ownerAddress.slice(-4)}`
      : "—";

  const handleOpenSpace = () => {
    reset();
    onClose();
  };

  const handleUploadMore = () => {
    reset();
  };

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between">
        <span className="label-mono text-emerald-text">
          {t("space.upload.keptStepDone")}
        </span>
        <span className="font-mono text-[11px] text-muted">
          {t("space.upload.progressOfTotal", {
            current: state.results.length,
            total: state.totalFiles,
          })}
        </span>
      </div>

      <div className="grid grid-cols-3 gap-2">
        {state.files.map((f, i) => {
          const result = state.results[i];
          return (
            <div
              key={f.id}
              className="relative aspect-square overflow-hidden rounded-[14px]"
            >
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={f.previewUrl}
                alt=""
                className="h-full w-full object-cover"
              />
              {result && (
                <span
                  aria-hidden="true"
                  className="absolute bottom-1.5 right-1.5 grid h-6 w-6 place-items-center rounded-full bg-emerald text-on-emerald"
                >
                  <svg
                    width="14"
                    height="14"
                    viewBox="0 0 24 24"
                    aria-hidden="true"
                  >
                    <path
                      d="M7 12.5l3.5 3.5L17 9"
                      fill="none"
                      stroke="currentColor"
                      strokeWidth="2.5"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                    />
                  </svg>
                </span>
              )}
            </div>
          );
        })}
      </div>

      <div>
        <h3 className="text-[24px] font-bold leading-tight tracking-[-0.02em] text-ink">
          {t("space.upload.keptTitle")}
        </h3>
        <p className="mt-1.5 text-[13px] leading-[1.5] text-muted">
          {t("space.upload.keptBody")}
        </p>
      </div>

      <div className="flex flex-col gap-1">
        <CompletedRow label={t("space.upload.progressItemLocked")} />
        <CompletedRow label={t("space.upload.progressItemKept")} />
        <CompletedRow label={t("space.upload.progressItemNoted")} />
      </div>

      <div className="rounded-[12px] border border-hairline bg-elevated/50 px-3 py-2.5 font-mono text-[11px] leading-[1.7] text-muted">
        <div>
          {t("space.upload.keptOwnerLabel")} {ownerShort}
        </div>
        {state.results.map((r, i) => {
          const id = r.irysId;
          const truncated =
            id.length > 12 ? `${id.slice(0, 6)}…${id.slice(-4)}` : id;
          return (
            <div key={r.hash}>
              {t("space.upload.keptIrysLabel")} {i + 1} · irys://{truncated}
            </div>
          );
        })}
      </div>

      <button
        type="button"
        onClick={handleOpenSpace}
        className="mt-1 inline-flex h-[48px] w-full items-center justify-center rounded-[14px] bg-emerald text-[15px] font-semibold text-on-emerald transition-transform duration-200 ease-[cubic-bezier(0.34,1.4,0.5,1)] hover:scale-[1.01]"
      >
        {t("space.upload.keptOpenSpace")}
      </button>
      <button
        type="button"
        onClick={handleUploadMore}
        className="text-[13px] font-medium text-muted transition-colors hover:text-ink"
      >
        {t("space.upload.keptUploadMore")}
      </button>
    </div>
  );
}

function CompletedRow({ label }: { label: string }) {
  return (
    <div className="flex items-center gap-3 py-1 text-[14px] text-ink">
      <svg
        width="18"
        height="18"
        viewBox="0 0 24 24"
        aria-hidden="true"
        className="flex-none"
      >
        <circle cx="12" cy="12" r="11" fill="var(--color-emerald)" />
        <path
          d="M7 12.5l3.5 3.5L17 9"
          fill="none"
          stroke="var(--color-on-emerald)"
          strokeWidth="2.5"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
      <span>{label}</span>
    </div>
  );
}
