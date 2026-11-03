"use client";

/**
 * Upload step 2 — pipeline progress with a live preview of the file
 * currently being processed.
 *
 * Error state
 *   When `state.stage === "error"`, renders a card with the translated
 *   error + a retry button. Retry calls `reset()` → stage goes back
 *   to `idle` → the dialog re-renders review (empty, user re-picks).
 *   Preserving the failed file list across retry would need a state
 *   change in `useUploadFlow`; on the old contract, re-picking the
 *   same files produces the same result, so a full restart is
 *   acceptable.
 *
 * Checklist — reordered honestly
 *   Locked → Kept → Noted. See `stageToChecklist` for the rationale.
 *   Each row renders one of three states:
 *     completed (✓)  | active (spinner)  | pending (hollow)
 *   `funding` and `preparing` show "Waiting for approval…" between
 *   rows because they correspond to a wallet popup with no visible
 *   duration.
 *
 * Preview
 *   Uses `state.files[state.currentIndex]?.previewUrl` — the URL was
 *   created by `useUploadFlow.start()` and lives until `reset()`.
 *   The scan overlay (`className="scan"`) signals "work in progress"
 *   without telling the user what stage of the pipeline is running.
 */
import { useI18n } from "@context/I18nContext";
import type { useUploadFlow } from "@hooks/vault/useUploadFlow";
import {
  errorToDictKey,
  stageToChecklist,
  stageToPercent,
  type ChecklistItem,
} from "./upload-types";

type UploadProgressProps = {
  flow: ReturnType<typeof useUploadFlow>;
};

export function UploadProgress({ flow }: UploadProgressProps) {
  const { t } = useI18n();
  const { state, reset } = flow;

  if (state.stage === "error") {
    return (
      <div className="flex flex-col items-center gap-4 py-6 text-center">
        <div className="grid h-12 w-12 place-items-center rounded-full bg-danger/15 text-danger-text">
          <span className="text-[24px] leading-none">!</span>
        </div>
        <p className="text-[15px] font-medium text-ink">
          {t(errorToDictKey(state.error))}
        </p>
        <button
          type="button"
          onClick={reset}
          className="mt-2 inline-flex h-[44px] items-center justify-center rounded-[12px] bg-emerald px-6 text-[14px] font-semibold text-on-emerald"
        >
          {t("space.upload.error.retry")}
        </button>
      </div>
    );
  }

  const current = state.files[state.currentIndex];
  const checklist = stageToChecklist(state.stage);
  const percent = stageToPercent(
    state.stage,
    state.currentIndex,
    state.totalFiles,
  );

  const showWaiting =
    state.stage === "preparing" || state.stage === "funding";

  const currentLabel = state.currentFileName
    ? t("space.upload.progressCurrentFile", {
        name: state.currentFileName,
      })
    : t("space.upload.progressTitle");

  const ofTotal =
    state.totalFiles > 0
      ? t("space.upload.progressOfTotal", {
          current: state.currentIndex + 1,
          total: state.totalFiles,
        })
      : "";

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between">
        <span className="label-mono text-emerald-text">
          {t("space.upload.progressTitle")}
        </span>
        <span className="font-mono text-[11px] text-muted">{ofTotal}</span>
      </div>

      {current && (
        <div className="relative h-[200px] w-full overflow-hidden rounded-[16px]">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={current.previewUrl}
            alt=""
            className="h-full w-full object-cover opacity-60 blur-[2px]"
          />
          <div className="scan" />
        </div>
      )}

      <div>
        <p className="text-[17px] font-semibold leading-tight text-ink">
          {currentLabel}
        </p>
      </div>

      <div className="flex flex-col gap-1">
        <ChecklistRow
          label={t("space.upload.progressItemLocked")}
          state={rowState("locked", checklist)}
        />
        <ChecklistRow
          label={t("space.upload.progressItemKept")}
          state={rowState("kept", checklist)}
        />
        <ChecklistRow
          label={t("space.upload.progressItemNoted")}
          state={rowState("noted", checklist)}
        />
      </div>

      {showWaiting && (
        <p className="flex items-center gap-2 font-mono text-[12px] text-muted">
          <span className="spn" aria-hidden="true" />
          {t("space.upload.progressWaiting")}
        </p>
      )}

      <div className="h-1 w-full overflow-hidden rounded-full bg-hairline">
        <div
          className="h-full rounded-full bg-emerald transition-[width] duration-500 ease-[cubic-bezier(0.2,0.8,0.2,1)]"
          style={{ width: `${percent}%` }}
        />
      </div>

      <p className="text-center text-[12px] text-muted">
        {t("space.upload.progressKeepOpen")}
      </p>
    </div>
  );
}

type RowState = "completed" | "active" | "pending";

function rowState(
  item: ChecklistItem,
  progress: ReturnType<typeof stageToChecklist>,
): RowState {
  if (progress.completed.includes(item)) return "completed";
  if (progress.active === item) return "active";
  return "pending";
}

function ChecklistRow({ label, state }: { label: string; state: RowState }) {
  return (
    <div className="flex items-center gap-3 py-1 text-[14px]">
      {state === "completed" && (
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
      )}
      {state === "active" && <span className="spn flex-none" aria-hidden="true" />}
      {state === "pending" && (
        <span
          aria-hidden="true"
          className="h-[18px] w-[18px] flex-none rounded-full border border-hairline"
        />
      )}
      <span
        className={
          state === "pending" ? "text-muted" : "text-ink"
        }
      >
        {label}
      </span>
    </div>
  );
}
