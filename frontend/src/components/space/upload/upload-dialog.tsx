"use client";

/**
 * Upload dialog — 5-step native `<dialog>` shell.
 *
 * Steps (local state, not derived from `flow.state.stage`)
 *   review   file picker + price + Continue
 *   login    sign-in prompt → opens login modal on top
 *   pay      OAuth-only: 3 disabled methods + Wallet → switch
 *   progress pipeline running (flow.start in flight or errored)
 *   kept     success confirmation
 *
 * Why local state, not derived from flow.state.stage
 *   `flow.state.stage` only moves once `flow.start()` is called. The
 *   steps `review`, `login`, and `pay` all live in `stage === "idle"`.
 *   The dialog needs to know which of those three is visible, and
 *   that state is UI, not pipeline. Keeping it local avoids bloating
 *   `useUploadFlow` with UI concerns.
 *
 * Three transitions driven by effects
 *   1. `isOpen` changes → set initial step based on current session
 *      (review for null/wallet, pay for OAuth). Fires on every open.
 *
 *   2. `sessionKind` becomes non-null while `dialogStep === "login"`
 *      → the user completed login. Wallet: load pending files from
 *      IndexedDB, start the flow, advance to progress. OAuth: advance
 *      to pay.
 *
 *   3. `sessionKind` becomes null while in progress/kept/pay → the
 *      user's session dropped (sign out elsewhere). Close + reset to
 *      avoid a zombie flow. Pay resets to login (re-auth).
 *
 *   4. `flow.state.stage === "kept"` while in progress → advance to
 *      kept.
 *
 * Single instance of useUploadFlow
 *   The hook is called exactly ONCE here. Step components receive
 *   `flow` as prop. If each step called the hook itself, each would
 *   hold its own `useState` — `flow.start()` from review would not
 *   move the dialog's stage.
 *
 * IndexedDB — the login persistence mechanism
 *   When Continue is clicked without a session, the raw `File[]` is
 *   saved to IndexedDB. After OAuth redirect and return, the dialog
 *   loads those files back and starts the flow automatically. TTL 1
 *   hour. See `lib/upload/pending-uploads.ts`.
 *
 * Close-block during active flow
 *   `preparing` through `registering` are in-flight. X disabled,
 *   Escape `preventDefault`, backdrop click ignored. Reset on close
 *   is triggered by the `close` listener.
 *
 * OAuth cannot upload
 *   The pay step is the honest boundary. The only live route is
 *   "Switch to a wallet", which disconnects the OAuth session and
 *   reopens the login modal. The current MVP contract has no account
 *   abstraction for OAuth identities — that arrives with the new
 *   contracts.
 */
import { useEffect, useRef, useState } from "react";
import { useI18n } from "@context/I18nContext";
import { useWallet } from "@context/WalletContext";
import { useLoginModal } from "@context/LoginModalContext";
import { useUploadDialog } from "@context/UploadDialogContext";
import { useUploadFlow, type UploadStage } from "@hooks/vault/useUploadFlow";
import {
  clearPendingUploads,
  loadPendingUploads,
  savePendingUploads,
} from "@lib/upload/pending-uploads";
import { UploadReview } from "./upload-review";
import { UploadLoginStep } from "./upload-login-step";
import { UploadPayStep } from "./upload-pay-step";
import { UploadProgress } from "./upload-progress";
import { UploadKept } from "./upload-kept";
import type { UploadStep } from "./upload-types";

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
  const { session, disconnect } = useWallet();
  const { openLogin } = useLoginModal();
  const { isOpen, close } = useUploadDialog();

  const flow = useUploadFlow();

  const flowRef = useRef(flow);
  flowRef.current = flow;

  const sessionKind = session?.kind ?? null;
  const flowStage = flow.state.stage;

  const dialogRef = useRef<HTMLDialogElement>(null);
  const [dialogStep, setDialogStep] = useState<UploadStep>("review");

  // Sync `<dialog>` visibility with `isOpen`.
  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) return;
    if (isOpen && !dialog.open) dialog.showModal();
    else if (!isOpen && dialog.open) dialog.close();
  }, [isOpen]);

  // Reset flow + step on any close path (X, backdrop, Escape allowed,
  // programmatic close, "Open my space").
  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) return;
    const handleClose = () => {
      close();
      flowRef.current.reset();
      setDialogStep("review");
      void clearPendingUploads();
    };
    dialog.addEventListener("close", handleClose);
    return () => dialog.removeEventListener("close", handleClose);
  }, [close]);

  // Set initial step on every fresh open. Wallet or null session →
  // review. OAuth → pay (nothing to review; the flow cannot proceed
  // past pay without a wallet).
  useEffect(() => {
    if (!isOpen) return;
    setDialogStep(sessionKind === "oauth" ? "pay" : "review");
  }, [isOpen]); // eslint-disable-line react-hooks/exhaustive-deps

  // Transition login → progress (wallet) / pay (OAuth) after auth.
  useEffect(() => {
    if (dialogStep !== "login") return;
    if (sessionKind === null) return;

    if (sessionKind === "wallet") {
      let cancelled = false;
      void loadPendingUploads().then((files) => {
        if (cancelled) return;
        if (files && files.length > 0) {
          setDialogStep("progress");
          void flowRef.current.start(files);
          void clearPendingUploads();
        } else {
          setDialogStep("review");
        }
      });
      return () => {
        cancelled = true;
      };
    }

    setDialogStep("pay");
  }, [dialogStep, sessionKind]);

  // Session dropped mid-flow — defensive reset. Not the common path,
  // but avoids a zombie dialog when the user signs out elsewhere.
  useEffect(() => {
    if (sessionKind !== null) return;
    if (dialogStep === "progress" || dialogStep === "kept") {
      close();
      flowRef.current.reset();
      setDialogStep("review");
    } else if (dialogStep === "pay") {
      setDialogStep("login");
    }
  }, [sessionKind, dialogStep, close]);

  // Pipeline reached `kept` → move from progress to kept.
  useEffect(() => {
    if (flowStage === "kept" && dialogStep === "progress") {
      setDialogStep("kept");
    }
  }, [flowStage, dialogStep]);

  const handleCancel = (e: React.SyntheticEvent<HTMLDialogElement>) => {
    if (ACTIVE_STAGES.has(flowStage)) {
      e.preventDefault();
    }
  };

  const handleBackdropClick = (e: React.MouseEvent<HTMLDialogElement>) => {
    if (e.target !== dialogRef.current) return;
    if (ACTIVE_STAGES.has(flowStage)) return;
    close();
  };

  const handleReviewContinue = async (files: File[]) => {
    if (!session) {
      await savePendingUploads(files);
      setDialogStep("login");
      openLogin({ returnTo: "/" });
      return;
    }
    if (session.kind === "wallet") {
      setDialogStep("progress");
      void flowRef.current.start(files);
      void clearPendingUploads();
      return;
    }
    // OAuth — save so "Switch to a wallet" can restore files later.
    await savePendingUploads(files);
    setDialogStep("pay");
  };

  const handleSignIn = () => {
    openLogin({ returnTo: "/" });
  };

  const handleSwitchToWallet = () => {
    disconnect();
    openLogin({ returnTo: "/" });
  };

  const handleRetry = () => {
    flowRef.current.reset();
    setDialogStep("review");
  };

  const isActive = ACTIVE_STAGES.has(flowStage);

  const body = (() => {
    switch (dialogStep) {
      case "review":
        return <UploadReview onContinue={handleReviewContinue} />;
      case "login":
        return (
          <UploadLoginStep
            onSignIn={handleSignIn}
            onBack={() => setDialogStep("review")}
          />
        );
      case "pay":
        return (
          <UploadPayStep
            onSwitchToWallet={handleSwitchToWallet}
            onBack={() => setDialogStep("review")}
          />
        );
      case "progress":
        return <UploadProgress flow={flow} onRetry={handleRetry} />;
      case "kept":
        return <UploadKept flow={flow} onClose={close} />;
    }
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
