"use client";

/**
 * Upload dialog — native `<dialog>` shell + step switch + OAuth gate.
 *
 * Single source of truth for the flow
 *   `useUploadFlow()` is called exactly ONCE, here. Step components
 *   receive the resulting `flow` object as a prop. If each step
 *   called the hook itself, each would get its own independent
 *   `useState` instance — `UploadReview.start()` would flip only the
 *   review's state, not the dialog's, and the dialog would stay on
 *   the review screen forever. See `upload-review.tsx` header for the
 *   same note from the child side.
 *
 * OAuth gate
 *   Rendered before the step switch. OAuth sessions cannot upload
 *   (ephemeral wallet has no funds, contract requires a real EOA
 *   signature) — the gate explains honestly and offers
 *   "Switch to a wallet" which closes this dialog and opens the
 *   login modal. No silent redirects.
 *
 * Close-block during active flow
 *   `preparing` / `hashing` / `compressing` / `encrypting` /
 *   `funding` / `uploading` / `registering` all represent in-flight
 *   work. During those stages:
 *     - Escape is blocked (`onCancel` → `preventDefault()`).
 *     - Backdrop click is ignored.
 *     - The X button is disabled.
 *   Rationale: the wallet transactions are already broadcast or
 *   about to be. Closing the UI mid-flow would lose progress and
 *   leave the user confused. On `idle` / `kept` / `error` the modal
 *   closes normally.
 *
 * Reset on close
 *   The `close` event listener calls `flow.reset()`. Fires for
 *   programmatic `dialog.close()` (our sync effect) and any other
 *   close path. Revokes preview URLs and returns to `idle` so the
 *   next open starts fresh.
 */
import { useEffect, useRef } from "react";
import { useI18n } from "@context/I18nContext";
import { useWallet } from "@context/WalletContext";
import { useLoginModal } from "@context/LoginModalContext";
import { useUploadDialog } from "@context/UploadDialogContext";
import { useUploadFlow, type UploadStage } from "@hooks/vault/useUploadFlow";
import { LockIcon } from "@components/space/space-icons";
import { stepFromStage } from "./upload-types";
import { UploadReview } from "./upload-review";
import { UploadProgress } from "./upload-progress";
import { UploadKept } from "./upload-kept";

const ACTIVE_STAGES: ReadonlySet<UploadStage> = new Set([
  "preparing",
  "hashing",
  "compressing",
  "encrypting",
  "funding",
  "uploading",
  "registering",
]);

export function UploadDialog() {
  const { t } = useI18n();
  const { session } = useWallet();
  const { openLogin } = useLoginModal();
  const { isOpen, close } = useUploadDialog();

  // Single instance of the flow — passed to step components as a
  // prop. Do NOT call `useUploadFlow()` from inside those components.
  const flow = useUploadFlow();

  // `flowRef` for the `close` listener so it does not re-subscribe on
  // every render (flow identity changes when state changes).
  const flowRef = useRef(flow);
  flowRef.current = flow;

  const dialogRef = useRef<HTMLDialogElement>(null);

  // Sync `<dialog>` visibility with `isOpen`.
  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) return;
    if (isOpen && !dialog.open) dialog.showModal();
    else if (!isOpen && dialog.open) dialog.close();
  }, [isOpen]);

  // Reset flow on any close (X, backdrop, Escape when not blocked,
  // "Open my space"). Keep deps on `close` only — `flowRef.current`
  // gives the latest `reset` without re-subscribing.
  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) return;
    const handleClose = () => {
      close();
      flowRef.current.reset();
    };
    dialog.addEventListener("close", handleClose);
    return () => dialog.removeEventListener("close", handleClose);
  }, [close]);

  const handleCancel = (e: React.SyntheticEvent<HTMLDialogElement>) => {
    // Escape fires `cancel`. Block during active stages.
    if (ACTIVE_STAGES.has(flow.state.stage)) {
      e.preventDefault();
    }
  };

  const handleBackdropClick = (e: React.MouseEvent<HTMLDialogElement>) => {
    if (e.target !== dialogRef.current) return;
    if (ACTIVE_STAGES.has(flow.state.stage)) return;
    close();
  };

  const handleSwitchAccount = () => {
    close();
    openLogin();
  };

  const isActive = ACTIVE_STAGES.has(flow.state.stage);

  // OAuth sessions cannot upload. Gate before the step switch.
  const body = (() => {
    if (session?.kind === "oauth") {
      return (
        <div className="flex flex-col items-center gap-3 py-4 text-center">
          <LockIcon size={28} className="text-muted" />
          <div>
            <h3 className="text-[17px] font-semibold text-ink">
              {t("space.upload.oauthGateTitle")}
            </h3>
            <p className="mt-1.5 max-w-[320px] text-[13px] leading-[1.5] text-muted">
              {t("space.upload.oauthGateBody")}
            </p>
          </div>
          <button
            type="button"
            onClick={handleSwitchAccount}
            className="mt-2 inline-flex h-[44px] items-center justify-center rounded-[12px] bg-emerald px-5 text-[14px] font-semibold text-on-emerald transition-transform duration-200 ease-[cubic-bezier(0.34,1.4,0.5,1)] hover:scale-[1.02]"
          >
            {t("space.upload.oauthGateAction")}
          </button>
        </div>
      );
    }

    const step = stepFromStage(flow.state.stage);
    if (step === "review") {
      return <UploadReview flow={flow} />;
    }
    if (step === "progress") {
      return <UploadProgress flow={flow} />;
    }
    return <UploadKept flow={flow} onClose={close} />;
  })();

  return (
    <dialog
      ref={dialogRef}
      aria-labelledby="upload-dialog-title"
      onCancel={handleCancel}
      onClick={handleBackdropClick}
      className="m-auto max-h-[90dvh] w-[min(92vw,420px)] overflow-visible border-0 bg-transparent p-0 backdrop:bg-black/60"
    >
      <div className="glass relative max-h-[90dvh] overflow-y-auto rounded-[28px] p-6">
        <h2 id="upload-dialog-title" className="sr-only">
          {t("space.upload.dialogTitle")}
        </h2>
        <button
          type="button"
          onClick={close}
          disabled={isActive}
          aria-label={t("space.upload.error.cancel")}
          className="absolute right-4 top-4 grid h-8 w-8 place-items-center rounded-full text-muted transition-colors duration-200 hover:text-ink disabled:cursor-not-allowed disabled:opacity-40"
        >
          <svg
            width="18"
            height="18"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.8"
            strokeLinecap="round"
            aria-hidden="true"
          >
            <path d="M6 6l12 12M18 6L6 18" />
          </svg>
        </button>
        <div className="pt-2">{body}</div>
      </div>
    </dialog>
  );
}
